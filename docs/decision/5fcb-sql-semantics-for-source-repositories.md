---
type: Architecture Decision Record
title: "LangSemantics.Sql で原典 SQL（PostgreSQL）の意味論を定義し、SourceModel のリポジトリを記述する"
description: "原典の MyBatis SQL に含まれる業務ロジックを、アプリ非依存の SQL 意味論モデル LangSemantics.Sql の上で忠実に写す。"
tags: [adr, sql, source-model, lang-semantics]
id: "5fcb0c8c-6512-4275-84bb-3046874de7f9"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# LangSemantics.Sql で原典 SQL（PostgreSQL）の意味論を定義し、SourceModel のリポジトリを記述する

## Context and Problem Statement

原典の振る舞いの一部は Java ではなく SQL（MyBatis の Mapper XML、PostgreSQL）に書かれている。

* 空席照会の絞り込み `#{beforeDayNum} BETWEEN rsrv_available_end_day_num AND rsrv_available_start_day_num` と並び `ORDER BY ft.display_order, fm.departure_time`（同順位の順序は未規定）
* ピーク時期の全件取得（`ORDER BY` 無し。Java 側は最初に一致したものを使う）
* 採番 `TO_CHAR(NEXTVAL('sq_member_1'), 'FM0999999999')`、シーケンス `MINVALUE 1 MAXVALUE 9999999999 CYCLE`
* 行ロック `SELECT … FOR UPDATE`、存在確認 `SELECT EXISTS (…)`
* パスワード更新 `SET last_password = password, password = #{new}`（右辺は更新前の値）
* `VARCHAR` 列の比較・整列（`departure_time`, `reserve_no`）

[ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md) で、アプリケーションに依存しない言語意味論を `LangSemantics.<lang>` に置くと決めた。
プロジェクトオーナーから、`LangSemantics` には `Java` と `Sql` を定義するよう指示があった。SQL の意味論の範囲と表現を決める。

## Decision Drivers

* 移植元モデル [Source] が、SQL 内の業務ロジック（並び順の未規定性を含む）を忠実に表せること
* SQL 意味論を ATRS から独立させ、他アプリケーションの移植でも再利用できること
* 汎用の SQL 処理系を作らないこと（原典が使う構文だけ）

## Considered Options

* `LangSemantics.Sql`: 原典が使う SQL の部分集合を、PostgreSQL 方言として Lean で意味づけする
* SQL の効果を `SourceModel` の中で直接 Lean 関数として書く（SQL 意味論を分けない）
* SQL 処理系（パーサを含む）を Lean で実装する

## Decision Outcome

Chosen option: "`LangSemantics.Sql`", because SQL 固有の意味（バッグ意味論、NULL の三値論理、未規定の並び順、シーケンス）をアプリから独立に一度だけ定義でき、[Source] の各リポジトリ操作をその上の式として原典の SQL と 1 対 1 に対応づけられるため。

範囲（`LangSemantics.Sql`、方言は PostgreSQL。必要に応じ `LangSemantics.Sql.Postgresql` に方言固有部分を分ける）:

| 対象 | 意味 |
| --- | --- |
| 値 | `NULL`、整数（`INT` は int32 範囲、`BIGINT`）、`VARCHAR(n)`、`DATE`、`TIMESTAMP`、`BOOLEAN` |
| 述語 | 比較・`AND`/`OR`/`NOT` の三値論理（`UNKNOWN`）、`BETWEEN a AND b` ≡ `x >= a AND x <= b`、`IN (…)`、`EXISTS` |
| 照会 | 内部結合・選択・射影を **バッグ（多重集合）** として定義 |
| 整列 | `ORDER BY k1, k2 …`: キーが等しい行の相対順序は **未規定**。結果は「許される順列の集合」として表し、[Source] は非決定的な結果を持つ |
| 文字列の比較 | 照合順序はパラメータ。原典の比較対象（数字のみの固定長文字列）では照合順序に依らず辞書順と一致することを補題にする |
| シーケンス | `NEXTVAL`: `MINVALUE`〜`MAXVALUE` を循環（`CYCLE`）する状態付きカウンタ |
| 書式 | `TO_CHAR(n, 'FM0999999999')`: 10 桁ゼロ埋め十進、先頭空白無し |
| 更新 | `UPDATE … SET c1 = e1, c2 = e2`: 右辺は更新前の行で評価する。更新件数を返す |
| ロック | `SELECT … FOR UPDATE`: トランザクション終了まで行を排他する。単一トランザクションの逐次実行では通常の `SELECT` と同じ結果を返し、並行実行の直列化は `TargetModel` 側の契約（[ADR 97f9](97f9-persistence-and-transaction-semantics.md)）で扱う |

使い方:

* `SourceModel` のリポジトリ操作（`SourceModel.Repository.*`）は、原典 Mapper XML の各 SQL 文を `LangSemantics.Sql` の式として書く。
* `Abstraction` で、`Spec` の純粋関数（例: `searchFlight` の絞り込みと整列）と [Source] の SQL 式の結果が、マスタ不変条件の下で一致すること（[Source] の許される結果の集合が `Spec` の結果 1 つに定まること）を証明する。
* `Spec` は `LangSemantics.Sql` に依存しない（[Spec] は SQL を持たない）。

### Consequences

* Good, because 「`ORDER BY` に無い順序は未規定」「`ORDER BY` 無しの取得順」といった原典の非決定性を、曖昧な文章ではなく形式的に扱える
* Good, because SQL 意味論を他アプリケーションの移植に再利用できる
* Bad, because バッグ意味論と非決定的整列の証明基盤（順列の補題）を自前で用意する必要がある（Mathlib 不使用のため。[ADR 659f](659f-lean-toolchain-and-dependencies.md)）

### Confirmation

* `LangSemantics.Sql` が ATRS 固有のモジュールを import していないことを CI で検査する。
* 原典 Mapper XML の全 SQL 文が [traceability.md](../spec/traceability.md) で `SourceModel.Repository` の定義に対応づけられていることを確認する。

## Pros and Cons of the Options

### `LangSemantics.Sql`

* Good, because 原典の SQL と 1 対 1 に対応し、非決定性も表せる
* Bad, because 初期の基盤整備が必要

### `SourceModel` に直接書く

* Good, because すぐ書ける
* Bad, because SQL の意味（未規定の順序、NULL）がアプリのコードに散らばり、再利用も検証もしにくい

### SQL 処理系を実装

* Good, because Mapper XML の SQL 文字列をそのまま実行できる
* Bad, because 過大な工数。パーサの正しさまで検証対象になる

## More Information

* [ADR 935b](935b-java-primitive-semantics.md)（`LangSemantics.Java`）, [ADR 97f9](97f9-persistence-and-transaction-semantics.md), [ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md)
* [backlog c7e8](../backlog/c7e8-lang-semantics-sql.md)
* （補足 2026-10-30）[ADR c336](c336-foundational-principles.md) により、SQL と `LangSemantics.Sql` での写しの一致は、決定論的な手段で確認する。手段は、同じデータについて、PostgreSQL での実際の実行結果と `LangSemantics.Sql` の評価結果を照合することである（SQL の差分実行。[spec-pivot/sql/verification.md](../../.agents/skills/spec-pivot/references/docs/lang/sql/verification.md)）。写しは手で翻訳するので、照合したデータの外での一致は保証の限界となる（[spec/assurance.md](../spec/assurance.md)）。上の Confirmation の「対応づけられていることを確認する」は網羅の確認であり、一致の根拠ではない。
