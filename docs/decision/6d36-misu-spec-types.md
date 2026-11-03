---
type: Architecture Decision Record
title: "ATRS の Spec の型を、不正な状態を表現できない型にする（L1 値・L2 境界・L3 関係）"
description: "スキルの ADR bf1b を ATRS の Spec に当てる。L1 で値に閉じた制約（コード値の形式・列の形・エラーコード・位置の組）を型に、L2 で機械の入力・要求を生の型にして検証済みの型に移し、L3 で設定・マスタ・World の不変条件を証明フィールドに置く。機械の PRE・INV と、状態とマスタの外部キーは述語のまま残す。表せない DB の値は D-027 に入れ、型に移った PRE の成分を挙げていた outsidePre の項目を付け替える。"
tags: [adr, spec, types, misu]
id: "6d36ed5f-510b-43ed-8f73-78f4325bff5e"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: プロジェクトオーナー（深さ L1+L2+L3、段ごとのコミット、JDouble の正規形化を含めること）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T14:00:00+09:00
---

# ATRS の Spec の型を、不正な状態を表現できない型にする（L1 値・L2 境界・L3 関係）

## Context and Problem Statement

プロジェクトオーナーは、spec-pivot と ATRS の `Spec` の両方で、各データ型を不正な状態を表現できない型（MISU）にすることを徹底するよう指示した。スキルの側の規則は、[スキルの ADR bf1b](../../.agents/skills/spec-pivot/references/docs/decision/bf1b-make-illegal-states-unrepresentable.md) に置いた。

ATRS の `Spec` には、次のように条件を型の外に置いた型がある（型の棚卸し。[guide/type-inventory.md](../../.agents/skills/spec-pivot/references/docs/guide/type-inventory.md)）。

* コード値（`AirportCd`・`FlightName`・`MembershipNumber`・`ReserveNo`・`CreditTypeCd`）は `val : String` で、形式は別の述語 `WellFormed` にある。うち 3 つの述語は、どこからも使われていない。
* `Reservation.reserveFlights` は「長さ 1 か 2」が docstring にしか無い。`ReserveFlight.reserveNo` は、親の予約番号の写しである。各予約フライトの搭乗者の列が同じであることも、docstring にしか無い。
* `AtrsError` のコードは文字列で、引数の数もコードごとの約束である。
* `Nondet.FaultSpec` は、位置で意味が決まる組 `Option Nat × Option Nat` である。
* `Config.Valid`・`MasterData.Valid`（MD-1〜MD-8）・`World.Inv` は、値とは別の述語である。

## Decision Drivers

* スキルの ADR bf1b の規則 1〜5。
* PRE の外の振る舞い（outsidePre）と、環境の前提の非自明性（G8。`EnvPre.badMasterData`）は、不正な入力・環境を表せることに依存する。
* 表せない DB の値は 1 つの差異 D-027 にまとめる（[ADR c108](c108-master-data-source-model-and-spec-fixes.md)、[ADR f353](f353-abs-026-proof-structure-nop-and-d027-scope.md)）。
* 便名の形式 `FlightName.WellFormed` の中身は変えない（ADR f353 のプロジェクトオーナーの決定）。

## Considered Options

* L1 のみ: 値に閉じた制約だけを型に置く。
* L1+L2: 加えて、境界の生の型と検証済みの型を分ける。
* L1+L2+L3: 加えて、設定・マスタ・World の関係的な不変条件を証明フィールドに置く。

## Decision Outcome

Chosen option: "L1+L2+L3", because プロジェクトオーナーが選び、内部の関数が PRE の外を表す `Option` を持たなくてよくなるからである。機械の PRE・INV の述語の枠は、B メソッドの枠として残す。

### L1 値

* コード値は、証明フィールド付きにする。形式は、いまの `WellFormed` の述語をそのまま使う。
* 照会条件・マスタ照会・選択フライトの値のように、外部から来るコードは生の型（`@[raw_input]`）にする。照合では `val` を比べる。
* `Reservation` について:
  * `reserveFlights` を、片道か往復かの和型にする。
  * `ReserveFlight.reserveNo` の写しは消す。
  * 搭乗者の列は予約に 1 つだけ置く。
* `AtrsError` のコードは列挙にし、引数の数を構築子ごとに決める。JSON の綴りは変えない。
* `FaultSpec` は名前付きの `structure` にする。

### L2 境界

* 機械の入力・要求・画面の入力（`BasicFareInput`・`FareInput`・`TotalFareInput`・`SearchInput`・`Request`・`ReserveInput`・`PassengerInput`・`SelectFlight`、照会条件）は生の型とし、`@[raw_input]` を付ける。
* 検証の関数（`buildDraft`・`validateFlightList` など）は、検証済みの型（予約の内容、片道・往復のフライト）を返す。

### L3 関係

* 設定とマスタは、生の型（環境）と検証済みの型に分ける。検証済みの型は、MD-1〜MD-8 と `Config.Valid` を証明フィールドで持つ。
* 入口の環境の前提 `EnvPre.masterConfigOk` は「検証が成功する」こととして書き直す。G8 の反例は、生の型で残す。
* `World` は、キーの一意性を証明フィールドで持つ。
* 状態とマスタの外部キー `World.RefMaster`・`World.MemberRefMaster` は、互いに独立な入力の間の関係なので、PRE の述語のまま残す（スキルの ADR bf1b の規則 3）。

### ギャップ

* 具体側（DB の行）に `Spec` の型で表せない値があれば、D-027（前提型・具体側の入力）に入れる。α は、具体側の不変条件の下で証明を渡し、外では既定の値に写す。
* 抽象側の PRE の成分が型に移ったら、その成分を `excludedBy` に挙げた outsidePre の項目（D-029・D-034・D-036 など）を付け替える。付け替えは、この ADR の段の記録に書く。
* `Spec` の振る舞いが変わる判断は、その段で止めてプロジェクトオーナーに確かめる。いま見えているのは、`ReserveNo` の 10 桁の形式と、上限の無い採番（D-009）がぶつかることである。

### 段

作業は [backlog 8d24](../backlog/8d24-misu-spec-types.md) で、スキルの側（[スキルの backlog d3fd](../../.agents/skills/spec-pivot/references/docs/backlog/d3fd-misu-skill-types.md)）の後に、L1・L2・L3 の順に行う。各段の結果は、下の「段の記録」に足す。

### Consequences

* Good, because 内部の関数は検証済みの型だけを受け、PRE の外を表す `none` が境界の検証にまとまる。
* Good, because コード値の 3 つの使われない述語が、型として効く。
* Bad, because α・生成器・テストの読み取り・証明の書き換えが大きい。

### Confirmation

* スキルの検査 MISU-1（`check_lean.py`）。
* トップレベルの主定理 `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts`、`seed_env`、`lake test` の適合テストベクタが通ること。
* `trace manifest` が生成する `docs/spec/abstraction.md` の表の差分が、段の記録に書いた付け替えだけであること。

## More Information

* [スキルの ADR bf1b](../../.agents/skills/spec-pivot/references/docs/decision/bf1b-make-illegal-states-unrepresentable.md)、[backlog 8d24](../backlog/8d24-misu-spec-types.md)

### 段の記録

* **前段（スキルの側）**: スキルの backlog d3fd の S1〜S4 で、ギャップの登録簿 `Abstraction.Gap` の 41 件を和型の `Trace.Gap` に書き換え（生成表は不変）、`LocalDate`・`LocalTime`・`double` の写しの妥当性・正規形の型に合わせて `Abstraction` の字面と補題を直した（[Spec] の暦日から `LocalDate` への `Abstraction.Prim.Date.jOfDate`）。運賃の double の解析（ADR e9bc）の定理の主張は変わらない。変わった `SourceModel` の定義の照合の記録は `trace rehash` で更新した。
* **検査の段階導入**: スキルの検査 MISU-1 が見つける `Spec` の 13 件（コード値 6 型とその `WellFormed` 5 件、`Query.Valid`・`Request.Valid`）のうち、`PasswordHash` は外部（パスワードエンコーダのポート）の不透明な値なので `@[raw_input]` にした。`Query`・`Request`（機械の入力）も `@[raw_input]` にした（その `Valid` は PRE）。残る 10 件（コード値 5 型とその `WellFormed`）は `trace/project.json` の `lean.misu_pending` に挙げ、L1・L2 の段で 1 件ずつ外す。
* **未決（プロジェクトオーナーの判断を待つ）**: `ReserveNo` の 10 桁の形式と、上限の無い採番（D-009）。
