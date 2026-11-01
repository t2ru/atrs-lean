#!/usr/bin/env python3
"""マスタの Mapper の文とコードリストの SQL を PostgreSQL で実行し、結果を conformance/sql/master-data.json に書き出す
（backlog 25f7、ADR c108）。lake test（Tests.MasterSql）が、同じ表の行から SourceModel.Repository.* を評価して照合する。

- 上流の DDL とシード（00100・00200・00210・00220・00240・00250）を、新しいデータベースに投入する。
  00240 のピーク時期と 00250 のフライトは投入日 2026-11-01 で展開する（current_timestamp・current_date を置き換える。ADR 9ee4）。
- 空席照会の文 FlightRepository#findByVacantSeatSearchCriteria を、条件の一覧（FLIGHT_CRITERIA）で実行し、
  結果を conformance/sql/flight-search.json に書き出す（backlog 0be7 の第 2 段）。動的 SQL（<foreach>・#{…}）は、
  この文に限って、束縛する値をリテラルにして描画する。投入した FLIGHT 表は書き出さず、要約（行数・整列した全行の md5）を
  生成器 tools/conformance/flight_seed.py の展開と照合し、あわせて生成順の全行の多項式ハッシュ（lake test が
  SourceModel.Db.FlightSeed と照合する）を書く。
- 文の SQL は、上流の Mapper の XML と AtrsCodeListConfig.java から抜き出したものをそのまま使う。
- PostgreSQL への接続は .agents/skills/spec-pivot/scripts/ci/with_postgres.sh が与える（照合順序 C・UTF8・UTC）。

  .agents/skills/spec-pivot/scripts/ci/with_postgres.sh uv run python -I tools/conformance/master_sql.py [--check] [--expect-version 16.15]
"""
import csv
import hashlib
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATRS = ROOT / "upstream/atrs/JavaConfig-Thymeleaf/atrs"
SQLS = ATRS / "atrs-initdb/src/sqls/integration-test-postgres"
MAPPERS = ATRS / "atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository"
CODELIST = ATRS / "atrs-domain/src/main/java/jp/co/ntt/atrs/config/app/AtrsCodeListConfig.java"
OUT = ROOT / "conformance/sql/master-data.json"
FLIGHT_OUT = ROOT / "conformance/sql/flight-search.json"
LOAD_DATE = "DATE '2026-11-01'"
DB = "atrs_master_sql"
LOAD_TIMESTAMP = "TIMESTAMP '2026-11-01 00:00:00'"
NULL = "\\N"

TABLES = ["AIRPORT", "ROUTE", "FLIGHT_MASTER", "BOARDING_CLASS", "FARE_TYPE", "PEAK_TIME", "PLANE", "CREDIT_TYPE"]
# （文の ID, ロケータ, Mapper の XML, select の id）
MAPPER_STATEMENTS = [
    ("route.findAll", "sql:jp.co.ntt.atrs.domain.repository.route.RouteRepository#findAll", "route/RouteRepository.xml", "findAll"),
    ("flight.findAllFlightMaster", "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findAllFlightMaster",
     "flight/FlightRepository.xml", "findAllFlightMaster"),
    ("boardingclass.findAll", "sql:jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository#findAll",
     "boardingclass/BoardingClassRepository.xml", "findAll"),
    ("faretype.findAll", "sql:jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository#findAll",
     "faretype/FareTypeRepository.xml", "findAll"),
    ("peaktime.findAll", "sql:jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository#findAll",
     "peaktime/PeakTimeRepository.xml", "findAll"),
]
CODELISTS = ["CL_AIRPORT", "CL_BOARDINGCLASS", "CL_FARETYPE", "CL_CREDITTYPE"]


def run(args, sql=None, db=DB):
    env = dict(os.environ, PGTZ="UTC", PGCLIENTENCODING="UTF8", PGDATABASE=db)
    r = subprocess.run(["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1"] + args, input=sql, capture_output=True,
                       text=True, encoding="utf-8", env=env)
    if r.returncode != 0:
        sys.exit(f"master_sql: psql failed: {r.stderr.strip()}")
    return r.stdout


def query(sql, db=DB):
    """（列名, 行）。値は文字列（NULL は None）。"""
    out = run(["--csv", "-P", f"null={NULL}", "-c", sql], db=db)
    rows = list(csv.reader(io.StringIO(out)))
    cols, body = rows[0], rows[1:]
    return cols, [[None if v == NULL else v for v in r] for r in body]


def mapper_sql(path, sid):
    root = ET.parse(MAPPERS / path).getroot()
    for el in root.iter("select"):
        if el.get("id") == sid:
            if len(list(el)) != 0:
                sys.exit(f"master_sql: {path}#{sid} has dynamic SQL (not supported)")
            return " ".join((el.text or "").split())
    sys.exit(f"master_sql: {path}#{sid} not found")


def literal(v):
    """束縛する値の SQL のリテラル（型は MyBatis の型ハンドラに合わせる）。"""
    kind, x = v
    if kind == "text":
        return "'" + x.replace("'", "''") + "'"
    if kind == "date":
        return f"DATE '{x}'"
    if kind == "bigint":
        return f"CAST({int(x)} AS bigint)"
    sys.exit(f"master_sql: unknown parameter kind {kind}")


def render_vacant_seat_sql(params):
    """findByVacantSeatSearchCriteria の <foreach> と #{…} を、束縛する値のリテラルにして描画する。"""
    root = ET.parse(MAPPERS / "flight/FlightRepository.xml").getroot()
    el = next((e for e in root.iter("select") if e.get("id") == "findByVacantSeatSearchCriteria"), None)
    if el is None:
        sys.exit("master_sql: findByVacantSeatSearchCriteria not found")
    parts = [el.text or ""]
    for child in el:
        if child.tag != "foreach" or child.get("collection") != "criteria.fareTypeList" or child.get("item") != "fareType":
            sys.exit(f"master_sql: unexpected dynamic SQL element <{child.tag}>")
        body = (child.text or "").strip()
        if body != "#{fareType}" or not params["fareTypeList"]:
            sys.exit("master_sql: unexpected <foreach> body or empty list")
        items = [literal(("text", t)) for t in params["fareTypeList"]]
        parts.append(child.get("open") + child.get("separator").join(items) + child.get("close"))
        parts.append(child.tail or "")
    sql = " ".join("".join(parts).split())
    names = {"criteria.route.departureAirport.code": ("text", params["depAirportCd"]),
             "criteria.route.arrivalAirport.code": ("text", params["arrAirportCd"]),
             "criteria.depDate": ("date", params["depDate"]),
             "criteria.boardingClass": ("text", params["boardingClass"]),
             "criteria.beforeDayNum": ("bigint", params["beforeDayNum"])}
    for k, v in names.items():
        if "#{" + k + "}" not in sql:
            sys.exit(f"master_sql: #{{{k}}} not in findByVacantSeatSearchCriteria")
        sql = sql.replace("#{" + k + "}", literal(v))
    if "#{" in sql:
        sys.exit(f"master_sql: unbound parameter in {sql}")
    return sql


ONE_WAY = ["OW", "RD1", "RD7", "ED", "LD", "GD", "SOW", "SRD"]
ROUND_TRIP = ["RT", "SRT"]
# 空席照会の条件の一覧: (ID, 出発日, 出発空港, 到着空港, 搭乗クラス, beforeDayNum, 運賃種別の列)。beforeDayNum は、
# 今日を投入日〜期間の末日のどれかとしたときの、出発日までの日数（原典の照会で到達する組み合わせ）
FLIGHT_CRITERIA = [
    ("first-HND-ITM-N-OW-0", "2026-11-01", "HND", "ITM", "N", 0, ONE_WAY),
    ("first-HND-ITM-N-RT-0", "2026-11-01", "HND", "ITM", "N", 0, ROUND_TRIP),
    ("d10-HND-ITM-N-OW-10", "2026-11-11", "HND", "ITM", "N", 10, ONE_WAY),
    ("d10-HND-ITM-S-OW-10", "2026-11-11", "HND", "ITM", "S", 10, ONE_WAY),
    ("d1-HND-OKA-N-OW-1", "2026-11-02", "HND", "OKA", "N", 1, ONE_WAY),
    ("d7-OKA-HND-N-OW-7", "2026-11-08", "OKA", "HND", "N", 7, ONE_WAY),
    ("d30-ITM-HND-N-OW-30", "2026-12-01", "ITM", "HND", "N", 30, ONE_WAY),
    ("d60-KIX-SPK-S-OW-60", "2026-12-31", "KIX", "SPK", "S", 60, ONE_WAY),
    ("d61-SPK-KIX-N-OW-61", "2027-01-01", "SPK", "KIX", "N", 61, ONE_WAY),
    ("d90-KIX-HND-N-RT-90", "2027-01-30", "KIX", "HND", "N", 90, ROUND_TRIP),
    ("d5-HND-ITM-S-RT-5", "2026-11-06", "HND", "ITM", "S", 5, ROUND_TRIP),
    ("last-OKA-HND-N-OW-0", "2027-03-01", "OKA", "HND", "N", 0, ONE_WAY),
    ("emptyroute-HND-FUK-N-OW-5", "2026-11-06", "HND", "FUK", "N", 5, ONE_WAY),
    ("noflight-HND-ITM-N-OW-0", "2027-03-02", "HND", "ITM", "N", 0, ONE_WAY),
    ("noroute-HND-NGO-N-OW-5", "2026-11-06", "HND", "NGO", "N", 5, ONE_WAY),
]

POLY_MOD = (1 << 61) - 1


def poly_hash(text):
    """文字列の多項式ハッシュ（h = h * 31 + 符号位置、法 2^61 − 1）。Tests.FlightSql と同じ。"""
    h = 0
    for c in text:
        h = (h * 31 + ord(c)) % POLY_MOD
    return h


def flight_seed_module():
    spec = importlib.util.spec_from_file_location("flight_seed", ROOT / "tools/conformance/flight_seed.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def flight_search(upstream):
    """FLIGHT の要約の照合と、空席照会の文の実行。"""
    rows = flight_seed_module().expand()
    canon = [f"{d.isoformat()},{n},{b},{f},{v}" for d, n, b, f, v in rows]
    expect_md5 = hashlib.md5(";".join(sorted(canon)).encode("utf-8")).hexdigest()
    _, got = query("SELECT count(*), md5(string_agg(to_char(departure_date, 'YYYY-MM-DD') || ',' || flight_name || ',' || "
                   "boarding_class_cd || ',' || fare_type_cd || ',' || vacant_num, ';' "
                   "ORDER BY (to_char(departure_date, 'YYYY-MM-DD') || ',' || flight_name || ',' || boarding_class_cd || ',' "
                   "|| fare_type_cd || ',' || vacant_num) COLLATE \"C\")) FROM flight")
    if int(got[0][0]) != len(rows) or got[0][1] != expect_md5:
        sys.exit(f"master_sql: FLIGHT after 00250 ({got[0][0]} rows, md5 {got[0][1]}) differs from flight_seed.py "
                 f"({len(rows)} rows, md5 {expect_md5})")
    statements = []
    for sid, dep_date, dep, arr, bc, before, fts in FLIGHT_CRITERIA:
        params = {"fareTypeList": fts, "depAirportCd": dep, "arrAirportCd": arr, "depDate": dep_date,
                  "boardingClass": bc, "beforeDayNum": before}
        sql = render_vacant_seat_sql(params)
        cols, out = query(sql)
        statements.append({"id": sid, "locator": "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria",
                           "params": params, "sql": sql, "ordered": True, "columns": cols, "rows": out})
    return {
        "note": "空席照会の文 findByVacantSeatSearchCriteria の PostgreSQL での実行結果（tools/conformance/master_sql.py が生成する。"
                "手で編集しない）。マスタの表は master-data.json の tables と同じ投入による。FLIGHT 表は 00250 を投入日で実行したもので、"
                "flightSeed は行数・整列した全行の md5（生成器の展開と照合済み）と、生成順の全行の多項式ハッシュ",
        "upstream": {"release": upstream["release"], "commit": upstream["commit"]},
        "postgresql": upstream["languages"]["postgresql"]["version"],
        "loadDate": "2026-11-01",
        "flightSeed": {"rows": len(rows), "md5": expect_md5, "polyHash": poly_hash("".join(c + "\n" for c in canon))},
        "statements": statements,
    }


def codelist_sql(bean):
    text = CODELIST.read_text(encoding="utf-8")
    m = re.search(r'@Bean\("' + bean + r'"\).*?setQuerySql\(\s*"([^"]*)"\s*\)', text, re.S)
    if not m:
        sys.exit(f"master_sql: {bean}: query SQL not found")
    return m.group(1)


def load():
    run(["-c", f"DROP DATABASE IF EXISTS {DB}"], db="postgres")
    run(["-c", f"CREATE DATABASE {DB}"], db="postgres")
    for f in ["00100_create_all_tables.sql", "00200_insert_fixed_value.sql", "00210_insert_route.sql",
              "00220_insert_flight_master.sql", "00240_insert_peak_time.sql", "00250_insert_flight.sql"]:
        sql = (SQLS / f).read_text(encoding="utf-8")
        if f.startswith("00240"):
            if "current_timestamp" not in sql:
                sys.exit("master_sql: 00240 does not use current_timestamp")
            sql = sql.replace("current_timestamp", LOAD_TIMESTAMP)
        if f.startswith("00250"):
            if "current_date" not in sql:
                sys.exit("master_sql: 00250 does not use current_date")
            sql = sql.replace("current_date", LOAD_DATE)
        run(["-f", "-"], sql=sql)


def main():
    args = sys.argv[1:]
    check = "--check" in args
    if "--expect-version" in args:
        expect = args[args.index("--expect-version") + 1]
        _, rows = query("SHOW server_version", db="postgres")
        ver = rows[0][0].split(" ")[0]
        if ver != expect:
            sys.exit(f"master_sql: server version {ver} != expected {expect}")
    load()
    upstream = json.loads((ROOT / "trace/upstream.json").read_text(encoding="utf-8"))
    tables = {}
    for t in TABLES:
        cols, rows = query(f"SELECT * FROM {t}")
        tables[t] = {"columns": cols, "rows": rows}
    statements = []
    for sid, loc, path, xid in MAPPER_STATEMENTS:
        sql = mapper_sql(path, xid)
        cols, rows = query(sql)
        statements.append({"id": sid, "locator": loc, "sql": sql, "ordered": False, "columns": cols, "rows": rows})
    for bean in CODELISTS:
        sql = codelist_sql(bean)
        cols, rows = query(sql)
        statements.append({"id": bean, "locator": f"java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#{bean}()",
                           "sql": sql, "ordered": True, "columns": cols, "rows": rows})
    flight_doc = flight_search(upstream)
    run(["-c", f"DROP DATABASE IF EXISTS {DB}"], db="postgres")
    doc = {
        "note": "マスタの Mapper の文とコードリストの SQL の PostgreSQL での実行結果（tools/conformance/master_sql.py が生成する。"
                "手で編集しない）。tables は投入した表の全行（行の順は未規定）、statements は各文の結果（ordered が偽なら順は未規定）",
        "upstream": {"release": upstream["release"], "commit": upstream["commit"]},
        "postgresql": upstream["languages"]["postgresql"]["version"],
        "loadTimestamp": "2026-11-01 00:00:00",
        "tables": tables,
        "statements": statements,
    }
    for path, d in [(OUT, doc), (FLIGHT_OUT, flight_doc)]:
        content = json.dumps(d, ensure_ascii=False, indent=1) + "\n"
        if check:
            if not path.is_file() or path.read_text(encoding="utf-8") != content:
                sys.exit(f"master_sql: {path.relative_to(ROOT)} is out of date (run tools/conformance/master_sql.py)")
            print(f"master_sql: {path.relative_to(ROOT)} up to date")
        else:
            path.write_text(content, encoding="utf-8")
            print(f"master_sql: wrote {path.relative_to(ROOT)} ({len(d['statements'])} statements)")


if __name__ == "__main__":
    main()
