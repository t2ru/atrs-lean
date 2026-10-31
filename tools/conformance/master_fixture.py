#!/usr/bin/env python3
"""適合テストベクタの共有入力 conformance/fixtures/master-data.json・config.json を生成する。

- master-data.json: 上流のシードの SQL（atrs-initdb の integration-test-postgres）の INSERT を読み、
  Spec.MasterData の欄名で書き出す。ピーク時期は投入年 2026 から 2 年分に展開する
  （docs/spec/conformance.md、ADR 0028）。行の順はシードの順のまま（Provider の読み込み順の既定）。
- config.json: 上流の atrs.properties の値を Spec.Config の欄名で書き出す。

  python3 -I tools/conformance/master_fixture.py           # 書き出す
  python3 -I tools/conformance/master_fixture.py --check   # 最新であることを確かめる
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATRS = ROOT / "upstream/atrs/JavaConfig-Thymeleaf/atrs"
SQLS = ATRS / "atrs-initdb/src/sqls/integration-test-postgres"
PROPS = ATRS / "atrs-domain/src/main/resources/META-INF/spring/atrs.properties"
OUT = ROOT / "conformance/fixtures"
LOAD_YEAR = 2026
PEAK_YEARS = 2

SEED_FILES = ["00200_insert_fixed_value.sql", "00210_insert_route.sql", "00220_insert_flight_master.sql"]

# テーブル → (Spec の欄名, [(列名, Spec の欄名, 型)])
TABLES = {
    "AIRPORT": ("airports", [("AIRPORT_CD", "code", str), ("AIRPORT_NAME", "name", str), ("DISPLAY_ORDER", "displayOrder", int)]),
    "ROUTE": ("routes", [("ROUTE_NO", "routeNo", int), ("DEP_AIRPORT_CD", "depAirportCd", str), ("ARR_AIRPORT_CD", "arrAirportCd", str),
                         ("FLIGHT_TIME", "flightTime", str), ("BASIC_FARE", "basicFare", int)]),
    "FLIGHT_MASTER": ("flightMasters", [("FLIGHT_NAME", "flightName", str), ("ROUTE_NO", "routeNo", int), ("DEPARTURE_TIME", "departureTime", str),
                                        ("ARRIVAL_TIME", "arrivalTime", str), ("CRAFT_TYPE", "craftType", str)]),
    "BOARDING_CLASS": ("boardingClasses", [("BOARDING_CLASS_CD", "boardingClassCd", str), ("BOARDING_CLASS_NAME", "boardingClassName", str),
                                           ("EXTRA_CHARGE", "extraCharge", int), ("DISPLAY_ORDER", "displayOrder", int)]),
    "FARE_TYPE": ("fareTypes", [("FARE_TYPE_CD", "fareTypeCd", str), ("FARE_TYPE_NAME", "fareTypeName", str), ("DISCOUNT_RATE", "discountRate", int),
                                ("RSRV_AVAILABLE_START_DAY_NUM", "rsrvAvailableStartDayNum", int),
                                ("RSRV_AVAILABLE_END_DAY_NUM", "rsrvAvailableEndDayNum", int), ("PASSENGER_MIN_NUM", "passengerMinNum", int),
                                ("DISPLAY_ORDER", "displayOrder", int)]),
    "PLANE": ("planes", [("CRAFT_TYPE", "craftType", str), ("N_SEAT_NUM", "nSeatNum", int), ("S_SEAT_NUM", "sSeatNum", int)]),
    "CREDIT_TYPE": ("creditTypes", [("CREDIT_TYPE_CD", "creditTypeCd", str), ("CREDIT_FIRM", "creditFirm", str), ("DISPLAY_ORDER", "displayOrder", int)]),
}
# 列名を書かない INSERT（00210）の列順は DDL の順
DDL_ORDER = {"ROUTE": ["ROUTE_NO", "DEP_AIRPORT_CD", "ARR_AIRPORT_CD", "FLIGHT_TIME", "BASIC_FARE"]}

INSERT = re.compile(r"INSERT\s+INTO\s+(\w+)\s*(?:\(([^)]*)\))?\s*VALUES\s*\((.*?)\)\s*;", re.I | re.S)
VALUE = re.compile(r"\s*('(?:[^']|'')*'|-?\d+)\s*(?:,|$)")


def values(s):
    out, pos = [], 0
    while pos < len(s):
        m = VALUE.match(s, pos)
        if not m:
            raise SystemExit(f"master_fixture: cannot parse values: {s!r}")
        v = m.group(1)
        out.append(v[1:-1].replace("''", "'") if v.startswith("'") else int(v))
        pos = m.end()
    return out


# Spec.MasterData.FlightMaster の時刻（HourMinute: 0:00〜23:59）で表せない到着時刻（"2415" = 翌日 0:15）。
# 行は上流どおり残し、Spec 用の読み込みだけが除く（ADR 0042。Spec の改訂は backlog 0006）。
OUTSIDE_SPEC_ARRIVAL = "arrivalTime が 24 時以降（翌日着）。Spec の時刻で表せない（backlog 0006 で Spec を改める。ADR 0042）"


def valid_hhmm(s):
    return len(s) == 4 and s.isdigit() and int(s[:2]) <= 23 and int(s[2:]) <= 59


def master_data():
    md = {name: [] for name, _ in TABLES.values()}
    md["peakTimes"] = []
    for f in SEED_FILES:
        for m in INSERT.finditer((SQLS / f).read_text(encoding="utf-8")):
            table = m.group(1).upper()
            if table not in TABLES:
                continue
            cols = [c.strip().upper() for c in m.group(2).split(",")] if m.group(2) else DDL_ORDER[table]
            row = dict(zip(cols, values(m.group(3))))
            name, fields = TABLES[table]
            rec = {key: ty(row[col]) for col, key, ty in fields}
            if table == "FLIGHT_MASTER" and not valid_hhmm(rec["arrivalTime"]):
                rec["outsideSpec"] = OUTSIDE_SPEC_ARRIVAL
            md[name].append(rec)
    # ピーク時期: 関数 C_PEAK_TIME の 1 年分の INSERT を、投入年から PEAK_YEARS 年分に展開する
    text = (SQLS / "00240_insert_peak_time.sql").read_text(encoding="utf-8")
    peak = re.compile(r"VALUES\s*\(\s*'(\w+)'\s*,\s*to_date\(currentYear \|\| '/(\d\d)/(\d\d)'[^)]*\)\s*,"
                      r"\s*to_date\(currentYear \|\| '/(\d\d)/(\d\d)'[^)]*\)\s*,\s*(\d+)\s*\)", re.I)
    rows = peak.findall(text)
    if len(rows) != 8:
        raise SystemExit(f"master_fixture: expected 8 peak-time rows per year, found {len(rows)}")
    for y in range(LOAD_YEAR, LOAD_YEAR + PEAK_YEARS):
        for cd, sm, sd, em, ed, ratio in rows:
            md["peakTimes"].append({"peakTimeCd": cd, "peakStartDate": f"{y}-{sm}-{sd}",
                                    "peakEndDate": f"{y}-{em}-{ed}", "multiplicationRatio": int(ratio)})
    return md


def config():
    props = {}
    for line in PROPS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            props[k.strip()] = v.strip()
    y, m, d = props["atrs.dateOfBirthMinDate"].split("/")
    return {
        "limitDay": int(props["atrs.limitDay"]),
        "reserveIntervalTime": int(props["atrs.reserveIntervalTime"]),
        "representativeMinAge": int(props["atrs.representativeMinAge"]),
        "adultPassengerMinAge": int(props["atrs.adultPassengerMinAge"]),
        "childFareRate": int(props["atrs.childFareRate"]),
        "dateOfBirthMinDate": f"{y}-{m}-{d}",
        "defaultFlightType": props["default.flightType"],
        "defaultDepAirportCd": props["default.depAirportCd"],
        "defaultArrAirportCd": props["default.arrAirportCd"],
        "defaultBoardingClassCd": props["default.boardingClassCd"],
    }


def render(note, body):
    upstream = json.loads((ROOT / "trace/upstream.json").read_text(encoding="utf-8"))
    doc = {"note": note, "upstream": {"release": upstream["release"], "commit": upstream["commit"]}}
    doc.update(body)
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    files = {
        "master-data.json": render(
            f"上流のシードのマスタ（tools/conformance/master_fixture.py が生成する。手で編集しない）。"
            f"投入日 {LOAD_YEAR}-11-01、ピーク時期は {LOAD_YEAR}・{LOAD_YEAR + 1} 年。行の順はシードの順",
            {"loadDate": f"{LOAD_YEAR}-11-01", **master_data()}),
        "config.json": render(
            "上流の atrs.properties の設定（tools/conformance/master_fixture.py が生成する。手で編集しない）",
            config()),
    }
    bad = False
    for name, content in files.items():
        p = OUT / name
        if check:
            if not p.is_file() or p.read_text(encoding="utf-8") != content:
                print(f"master_fixture: {p.relative_to(ROOT)} is out of date (run tools/conformance/master_fixture.py)", file=sys.stderr)
                bad = True
        else:
            p.write_text(content, encoding="utf-8")
    if bad:
        sys.exit(1)
    md = json.loads(files["master-data.json"])
    counts = ", ".join(f"{k} {len(v)}" for k, v in md.items() if isinstance(v, list))
    print(f"master_fixture: {counts}" + (" (up to date)" if check else ""))


if __name__ == "__main__":
    main()
