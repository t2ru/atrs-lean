---
type: Specification
title: "具体化証明課題（Refinement）"
description: "正規仕様 Lean Spec から Rust の移植先モデル target_model への具体化で満たすべき課題 REF-NNN と、Verus・Kani・適合テストによる充足方法。"
tags: [spec, refinement, proof, rust]
status: draft
spec_role: meta
models: [spec]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 具体化証明課題（Refinement）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

[Spec]（Lean `Spec`）と [Target]（Rust `target_model`）の関係を定める（[ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md), [ADR 0020](../decision/0020-rust-as-target-language.md)）。
課題は Rust プロジェクトの `refinement` で充足する。規約は [rules/rust.md](../rules/rust.md)。

## 信頼の連鎖

```
Lean Spec ──(適合テストベクタ: Lean Spec を実行して生成)──▶ Rust target_model
                                                              │
                                             (Verus の ensures と証明)
                                                              ▼
                                                     Rust spec（Lean Spec の Verus 写し）
```

- Verus は `target_model` が **Verus の写し `spec`** と全入力で一致することを証明する。
- 写し `spec` と Lean `Spec` の一致は、(1) 同名・同構造で写す規約とレビュー、(2) 適合テストベクタ（写しと一致する実装が Lean の生成値と食い違えば、写しの誤りが分かる）で担保する。証明ではない点に注意する。

## 証明課題

| ID | 内容 | 手段 | 状況 |
| --- | --- | --- | --- |
| REF-001 | `conformance/spec/` と `conformance/shared/` の全ベクタを通す | 適合テスト（`refinement::conformance`） | 未着手 |
| REF-002 | 予約確定の前後で全フライトの `vacantNum ≥ 0`。失敗時は状態が変化しない | Verus（インメモリ状態の遷移関数の `ensures`） | 未着手 |
| REF-003 | 状態を変更するユースケースが原子的かつ直列化可能（[ports.md](ports.md#トランザクション) の規範節） | インメモリ: 排他（Mutex）下の逐次実行として Verus の結果に帰着。DB: トランザクション分離レベルと行ロックの設計レビュー＋結合テスト | 未着手 |
| REF-004 | 純粋関数（運賃計算・空席照会・検証・CSV 生成・書式）が値域内の全入力で [Spec] と同じ結果を返し、オーバーフロー・パニックが無い | Verus（`core`）、Kani（`verus!` の外の変換・JSON） | 未着手 |
| REF-005 | ポートのアダプタが [ports.md](ports.md) の契約を満たす（採番の一意性・書式、`publish` の原子性、`findForUpdate` の排他） | Kani（インメモリ・有界）、結合テスト（DB・ファイル） | 未着手 |
| REF-006 | HTTP 契約（[http-contract.md](http-contract.md)）のステータス・遷移先・JSON 形状を満たす | 結合テスト（HTTP レベルの適合ベクタ） | 未着手 |
| REF-007 | 文字列長・文字クラスを Unicode スカラ値で判定する | Verus（`Seq<char>` 上の `ensures`） | 未着手 |
| REF-008 | 「今日」「現在日時」を Clock ポートからのみ取得し、同一ユースケース内で一定である | 設計レビュー（`core` が時刻を引数で受け取ることで構造的に保証） | 未着手 |

「状況」は課題を充足した関数・ハーネス・テストへのリンクで更新する。

## 未証明の前提

Verus の `assume`・`admit`・`external_body` を使った場合は、その箇所と理由をここに列挙する（[rules/rust.md](../rules/rust.md#refinement)）。

（現在なし）
