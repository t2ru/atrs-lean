---
type: Backlog Item
title: "Lean プロジェクトの雛形と CI"
description: "lean/ に Lake プロジェクトを作り、全名前空間の骨格・追跡属性の基盤・依存方向検査を含む CI を整える。"
tags: [backlog, lean, ci]
id: "0001"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Lean プロジェクトの雛形と CI

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

Lean 側（全モデルと証明）の作業の土台を用意する。

## 範囲

- `lean/lean-toolchain`（着手時点の最新安定版）, `lakefile.lean`（依存は Batteries のみ）
- トップレベル名前空間 `LangSemantics`, `SourceModel`, `Spec`, `Abstraction`, `TargetModel`, `Refinement`, `Trace` と、実行ファイル用の `Tests`, `Tools` の空モジュール（`Machine` は [backlog 0027](0027-machine-refinement-framework.md) でスキルの assets から取り込む）（[port-lang/lean/rules.md](../../.agents/skills/port-lang/references/lean/rules.md)）
- `Trace`: 属性 `@[source]`, `@[target]`, `@[obligation]`, `@[deviation]`, `@[spec_doc]`, `@[no_source]` の定義と、`lake exe trace-dump`（定義・属性・Merkle ハッシュの JSON 出力）
- ルートの `lakefile.lean`（作成済みの Lake ワークスペース）に `require atrs from "./lean"` を追加し、ルートで `lake setup-file lean/<任意のファイル>` が成功することを確認する（Lean LSP 用）
- CI: `lake build`, `lake test`, `sorry`・新規 `axiom`・`Tests` の外の `native_decide`/`bv_decide` の検出, `Float` 使用禁止範囲, 名前空間の依存方向（特に移植元側と移植先側の相互非依存）
- Lean の版を [ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md) の More Information に追記

## 対象外

- 業務ロジックの実装
- Rust 側（[backlog 0018](0018-rust-project-scaffold.md)）

## 完了条件

- [ ] `lake build` と `lake test` が成功する
- [ ] `trace-dump` がダミー定義の属性と Merkle ハッシュを出力する
- [ ] 依存方向に違反する import を入れると CI が失敗することを確認した
- [ ] AGENTS.md の「現在の状態」を更新した

## 参照

- [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)
- [ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)
- [port-lang/lean/rules.md](../../.agents/skills/port-lang/references/lean/rules.md)
