---
type: Backlog Item
title: "Lean TargetModel から Verus の写しを生成する道具"
description: "lake exe gen-verus で、Lean TargetModel の公開定義から rust/src/model/ の Verus spec 関数と追跡タグを決定論的に生成し、CI で再生成の差分が無いことを確認する。"
tags: [backlog, lean, rust, verus, tooling]
id: "d77caf9a-257d-4bcc-9be8-f34b6c03f2b6"
state: todo
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8", "a936801c-476d-4b16-baed-ca3bab07cee3"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Lean TargetModel から Verus の写しを生成する道具

## 目的

原則 1（[ADR c336](../decision/c336-foundational-principles.md)）を満たすため、移植先ソースと移植先モデルを決定論的な手段だけでつなぐ。つなぎ方は次の 2 段である（[ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md)）。

1. Lean `TargetModel` から写しを生成する（変換）。
2. 写しと Rust の実行コードの一致を、Verus で証明する。

## 範囲

- `lean/Tools/GenVerus`（`lake exe gen-verus`）
  - 入力: Lean の環境（`TargetModel` 名前空間の公開定義）
  - 出力: `rust/src/model/<機能>.rs`（`spec fn`・`struct`・`enum`）。各定義の doc コメントに `/// trace: models <完全名> @<Merkle ハッシュ>` を書く
  - 受け付ける部分集合: 構造的再帰・`match`・`if`・`let`・`Except`・`Option`・`structure`・`inductive`・`LangSemantics.Rust` の演算。部分集合の外の定義があれば失敗する
- スキルの `assets/verus/model_prelude.rs`: `LangSemantics.Rust` の各演算の Verus 版（各定義に `/// trace: models LangSemantics.Rust.… @<Merkle>`）。`rust/src/model_prelude.rs` に写す
- 入力は `TargetModel` のうち `TargetModel.Adapter.*` を除いた公開定義
- 各操作の事前条件を写した `pre_<操作>` の出力と、`gen-verus --check-contracts`（各 `@[target]` の実行関数が `requires pre_x(..)`・`ensures r == model::x(..)` をちょうど持つことの検査）
- CI: 生成 → `git diff --exit-code rust/src/model/`
- 出力の決定性: 同じ入力から、バイト単位で同じ出力を得る（定義の並び順を名前順に固定する）
- 生成器と対応表の信頼の基盤を [assurance.md](../spec/assurance.md) に記載する

## 対象外

- Verus 以外の検証器向けの生成
- `TargetModel` 以外の層の生成

## 完了条件

- [ ] 運賃計算（`TargetModel.Fare`）の写しを生成でき、Verus が構文・型検査を通す
- [ ] 2 回生成して、出力がバイト単位で同じ
- [ ] 部分集合の外の定義（例: `partial def`）で生成器が失敗する
- [ ] `requires` を手で強めた関数を、`--check-contracts` が検出する
- [ ] `model_prelude.rs` の各演算について、`LangSemantics.Rust` の `#guard` の例と同じ値になることを、Verus の `assert(...) by (compute)` で確認した

## 参照

- [ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md), [spec-pivot/rust/layout.md](../../.agents/skills/spec-pivot/references/docs/lang/rust/layout.md), [spec-pivot/rust/verification.md](../../.agents/skills/spec-pivot/references/docs/lang/rust/verification.md)
- [refinement.md](../spec/refinement.md)（SRC-002）
