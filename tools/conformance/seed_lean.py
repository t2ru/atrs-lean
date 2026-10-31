#!/usr/bin/env python3
"""シードのマスタ・設定（conformance/fixtures の JSON）から、[Spec] の値のリテラル `lean/Spec/Seed.lean` を生成する。

backlog 0fdf: シードのマスタ・設定が入口の環境の前提（MD-1〜MD-8 と設定の妥当性）を満たすことを、Lean の定理で
示すために使う。行の順は JSON（シードの順）のまま。`outsideSpec` の行（到着時刻 2415 など。[Spec] の値域の外）は、
`Tests.ConformanceFare` の読み込みと同じく除く（ADR 8f18、master-data.md の TODO(spec)。backlog 0be7 で [Spec] を改める）。

使い方:
  python3 -I tools/conformance/seed_lean.py           # lean/Spec/Seed.lean を書く
  python3 -I tools/conformance/seed_lean.py --check   # 生成物が最新であることを確かめる（CI）
"""
import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
FIX = REPO / "conformance" / "fixtures"
OUT = REPO / "lean" / "Spec" / "Seed.lean"
CHUNK = 100


def s(v: str) -> str:
    return json.dumps(v, ensure_ascii=False)


def date(v: str) -> str:
    y, m, d = (int(x) for x in v.split("-"))
    return f"⟨{y}, {m}, {d}, by decide⟩"


def hm(v: str) -> str:
    return f"⟨{int(v[:2])}, {int(v[2:])}, by decide⟩"


ROWS = {
    "airports": ("Airport", lambda r: f"⟨⟨{s(r['code'])}⟩, {s(r['name'])}, {r['displayOrder']}⟩"),
    "routes": ("Route", lambda r: f"⟨{r['routeNo']}, ⟨{s(r['depAirportCd'])}⟩, ⟨{s(r['arrAirportCd'])}⟩, {r['basicFare']}⟩"),
    "flightMasters": ("FlightMaster", lambda r: f"⟨⟨{s(r['flightName'])}⟩, {r['routeNo']}, {hm(r['departureTime'])}, "
                      f"{hm(r['arrivalTime'])}, {s(r['craftType'])}⟩"),
    "boardingClasses": ("BoardingClass", lambda r: f"⟨.{r['boardingClassCd']}, {s(r['boardingClassName'])}, "
                        f"{r['extraCharge']}, {r['displayOrder']}⟩"),
    "fareTypes": ("FareType", lambda r: f"⟨.{r['fareTypeCd']}, {s(r['fareTypeName'])}, {r['discountRate']}, "
                  f"{r['rsrvAvailableStartDayNum']}, {r['rsrvAvailableEndDayNum']}, {r['passengerMinNum']}, "
                  f"{r['displayOrder']}⟩"),
    "peakTimes": ("PeakTime", lambda r: f"⟨{s(r['peakTimeCd'])}, {date(r['peakStartDate'])}, {date(r['peakEndDate'])}, "
                  f"{r['multiplicationRatio']}⟩"),
    "planes": ("Plane", lambda r: f"⟨{s(r['craftType'])}, {r['nSeatNum']}, {r['sSeatNum']}⟩"),
    "creditTypes": ("CreditType", lambda r: f"⟨⟨{s(r['creditTypeCd'])}⟩, {s(r['creditFirm'])}, {r['displayOrder']}⟩"),
}


def table(name: str, ty: str, rows: list, fmt) -> list[str]:
    """100 行ずつの部分の列を `++` でつなぐ（長いリストのリテラルの展開の深さを抑える）。"""
    out = []
    parts = [rows[i:i + CHUNK] for i in range(0, len(rows), CHUNK)] or [[]]
    for k, part in enumerate(parts):
        out.append(f"def {name}{k} : List {ty} := [")
        out.extend(f"  {fmt(r)}{',' if j + 1 < len(part) else ''}" for j, r in enumerate(part))
        out.append("]")
        out.append("")
    out.append(f"/-- `{name}`（{len(rows)} 行）。 -/")
    out.append(f"def {name} : List {ty} := " + " ++ ".join(f"{name}{k}" for k in range(len(parts))))
    out.append("")
    return out


def render() -> str:
    md = json.loads((FIX / "master-data.json").read_text(encoding="utf-8"))
    cfg = json.loads((FIX / "config.json").read_text(encoding="utf-8"))
    lines = [
        "import Spec.MasterData",
        "import Spec.Config",
        "",
        "/-!",
        "# Spec.Seed",
        "",
        "シードのマスタ・設定（`conformance/fixtures/master-data.json`・`config.json`）の [Spec] の値。",
        "`tools/conformance/seed_lean.py` が生成する。手で編集しない。",
        f"上流: {md['upstream']['release']} / {md['upstream']['commit']}。行の順はシードの順。",
        "`outsideSpec` の行（到着時刻 2415 の便マスタ 2 行。[Spec] の値域の外）は除く（ADR 8f18。backlog 0be7 で [Spec] を改める）。",
        "-/",
        "",
        "set_option maxRecDepth 4096",
        "",
        "namespace Spec.Seed",
        "",
        "open Spec.Prim",
        "open Spec.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType)",
        "",
    ]
    for key, (ty, fmt) in ROWS.items():
        rows = [r for r in md[key] if "outsideSpec" not in r]
        lines += table(key, ty, rows, fmt)
    lines += [
        "/-- シードのマスタ。 -/",
        "def masterData : MasterData :=",
        "  ⟨airports, routes, flightMasters, boardingClasses, fareTypes, peakTimes, planes, creditTypes⟩",
        "",
        "/-- シードの設定（上流の `atrs.properties`）。 -/",
        "def config : Config :=",
        f"  ⟨{cfg['limitDay']}, {cfg['reserveIntervalTime']}, {cfg['representativeMinAge']}, "
        f"{cfg['adultPassengerMinAge']}, {cfg['childFareRate']}, {date(cfg['dateOfBirthMinDate'])}, "
        f".{cfg['defaultFlightType']}, ⟨{s(cfg['defaultDepAirportCd'])}⟩, ⟨{s(cfg['defaultArrAirportCd'])}⟩, "
        f".{cfg['defaultBoardingClassCd']}⟩",
        "",
        "end Spec.Seed",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    text = render()
    if "--check" in sys.argv[1:]:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"seed_lean: {OUT.relative_to(REPO)} is out of date (run tools/conformance/seed_lean.py)",
                  file=sys.stderr)
            return 1
        print(f"seed_lean: {OUT.relative_to(REPO)} is up to date")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"seed_lean: wrote {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
