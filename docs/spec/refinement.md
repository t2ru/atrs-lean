---
type: Specification
title: "具体化証明課題（Refinement）と移植先ソースの確認"
description: "Lean で証明する Spec → TargetModel の課題 REF-NNN と、TargetModel ⇔ Rust ソースの対応を確認する課題 SRC-NNN（Verus・Kani・適合テスト）。"
tags: [spec, refinement, proof, rust]
status: draft
spec_role: meta
models: [spec]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 具体化証明課題（Refinement）と移植先ソースの確認

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

構成は [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)。

```
Spec ←Refinement（Lean の定理: REF-NNN）─ TargetModel ⇔（追跡＋確認: SRC-NNN）⇔ Rust ソース
```

- **REF**: `Spec` → `TargetModel` の関係。Lean の `Refinement` で **証明** する。
- **SRC**: `TargetModel` ⇔ Rust ソースの対応。追跡注釈（[traceability.md](traceability.md)）、適合テスト、Verus、Kani で **確認** する。Rust の実行コードが `model/`（`TargetModel` の Verus 写し）と一致することは Verus で証明するが、`model/` と Lean `TargetModel` の対応は規約・ハッシュ・テストによる担保であり、証明ではない。

## REF: Spec → TargetModel（Lean で証明）

抽象化関数 β は `TargetModel` の値を `Spec` の値に写す（`LangSemantics.Rust` の `U64` → `Nat`、`RString` → スカラ値の列、`Result` → `Except`、`Panic` → β 未定義）。

| ID | 内容 |
| --- | --- |
| REF-001 | 純粋関数（運賃計算・空席照会・入力検証・CSV 生成・書式）について、値域内の全入力で `β(TargetModel.f(x)) = Spec.f(β(x))` |
| REF-002 | 予約確定の前後で全フライトの `vacantNum ≥ 0`。失敗時は状態が変化しない（`TargetModel` の状態遷移が `Spec` の状態遷移を具体化する） |
| REF-003 | 値域内で `TargetModel` の算術がオーバーフローせず、パニック（`Panic` 値）に到達しない |
| REF-004 | 基本運賃・運賃・合計金額の一致（REF-001 の運賃部分。最初に着手する） |
| REF-005 | 文字列長・文字クラスを Unicode スカラ値で判定する（`RString` の `chars` 上で `Spec` と一致） |
| REF-006 | 「今日」「現在日時」を Clock ポートからのみ受け取る（`TargetModel` の関数が時刻を引数に取る構造であること） |

## SRC: TargetModel ⇔ Rust ソース（確認）

| ID | 内容 | 手段 |
| --- | --- | --- |
| SRC-001 | Rust が `conformance/target-model/` と `conformance/shared/` の全ベクタを通す | 適合テスト（`rust/tests/`） |
| SRC-002 | Rust の実行コードが `model/` の写しと全入力で一致し、算術がオーバーフローしない | Verus（`ensures`, `rust/src/proof/`） |
| SRC-003 | `verus!` の外のコード（変換・JSON）とアダプタに、有界な入力でパニック・未定義動作が無い | Kani（`rust/kani/`） |
| SRC-004 | アダプタが [ports.md](ports.md) の契約を満たす（採番の一意性・書式、`publish` の原子性、`findForUpdate` の排他） | Kani（インメモリ）、結合テスト（DB・ファイル） |
| SRC-005 | 状態変更の原子性・直列化可能性（[ports.md](ports.md#トランザクション) の規範節） | インメモリ: Mutex 下の逐次実行。DB: 分離レベルと行ロックの設計レビュー＋結合テスト |
| SRC-006 | HTTP 契約（[http-contract.md](http-contract.md)）のステータス・遷移先・JSON 形状 | 結合テスト（HTTP レベルのベクタ） |
| SRC-007 | 追跡の検査 TR-T1・TR-T2・TR-X が通る | `tools/trace check` |

## 状況

| ID | 状況 |
| --- | --- |
| REF-001〜006 | 未着手 |
| SRC-001〜007 | 未着手 |

「状況」は、課題を充足した定理・関数・ハーネス・テストへのリンクで更新する。

## 未証明の前提

Verus の `assume`・`admit`・`external_body` を使った場合は、その箇所と理由をここに列挙する（[rules/rust.md](../rules/rust.md#検証)）。

（現在なし）
