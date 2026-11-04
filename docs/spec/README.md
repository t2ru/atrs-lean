---
type: Overview
title: "ATRS 仕様文書"
description: "docs/spec の役割（メタ情報）、業務仕様を書く Spec のモジュール文書と仕様の本、正規性、対象版、文書の区分一覧。"
tags: [spec, index]
status: draft
spec_role: meta
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
sources:
  - id: atrs-upstream
    resource: https://github.com/terasolunaorg/atrs/tree/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf
    title: TERASOLUNA ATRS (JavaConfig-Thymeleaf)
---

# ATRS 仕様文書

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

ATRS（航空券予約システム）の **正規仕様は Lean の `Spec`** である（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。
業務仕様の散文（形式化した規則の要約、Lean に形式化する前の業務規則の **草案**、`Spec` で表現できない仕様の **規範**）は、`Spec` の各モジュールのモジュール文書（`/-! … -/`）に、定義のすぐ前に書く（[ADR 68a6](../decision/68a6-business-spec-in-lean-module-docs-and-book.md)）。それを mdgen と mdbook で HTML の本にする（`mise run book:build`。出力は `build/book/html/`、CI の artifact `spec-book`）。本は Lean のソース全体（モデル・証明・テストとスキルのライブラリ）を層ごとの部に分けた 1 冊で、仕様（`Spec`）が最初の部である（[ADR f779](../decision/f779-whole-lean-source-book.md)）。
本ディレクトリには、仕様と検証を運用するための **メタ情報**（課題一覧・既知差異・保証の限界・適合テストベクタ・追跡）だけを置く。
移植先モデル `TargetModel`（Lean）と移植先ソース（Rust）は、Lean `Spec` と、そのモジュール文書の規範節に従う（[ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md)）。区分（normative / meta / draft / informative）と書き方は、スキル spec-pivot の [spec-documents.md](../../.agents/skills/spec-pivot/references/docs/rules/spec-documents.md) による。

| 優先 | 正規の定義 |
| --- | --- |
| 1 | Lean `Spec`（`lean/Spec/`）の定義 |
| 2 | `Spec` のモジュール文書の `normative` の節 |
| — | `draft` は Lean に形式化するまでの暫定。`informative` は非規範の要約 |

## 対象版

追従中の版の正は `trace/upstream.json`（[ADR 3f36](../decision/3f36-following-upstream-releases.md)、[backlog 455f](../backlog/455f-upstream-submodule-and-inventory.md)）である。下表は現在の値の写しで、道具の導入後は生成する。

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

業務仕様（`Spec` のモジュール文書。本の目次の順）:

| モジュール | 内容 | 原典の機能 ID | 区分 |
| --- | --- | --- | --- |
| [`Spec`](../../lean/Spec.lean) | 序（本書の目的・区分と記号の凡例・章の表・トップレベルの機械） | — | meta |
| [`Spec.Glossary`](../../lean/Spec/Glossary.lean) | 用語集（日英対応） | — | meta |
| [`Spec.Prim`](../../lean/Spec/Prim.lean) とその下 | 基本演算・暦日と時刻・書式・文字クラス | — | informative＋draft |
| [`Spec.Model`](../../lean/Spec/Model.lean) | 列挙・コード値・エンティティ・値域 | — | informative＋draft |
| [`Spec.Error`](../../lean/Spec/Error.lean) | エラー分類・コード・メッセージ | 全体 | informative＋draft |
| [`Spec.Env`](../../lean/Spec/Env.lean) とその下（[`Config`](../../lean/Spec/Env/Config.lean)・[`MasterData`](../../lean/Spec/Env/MasterData.lean)・[`CodeList`](../../lean/Spec/Env/CodeList.lean)） | 環境（設定とマスタ）: 検証済みの型と入口の前提、設定パラメータ、マスタの構造と不変条件・参照関数、コードリスト | — | informative＋draft |
| [`Spec.World`](../../lean/Spec/World.lean) | 抽象状態とリポジトリ・採番の操作 | 全体 | informative＋draft |
| [`Spec.Port`](../../lean/Spec/Port.lean) | ポートの契約と実行環境の要件（文書だけのモジュール） | 全体 | draft＋normative |
| [`Spec.Nondet`](../../lean/Spec/Nondet.lean) | 非決定性 N-NNN の選択の型 | 全体 | informative |
| [`Spec.MasterQuery`](../../lean/Spec/MasterQuery.lean) | マスタ・設定・コードリストの参照 | — | informative |
| [`Spec.Fare`](../../lean/Spec/Fare.lean) | 基本運賃・運賃・合計運賃 | B0 | informative |
| [`Spec.FlightSearch`](../../lean/Spec/FlightSearch.lean) | 空席照会 | B1 | informative |
| [`Spec.Reserve`](../../lean/Spec/Reserve.lean)・[`Spec.Reserve.FlightSelection`](../../lean/Spec/Reserve/FlightSelection.lean) | 予約（予約内容の検証・予約確認・予約確定）と選択フライトの検証 | B0, B2 | informative |
| [`Spec.Member`](../../lean/Spec/Member.lean) | 会員登録・会員情報変更（文書だけのモジュール） | C0, C1, C2 | draft |
| [`Spec.Auth`](../../lean/Spec/Auth.lean) | ログイン・ログアウト（文書だけのモジュール） | A0, A1, A2 | draft |
| [`Spec.Report`](../../lean/Spec/Report.lean) | 予約履歴レポート（文書だけのモジュール） | D1 | draft |
| [`Spec.Validation`](../../lean/Spec/Validation.lean) | 入力検証（文書だけのモジュール） | 全画面 | draft |
| [`Spec.Http`](../../lean/Spec/Http.lean) | 画面遷移・REST API の契約（文書だけのモジュール） | 全画面 | draft＋normative |
| [`Spec.Seed`](../../lean/Spec/Seed.lean) とその下 | シードデータ（初期状態。`Seed.Master`・`Seed.Flight`・`Seed.Member` は生成物） | — | informative |

旧 `docs/spec/<文書>.md#<見出し>` から新しい場所への対応は `tools/docs/spec-anchors.json` にある（[backlog c89a](../backlog/c89a-business-spec-in-lean-module-docs.md)）。その後のモジュールの移動と改名（[ADR b385](../decision/b385-spec-module-layout-and-book-shaped-docs.md)）の対応は `tools/docs/lean-renames-spec.json` と `tools/docs/spec_layout.py` にある。

メタ情報（本ディレクトリ）:

| 文書 | 内容 | 区分 |
| --- | --- | --- |
| [abstraction.md](abstraction.md) | 抽象化証明課題・既知差異 | meta |
| [refinement.md](refinement.md) | 具体化証明課題・移植先の既知差異・移植先ソースの確認課題 | meta |
| [assurance.md](assurance.md) | 保証の限界（ソース ⇔ モデルの決定論的な手段と、その届かない部分） | meta |
| [conformance.md](conformance.md) | 適合テストベクタの形式 | meta |
| [traceability.md](traceability.md) | 両端の追跡（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）。原典と実装を直接はつながない | meta |

## 状態

業務仕様とメタ情報は初版（`status: draft`）であり、人によるレビュー（frontmatter の `verified`）を経ていない。形式化していない領域では、モジュール文書の草案が形式化の唯一の入力である。
原典の調査で確定していない箇所には `TODO(spec)` を付けている。
