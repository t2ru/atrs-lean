---
type: Overview
title: "ATRS 仕様文書"
description: "docs/spec の役割（Spec 外の規範・メタ情報・草案）、正規性、対象版、文書の区分一覧。"
tags: [spec, index]
status: draft
spec_role: meta
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
sources:
  - id: atrs-upstream
    resource: https://github.com/terasolunaorg/atrs/tree/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf
    title: TERASOLUNA ATRS (JavaConfig-Thymeleaf)
---

# ATRS 仕様文書

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

ATRS（航空券予約システム）の **正規仕様は Lean の `Spec`** である。本ディレクトリは、**`Spec` で表現できない仕様**（規範）と、仕様・検証を運用するためのメタ情報、そして Lean に形式化する前の業務規則の **草案** を置く（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。
移植先モデル `TargetModel`（Lean）と移植先ソース（Rust）は、Lean `Spec` と本ディレクトリの規範節に従う（[ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。区分（normative / meta / draft / informative）と書き方は、スキル port-lang の [spec-documents.md](../../.agents/skills/port-lang/references/spec-documents.md) による。

| 優先 | 正規の定義 |
| --- | --- |
| 1 | Lean `Spec`（`lean/Spec/`） |
| 2 | 本ディレクトリの `normative` の文書・節 |
| — | `draft` は Lean に形式化するまでの暫定。`informative` は非規範の要約 |

## 対象版

追従中の版の正は `trace/upstream.json`（[ADR 0024](../decision/0024-following-upstream-releases.md)、[backlog 0025](../backlog/0025-upstream-submodule-and-inventory.md)）である。下表は現在の値の写しで、道具の導入後は生成する。

| 項目 | 値 |
| --- | --- |
| 上流 | <https://github.com/terasolunaorg/atrs> |
| ディレクトリ | `JavaConfig-Thymeleaf/atrs/` |
| branch | `release/5.11.0.RELEASE` |
| commit | `f4bfbf0615eb91805546c9c780d4761be92ce17e` |

出典表記の `atrs-domain/.../` は `atrs-domain/src/main/java/jp/co/ntt/atrs/domain/`、`atrs-web/.../` は `atrs-web/src/main/java/jp/co/ntt/atrs/` の省略である。

## モデル

| 記号 | 名前空間 | 意味 |
| --- | --- | --- |
| **[Spec]** | `Spec` | 抽象モデル。正規の業務仕様（Lean） |
| **[Target]** | `TargetModel` | 移植先モデル（Rust ソースの振る舞いを Lean で写したもの） |
| **[Source]** | `SourceModel` | 移植元モデル。原典 Java の観測可能な振る舞い |
| **[Spec=Source]** | — | 両モデルで定義が同一 |

[Source] → [Spec] の関係は [abstraction.md](abstraction.md)、[Spec] → 移植先 [Target] の関係は [refinement.md](refinement.md) にまとめる。

## 文書

| 文書 | 内容 | 原典の機能 ID | 区分 |
| --- | --- | --- | --- |
| [glossary.md](glossary.md) | 用語集（日英対応） | — | meta |
| [configuration.md](configuration.md) | 設定パラメータ | — | draft |
| [domain-model.md](domain-model.md) | 型・列挙・値域・不変条件・基本演算 | — | draft |
| [master-data.md](master-data.md) | マスタデータの構造と不変条件、シードデータ | — | draft |
| [fare-calculation.md](fare-calculation.md) | 基本運賃・運賃・合計運賃 | B0 | draft |
| [flight-search.md](flight-search.md) | 空席照会 | B1 | draft |
| [reservation.md](reservation.md) | フライト検証・予約検証・予約登録 | B0, B2 | draft |
| [member.md](member.md) | 会員登録・会員情報変更 | C0, C1, C2 | draft |
| [authentication.md](authentication.md) | ログイン・ログアウト | A0, A1, A2 | draft |
| [reservation-history-report.md](reservation-history-report.md) | 予約履歴レポート | D1 | draft |
| [input-validation.md](input-validation.md) | 入力検証・文字クラス | 全画面 | draft |
| [errors-and-messages.md](errors-and-messages.md) | エラー分類・コード・メッセージ | 全体 | draft |
| [ports.md](ports.md) | ポート（副作用）の契約 | 全体 | draft＋normative |
| [http-contract.md](http-contract.md) | 画面遷移・REST API の契約 | 全画面 | draft＋normative |
| [abstraction.md](abstraction.md) | 抽象化証明課題・既知差異 | — | meta |
| [refinement.md](refinement.md) | 具体化証明課題 | — | meta |
| [conformance.md](conformance.md) | 適合テストベクタの形式 | — | meta |
| [traceability.md](traceability.md) | 原典 ↔ 仕様 ↔ 実装の対応表 | — | meta |

## 状態

本ディレクトリは初版（`status: draft`）であり、人によるレビュー（frontmatter の `verified`）を経ていない。Lean `Spec` はまだ無いため、現時点では草案が形式化の唯一の入力である。
原典の調査で確定していない箇所には `TODO(spec)` を付けている。
