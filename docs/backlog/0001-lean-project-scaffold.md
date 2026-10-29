---
type: Backlog Item
title: "Lean プロジェクトの雛形と CI"
description: "lean/ に Lake プロジェクトを作り、名前空間の骨格・依存方向検査を含む CI を整える。"
tags: [backlog, lean, ci]
id: "0001"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Lean プロジェクトの雛形と CI

## 目的

Lean 側（正規仕様 `Spec` の形式化と抽象化証明）の全作業の土台となるビルド・テスト・検査の仕組みを用意する。

## 範囲

- `lean/lean-toolchain`（着手時点の最新安定版）, `lakefile.lean`（依存は Batteries のみ）
- トップレベル名前空間 `LangSemantics`, `SourceModel`, `Spec`, `Abstraction` と、実行ファイル用の `Tests`, `Tools` の空モジュール
- `lake test` で動くテストドライバ
- CI: `lake build`, `lake test`, `sorry`・新規 `axiom` の検出, `Float` 使用禁止範囲の検査, 名前空間の依存方向の検査（[rules/lean.md](../rules/lean.md)）
- Lean の版を [ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md) の More Information に追記

## 対象外

- 業務ロジックの実装
- Rust 側（[backlog 0018](0018-rust-project-scaffold.md)）

## 完了条件

- [ ] `lake build` と `lake test` が成功する
- [ ] 依存方向に違反する import を入れると CI が失敗することを確認した
- [ ] AGENTS.md の「現在の状態」を更新した

## 参照

- [ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md)
- [ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md)
- [ADR 0020](../decision/0020-rust-as-target-language.md)
- [rules/lean.md](../rules/lean.md)
