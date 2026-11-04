---
type: Architecture Decision Record
title: "マスタ・設定・コードリストの読み込みの SourceModel と、[Spec] の修正（所要時間・空港コードの値域・問い合わせ）を決める"
description: "マスタの読み込みの SourceModel の写し方を決める（列の型は処理系の範囲で写す、Mapper の結果の順列を選ぶ具体機械、MyBatis の対応、コードリスト、設定）。あわせて、Spec.Env.MasterData.Route の所要時間の削除、MD-8 の空港コードの値域、問い合わせの機械の拡張、表せない値の差異 D-027、PostgreSQL での差分実行の形を決める。"
tags: [adr, source-model, master-data, sql]
id: "c10895a2-8187-428d-8c87-f925e9c55a4e"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T11:01:08+09:00
---

# マスタ・設定・コードリストの読み込みの SourceModel と、[Spec] の修正（所要時間・空港コードの値域・問い合わせ）を決める

## Context and Problem Statement

[backlog 25f7](../backlog/25f7-fare-calculation-both-models.md) の第 2 段では、R 課題 ABS-026 の両側を作る。ABS-026 は「マスタ・設定・コードリストの読み込みが、[Spec] の `MasterData`・設定をリファインする」ことである。第 2 段は 2a と 2b に分けた（プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 2a | 両側のモデルと差分実行 |
| 2b | ABS-026 の証明 |

作り始めて、次の問題が見つかった。

* `Spec.Env.MasterData.Route.flightTime`（所要時間）は、原典のどの SQL も Java も読まない。[Source] では観測できない。
* 区間の Provider は、キー `"[出発空港コード]-[到着空港コード]"` で引く。空港コードに `-` が入ると、キーが衝突しうる。
  * [Spec] の MD-8 には、空港コードの形式（英大文字 3 文字）が無かった。
  * domain-model.md の値域の表にも無かった。
* DB の値には、[Spec] の型で表せないものが入りうる。例: 未知のコード、NOT NULL の無い列の `NULL`、負の値、`2415` のような時刻。
  * それらには α の像が無く、入力の全域性の義務を満たせない。
* 原典の `getRouteByAirportCd`・`getFlightMaster` は、引数が `hasText` でなければ `IllegalArgumentException` を投げる。[Spec] の問い合わせには、引数の値域が無かった。
* 具体モデルの列の型の扱い。プロジェクトオーナーの指示は、「具体モデルは元の処理系の制限を再現する。物理的なビット幅でなくてよい。違いは抽象モデルとのリファインメントの例外として表す」である。

## Decision Drivers

* 基本原則 1〜3（ADR c336）。特に、不一致はすべて証明と文書で明示する。
* `obligation-check` の G1〜G8（ADR 70eb）
* 原典の振る舞い（読み込みの順序が未規定であること、MyBatis・Spring・terasoluna の振る舞い）を、そのまま写すこと

## Considered Options

* 下表のとおり決める
* 表せない値を「[Spec] の前提の外」として文書だけに書く（D-015 と同じ扱い）
* 所要時間を観測型の差異にする

## Decision Outcome

Chosen option: "下表のとおり決める", because 不一致を Lean と文書の両方に明示でき、[Spec] から観測できない値を除けるため。

| 項目 | 決定 |
| --- | --- |
| 所要時間 | `Spec.Env.MasterData.Route.flightTime` を削除する。fixture には上流どおり残し、[Spec] の読み込みは無視する（プロジェクトオーナーの決定） |
| 空港コードの値域 | MD-8 に「空港のコードは `AirportCd.WellFormed`（英大文字 3 文字）」を足す。domain-model.md の値域の表にも足す |
| 問い合わせの機械 | `Spec.MasterQuery` に移し、次のように広げる。<br>- 問い合わせに、設定（`config`）とコードリスト（`codeList`。8 種）を加える<br>- PRE に、問い合わせの引数の値域（`Query.Valid`: 区間の空港コードと便名が `WellFormed`）を加える<br>- `queryMachine_initIs`（SPEC-007）を加える |
| 表せない値 | 前提型の差異 D-027（具体側の入力。`Concrete.restrict dev_D027`）とする。<br>- 述語は「DB のマスタの各行と設定の値が [Spec] の型で表せる（α が定義される）」<br>- W 課題は ABS-127<br>- 影響は「中断」（プロジェクトオーナーの決定） |
| 列の型 | `LangSemantics.Sql.Postgresql` に、範囲を持つ型 `Int4`・`PgDate`・`Varchar n` を足す。<br>- 物理的なビット幅ではなく、取りうる値の範囲を型で持つ（プロジェクトオーナーの指示）<br>- 範囲は PostgreSQL 16.15 と突き合わせる（`pg_table.py`。日付は 4714-11-24 BC〜5874897-12-31）<br>- `SourceModel.Db.Schema` の表の行は、`INT` を `Int4`、`DATE` を `PgDate`、`VARCHAR(n)` を `Varchar n`、NULL 可の列を `Option` で持つ<br>- Java 側は `J32`・`JLocalDate` |
| Mapper の文 | `SourceModel.Repository.MasterData` に、`LangSemantics.Sql` の `Bag` の演算で写す。<br>- 結合の条件は、照合順序 C の比較で評価する<br>- コードリストの SQL（`ORDER BY display_order`）は、整列前のバッグと整列キーで与える |
| MyBatis の対応 | `SourceModel.Repository.Mapping` に写す。<br>- enum の列は `Enum.valueOf`（未知のコードは `IllegalArgumentException`）<br>- 入れ子の `resultMap`（`flightMaster-map`）は、`<id>` が同じ行を最初の 1 つにまとめる<br>- G4 のため、`Spec` の関数（`ofCode?` など）は使わず、構築子へ自前で写す |
| Provider | `load()` は、Mapper の文の結果の 1 つの並び（`List`）を受けてキャッシュを作る。<br>- `HashMap` の `put` は後勝ち<br>- 区間のキーは `makeCacheKey`<br>- `Assert.hasText` は `Character.isWhitespace` で判定する |
| コードリスト | `SourceModel.CodeList` に写す。<br>- `JdbcCodeList.retrieveMap`（terasoluna-gfw-common 5.11.0 のソースで確かめた）: キーか表示が null の行を飛ばし、`LinkedHashMap` に `put` する<br>- `AirportCodeList.retrieveMap`（区切り行の挿入）<br>- `NumberRangeCodeList`・`SimpleMapCodeList`<br>- `LangSemantics.Java.HashMap.JLinkedHashMap`（挿入順。同じキーは位置を保って置き換える）を足す |
| 設定 | `SourceModel.AtrsProperties.AtrsConfig` は、`@Value` で注入された値（注入先の Java の型）を入力とする。文字列からの変換（Spring）は D-027 の前提に含める。上流の値は `upstreamConfig`（`prop:` の `@[source]`） |
| 具体機械 | `SourceModel.MasterQuery.queryConcrete`（`Concrete.mk`、状態なし）。<br>- 1 歩は、各文の結果の許される並び（`Order.Allowed`）のどれかを選び、全 Provider とコードリストを読み込んで問い合わせに答える関係<br>- 順序の無い文は `List.Perm`、`ORDER BY` は `isAllowedOrder` |
| 差分実行 | `tools/conformance/master_sql.py` が、上流の DDL とシード（投入日 2026-11-01）を PostgreSQL に投入する。<br>- Mapper の XML と `AtrsCodeListConfig` から抜き出した SQL を実行し、`conformance/sql/master-data.json` に書き出す<br>- `lake test`（`Tests.MasterSql`）が、同じ表から `SourceModel.Repository.*` を評価して照合する。順序の無い文はバッグとして、`ORDER BY` は許される順列として照合する<br>- あわせて、共有入力の表と PostgreSQL の表の一致も確かめる<br>- `trace/checks.json` に `pg-master-sql` を登録する |

### Consequences

* Good, because 読み込みの順序の未規定さが、具体機械の非決定性としてそのまま残り、ABS-026 の証明がすべての順列について示すべきことが明確になる
* Good, because SQL の写しが PostgreSQL と同じ表で照合される
* Good, because fixture の生成器も、PostgreSQL への投入と照合される
* Good, because 処理系の範囲（int4・日付・文字列の長さ）がモデルの型にあり、[Spec] との違いが D-027 の前提に集まる
* Bad, because `Order` に文ごとの並びを持つので、文を足すたびに具体機械を直す必要がある
* Bad, because ABS-026 の証明（2b）は、マスタ 6 種の順列の独立性、コードリストの整列の一意性、区間のキーの単射性を含み、規模が大きい

### Confirmation

* `lake test` で次を確かめる。
  * `shared/master-data/` のベクタを、`Spec` と `SourceModel` の両方で実行する（23 件）。
  * `source-model/master-data/` の到着時刻 `2415` の例（D-027 の前提の外）
  * `Tests.MasterSql` の 9 文の照合と、表 8 つの一致
* `tools/ci/master_sql.sh` と `pg_table.sh`（PostgreSQL 16.15）
* `tools/trace rehash` で、`lake-test`・`pg-master-sql` の合格を記録する。

## More Information

* [ADR c336](c336-foundational-principles.md)、[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)、[ADR 70eb](70eb-refinement-non-vacuity-obligations.md)、[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)
* [abstraction.md](../spec/abstraction.md#既知差異)（D-027・ABS-026・ABS-127）、[`Spec.Env.MasterData`](../../lean/Spec/Env/MasterData.lean)
* D-027 の対象を具体側の入力全体（問い合わせの引数を含む）に広げ、MD-8 に空港コード `NOP` の禁止を加えたことは、[ADR f353](f353-abs-026-proof-structure-nop-and-d027-scope.md) で補った
