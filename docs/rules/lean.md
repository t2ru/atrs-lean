---
type: Guideline
title: "Lean 規約"
description: "Lean プロジェクトの名前空間構成・全域性・型選択・命名・証明方針。"
tags: [rules, lean]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Lean 規約

ツールチェーンと依存は [ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md) に従う
（Lean 4 を `lean-toolchain` で固定、Lake、依存は Batteries のみ、**Mathlib は使わない**）。
名前空間の規則は言語共通の [ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md)、配置は [ADR 0020](../decision/0020-rust-as-target-language.md) に従う。
Lean プロジェクトの役割は **正規仕様 `Spec` の形式化**（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）と **移植元からの抽象化の証明** であり、移植先モデル（`TargetModel`）と具体化証明（`Refinement`）は Rust 側に置く。

## トップレベル名前空間

Lean プロジェクトは `lean/` に置き（[backlog 0001](../backlog/0001-lean-project-scaffold.md)）、次の名前空間 **だけ** をトップレベルに置く（`Tests`・`Tools` は実行ファイルのための例外）。

```
lean/
  lean-toolchain
  lakefile.lean
  LangSemantics/   -- 言語意味論モデル（アプリケーション非依存）
    Java/          --   LangSemantics.Java: Int32, JDouble, BigDecimal 丸め, UTF-16 文字列, LocalDate [ADR 0005]
    Sql/           --   LangSemantics.Sql: 値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR [ADR 0019]
  SourceModel/     -- 移植元モデル [Source]
  Spec/            -- 抽象モデル [Spec]（正規の形式化）
    Prim/          --   基本演算（floorDiv, ceilTo, 暦日, 文字クラス）
  Abstraction/     -- 抽象化証明課題: SourceModel → Spec [spec/abstraction.md]
  Tests/           -- テストドライバ（`lake test`）: ベクタ照合、性質テスト
  Tools/           -- 実行ファイル: `Spec` を実行して適合テストベクタの期待値を生成する
```

- ファイルパスと名前空間を一致させる（`Spec.Fare` は `Spec/Fare.lean`、`LangSemantics.Java.Int32` は `LangSemantics/Java/Int32.lean`）。
- 上記以外のトップレベル名前空間（`Atrs` など）を作ってはならない。
- 依存の向き（違反は CI で検出する）:

| モジュール | import してよいもの |
| --- | --- |
| `LangSemantics.<lang>` | 同じ `LangSemantics.<lang>` のみ（＋core, Batteries） |
| `Spec` | `Spec` のみ（＋core, Batteries） |
| `SourceModel` | `SourceModel`, `Spec`, `LangSemantics.Java`, `LangSemantics.Sql` |
| `Abstraction` | `Abstraction`, `SourceModel`, `Spec`, `LangSemantics.Java`, `LangSemantics.Sql` |
| `Tests`, `Tools` | すべて |

- `LangSemantics` には ATRS の型・用語を入れてはならない。他アプリケーションの移植でも再利用できる汎用の意味論として書き、言語仕様の該当節（JLS 等）を docstring に書く。
- 原典 Mapper XML の SQL 文は `SourceModel.Repository.*` に、`LangSemantics.Sql` の式として 1 文ずつ写す。
- ユースケース（ポートを使う手続き）は `Spec.UseCase.*` に置く。ポートの型は `Spec.Port`。
- `Spec` は **実行可能** でなければならない（適合テストベクタの期待値を生成するため）。命題だけで定義し計算できない定義を公開 API にしてはならない。命題で述べたい性質は、計算可能な定義に対する定理として書く。
- Rust の Verus の写し（[rules/rust.md](rust.md)）と対応づけやすいよう、`Spec` の公開定義は 1 定義 1 責務で書き、名前を安易に変えない。名前を変えた場合は Rust 側の写しも同じ変更で直す。

## 全域性と安全性

- `LangSemantics` / `Spec` / `SourceModel` / `Abstraction` では `partial`, `unsafe`, `panic!`, `get!`, `xs[i]!`, `sorry`, `implemented_by` を使ってはならない。`Tests`・`Tools` では I/O 境界に限り `partial` を許す。
- 停止性は構造的再帰か `termination_by` で示す。
- 失敗しうる操作は `Except AtrsError α`（または `Option`）を返す。
- `Float` を `LangSemantics` / `Spec` / `SourceModel` / `Abstraction` で使ってはならない。[Source] の double は `LangSemantics.Java.JDouble`（検証可能なソフトモデル）を使う。ネイティブ `Float` は `Tests` での突き合わせにのみ使ってよい。
- `axiom` を追加してはならない（標準の `propext`, `Quot.sound`, `Classical.choice` 以外）。CI で `#print axioms` を確認する。

## 型の選び方（Spec）

| 量 | 型 |
| --- | --- |
| 金額・人数・日数・百分率 | `Nat`（非負が保証される量） |
| 差分・符号を持つ中間値 | `Int` |
| コード値（空港コード等） | 専用 `structure`（`String` を包む）または `inductive` 列挙 |
| 列挙（`FareTypeCd` 等） | `inductive` + `DecidableEq` + `Repr` + JSON 変換 |
| 暦日 | `Spec.Prim.Date`（年月日、妥当性を型で保証） |
| 時刻 | `Spec.Prim.HourMinute`（0–23, 0–59） |
| 不変条件付きの値 | `Subtype` または `structure` + 証明フィールド |

- 他言語へ写しにくい高度な型機能（依存型による長さ付きベクタ等）は **証明側（`Abstraction`）に閉じ込め**、`Spec` の公開関数のシグネチャは上表の素朴な型に留める。

## 命名

- 型・構造体: `UpperCamelCase`、関数・フィールド: `lowerCamelCase`、定理: `snake_case`。
- `Spec` は仕様の用語、`SourceModel` は原典の識別子を優先する（`Spec.Fare.basicFare` と `SourceModel.Fare.calculateBasicFare`）。
- 下位の名前空間は層をまたいで同じ機能名を使う（`SourceModel.Fare` / `Spec.Fare` / `Abstraction.Fare`。Rust では `spec::fare` / `target_model::fare` / `refinement::fare`）。
- 定理名は対象と性質を表す（`basicFare_source_eq_spec_of_seed`）。

## 証明

- 使ってよい自動化: `simp`, `omega`, `decide`, `native_decide`（**有限な具体値の確認のみ**、`Abstraction` の主定理には使わない）, `bv_decide`, `grind`（利用可能なら）。
- 主要な定理の docstring に課題 ID（`ABS-NNN`）を書く。
- 証明が未完の定理を `sorry` で残してはならない。未完のものは backlog に残し、定理自体をコミットしない。

## スタイル

- 1 ファイル 400 行程度を目安に分割する。
- 公開定義には docstring を付け、対応する spec の節へのパスを書く（`/-- spec: docs/spec/fare-calculation.md#基本運賃 -/`）。
- `open` はファイル先頭に限定し、`open ... in` を優先する。
