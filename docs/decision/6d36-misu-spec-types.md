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
* **検査の段階導入**: スキルの検査 MISU-1 が見つける `Spec` の 13 件（コード値 6 型とその `WellFormed` 5 件、`Query.Valid`・`Request.Valid`）のうち、`PasswordHash` は外部（パスワードエンコーダのポート）の不透明な値なので `@[raw_input]` にした。`Query`・`Request`（機械の入力）も `@[raw_input]` にした（その `Valid` は PRE）。残る 10 件（コード値 5 型とその `WellFormed`。うち `ReserveNo` の 2 件は下の決定で外した）は `trace/project.json` の `lean.misu_pending` に挙げ、L1・L2 の段で 1 件ずつ外す。
* **`ReserveNo` の決定（プロジェクトオーナー、案 A）**: 10 桁の形式と上限の無い採番（D-009）がぶつかる件は、次の 4 案から A を選んだ。
  * A: 予約番号を採番の値（`num : Nat`）で持ち、10 桁のゼロ埋めの表記は関数 `ReserveNo.val` で与える。`Spec` の振る舞いは変えず、10 桁を超えたときの [Source] との違いは D-009 に残す。
  * B: 10 桁の型にし、`Spec` の採番に上限を設ける（上限での振る舞いを新たに決める）。
  * C: 10 桁の型にし、「採番が上限未満」を予約の PRE に入れる（D-009 の一部を PRE の外に付け替える）。
  * D: いまのまま（MISU の指示に反する）。

  A を選んだのは、型が表す値と `Spec` が作りうる値が一致し、仕様の振る舞いを変えないからである。表記を読む `ReserveNo.ofString?` は表記の形（10 桁以上のゼロ埋めの十進文字列）でない文字列を拒む。DB の行から写す α（`Abstraction.World.Alpha`）と予約確定の出力の α（`Abstraction.Reserve.Alpha.aoR`）は、これで表記を読む。読めない表記は D-027（表せない DB の値）に当たる。予約番号の書式の補題（`Abstraction.Reserve.Keys`・`Register`・`Insert`・`RegisterRun`・`Registration`・`ReserveRun`）を、表記 `val` についての主張と、表記を読むと元に戻ること（`Keys.ofString?_val`）で直した。使われていなかった述語 `ReserveNo.WellFormed` は除いた。検査 MISU-1 の段階導入の一覧から `ReserveNo` を外した（残り 8 件）。
* **エラーコード**: `AtrsError` の業務・未検出・システムのコードを、事由の列挙 `Spec.Error.BusinessError`（12 個。代表者の年齢・搭乗者の位置・運賃種別名・最少人数の引数は構築子が持つ）・`NotFoundError`（`noFlight`）・`SystemError`（`ioFailure`）にした。コードと引数の綴りは関数 `code`・`args` が与え、適合テストベクタの JSON は変わらない。具体側の文字列のコードからの α（`Abstraction.FlightSearch.Alpha.aoS`・`Abstraction.Reserve.Alpha.aoR`）は `BusinessError.ofCode?` で読み、知らないコード・引数の数の違うものは像を持たない。往復は `ofCode?_code_args`・`code_args_of_ofCode?`。予約の証明（業務例外の事後条件・改行を含まないこと `NoNL.code_noNL`）は、事由についての主張に直した。`SourceModel` は変えていない。
* **空港コード・カード種別コード**: `AirportCd`・`CreditTypeCd` を、形式の証明（`valid`、既定 `by decide`）を持つ型にし、読み取り `ofString?` を置いた。字面は `{ val := "HND" }` で書く（無名構築子は証明の既定を埋めないため。生成器 `tools/conformance/seed_lean.py`・`member_seed.py` も合わせた）。空席照会の条件の空港コードとマスタの問い合わせ `Query.routeOf` の引数は生の文字列にし、`MasterData.routeOf` は値を比べる。`Query.Valid` は `AirportCd.valid` で書いた（D-034 の分類は不変）。MD-8 から形式の連言を除き、`NOP` でないことだけを残した（D-029 は不変）。`EnvPre.validB` から形式の検査を除いた。DB の行・設定からの α は α の葉 `airportCdOf`・`creditTypeCdOf`（`Abstraction.MasterData.AlphaLeaf`。核の定理は ABS-048）で読み、読めない値は α を定義しない（D-027）。
* **D-036 の付け替え（プロジェクトオーナーの決定: 被覆）**: 空港コードの形式が型に移ったので、D-036 を PRE の外（MD-8 の第 1 連言）から、前提型（具体側の入力）に付け替えた。述語 `dev_D036`（DB のマスタの空港の行のコードがどれも英大文字 3 文字。`Abstraction.MasterData.Alpha`）を ABS-026 の具体側の制限に加え（トップレベルの `devC` の該当の成分も `dev_D027 ∧ dev_D036`）、D-027 が D-036 を覆う定理 `covers_D036`（W 課題 ABS-142）を置いた。被覆の連鎖は、偽を証明済みの D-027 で終わる。W 課題 ABS-127 `need_D027` は D-027 だけを外した形（`queryConcrete.restrict dev_D036`）に直した。箇所の印 `@[gap "D-036"]` は `Spec.Model.AirportCd` に移した。検査 MISU-1 の段階導入の一覧から 4 件を外した（残り 4 件: `FlightName`・`MembershipNumber` とその `WellFormed`）。
