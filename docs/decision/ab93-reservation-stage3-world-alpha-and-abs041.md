---
type: Architecture Decision Record
title: "予約の第 3 段: 全表の α と共有の初期状態、具体側の不変条件、予約の R 課題"
description: "backlog aedf の第 3 段の設計を決める。状態の α worldOfDb を全表（会員・予約・シーケンス）に広げて Abstraction.World.Alpha に置き、空席照会と予約で共有する。予約の表は、子の行が親の順に並ぶときに限って写す。主キーの一意性に使う具体側の不変条件 IcW（使用済みの番号が採番の次の値より小さい）を、両方の貼り合わせに置く。空席照会の初期状態を、シードを投入した後の World・状態の表に揃える。第 3 段を小段 3a〜3d に分ける。"
tags: [adr, abstraction, reservation, machine, alpha]
id: "ab9318bc-ec06-4d90-8080-42395aadcfaa"
status: stable
decision_status: accepted
date: 2026-11-02
decision-makers: プロジェクトオーナー（3 段の進め方と、確認待ちで登録して続けること）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T12:00:00+09:00
---

# 予約の第 3 段: 全表の α と共有の初期状態、具体側の不変条件、予約の R 課題

## Context and Problem Statement

[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md) で、[backlog aedf](../backlog/aedf-reservation-usecase.md) を 3 段に分けた。第 1・2 段では、予約の関数・ベクタ・機械・初期状態・SQL の差分実行を置いた（[ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md)）。

第 3 段では、予約の R 課題を証明し、トップレベルの主定理に統合する。予約と空席照会は同じ状態 `World` を共有し、合成子 `Machine.alt` で並置する（[スキルの ADR a303](../../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)）。`Refines.alt`・`Preserves.alt` は、次を仮定する。

* 2 つの貼り合わせの `J` が等しい
* 初期状態が同じ 1 点である
* INV が等しい

第 2 段までの空席照会の α `worldOfDb` には、次の制限があった。

* 予約・会員の表とシーケンスが使われていない状態に限っていた
* 初期状態は、FLIGHT 表だけのシード（`Spec.Seed.Flight.world`・`seedFlightDb`）だった

予約の主キーの一意性を示すには、使用済みの番号と採番の関係も要る。

## Decision Drivers

* 原則 B: 予約と空席照会を、トップレベルの主定理で並置する。
* α は、定義域の上で単射な部分写像で、核の義務 ABS-048（obligation-check の G7）を満たす。
* 既存の ABS-011 の証明を、状態の型を合わせるだけで使い続ける。

## Considered Options

* α の置き場所
  * (a) 空席照会と予約が共有するモジュール `Abstraction.World.Alpha` に置く
  * (b) 空席照会のモジュールに置いたまま広げる
* 予約の表の写し方
  * (a) 予約の行ごとに、予約番号の同じ予約フライトの行（と、予約フライト番号の同じ搭乗者の行）を表の順に集め、子の表が親ごとの子の列をつないだものに等しいときに限って写す
  * (b) 子の表を予約番号・予約フライト番号で並べ替えて集める
* 主キーの一意性の不変条件
  * (a) 具体側の不変条件 `Ic`（`Glue.ofStd` の成分）に置く
  * (b) [Spec] の `World.Inv` に置く

## Decision Outcome

Chosen option: "α の置き場所 (a)・予約の表 (a)・不変条件 (a)"。理由は次のとおりである。

* 置き場所 (a): 2 つの機能の貼り合わせの `J` が、同じ定義になる。
* 予約の表 (a): 登録は親・子の順に表の末尾に足すので、[Source] の到達する状態はこの形である。写しが単射なので、核は `undefOrEq` のままになる。(b) は登録順（[Spec] の予約の列の順）を失う。
* 不変条件 (a): [ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md) の方針どおり。[Spec] の INV を変えずに済み、予約の SPEC 課題の証明を作り直さない。

### 第 3 段の小段

| 小段 | 内容 |
| --- | --- |
| 3a | 全表の α、具体側の不変条件、空席照会の初期状態の変更（本 ADR の決定） |
| 3b | ポートの R 課題 ABS-021・ABS-023、差異の述語（D-009・D-014・D-031）、W 課題 ABS-109・ABS-131 |
| 3c | 予約の R 課題 ABS-041 と L 課題 ABS-020・ABS-022 |
| 3d | トップレベルへの統合（`searchMachine.alt reserveMachine`）、束、記録 |

### 3a の決定

| 項目 | 決定 |
| --- | --- |
| 状態の α | `Abstraction.World.Alpha.worldOfDb`（葉。核 `worldOfDb_kernel`）。<br>- FLIGHT: 行ごとに `flightOfRow`<br>- MEMBER・MEMBER_LOGIN: 同じ位置の行を組にする（会員番号が違えば定義しない）。ログイン日時は 0:00 のときだけ暦日に写す（`dateOfTimestamp`）<br>- 予約の表: 上の (a)<br>- シーケンス: 次に返す値（未使用なら 1、最後に返した値 `v ≥ 1` なら `v + 1`）<br>補助の写像（複数の行を組にするもの）には `@[std_abs]` を付けない（G7 は 1 引数の葉か、許可した合成を求める） |
| 具体側の不変条件 | `IcW t`: α の像で、使用済みの予約番号は次の予約番号より小さい番号の書式、予約フライト番号・搭乗者番号は次の値より小さい（`KeysBelow`） |
| 空席照会 | 貼り合わせ `glueFS` の `Ic` を `IcW` にする。`searchMachine` の初期状態を `Spec.Seed.World.world`、`searchConcrete` の初期状態を `SourceModel.Db.Seed.seedDb` にする。照会は状態を変えないので、`IcW` は保たれる |
| 初期状態の対応 | `Abstraction.World.Init.worldOfDb_seed`（FLIGHT は生成の形の上で合成、会員はカーネルで照合）と `icW_seed`。旧 `Abstraction.FlightSearch.Init` を移した |
| 予約・会員を含む状態の空席照会 | 暫定の制限（[assurance.md](../spec/assurance.md) の行）を外した。上流のシードの会員を投入した状態も α の定義域に入る |

### 3b の決定（途中）

| 項目 | 決定 |
| --- | --- |
| [Spec] の予約の PRE | 次を足す（[Spec] の修正）。<br>- `Request.Valid`: 入力検証の単項目制約のうち長さと桁、相関 1 の電話番号の長さの上限、選択フライトの便名が空白でないこと。原典の列の長さ（`VARCHAR(n)`）と `int` に収まることに使う<br>- `World.RefMaster`: フライトの便名・搭乗クラス・運賃種別がマスタにある。原典は存在の確認で搭乗クラス・運賃種別のコードを束縛するので、マスタに無いと `NULL` になり、[Spec] と結果が分かれる<br>- `World.MemberRefMaster`: 会員のカード種別がマスタにある。原典の会員の取得はカード種別の表と結合する |
| 具体側の不変条件 | `IcW` の `KeysOk` に、会員番号の一意性（PK_MEMBER）を足す。会員の取得の文の結果を高々 1 行にするのに使う |
| ABS-021・ABS-023 の種類 | R 課題から、ABS-041 の補題（L 課題）に改める（プロジェクトオーナーの決定）。ポートの実装は、予約の具体機械の中で使われ、単独の機械として外に出ない。R 課題にすると、ポートごとの機械と束 `Preserves` が要る。ABS-023 は `Abstraction.Reserve.Port`・`Member` の補題に付けた。ABS-021 は採番の補題を置くとき（3c）に付ける。ABS-024・ABS-025 の種類は、それぞれの機能の backlog で決める |
| 予約の入出力の α | `aiR`（設定・マスタ・Clock の最初の読み出し・選択フライト・予約フォーム・操作の種類）と `aoR`（核 `undefOrEq`）。不正要求の詳細は空文字に写し、[Spec] の詳細は自由な選択 N-004 で置き換える |
| [Source] の計算の検証 | 3c の前に検証の道具を整える（プロジェクトオーナーの決定）。Hoare 三つ組と、状態を与えた形に簡約するタクティク `java_estate_simp` をスキルの assets に置いた（[スキルの ADR cd90](../../.agents/skills/spec-pivot/references/docs/decision/cd90-estate-hoare-and-simp-tactics.md)。スキルの版 0.26）。文の実行の規則と障害の例外 `IsFault` は ATRS の `Abstraction.Reserve.Tx` に置く。試しとして、選択フライトの検証の全経路（1 便・往復、便マスタの有無、障害）の三つ組と [Spec] の対応を `Abstraction.Reserve.ValidateFlights` で示した |

| 差異の述語 | `Abstraction.Reserve.Alpha` に置き、それぞれに非自明性の定理を `Abstraction.Reserve.Witness` に置いた（G8）。<br>- 具体側: `dev_D027R`（`aiR` が定義され、業務例外の引数に使う運賃種別名が改行を含まない。SourceModel の業務例外のメッセージがコードと引数を改行でつないだものなので）、`dev_D014R`（Clock のどの読み出しも最初と同じ日付）<br>- 抽象側: `dev_D009`（状態と入力。予約確定で使う番号がシーケンスの最大値と `int` の上限を超えない）、`dev_D031`（往復の往路便の到着時刻が 24:00 より前）、`dev_D001R`・`dev_D002R`・`dev_D012R`（合計金額の入力 `tfOf` に `dev_D001T` などを課す）<br>ABS-041 の機械は `reserveMachine` に `restrictState dev_D009` と抽象側の `restrict` の層、`reserveConcrete` に `dev_D027R`・`dev_D014R` の `restrict` の層をかけたものとする（層の並びは 3c で W 課題の否定の定理と合わせて固める） |
| W 課題の証人 | D-031 の証人の材料（往路便 NTT523 の到着時刻 `2415` のマスタ `db2415`・FLIGHT 表 `fd2415`・往復の予約確認 `ic2415`）を置いた。[Source] の計算が `DateTimeParseException` で終わることは `#eval` で確かめた。カーネルでの評価（`decide +kernel`）は途中で簡約できずに止まるので、評価の定理と否定の定理 `need_D031`・`need_D009` は 3c で ABS-041 と同時に置く |

置いた補題（すべて `sorry` なし）:

* `Abstraction.Reserve.Port`: FLIGHT の主キーの条件・`exists`・`findOneForUpdate`・`update` の行
* `Abstraction.Reserve.Member`: `MemberRepository.findOne` の文の結果と `World.findMember`、`member-map` と会員の照合
* `Abstraction.Reserve.Providers`: 便マスタの Provider の答え（区間の空港コード、無い場合の `null`）、予約が使う読み込みの性質 `load_res`
* `Abstraction.Reserve.Flights`: 到着・出発時刻の解釈、搭乗間隔の検査（D-031 の前提）、運賃種別・逆区間の検査の対応 `AgreeV`
* `Abstraction.Reserve.Select`: `toFlightList` が作るフライト情報の性質（便マスタの有無、存在の確認の文の結果、運賃種別のコード）
* `Abstraction.Reserve.ValidateFlights`: 選択フライトの検証の Hoare 三つ組と、[Spec] の `validateFlightList` の対応

### 3c の決定（途中）

| 項目 | 決定 |
| --- | --- |
| 業務例外の対応 | 検査の結果の対応 `AgreeB`（どちらも成功するか、[Source] の業務例外と [Spec] の `Business` のコードと引数が同じ）を置く。状態を伴う検査の事後条件は `PostB`・`PostBE`（障害 `IsFault` か、同じコードと引数の業務例外）とし、検査の逐次は `seqB`、純粋な検査の持ち上げは `lift_agreeB` でつなぐ |
| 予約フライトごとの繰り返し | 原典は、運賃種別の利用条件と搭乗者の会員照合を予約フライトごとに繰り返す。[Spec] は、運賃種別の利用条件を便ごとの検査の最初の失敗（`firstErr`）、搭乗者の会員照合を 1 回とする。後者は、すべての予約フライトが同じ搭乗者列を持つので、最初の繰り返しが [Spec] と同じ結果になり、2 回目以降は成功か障害である（`forIn_same`） |
| トランザクションの取消 | 状態の表を変えない計算（`validateReservation`）では、取消は状態を変えない（`transactional_hoare`。`FlightDb.rollback fd fd = fd`） |
| 合計金額 | 予約の合計金額の計算は、合計金額の L 課題 ABS-005（`runTotalFare_eq`）から [Spec] の `totalFareOfKeys` の値になる（`Abstraction.Reserve.TotalFare.calc_eq`）。会員の表を差し替えたサービスでも同じ |

置いた補題（すべて `sorry` なし）:

* `Abstraction.Reserve.Validate`: 代表者の年齢・運賃種別の利用条件の検査の対応（`repAge`・`fareTypes`）
* `Abstraction.Reserve.MemberCheck`: 会員の取得の三つ組 `findOne_hoare`、代表者・搭乗者の会員照合の三つ組（`repMember_hoare`・`passengerMember_hoare`）
* `Abstraction.Reserve.ValidateReservation`: 予約内容の検証の三つ組と、[Spec] の `validateReservation` の対応（`validate_hoare`）
* `Abstraction.Reserve.TotalFare`: 予約の合計金額（`calc_eq`）

### Consequences

* Good, because 空席照会と予約の貼り合わせの `J` が同じ定義になり、`Refines.alt`・`Preserves.alt` の仮定を満たせる
* Good, because 会員を投入した上流のシードの状態で、空席照会のリファインメントが成り立つ
* Bad, because 予約の表の α は子の行の並びを定義域に課す。登録以外の書き込み（予約の取消など。backlog ac71・4e0e）を写すときは、その操作がこの形を保つことを示す

### Confirmation

* `lake build`・`lake test`・axiom-check・layout-check・obligation-check・`trace check` が通る。
* ABS-011（`searchRefines`・`searchPreserves`）とトップレベルの主定理が、新しい貼り合わせで通る。

## More Information

* [backlog aedf](../backlog/aedf-reservation-usecase.md)、[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md)、[ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md)
* [spec/abstraction.md](../spec/abstraction.md#抽象化関数-α)
