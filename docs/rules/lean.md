---
type: Guideline
title: "Lean 規約"
description: "Lean プロジェクトの名前空間構成・依存の向き・追跡注釈・全域性・型選択・命名・証明方針。"
tags: [rules, lean]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Lean 規約

ツールチェーンと依存は [ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md) に従う
（Lean 4 を `lean-toolchain` で固定、Lake、依存は Batteries のみ、**Mathlib は使わない**）。
構成は [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md) に従う。**モデルと証明はすべて Lean に置く**。
正規仕様は `Spec`（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）である。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
```

## トップレベル名前空間

Lean プロジェクトは `lean/` に置き（[backlog 0001](../backlog/0001-lean-project-scaffold.md)）、次の名前空間 **だけ** をトップレベルに置く。
例外は 3 つで、実行ファイル用の `Tests`・`Tools` と、追跡属性の基盤 `Trace`（どのモデルにも依存しない）である。

```
lean/
  lean-toolchain
  lakefile.lean
  LangSemantics/   -- 言語意味論モデル（アプリケーション非依存）
    Java/          --   Int32, JDouble, BigDecimal 丸め, UTF-16 文字列, LocalDate [ADR 0005]
    Sql/           --   値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR [ADR 0019]
    Rust/          --   固定長整数（検査付き・折り返し）、char、UTF-8 String、Vec、Result、パニック
  SourceModel/     -- 移植元モデル [Source]: Java/SQL ソースを写す
  Spec/            -- 抽象モデル [Spec]（正規仕様）
    Prim/          --   基本演算（floorDiv, ceilTo, 暦日, 文字クラス）
  Abstraction/     -- 抽象化証明課題: SourceModel → Spec（ABS-NNN）
  TargetModel/     -- 移植先モデル [Target]: Rust ソースを写す
  Refinement/      -- 具体化証明課題: Spec → TargetModel（REF-NNN）
  Trace/           -- 追跡属性 @[source] @[target] @[obligation] @[spec_doc] と trace-dump
  Tests/           -- テストドライバ（`lake test`）: ベクタ照合、性質テスト
  Tools/           -- 実行ファイル: ベクタの期待値生成、trace-dump
```

- ファイルパスと名前空間を一致させる（`Spec.Fare` は `Spec/Fare.lean`、`LangSemantics.Rust.Int` は `LangSemantics/Rust/Int.lean`）。
- 上記以外のトップレベル名前空間（`Atrs` など）を作ってはならない。
- 依存の向き（違反は CI で検出する）:

| モジュール | import してよいもの |
| --- | --- |
| `Trace` | `Trace` のみ |
| `LangSemantics.<lang>` | 同じ `LangSemantics.<lang>`, `Trace` |
| `Spec` | `Spec`, `Trace` |
| `SourceModel` | `SourceModel`, `Spec`, `LangSemantics.Java`, `LangSemantics.Sql`, `Trace` |
| `Abstraction` | `Abstraction`, `SourceModel`, `Spec`, `LangSemantics.Java`, `LangSemantics.Sql`, `Trace` |
| `TargetModel` | `TargetModel`, `Spec`, `LangSemantics.Rust`, `Trace` |
| `Refinement` | `Refinement`, `TargetModel`, `Spec`, `LangSemantics.Rust`, `Trace` |
| `Tests`, `Tools` | すべて |

- **移植元側（`SourceModel`, `Abstraction`, `LangSemantics.Java/Sql`）と移植先側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）は互いに import してはならない。**
- `LangSemantics` には ATRS の型・用語を入れてはならない。他アプリケーションの移植でも再利用できる汎用の意味論として書き、言語仕様の該当節（JLS、The Rust Reference 等）を docstring に書く。
- 原典 Mapper XML の SQL 文は `SourceModel.Repository.*` に、`LangSemantics.Sql` の式として 1 文ずつ写す。
- ユースケース（ポートを使う手続き）は `Spec.UseCase.*` に置く。ポートの型は `Spec.Port`。
- `Spec` と `TargetModel` は **実行可能** でなければならない（適合テストベクタの期待値を生成するため）。命題で述べたい性質は、計算可能な定義に対する定理として書く。
- `TargetModel` は Rust ソースの構造（関数の分け方・評価順・エラーの返し方）をそのまま写す。Rust の最適化を `TargetModel` で抽象化してはならない（抽象化は `Refinement` の仕事である）。

## 追跡注釈

[ADR 0023](../decision/0023-cross-language-traceability.md) に従い、ソースとの対応を **モデル側** に属性で書く。

| 層 | 属性 | 例 |
| --- | --- | --- |
| `SourceModel`, `LangSemantics.Java/Sql` | `@[source "<移植元ロケータ>@<ハッシュ>", …]` | `@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@9c1e…"]` |
| `TargetModel`, `LangSemantics.Rust` | `@[target "<移植先ロケータ>@<ハッシュ>", …]` | `@[target "rust:atrs::fare::basic_fare@41d0…", "rust:atrs::model::fare::basic_fare@77ab…"]` |
| `Abstraction`, `Refinement` の主定理 | `@[obligation "ABS-NNN"]` / `@[obligation "REF-NNN"]` | |
| `Spec` の公開定義 | `@[spec_doc "docs/spec/<file>#<anchor>"]`。原典に対応が無い定義は `@[no_source "理由"]` | |

- フレームワーク・処理系の挙動に依存する定義は、`dep:`・`lang:` ロケータも `@[source]` / `@[target]` に含めなければならない（例: 入力の空白除去 → `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText`）。
- 移植元側の層に `rust:` を、移植先側の層に移植元ロケータを書いてはならない（検査 TR-X）。
- ハッシュは道具が出す値をそのまま書く。ソースを確認して振る舞いが変わっていなければハッシュだけを更新する。

## 全域性と安全性

- `Trace`・`Tests`・`Tools` 以外では `partial`, `unsafe`, `panic!`, `get!`, `xs[i]!`, `sorry`, `implemented_by` を使ってはならない。`Tests`・`Tools` では I/O 境界に限り `partial` を許す。
- Rust のパニックは `TargetModel` では `LangSemantics.Rust` の `Panic` 値として明示的に表す（Lean の `panic!` で表してはならない）。
- 停止性は構造的再帰か `termination_by` で示す。
- 失敗しうる操作は `Except AtrsError α`（または `Option`）を返す。
- `Float` は `Tests` での突き合わせ以外で使ってはならない。Java の double は `LangSemantics.Java.JDouble` を使う。
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

- 他言語へ写しにくい高度な型機能（依存型による長さ付きベクタ等）は **証明側（`Abstraction`・`Refinement`）に閉じ込め**、`Spec` の公開関数のシグネチャは上表の素朴な型に留める。
- `TargetModel` の型は Rust の型に対応させる（`u64` は `LangSemantics.Rust.U64`、`String` は `LangSemantics.Rust.RString`、`Result<T, E>` は `Except E T` 相当）。

## 命名

- 型・構造体: `UpperCamelCase`、関数・フィールド: `lowerCamelCase`、定理: `snake_case`。
- `Spec` は仕様の用語、`SourceModel` は原典の識別子、`TargetModel` は Rust の識別子の lowerCamelCase を優先する（`Spec.Fare.basicFare`、`SourceModel.Fare.calculateBasicFare`、`TargetModel.Fare.basicFare`）。
- 下位の名前空間は層をまたいで同じ機能名を使う（`SourceModel.Fare` / `Spec.Fare` / `Abstraction.Fare` / `TargetModel.Fare` / `Refinement.Fare`）。
- 定理名は対象と性質を表す（`basicFare_source_eq_spec_of_seed`、`basicFare_target_refines_spec`）。

## 証明

- 使ってよい自動化: `simp`, `omega`, `decide`, `native_decide`（**有限な具体値の確認のみ**、`Abstraction`・`Refinement` の主定理には使わない）, `bv_decide`, `grind`（利用可能なら）。
- 主定理には `@[obligation]` で課題 ID を付ける。
- 証明が未完の定理を `sorry` で残してはならない。未完のものは backlog に残し、定理自体をコミットしない。

## スタイル

- 1 ファイル 400 行程度を目安に分割する。
- 公開定義には docstring を付ける。docs/spec との対応は docstring ではなく `@[spec_doc]` に書く。
- `open` はファイル先頭に限定し、`open ... in` を優先する。
