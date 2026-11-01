#!/usr/bin/env python3
"""予約が使う Mapper の文を PostgreSQL で実行し、結果を conformance/sql/reservation.json に書き出す（backlog aedf の第 2 段）。
lake test（Tests.ReservationSql）が、同じ初期状態と引数から SourceModel の文の写しを評価して照合する。

- 対象の文: FlightRepository の exists・findOneForUpdate・update、MemberRepository の findOne、
  ReservationRepository の insert・insertReserveFlight・insertPassenger（各 selectKey を別の段とする）。
  SQL は上流の Mapper の XML から抜き出し、#{…} を位置の束縛変数 $n にして、JDBC が送る型（String は varchar、
  Integer は int4、LocalDate は date）で PREPARE する。null は NULL を束縛する。
- 上流の DDL とシード（00100・00200・00210・00220・00230）を新しいデータベースに投入する。まず、シードの MEMBER・
  MEMBER_LOGIN と sq_member_1 の状態を書き出す（seed。lake test が SourceModel.Db.MemberSeed と照合する）。
  MEMBER_LOGIN.LOGIN_DATE_TIME はシードでは localtimestamp（投入の時刻）で、モデルは投入日の 0:00 に固定するので、
  この列だけは書き出さず、NULL でないことだけを記録する。
- 各ケース（CASES）: 状態の表（FLIGHT・MEMBER・MEMBER_LOGIN・RESERVATION・RESERVE_FLIGHT・PASSENGER）を空にして
  初期状態を投入し、シーケンスを初期状態にする（None は未使用。ALTER SEQUENCE … RESTART）。段を順に自動コミットで実行し、
  各段の結果（行・件数・誤りの SQLSTATE と制約名・列名）と、最後の状態（表の全行とシーケンスの状態）を書き出す。
  誤りの段は最後の段に限る（文は原子的なので、誤りの段は表を変えない）。初期状態も PostgreSQL から読み戻した値を書く。
- 予約フライト番号・搭乗者番号の selectKey（resultType="Integer"）で、NEXTVAL が int の範囲を超えたときは、
  あわせてその値（bigint）を INSERT に束縛した結果を insertWithValue に記録する（原典では JDBC の読み出しが先に失敗する）。
- KNOWN_MISMATCH は、PostgreSQL とモデルの結果が異なると分かっているケースと、その分析。lake test は、そのケースが
  実際に異なること（直ったら注記を外させる）を確かめる。いまは無い（制約の検査の順を PostgreSQL に合わせた。ADR ca17）。

  .agents/skills/spec-pivot/scripts/ci/with_postgres.sh uv run python -I tools/conformance/reservation_sql.py [--check] [--expect-version 16.15]
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
OUT = ROOT / "conformance/sql/reservation.json"
DB = "atrs_reservation_sql"
NULL = "\\N"

STATE_TABLES = ["FLIGHT", "MEMBER", "MEMBER_LOGIN", "RESERVATION", "RESERVE_FLIGHT", "PASSENGER"]
SEQUENCES = ["sq_member_1", "sq_reservation_1", "sq_reserve_flight_1", "sq_passenger_1"]
INT_MAX = 2147483647

SQLSTATES = {
    "23505": "unique_violation",
    "23503": "foreign_key_violation",
    "23502": "not_null_violation",
    "22001": "string_data_right_truncation",
    "22003": "numeric_value_out_of_range",
    "22008": "datetime_field_overflow",
    "2200H": "sequence_generator_limit_exceeded",
}

KEY = [("departureDate", "date"), ("flightName", "varchar"), ("boardingClass.boardingClassCd", "varchar"),
       ("fareType.fareTypeCd", "varchar")]
# 段の種類: (Mapper の XML, 要素, id, selectKey か本体か, 束縛変数（名前, JDBC の型）, 結果の種類)
STATEMENTS = {
    "flight.exists": ("flight/FlightRepository.xml", "select", "exists", "body", KEY, "rows"),
    "flight.findOneForUpdate": ("flight/FlightRepository.xml", "select", "findOneForUpdate", "body", KEY, "rows"),
    "flight.update": ("flight/FlightRepository.xml", "update", "update", "body",
                      [("vacantNum", "int4"), ("departureDate", "date"), ("flightMaster.flightName", "varchar"),
                       ("boardingClass.boardingClassCd", "varchar"), ("fareType.fareTypeCd", "varchar")], "count"),
    "member.findOne": ("member/MemberRepository.xml", "select", "findOne", "body", [("membershipNumber", "varchar")], "rows"),
    "reservation.nextReserveNo": ("reservation/ReservationRepository.xml", "insert", "insert", "selectKey", [], "rows"),
    "reservation.insert": ("reservation/ReservationRepository.xml", "insert", "insert", "body",
                           [("reserveNo", "varchar"), ("reserveDate", "date"), ("totalFare", "int4"),
                            ("repFamilyName", "varchar"), ("repGivenName", "varchar"), ("repAge", "int4"),
                            ("repGender.code", "varchar"), ("repTel", "varchar"), ("repMail", "varchar"),
                            ("repMember.membershipNumber", "varchar")], "count"),
    "reservation.nextReserveFlightNo": ("reservation/ReservationRepository.xml", "insert", "insertReserveFlight", "selectKey",
                                        [], "rows"),
    "reservation.insertReserveFlight": ("reservation/ReservationRepository.xml", "insert", "insertReserveFlight", "body",
                                        [("reserveFlightNo", "int4"), ("reserveNo", "varchar"),
                                         ("flight.departureDate", "date"), ("flight.flightMaster.flightName", "varchar"),
                                         ("flight.boardingClass.boardingClassCd", "varchar"),
                                         ("flight.fareType.fareTypeCd", "varchar")], "count"),
    "reservation.nextPassengerNo": ("reservation/ReservationRepository.xml", "insert", "insertPassenger", "selectKey", [], "rows"),
    "reservation.insertPassenger": ("reservation/ReservationRepository.xml", "insert", "insertPassenger", "body",
                                    [("passengerNo", "int4"), ("reserveFlightNo", "int4"), ("familyName", "varchar"),
                                     ("givenName", "varchar"), ("age", "int4"), ("gender.code", "varchar"),
                                     ("member.membershipNumber", "varchar")], "count"),
}
LOCATORS = {
    "flight.exists": "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#exists",
    "flight.findOneForUpdate": "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findOneForUpdate",
    "flight.update": "sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#update",
    "member.findOne": "sql:jp.co.ntt.atrs.domain.repository.member.MemberRepository#findOne",
    "reservation.nextReserveNo": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert",
    "reservation.insert": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insert",
    "reservation.nextReserveFlightNo": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight",
    "reservation.insertReserveFlight": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertReserveFlight",
    "reservation.nextPassengerNo": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger",
    "reservation.insertPassenger": "sql:jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository#insertPassenger",
}

# ---------------------------------------------------------------------------
# ケースのデータ

F1 = ("2026-11-10", "NTT001", "N", "OW", 10)
F2 = ("2026-11-10", "NTT001", "S", "OW", 0)
F3 = ("2026-11-11", "NTT006", "N", "RT", 300)
FLIGHTS = [F1, F2, F3]


def member(no, credit="VIS", gender="F", name="花子"):
    return (no, "電電", name, "デンデン", "ハナコ", "1979-01-25", gender, "111-1111-1111", "1111111", "東京都港区港南Ｘ－Ｘ－Ｘ",
            "xxxxxx@ntt.co.jp", "1111111111111111", credit, "01/20")


M1 = member("0000000001")
M2 = member("0000000002", credit="JCB", gender="M", name="太郎")
M3 = member("0000000003", credit="AMX", gender="M", name="次郎")
L1 = ("0000000001", "{pbkdf2}aaa", "{pbkdf2}bbb", "2026-11-01 00:00:00", False)
L2 = ("0000000002", "{pbkdf2}ccc", None, "2026-10-31 23:59:59.5", True)
MEMBERS = {"MEMBER": [M1, M2, M3], "MEMBER_LOGIN": [L1, L2]}
R1 = ("0000000001", "2026-11-01", 20000, "電電", "花子", 30, "F", "111-1111-1111", "xxxxxx@ntt.co.jp", None)
RF1 = (1, "0000000001", "2026-11-10", "NTT001", "N", "OW")
P1 = (1, 1, "デンデン", "ハナコ", 30, "F", None)


def key(f, **kw):
    p = {"departureDate": f[0], "flightName": f[1], "boardingClass.boardingClassCd": f[2], "fareType.fareTypeCd": f[3]}
    p.update(kw)
    return p


def upd(f, vacant, **kw):
    p = {"vacantNum": vacant, "departureDate": f[0], "flightMaster.flightName": f[1],
         "boardingClass.boardingClassCd": f[2], "fareType.fareTypeCd": f[3]}
    p.update(kw)
    return p


def rsv(no="0000000001", **kw):
    p = {"reserveNo": no, "reserveDate": "2026-11-01", "totalFare": 20000, "repFamilyName": "電電", "repGivenName": "花子",
         "repAge": 30, "repGender.code": "F", "repTel": "111-1111-1111", "repMail": "xxxxxx@ntt.co.jp",
         "repMember.membershipNumber": None}
    p.update(kw)
    return p


def rf(no=1, reserve="0000000001", f=F1, **kw):
    p = {"reserveFlightNo": no, "reserveNo": reserve, "flight.departureDate": f[0], "flight.flightMaster.flightName": f[1],
         "flight.boardingClass.boardingClassCd": f[2], "flight.fareType.fareTypeCd": f[3]}
    p.update(kw)
    return p


def psg(no=1, rfno=1, **kw):
    p = {"passengerNo": no, "reserveFlightNo": rfno, "familyName": "デンデン", "givenName": "ハナコ", "age": 30,
         "gender.code": "F", "member.membershipNumber": None}
    p.update(kw)
    return p


def st(op, params=None):
    return {"op": op, "params": params or {}}


def case(cid, desc, tables=None, seqs=None, steps=()):
    return {"id": cid, "description": desc, "tables": tables or {}, "sequences": seqs or {}, "steps": list(steps)}


FT = {"FLIGHT": FLIGHTS}
RSV_STATE = {"FLIGHT": FLIGHTS, **MEMBERS}
RF_STATE = {**RSV_STATE, "RESERVATION": [R1]}
P_STATE = {**RF_STATE, "RESERVE_FLIGHT": [RF1]}

CASES = [
    # FlightRepository.exists
    case("flight-exists-hit", "主キーが一致するフライトがある", FT, steps=[st("flight.exists", key(F1))]),
    case("flight-exists-miss-date", "出発日が異なる", FT, steps=[st("flight.exists", key(F1, departureDate="2026-11-12"))]),
    case("flight-exists-trailing-space", "便名の末尾の空白は比較で無視されない（varchar）", FT,
         steps=[st("flight.exists", key(F1, flightName="NTT001 "))]),
    case("flight-exists-null-fare-type", "運賃種別が null（= NULL は真にならない）", FT,
         steps=[st("flight.exists", key(F1, **{"fareType.fareTypeCd": None}))]),
    case("flight-exists-empty", "FLIGHT が空", {}, steps=[st("flight.exists", key(F1))]),
    # FlightRepository.findOneForUpdate
    case("flight-find-hit", "主キーで 1 行", FT, steps=[st("flight.findOneForUpdate", key(F2))]),
    case("flight-find-miss", "該当なし（搭乗クラスが異なる）", {"FLIGHT": [F1]},
         steps=[st("flight.findOneForUpdate", key(F1, **{"boardingClass.boardingClassCd": "S"}))]),
    case("flight-find-null-date", "出発日が null", FT, steps=[st("flight.findOneForUpdate", key(F1, departureDate=None))]),
    # FlightRepository.update
    case("flight-update-hit", "空席数を更新する", FT, steps=[st("flight.update", upd(F1, 7))]),
    case("flight-update-miss", "該当なし", FT, steps=[st("flight.update", upd(F1, 7, departureDate="2026-11-12"))]),
    case("flight-update-negative", "負の空席数（検査制約は無い）", FT, steps=[st("flight.update", upd(F2, -1))]),
    case("flight-update-int-max", "空席数が int の最大値", FT, steps=[st("flight.update", upd(F3, INT_MAX))]),
    case("flight-update-null-vacant-hit", "空席数が null で該当あり（NOT NULL 違反）", FT, steps=[st("flight.update", upd(F1, None))]),
    case("flight-update-null-vacant-miss", "空席数が null で該当なし（0 件。SET は評価されない）", FT,
         steps=[st("flight.update", upd(F1, None, departureDate="2026-11-12"))]),
    case("flight-update-null-key", "便名が null（0 件）", FT,
         steps=[st("flight.update", upd(F1, 5, **{"flightMaster.flightName": None}))]),
    case("flight-find-update-find", "行ロックで読み、更新し、読み直す", FT,
         steps=[st("flight.findOneForUpdate", key(F1)), st("flight.update", upd(F1, 8)), st("flight.findOneForUpdate", key(F1)),
                st("flight.exists", key(F1))]),
    # MemberRepository.findOne
    case("member-find-hit", "会員と会員ログイン・カード会社", MEMBERS, steps=[st("member.findOne", {"membershipNumber": "0000000001"})]),
    case("member-find-nulls", "前回パスワードが NULL、ログイン日時に小数秒、ログイン中", MEMBERS,
         steps=[st("member.findOne", {"membershipNumber": "0000000002"})]),
    case("member-find-no-login", "会員ログインの行が無い会員（内部結合で 0 行）", MEMBERS,
         steps=[st("member.findOne", {"membershipNumber": "0000000003"})]),
    case("member-find-miss", "該当なし", MEMBERS, steps=[st("member.findOne", {"membershipNumber": "9999999999"})]),
    case("member-find-null", "会員番号が null", MEMBERS, steps=[st("member.findOne", {"membershipNumber": None})]),
    case("member-find-empty", "会員番号が空文字列", MEMBERS, steps=[st("member.findOne", {"membershipNumber": ""})]),
    # ReservationRepository.insert
    case("rsv-insert-ok", "予約番号を採番して、非会員の予約を挿入する", RSV_STATE,
         steps=[st("reservation.nextReserveNo"), st("reservation.insert", rsv())]),
    case("rsv-insert-member", "会員の予約", RSV_STATE, steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": "0000000001"}))]),
    case("rsv-insert-nullif-empty", "会員番号が空文字列（NULLIF で NULL）", RSV_STATE,
         steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": ""}))]),
    case("rsv-insert-fk-member", "存在しない会員番号（FK_RESERVATION_1）", RSV_STATE,
         steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": "0000000099"}))]),
    case("rsv-insert-fk-space", "会員番号が空白 1 文字（NULLIF は空白を落とさない。FK_RESERVATION_1）", RSV_STATE,
         steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": " "}))]),
    case("rsv-insert-pk-dup", "予約番号の重複（PK_RESERVATION）", RF_STATE, steps=[st("reservation.insert", rsv())]),
    case("rsv-insert-pk-dup-and-fk", "予約番号の重複と、存在しない会員番号", RF_STATE,
         steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": "0000000099"}))]),
    case("rsv-insert-null-family", "代表者の姓が null", RSV_STATE, steps=[st("reservation.insert", rsv(repFamilyName=None))]),
    case("rsv-insert-null-gender", "代表者の性別が null", RSV_STATE, steps=[st("reservation.insert", rsv(**{"repGender.code": None}))]),
    case("rsv-insert-null-reserve-no", "予約番号が null", RSV_STATE, steps=[st("reservation.insert", rsv(no=None))]),
    case("rsv-insert-null-date", "予約日が null", RSV_STATE, steps=[st("reservation.insert", rsv(reserveDate=None))]),
    case("rsv-insert-null-fare", "合計金額が null", RSV_STATE, steps=[st("reservation.insert", rsv(totalFare=None))]),
    case("rsv-insert-too-long-family", "代表者の姓が 11 文字", RSV_STATE,
         steps=[st("reservation.insert", rsv(repFamilyName="ABCDEFGHIJK"))]),
    case("rsv-insert-kanji-10", "代表者の姓が漢字 10 文字（文字数で数える）", RSV_STATE,
         steps=[st("reservation.insert", rsv(repFamilyName="電" * 10))]),
    case("rsv-insert-kanji-11", "代表者の姓が漢字 11 文字", RSV_STATE, steps=[st("reservation.insert", rsv(repFamilyName="電" * 11))]),
    case("rsv-insert-trailing-spaces", "超えた部分が空白だけなら切り詰めて格納する", RSV_STATE,
         steps=[st("reservation.insert", rsv(repFamilyName="ABCDEFGHIJ   "))]),
    case("rsv-insert-too-long-mail", "メールアドレスが 257 文字", RSV_STATE, steps=[st("reservation.insert", rsv(repMail="a" * 257))]),
    case("rsv-insert-too-long-customer", "会員番号が 11 文字", RSV_STATE,
         steps=[st("reservation.insert", rsv(**{"repMember.membershipNumber": "00000000011"}))]),
    case("rsv-insert-too-long-then-null", "代表者の姓が 11 文字で、電話番号が null", RSV_STATE,
         steps=[st("reservation.insert", rsv(repFamilyName="ABCDEFGHIJK", repTel=None))]),
    case("rsv-insert-null-then-too-long", "代表者の姓が null で、電話番号が 14 文字", RSV_STATE,
         steps=[st("reservation.insert", rsv(repFamilyName=None, repTel="111-1111-11111"))]),
    case("rsv-insert-int-bounds", "合計金額が int の最大値、年齢が負", RSV_STATE,
         steps=[st("reservation.insert", rsv(totalFare=INT_MAX, repAge=-2147483648))]),
    case("rsv-insert-date-max", "予約日が 9999-12-31", RSV_STATE, steps=[st("reservation.insert", rsv(reserveDate="9999-12-31"))]),
    # シーケンス
    case("seq-reservation-fresh", "予約番号の採番（未使用から 2 回）", {},
         steps=[st("reservation.nextReserveNo"), st("reservation.nextReserveNo")]),
    case("seq-reservation-cycle", "予約番号のシーケンスが最大値を超えて 1 に戻る（CYCLE）", {}, {"sq_reservation_1": 9999999998},
         steps=[st("reservation.nextReserveNo"), st("reservation.nextReserveNo")]),
    case("seq-reserve-flight-fresh", "予約フライト番号の採番（未使用から）", {}, steps=[st("reservation.nextReserveFlightNo")]),
    case("seq-reserve-flight-int-overflow", "予約フライト番号が int の最大値を超える", {}, {"sq_reserve_flight_1": INT_MAX - 1},
         steps=[st("reservation.nextReserveFlightNo"), st("reservation.nextReserveFlightNo")]),
    case("seq-reserve-flight-cycle", "予約フライト番号のシーケンスが最大値を超えて 1 に戻る", {}, {"sq_reserve_flight_1": 999999999999},
         steps=[st("reservation.nextReserveFlightNo")]),
    case("seq-passenger-fresh", "搭乗者番号の採番（未使用から）", {}, steps=[st("reservation.nextPassengerNo")]),
    case("seq-passenger-int-overflow", "搭乗者番号が int の最大値を超える", {}, {"sq_passenger_1": INT_MAX},
         steps=[st("reservation.nextPassengerNo")]),
    case("seq-passenger-cycle", "搭乗者番号のシーケンスが最大値を超えて 1 に戻る", {}, {"sq_passenger_1": 9999999999999},
         steps=[st("reservation.nextPassengerNo")]),
    # ReservationRepository.insertReserveFlight
    case("rf-insert-ok", "予約フライト番号を採番して挿入する", RF_STATE,
         steps=[st("reservation.nextReserveFlightNo"), st("reservation.insertReserveFlight", rf())]),
    case("rf-insert-pk-dup", "予約フライト番号の重複（PK_RESERVE_FLIGHT）", P_STATE, steps=[st("reservation.insertReserveFlight", rf(f=F2))]),
    case("rf-insert-fk-reservation", "存在しない予約番号（FK_RESERVE_FLIGHT_1）", RF_STATE,
         steps=[st("reservation.insertReserveFlight", rf(reserve="0000000002"))]),
    case("rf-insert-fk-flight", "存在しないフライト（FK_RESERVE_FLIGHT_2）", RF_STATE,
         steps=[st("reservation.insertReserveFlight", rf(f=("2026-11-11", "NTT001", "N", "OW")))]),
    case("rf-insert-fk-both", "予約もフライトも存在しない", RF_STATE,
         steps=[st("reservation.insertReserveFlight", rf(reserve="0000000002", f=("2026-11-11", "NTT001", "N", "OW")))]),
    case("rf-insert-pk-dup-and-fk", "予約フライト番号の重複と、存在しない予約番号", P_STATE,
         steps=[st("reservation.insertReserveFlight", rf(reserve="0000000002"))]),
    case("rf-insert-null-fare-type", "運賃種別が null", RF_STATE,
         steps=[st("reservation.insertReserveFlight", rf(**{"flight.fareType.fareTypeCd": None}))]),
    case("rf-insert-null-reserve-no", "予約番号が null", RF_STATE, steps=[st("reservation.insertReserveFlight", rf(reserve=None))]),
    case("rf-insert-null-no", "予約フライト番号が null", RF_STATE, steps=[st("reservation.insertReserveFlight", rf(no=None))]),
    case("rf-insert-too-long-flight-name", "便名が 7 文字", RF_STATE,
         steps=[st("reservation.insertReserveFlight", rf(**{"flight.flightMaster.flightName": "NTT0011"}))]),
    # ReservationRepository.insertPassenger
    case("p-insert-ok", "搭乗者番号を採番して、非会員の搭乗者を挿入する", P_STATE,
         steps=[st("reservation.nextPassengerNo"), st("reservation.insertPassenger", psg())]),
    case("p-insert-member", "会員の搭乗者", P_STATE, steps=[st("reservation.insertPassenger", psg(**{"member.membershipNumber": "0000000002"}))]),
    case("p-insert-nullif-empty", "会員番号が空文字列（NULLIF で NULL）", P_STATE,
         steps=[st("reservation.insertPassenger", psg(**{"member.membershipNumber": ""}))]),
    case("p-insert-fk-reserve-flight", "存在しない予約フライト番号（FK_PASSENGER_1）", P_STATE,
         steps=[st("reservation.insertPassenger", psg(rfno=2))]),
    case("p-insert-fk-member", "存在しない会員番号（FK_PASSENGER_2）", P_STATE,
         steps=[st("reservation.insertPassenger", psg(**{"member.membershipNumber": "0000000099"}))]),
    case("p-insert-fk-both", "予約フライトも会員も存在しない", P_STATE,
         steps=[st("reservation.insertPassenger", psg(rfno=2, **{"member.membershipNumber": "0000000099"}))]),
    case("p-insert-pk-dup", "搭乗者番号の重複（PK_PASSENGER）", {**P_STATE, "PASSENGER": [P1]},
         steps=[st("reservation.insertPassenger", psg())]),
    case("p-insert-pk-dup-and-fk", "搭乗者番号の重複と、存在しない会員番号", {**P_STATE, "PASSENGER": [P1]},
         steps=[st("reservation.insertPassenger", psg(**{"member.membershipNumber": "0000000099"}))]),
    case("p-insert-null-given", "搭乗者の名が null", P_STATE, steps=[st("reservation.insertPassenger", psg(givenName=None))]),
    case("p-insert-null-age", "搭乗者の年齢が null", P_STATE, steps=[st("reservation.insertPassenger", psg(age=None))]),
    case("p-insert-null-reserve-flight-no", "予約フライト番号が null", P_STATE,
         steps=[st("reservation.insertPassenger", psg(rfno=None))]),
    case("p-insert-too-long-given", "搭乗者の名が 11 文字", P_STATE,
         steps=[st("reservation.insertPassenger", psg(givenName="ハナコハナコハナコハナ"))]),
    # 予約の登録の一連の文
    case("flow-reserve", "予約の登録の一連の文（採番・予約・予約フライト・搭乗者 2 名・空席数の更新）", RSV_STATE,
         {"sq_reservation_1": 41, "sq_reserve_flight_1": 9, "sq_passenger_1": 99},
         steps=[st("reservation.nextReserveNo"), st("reservation.insert", rsv("0000000042", **{"repMember.membershipNumber": "0000000001"})),
                st("reservation.nextReserveFlightNo"), st("reservation.insertReserveFlight", rf(10, "0000000042", F3)),
                st("reservation.nextPassengerNo"), st("reservation.insertPassenger", psg(100, 10, **{"member.membershipNumber": "0000000001"})),
                st("reservation.nextPassengerNo"), st("reservation.insertPassenger", psg(101, 10, familyName="デンデン", givenName="タロウ",
                                                                                         age=5, **{"gender.code": "M"})),
                st("flight.findOneForUpdate", key(F3)), st("flight.update", upd(F3, 298)), st("flight.exists", key(F3))]),
]

KNOWN_MISMATCH: dict[str, str] = {}

# ---------------------------------------------------------------------------
# psql


def psql(args, sql=None, db=DB, check=True):
    env = dict(os.environ, PGTZ="UTC", PGCLIENTENCODING="UTF8", PGDATABASE=db)
    r = subprocess.run(["psql", "-X", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose", "-v", "SHOW_CONTEXT=never"] + args,
                       input=sql, capture_output=True, text=True, encoding="utf-8", env=env)
    if check and r.returncode != 0:
        sys.exit(f"reservation_sql: psql failed: {r.stderr.strip()}")
    return r


def query(sql):
    out = psql(["-q", "--csv", "-P", f"null={NULL}", "-c", sql]).stdout
    rows = list(csv.reader(io.StringIO(out)))
    return rows[0], [[None if v == NULL else v for v in r] for r in rows[1:]]


def pg_error(stderr):
    m = re.search(r"ERROR:\s+([0-9A-Z]{5}): (.*)", stderr)
    if not m:
        sys.exit(f"reservation_sql: unexpected psql error: {stderr.strip()}")
    code, msg = m.group(1), m.group(2).strip()
    if code not in SQLSTATES:
        sys.exit(f"reservation_sql: unexpected SQLSTATE {code}: {msg}")
    err = {"sqlstate": code, "condition": SQLSTATES[code], "message": msg}
    c = re.search(r'constraint "([^"]+)"', msg)
    if c:
        err["constraint"] = c.group(1)
    c = re.search(r'column "([^"]+)"', msg)
    if c:
        err["column"] = c.group(1)
    return err


# ---------------------------------------------------------------------------
# 文の SQL


def statement_sql(op):
    path, tag, sid, part, params, _ = STATEMENTS[op]
    root = ET.parse(MAPPERS / path).getroot()
    el = next((e for e in root.iter(tag) if e.get("id") == sid), None)
    if el is None:
        sys.exit(f"reservation_sql: {path}#{sid} not found")
    children = list(el)
    if part == "selectKey":
        if len(children) != 1 or children[0].tag != "selectKey" or children[0].get("order") != "BEFORE":
            sys.exit(f"reservation_sql: {path}#{sid}: unexpected selectKey")
        text = children[0].text or ""
    else:
        if tag == "insert":
            if len(children) != 1 or children[0].tag != "selectKey":
                sys.exit(f"reservation_sql: {path}#{sid}: unexpected children")
            text = (el.text or "") + (children[0].tail or "")
        else:
            if children:
                sys.exit(f"reservation_sql: {path}#{sid} has dynamic SQL (not supported)")
            text = el.text or ""
    sql = " ".join(text.split())
    for i, (name, _) in enumerate(params, 1):
        if "#{" + name + "}" not in sql:
            sys.exit(f"reservation_sql: #{{{name}}} not in {path}#{sid}")
        sql = sql.replace("#{" + name + "}", f"${i}")
    if "#{" in sql:
        sys.exit(f"reservation_sql: unbound parameter in {sql}")
    return sql


def literal(v, ty):
    if v is None:
        return "NULL"
    if ty == "int4" or ty == "int8":
        return str(int(v))
    return "'" + str(v).replace("'", "''") + "'"


def execute(op, sql, params, types=None):
    """段を 1 つ実行し、結果（{"rows"}・{"count"}・{"error"}）を返す。"""
    _, _, _, _, decl, kind = STATEMENTS[op]
    types = types or [t for _, t in decl]
    if set(params) != {n for n, _ in decl}:
        sys.exit(f"reservation_sql: {op}: parameters {sorted(params)} != {[n for n, _ in decl]}")
    if decl:
        script = f"PREPARE s({', '.join(types)}) AS {sql};\nEXECUTE s({', '.join(literal(params[n], t) for (n, _), t in zip(decl, types))});\n"
    else:
        script = sql + ";\n"
    if kind == "rows":
        r = psql(["-q", "--csv", "-P", f"null={NULL}", "-f", "-"], sql=script, check=False)
        if r.returncode != 0:
            return {"error": pg_error(r.stderr)}
        rows = list(csv.reader(io.StringIO(r.stdout)))
        return {"columns": rows[0], "rows": [[None if v == NULL else v for v in x] for x in rows[1:]]}
    r = psql(["-f", "-"], sql=script, check=False)
    if r.returncode != 0:
        return {"error": pg_error(r.stderr)}
    tags = [ln for ln in r.stdout.splitlines() if re.fullmatch(r"(INSERT 0|UPDATE) \d+", ln)]
    if len(tags) != 1:
        sys.exit(f"reservation_sql: {op}: unexpected output {r.stdout!r}")
    return {"count": int(tags[0].split()[-1])}


# ---------------------------------------------------------------------------
# 状態


COLUMNS = {}


def columns(t):
    if t not in COLUMNS:
        COLUMNS[t] = query(f"SELECT * FROM {t} LIMIT 0")[0]
    return COLUMNS[t]


def dump(tables, sequences):
    """表（{名前: 除く列}）の全行（全列で整列）と、シーケンスの（last_value, is_called）を 1 回の psql で読む。"""
    parts, script = [], []
    for t, exclude in tables.items():
        keep = [c for c in columns(t) if c not in exclude]
        parts.append(("table", t))
        order = ", ".join(str(i) for i in range(1, len(keep) + 1))
        script.append(f"\\echo '#### {t}'\nSELECT {', '.join(keep)} FROM {t} ORDER BY {order};")
    for sname in sequences:
        parts.append(("sequence", sname))
        script.append(f"\\echo '#### {sname}'\nSELECT last_value, is_called FROM {sname};")
    out = psql(["-q", "--csv", "-P", f"null={NULL}", "-f", "-"], sql="\n".join(script) + "\n").stdout
    chunks = re.split(r"^#### \S+\n", out, flags=re.M)[1:]
    if len(chunks) != len(parts):
        sys.exit(f"reservation_sql: unexpected dump output {out!r}")
    tabs, seqs = {}, {}
    for (kind, name), chunk in zip(parts, chunks):
        rows = list(csv.reader(io.StringIO(chunk)))
        body = [[None if v == NULL else v for v in r] for r in rows[1:]]
        if kind == "table":
            tabs[name] = {"columns": rows[0], "rows": body}
        else:
            last, called = int(body[0][0]), body[0][1] == "t"
            if not called and last != 1:
                sys.exit(f"reservation_sql: {name}: is_called = false with last_value {last}")
            seqs[name] = last if called else None
    return tabs, seqs


def dump_state():
    tabs, seqs = dump({t: () for t in STATE_TABLES}, SEQUENCES)
    return {"tables": tabs, "sequences": seqs}


def set_state(c):
    stmts = ["TRUNCATE passenger, reserve_flight, reservation, member_login, member, flight"]
    for t, rows in c["tables"].items():
        if t not in STATE_TABLES:
            sys.exit(f"reservation_sql: {c['id']}: unknown table {t}")
        for r in rows:
            vals = ", ".join("NULL" if v is None else ("TRUE" if v is True else "FALSE" if v is False else
                                                       str(v) if isinstance(v, int) else "'" + v.replace("'", "''") + "'")
                             for v in r)
            stmts.append(f"INSERT INTO {t} VALUES ({vals})")
    for s in SEQUENCES:
        v = c["sequences"].get(s)
        stmts.append(f"ALTER SEQUENCE {s} RESTART" if v is None else f"SELECT setval('{s}', {int(v)}, true)")
    psql(["-q", "-f", "-"], sql=";\n".join(stmts) + ";\n")


def run_case(c, sqls):
    set_state(c)
    initial = dump_state()
    steps = []
    for i, s in enumerate(c["steps"]):
        res = execute(s["op"], sqls[s["op"]], s["params"])
        step = {"op": s["op"], "params": s["params"], "result": res}
        if s["op"] in ("reservation.nextReserveFlightNo", "reservation.nextPassengerNo") and "rows" in res:
            v = int(res["rows"][0][0])
            if v > INT_MAX:
                # 原典では JDBC の getInt が先に失敗する。その値を INSERT に束縛したら、を記録する
                ins = "reservation.insertReserveFlight" if s["op"] == "reservation.nextReserveFlightNo" else "reservation.insertPassenger"
                p = rf(no=v) if ins == "reservation.insertReserveFlight" else psg(no=v)
                types = ["int8"] + [t for _, t in STATEMENTS[ins][4][1:]]
                step["insertWithValue"] = {"op": ins, "params": p, "paramTypes": types,
                                           "result": execute(ins, sqls[ins], p, types)}
                if "error" not in step["insertWithValue"]["result"]:
                    sys.exit(f"reservation_sql: {c['id']}: INSERT with {v} did not fail")
        steps.append(step)
        if "error" in res and i + 1 < len(c["steps"]):
            sys.exit(f"reservation_sql: {c['id']}: error in a step that is not the last")
    out = {"id": c["id"], "description": c["description"], "initial": initial, "steps": steps, "final": dump_state()}
    if c["id"] in KNOWN_MISMATCH:
        out["knownMismatch"] = KNOWN_MISMATCH[c["id"]]
    return out


def load():
    psql(["-q", "-c", f"DROP DATABASE IF EXISTS {DB}"], db="postgres")
    psql(["-q", "-c", f"CREATE DATABASE {DB}"], db="postgres")
    for f in ["00100_create_all_tables.sql", "00200_insert_fixed_value.sql", "00210_insert_route.sql",
              "00220_insert_flight_master.sql", "00230_insert_member.sql"]:
        psql(["-q", "-f", "-"], sql=(SQLS / f).read_text(encoding="utf-8"))


def seed():
    sql = (SQLS / "00230_insert_member.sql").read_text(encoding="utf-8")
    if "localtimestamp" not in sql:
        sys.exit("reservation_sql: 00230 does not use localtimestamp")
    _, rows = query("SELECT count(*), bool_and(login_date_time IS NOT NULL) FROM member_login")
    tabs, seqs = dump({"MEMBER": (), "MEMBER_LOGIN": ("login_date_time",)}, SEQUENCES)
    return {"tables": tabs, "loginDateTimeNotNull": rows[0][1] == "t", "sequences": seqs}


def main():
    args = sys.argv[1:]
    check = "--check" in args
    if "--expect-version" in args:
        expect = args[args.index("--expect-version") + 1]
        ver = psql(["-q", "-t", "-A", "-c", "SHOW server_version"], db="postgres").stdout.strip().split(" ")[0]
        if ver != expect:
            sys.exit(f"reservation_sql: server version {ver} != expected {expect}")
    if len({c["id"] for c in CASES}) != len(CASES) or not set(KNOWN_MISMATCH) <= {c["id"] for c in CASES}:
        sys.exit("reservation_sql: duplicate case id or unknown KNOWN_MISMATCH id")
    load()
    upstream = json.loads((ROOT / "trace/upstream.json").read_text(encoding="utf-8"))
    sqls = {op: statement_sql(op) for op in STATEMENTS}
    seed_doc = seed()
    cases = [run_case(c, sqls) for c in CASES]
    psql(["-q", "-c", f"DROP DATABASE IF EXISTS {DB}"], db="postgres")
    doc = {
        "note": "予約が使う Mapper の文の PostgreSQL での実行結果（tools/conformance/reservation_sql.py が生成する。手で編集しない）。"
                "statements は各段の SQL（#{…} を $n にしたもの）と束縛変数の名前・JDBC の型。seed は上流のシード（00230）を投入した"
                " MEMBER・MEMBER_LOGIN（LOGIN_DATE_TIME は localtimestamp なので除き、NULL でないことだけを記録）と、シーケンスの状態"
                "（null は未使用）。cases の各ケースは、初期状態（PostgreSQL から読み戻した値）、段ごとの結果（rows・count・error）、"
                "最後の状態。表の行の順は未規定。knownMismatch はモデルと異なると分かっているケースの分析",
        "upstream": {"release": upstream["release"], "commit": upstream["commit"]},
        "postgresql": upstream["languages"]["postgresql"]["version"],
        "statements": {op: {"locator": LOCATORS[op], "sql": sqls[op], "params": [n for n, _ in STATEMENTS[op][4]],
                            "paramTypes": [t for _, t in STATEMENTS[op][4]]} for op in STATEMENTS},
        "seed": seed_doc,
        "cases": cases,
    }
    content = json.dumps(doc, ensure_ascii=False, indent=1) + "\n"
    if check:
        if not OUT.is_file() or OUT.read_text(encoding="utf-8") != content:
            sys.exit(f"reservation_sql: {OUT.relative_to(ROOT)} is out of date (run tools/conformance/reservation_sql.py)")
        print(f"reservation_sql: {OUT.relative_to(ROOT)} up to date")
    else:
        OUT.write_text(content, encoding="utf-8")
        print(f"reservation_sql: wrote {OUT.relative_to(ROOT)} ({len(cases)} cases)")


if __name__ == "__main__":
    main()
