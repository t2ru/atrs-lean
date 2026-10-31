#!/usr/bin/env python3
"""マスタの Mapper の文とコードリストの SQL を PostgreSQL で実行し、結果を conformance/sql/master-data.json に書き出す
（backlog 25f7、ADR c108）。lake test（Tests.MasterSql）が、同じ表の行から SourceModel.Repository.* を評価して照合する。

- 上流の DDL とシード（00100・00200・00210・00220・00240）を、新しいデータベースに投入する。
  00240 のピーク時期は投入日 2026-11-01 で展開する（current_timestamp を置き換える。ADR 9ee4）。
- 文の SQL は、上流の Mapper の XML と AtrsCodeListConfig.java から抜き出したものをそのまま使う。
- PostgreSQL への接続は .agents/skills/port-lang/scripts/ci/with_postgres.sh が与える（照合順序 C・UTF8・UTC）。

  .agents/skills/port-lang/scripts/ci/with_postgres.sh python3 -I tools/conformance/master_sql.py [--check] [--expect-version 16.15]
"""
import csv
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
              "00220_insert_flight_master.sql", "00240_insert_peak_time.sql"]:
        sql = (SQLS / f).read_text(encoding="utf-8")
        if f.startswith("00240"):
            if "current_timestamp" not in sql:
                sys.exit("master_sql: 00240 does not use current_timestamp")
            sql = sql.replace("current_timestamp", LOAD_TIMESTAMP)
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
    content = json.dumps(doc, ensure_ascii=False, indent=1) + "\n"
    if check:
        if not OUT.is_file() or OUT.read_text(encoding="utf-8") != content:
            sys.exit(f"master_sql: {OUT.relative_to(ROOT)} is out of date (run tools/conformance/master_sql.py)")
        print(f"master_sql: {OUT.relative_to(ROOT)} up to date")
    else:
        OUT.write_text(content, encoding="utf-8")
        print(f"master_sql: wrote {OUT.relative_to(ROOT)} ({len(statements)} statements)")


if __name__ == "__main__":
    main()
