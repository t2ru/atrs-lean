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
| ABS-021・ABS-023 の種類 | R 課題から、ABS-041 の補題（L 課題）に改める案（プロジェクトオーナーの確認待ち）。ポートの実装は、予約の具体機械の中で使われ、単独の機械として外に出ない。R 課題にすると、ポートごとの機械と束 `Preserves` が要る |
| 予約の入出力の α | `aiR`（設定・マスタ・Clock の最初の読み出し・選択フライト・予約フォーム・操作の種類）と `aoR`（核 `undefOrEq`）。不正要求の詳細は空文字に写し、[Spec] の詳細は自由な選択 N-004 で置き換える |
| [Source] の計算の検証 | Hoare 三つ組の枠組み `Abstraction.Reserve.Hoare`（`EStateM` の逐次・分岐・例外・`for`）と、文の実行の規則 `Abstraction.Reserve.Tx`（障害の例外 `IsFault`）。Lean 4.35 の `Std.Do`（`mvcgen`）も使えることを確かめたが、原典のメソッドを展開すると `Assert` などの細部が検証条件に混ざるので、経路ごとの計算の形を先に示す |

置いた補題（すべて `sorry` なし）:

* `Abstraction.Reserve.Port`: FLIGHT の主キーの条件・`exists`・`findOneForUpdate`・`update` の行
* `Abstraction.Reserve.Member`: `MemberRepository.findOne` の文の結果と `World.findMember`、`member-map` と会員の照合
* `Abstraction.Reserve.Providers`: 便マスタの Provider の答え（区間の空港コード、無い場合の `null`）、予約が使う読み込みの性質 `load_res`
* `Abstraction.Reserve.Flights`: 到着・出発時刻の解釈、搭乗間隔の検査（D-031 の前提）、運賃種別・逆区間の検査の対応 `AgreeV`
* `Abstraction.Reserve.Select`: `toFlightList` が作るフライト情報の性質（便マスタの有無、存在の確認の文の結果、運賃種別のコード）

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
