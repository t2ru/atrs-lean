---
type: Backlog Item
title: "Lean プロジェクトの雛形と CI"
description: "lean/ に Lake プロジェクトを作り、全名前空間の骨格・追跡属性の基盤・依存方向検査を含む CI を整える。"
tags: [backlog, lean, ci]
id: "be4969d4-478c-47a9-8fd9-b8cf31202bc8"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T07:30:00+09:00
---

# Lean プロジェクトの雛形と CI

> 2026-10-29 に ADR 796c（モデルは Lean、Rust は移植先ソース）と ADR 81ab（両端の追跡）に合わせて範囲を改めた。

## 目的

Lean 側（全モデルと証明）の作業の土台を用意する。

## 範囲

- `lean/lean-toolchain`（着手時点の最新安定版）, `lakefile.lean`（依存は Batteries のみ）
- トップレベル名前空間 `LangSemantics`, `SourceModel`, `Spec`, `Abstraction`, `TargetModel`, `Refinement`, `Trace` と、実行ファイル用の `Tests`, `Tools` の空モジュール（`Machine` は [backlog 1ae4](../../.agents/skills/port-lang/references/docs/backlog/1ae4-machine-refinement-framework.md) でスキルの assets から取り込む）（[port-lang/lean/rules.md](../../.agents/skills/port-lang/references/docs/lang/lean/rules.md)）
- `Trace`: 属性 `@[source]`, `@[target]`, `@[obligation]`, `@[deviation]`, `@[spec_doc]`, `@[no_source]` の定義と、`lake exe trace-dump`（定義・属性・Merkle ハッシュの JSON 出力）
- ルートの `lakefile.lean`（作成済みの Lake ワークスペース）に `require atrs from "./lean"` を追加し、ルートで `lake setup-file lean/<任意のファイル>` が成功することを確認する（Lean LSP 用）
- CI: `lake build`, `lake test`, `sorry`・新規 `axiom`・`Tests` の外の `native_decide`/`bv_decide` の検出, `Float` 使用禁止範囲, 名前空間の依存方向（特に移植元側と移植先側の相互非依存）
- Lean の版を [ADR 659f](../decision/659f-lean-toolchain-and-dependencies.md) の More Information に追記

## 対象外

- 業務ロジックの実装
- Rust 側（[backlog fb50](fb50-rust-project-scaffold.md)）

## 完了条件

- [x] `lake build` と `lake test` が成功する
- [x] `trace-dump` がダミー定義の属性と Merkle ハッシュを出力する（`lake exe trace-dump --module Tests.TraceFixture --root Tests`。`lake test` で自動検査する）
- [x] 依存方向に違反する import を入れると CI が失敗することを確認した（`lean/SourceModel.lean` に `import TargetModel` を入れると `tools/ci/lean.sh` が失敗する。Lean のビルド自体は通るため、検査は `check_lean.py` が担う。違反例 22 件の自己テスト `check_lean.py --self-test` を CI で常に実行する）
- [x] AGENTS.md の「現在の状態」を更新した

## 結果

- **構成**: `lean/`（パッケージ `atrs`）。ライブラリ `Trace`, `Spec`, `SourceModel`, `Abstraction`, `TargetModel`, `Refinement`, `Tests`、実行ファイル `trace-dump`, `axiom-check`, `tests`（`lake test` のドライバ。Lake は名前に `-` を含むドライバを解決できないため `tests` とした）。
- **`LangSemantics`**: ATRS に固有の定義を足さない規約（[atrs-porting.md](../rules/atrs-porting.md)）のため、`lean/` に空モジュールを作らず、スキルの `assets/lean` を Lake 依存（`langSemantics`）として取り込んだ。`SourceModel` は `LangSemantics.Java`・`LangSemantics.Sql` を、`TargetModel` は `LangSemantics.Rust` を import する。
- **追跡属性**（`Trace.Attr`）: 引数は文字列リテラルの並び。区切りの `,` は次が文字列のときだけ引数の区切りとみなすため、`@[spec_doc "…", no_source "…"]` のように他の属性と並べて書ける。属性名は予約語にならない（識別子 `source`・`target` を使える。`Tests.AttrErrors` で確認）。
- **trace-dump**（`Trace.Dump`）: 出力は `{"lean_version", "definitions": [...]}`。各定義は `name`・`layer`・`attributes`・`merkle`・`references`。`match_1` などの補助定数は展開して親に含める。`merkle` は `Expr` の構造ハッシュを基に 64 bit（16 進 16 桁）で合成し、同じ層と `LangSemantics.*`・`Machine` の参照先だけを合成する。相互再帰は強連結成分ごとに計算する（カーネルの定義は直接には再帰しないため、閉路の扱いは合成グラフで検査した）。並びは完全名の文字列の辞書順。
- **axiom-check**: モデルの全定義が依存する公理が `propext`・`Quot.sound`・`Classical.choice` に限られることを検査する（`sorry` を入れると `sorryAx` で失敗することを確認した）。
- **CI**: `tools/ci/lean.sh` をローカルと GitHub Actions（`.github/workflows/lean.yml`）で共通に使う。`Float`・`native_decide` などの禁止範囲と、名前空間の依存の向きは `tools/ci/check_lean.py` で検査する。
- **残り**: `Machine` の取り込みは [backlog 1ae4](../../.agents/skills/port-lang/references/docs/backlog/1ae4-machine-refinement-framework.md)、TR 検査（TR-X を含む）は [backlog ffdc](ffdc-trace-tooling.md)、OKF とリンクの検査は [backlog ddbd](ddbd-okf-bundle-lint.md) で扱う。スキルの `assets/lean`（`LangSemantics`）は core だけに依存するため、`LangSemantics` の定義に `@[source]`/`@[target]` を付ける方法は [backlog a8be](a8be-lang-semantics-java.md)・[a936](../../.agents/skills/port-lang/references/docs/backlog/a936-lang-semantics-rust.md) で決める。

## 参照

- [ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md)
- [ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)
- [port-lang/lean/rules.md](../../.agents/skills/port-lang/references/docs/lang/lean/rules.md)
