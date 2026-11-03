---
type: Specification
title: "予約（B0/B2）"
description: "選択フライトの検証、予約内容の検証、予約確認、空席の確保と予約登録、会員情報による入力補完。"
tags: [spec, reservation, b0, b2]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 予約（B0/B2）

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。ただし「予約確定」の原子性・排他の要件は [ports.md](ports.md#トランザクション) の規範節に従う。

> Lean の定義（backlog aedf の第 1 段）: `Spec.Ticket`（選択フライト・`validateFlightList`）、`Spec.UseCase.Reserve`（予約内容の組み立て・`validateReservation`・`reserveConfirm`・`reserve`・`confirmOp`・`reserveOp`）。抽象機械と SPEC 課題は第 2 段、抽象化の証明は第 3 段で置き、そのときに本書の該当節を informative に置き換える。

予約は「フライト選択（B1 画面）→ 予約入力（B2）→ 確認 → 確定」の順に進む。画面遷移は [http-contract.md](http-contract.md)、入力検証は [input-validation.md](input-validation.md#予約入力b2) を参照。

## 選択フライト

画面から送られる選択フライトは `SelectFlight = { depDate, flightName, boardingClassCd, fareTypeCd }` の列（往路、復路の順）である。
これをマスタで解決したものを `Flight`（便マスタ・運賃種別・搭乗クラスの実体を伴う）として扱う。

**[Spec=Source]** `resolve(sel)`: `flightMasterOf(sel.flightName)`, `fareTypeOf(sel.fareTypeCd)`, `boardingClassOf(sel.boardingClassCd)` を引く。選択フライトの便名は生の文字列で、便マスタを値で引き、主キーの便名は便マスタの便名とする（Lean では便マスタが無ければ解決の結果が無い。[ADR 6d36](../decision/6d36-misu-spec-types.md)）。便マスタが無い場合は「便マスタ無し」として次の検証で `InvalidRequest` にする。便名が空白だけ（U+3000 など）の場合も同じである。[Source] は `FlightMasterProvider.getFlightMaster` の `Assert.hasText` で例外（500）になる（既知差異 [D-039](abstraction.md#既知差異)）。

出典: `java:jp.co.ntt.atrs.app.b0.TicketHelper#toFlightList(List)`

## validateFlightList

選択フライトの整合性検証。改竄（通常の画面操作では起きない値）は `InvalidRequest`、利用者の選択ミスは `Business` とする。

### シグネチャ

`validateFlightList(flights: [Flight], allFlights; master, config) : Except AtrsError Itinerary`

成功したときは、検証した便の主キーを、片道（1 便）か往復（往路・復路）の `Itinerary` で返す。予約確認・予約確定は、この主キーを使う（Lean: `Spec.Ticket.Itinerary`）。

### 事前条件

- `1 ≤ len(flights) ≤ 2`（[Source]: `Assert`）。

### 定義（評価順）

1. 往路 `o = flights[0]`: 便マスタが無ければ `InvalidRequest("flightMaster is null")`。`o` の主キーに一致するフライトが `allFlights` に無ければ `InvalidRequest("flight not found")`。
2. `len(flights) = 2` のとき、復路 `h = flights[1]` に同じ検査を行い、さらに:
   1. 搭乗間隔: `at(o.departureDate, o.arrivalTime) + reserveIntervalTime 分 > at(h.departureDate, h.departureTime)` なら `Business("e.ar.b2.2001")`。ちょうど間隔分なら可。到着時刻は出発日 0:00 からの時分で、24:00 より後（翌日着）でもよい（[Source] は `HHmm` で読むので、翌日着の便で例外になる。既知差異 [D-031](abstraction.md#既知差異)）。
   2. 逆区間: `o` の区間の出発空港 ≠ `h` の区間の到着空港、または `o` の到着空港 ≠ `h` の出発空港なら `InvalidRequest("homeward route is not outward route reverse")`。
3. 運賃種別:
   - `len = 1`: `o.fareTypeCd ∉ oneWayFareTypes` なら `InvalidRequest`。
   - `len = 2`: `o.fareTypeCd ∉ roundTripFareTypes` または `h.fareTypeCd ∉ roundTripFareTypes` なら `InvalidRequest`。

搭乗日が照会可能期間内か・運賃種別が予約可能期間内かは **ここでは検査しない**（後者は予約登録時に検査する）。

出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#validateFlightList(List)`, `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#existsFlight(Flight)`

### 例

`reserveIntervalTime = 120`。往路 HND→ITM 2026-04-11 09:00–10:00、復路 ITM→HND 2026-04-11 12:00 発 → 可（10:00 + 120 分 = 12:00）。復路 11:59 発 → `e.ar.b2.2001`。復路が 2026-04-10 → `e.ar.b2.2001`。

## 予約内容の組み立て

**[Spec=Source]** 予約入力（`TicketReserveInput`、[input-validation.md](input-validation.md#予約入力b2)）とフライト列から `Reservation`（採番前）を作る。

- `passengers` = 入力の搭乗者欄のうち **空でないもの** を入力順に並べたもの。搭乗者欄が空とは、姓・名・会員番号がいずれも空白のみ（または未入力）で、年齢と性別が未入力であること。
- `reserveFlights` = 各フライトに 1 つずつ。**すべての予約フライトが同じ `passengers` を持つ**。
- `repTel = tel1 ++ "-" ++ tel2 ++ "-" ++ tel3`。
- `repMembershipNumber` は入力が空なら無し。各搭乗者の `membershipNumber` も同様。予約内容の会員番号は入力の文字列のままで（Lean: `Spec.UseCase.Reserve.DraftPassenger`）、会員の照合は値で引く。形式に合わない番号は会員が見つからない業務エラーになる。登録では、照合に成功した番号（会員の番号）を `MembershipNumber` として読む（[ADR 6d36](../decision/6d36-misu-spec-types.md)）。

出典: `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserveConfirm(TicketReserveForm,List)`・`java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserve(TicketReserveForm,List)`（private の `createReservation` を含む）, `java:jp.co.ntt.atrs.app.b2.TicketReserveForm#resetPassengersIndex()`, `java:jp.co.ntt.atrs.app.b2.PassengerForm#isEmpty()`

## validateReservation

### シグネチャ

`validateReservation(r: Reservation, members: MemberRepository; master, config) : Except AtrsError Unit`

### 定義（評価順。最初に失敗した検査のエラーを返す）

1. **代表者年齢**: `r.repAge < representativeMinAge` なら `Business("e.ar.b2.2004", [representativeMinAge])`。
2. **運賃種別の利用条件**: 予約フライトを順に、
   - `fareTypeCd = LD`（レディース割）: 搭乗者に `gender = M` がいれば `Business("e.ar.b2.2007")`。
   - `fareTypeCd = GD`（グループ割）: `len(passengers) < fareType.passengerMinNum` なら `Business("e.ar.b2.2010", [fareTypeName, passengerMinNum])`。
   - その他の運賃種別では `passengerMinNum` を検査しない（原典どおり）。
3. **代表者の会員照合**（`repMembershipNumber` がある場合のみ）:
   - 会員が存在しなければ `Business("e.ar.b2.2002")`。
   - `repFamilyName = member.kanaFamilyName ∧ repGivenName = member.kanaGivenName ∧ repGender = member.gender` でなければ `Business("e.ar.b2.2003")`。
4. **搭乗者の会員照合**: 予約フライトを順に、その搭乗者を 1 から数えた位置 `pos`（空の搭乗者欄を詰めた後の位置。入力欄の添字 + 1 とは一致しないことがある）で、`membershipNumber` がある搭乗者について、
   - 会員が存在しなければ `Business("e.ar.b2.2005", [pos])`。
   - `familyName = member.kanaFamilyName ∧ givenName = member.kanaGivenName ∧ gender = member.gender` でなければ `Business("e.ar.b2.2006", [pos])`。

文字列比較はスカラ値の完全一致（[spec-pivot/portability.md](../../.agents/skills/spec-pivot/references/docs/spec/portability.md#文字列)）。

出典: `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#validateReservation(Reservation)` ほか

## 予約確認（reserveConfirm）

**[Spec=Source]**

1. 搭乗者欄を詰める（空でない欄を前に詰め、6 欄に戻す）。
2. 予約内容を組み立てる。
3. `validateReservation`。
4. `totalFare = totalFare(flights, reserveFlights[0].passengers)`（[fare-calculation.md](fare-calculation.md#合計金額)）を返す。

出典: `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserveConfirm(TicketReserveForm,List)`

## 予約確定（reserve）

**[Spec]** 1 つのトランザクションとして実行する（[ADR 97f9](../decision/97f9-persistence-and-transaction-semantics.md)）。[Source] は手順 2（`validateReservation`）と手順 3 以降（`registerReservation`）を別のトランザクションで行う（モデル外の既知差異 [D-037](abstraction.md#既知差異)）。いずれかの段階で失敗した場合、状態は一切変化しない（採番の前進 `World.sequences` を除く。[ports.md](ports.md#idgenerator)）。

1. 予約内容を組み立てる。
2. `validateReservation`。
3. `reserveDate = today`、`totalFare = totalFare(flights, reserveFlights[0].passengers)`。`today` は、ユースケースの初めに 1 回だけ読んだ値である（[Source] は呼ぶたびに読む。既知差異 [D-014](abstraction.md#既知差異)）。
4. 予約フライトを順に、
   1. `isAvailableFareType(fareType, departureDate, today)`（[flight-search.md](flight-search.md#運賃種別の予約可能判定)）でなければ `Business("e.ar.b2.2008")`。
   2. 主キーでフライトを **排他的に** 取得し（同時実行の予約と直列化される）、`vacantNum < len(passengers)` なら `Business("e.ar.b2.2009")`。
   3. `vacantNum := vacantNum − len(passengers)` に更新する。
5. `reserveNo = IdGenerator.nextReserveNo()` で予約を登録する。
6. 予約フライトを順に `reserveFlightNo = IdGenerator.nextReserveFlightNo()` で登録し、その搭乗者を順に `passengerNo = IdGenerator.nextPassengerNo()` で登録する。
7. `paymentDate = reserveFlights[0].flight.departureDate`（往路搭乗日を支払期限とする）。
8. `{ reserveNo, paymentDate, totalFare }` を返す。

**[Source]** の追加の振る舞い:

- 各登録・更新の件数が 1 でなければ `System("e.ar.a0.L9002", [件数, 1])`（[Spec] ではリポジトリ契約により到達不能。[Spec] の前提の外の振る舞い [D-010](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。
- 手順 4.2 で主キーのフライトが存在しなければ `NullPointerException`（前提違反）。`validateFlightList` 済みなら到達しない。
- 採番が循環して既存番号と衝突した場合は主キー違反によるシステムエラー（既知差異 [D-009](abstraction.md#既知差異)）。

### 不変条件

- 予約確定の前後で、すべてのフライトの `vacantNum ≥ 0`（課題 [ABS-020](abstraction.md#証明課題), [REF-002](refinement.md)）。
- 成功時、各予約フライトのフライトの `vacantNum` は搭乗者数だけ減る。失敗時は `sequences` 以外の状態が不変。

出典: `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#reserve(TicketReserveForm,List)`, `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#registerReservation(Reservation)`（private の `validateAndUpdateVacancy` を含む）

### 例

フライト残席 2 に搭乗者 3 名で予約 → `e.ar.b2.2009`、残席 2 のまま。
往復予約で往路は残席十分・復路が残席不足 → `e.ar.b2.2009`、往路の残席も変化しない。

## 会員情報による入力補完

**[Spec=Source]** ログイン中の会員が予約入力画面を開いたとき、入力の初期値を会員情報から作る。

- `repFamilyName ← kanaFamilyName`, `repGivenName ← kanaGivenName`, `repGender ← gender`, `repMail ← mail`, `repMembershipNumber ← membershipNumber`
- `tel` を `-` で分割し、ちょうど 3 要素なら `repTel1, repTel2, repTel3` に設定（それ以外は未設定）。
- `repAge = fullYearsBetween(birthday, today)`（[domain-model.md](domain-model.md#date)）。
- 1 番目の搭乗者欄に代表者と同じ姓・名・年齢・性別・会員番号を設定する。

未ログイン時は 6 欄すべて空の入力を初期値とする。

出典: `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#createTicketReserveForm(AtrsUserDetails)`

## 予約画面のフライト表示

**[Spec=Source]** 選択フライトの各 `i` について、`lineType = (i = 0 ? OUTWARD : HOMEWARD)`、便名・出発時刻・到着時刻・出発/到着空港コード・搭乗クラス・運賃種別・`fare = fare(basicFare(route.basicFare, boardingClassCd, depDate), discountRate)` を表示する。

出典: `java:jp.co.ntt.atrs.app.b2.TicketReserveHelper#createSelectFlightDtoList(List)`
