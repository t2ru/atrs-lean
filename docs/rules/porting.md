---
type: Guideline
title: "移植規約"
description: "原典 → 草案 → Lean の SourceModel/Spec/Abstraction → TargetModel/Refinement → Rust ソースの順で移植し、両端を追跡注釈でつなぐ原則。"
tags: [rules, porting]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 移植規約

## 作業の順序

機能単位で、必ず次の順に進める。

1. **原典の調査**: Java（サービス・ユーティリティ・SQL・設定・Web 層）の振る舞いを読み、観測可能な振る舞いを洗い出す。SQL に書かれた業務ロジック（絞り込み条件・並び順・採番）も対象である。
2. **草案**: `docs/spec/` の「形式化前の草案」に [Spec] と [Source] を書く（すでにある場合は見直す）。差異は [abstraction.md](../spec/abstraction.md) に登録する。`Spec` で表現できない仕様は規範節として書く（[spec-writing.md](spec-writing.md)）。
3. **形式化**: Lean で `Spec`（正規）と `SourceModel` を実装する。草案の例と境界値を手計算のテストとして Lean に置く。
4. **草案の置き換え**: 形式化した節の定義を `docs/spec` から取り除き、Lean の定義へのリンクと非規範の要約に置き換える（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。
5. **抽象化証明**: [abstraction.md](../spec/abstraction.md) の課題（`ABS-NNN`）を `Abstraction` で証明する。
6. **テストベクタ生成**: Lean `Spec` を実行して `conformance/spec/`・`shared/` の期待値を生成し、差分をレビューする（[testing.md](testing.md)）。
7. **移植先モデル**: Lean に `TargetModel`（Rust の意味論 `LangSemantics.Rust` で、これから書く Rust ソースの振る舞いを表す）を書き、`Refinement` で `Spec` → `TargetModel` を証明する（`REF-NNN`）。`target-model/` のベクタを `TargetModel` から生成する。
8. **移植先ソース**: Rust を書く。`model/` に `TargetModel` の Verus 写しを置き、実行コードの `ensures` で写しとの一致を述べる（[rust.md](rust.md)）。
9. **両端の追跡**: `SourceModel` に `@[source]`、`TargetModel` に `@[target]`、Rust の写しに `/// trace: models` を付け、ハッシュを道具の出力で埋める（[ADR 0023](../decision/0023-cross-language-traceability.md)）。
10. **検証**: Lean の `Spec`・`SourceModel`・`TargetModel` と Rust が、対応するテストベクタを全件通すこと。Verus・Kani・追跡の検査（TR）を通すこと。可能なら Java オラクル（[backlog 0013](../backlog/0013-java-oracle-harness.md)）でも [Source] ベクタを確認する。

## 原則

- **仕様にない振る舞いを実装してはならない。** 実装中に仕様の不足に気付いたら、先に仕様を直す。
- **[Source] は原典の不具合も再現する。** 原典の明らかな不具合（例: REST 予約 API で相関検証が適用されない）は [Source] では再現し、[Spec] でどう扱うかを ADR で決める。
- **[Spec] は原典の意図を表す。** [Spec] が [Source] と異なってよいのは、ADR で理由が記録されている場合に限る。
- 原典のフレームワーク機能（Spring の DI、Bean Validation、MyBatis、トランザクショントークン、JMS 等）は移植しない。その **効果** だけを仕様化する。
- 原典の `Assert`（引数検査）は業務エラーではない。[Spec] では型・事前条件で排除し、[Source] では「前提違反」として表す。
- 原典がキャッシュしているマスタ（`*Provider`）は「起動時に読み込まれた不変のマスタ」として純粋な入力にする。

## スコープ

対象と対象外は [ADR 0002](../decision/0002-porting-scope.md) に従う。対象外の機能を移植する場合は先に ADR を更新する。

## 追跡可能性

- 原典のクラス・メソッドを仕様化したら [traceability.md](../spec/traceability.md) を更新する。
- 追跡の正は Lean の注釈（`@[source]`, `@[target]`）である。[traceability.md](../spec/traceability.md) の表は manifest から生成するので、手で書き足してはならない（生成区画の外の説明・対象外一覧を除く）。
- 移植元ソースと移植先ソースを直接対応づけてはならない（[ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。
