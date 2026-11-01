---
type: Architecture Decision Record
title: "トップレベル名前空間を LangSemantics.<lang> / SourceModel / Spec / Abstraction / TargetModel / Refinement に統一する"
description: "言語意味論・移植元・抽象・移植先の各モデルと 2 種類の証明課題に、実装言語を固定しない共通のトップレベル名前空間を与える。"
tags: [adr, architecture, naming]
id: "3e1d0a0c-a87e-42be-af3d-40110fa20351"
status: deprecated
decision_status: superseded
superseded_by: "796cdc52-2288-46c9-a061-40bc68d61fa4"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# トップレベル名前空間を LangSemantics.<lang> / SourceModel / Spec / Abstraction / TargetModel / Refinement に統一する

## Context and Problem Statement

[ADR a43d](a43d-two-layer-model-java-faithful-and-abstract.md) で、原典の振る舞いを写すモデルと抽象モデルを分け、関係を証明する方針を決めた。
当初は Lean の `Atrs.JavaModel` / `Atrs.Spec` / `Atrs.Refinement` のように、移植元の言語（Java）や移植先の言語（Lean）を名前に織り込んでいた。
しかし最終目標は「あらゆる言語への移植」であり、Lean も移植先の一つにすぎない。
どの言語で書いても同じ名前で各層を指せる規則が必要である。プロジェクトオーナーから次の名前で統一する指示があった。
さらに、アプリケーション（ATRS）に依存しない言語固有の意味論（Java の int32・double など）を、Lean の名前空間 `LangSemantics.<lang>` として独立に定義する指示があった。

## Decision Drivers

* 移植元・移植先の言語を名前に固定しないこと
* 全言語・全文書で同じ名前で各層を指せること
* 証明課題の向き（移植元 → 抽象、抽象 → 移植先）が名前から分かること

## Considered Options

* 言語名を含まない 5 つのアプリケーション層と、言語意味論の `LangSemantics.<lang>`
* 言語名を含む名前（`JavaModel`, `Target.Lean` など）
* プロジェクト名の下にまとめる（`Atrs.*`）

## Decision Outcome

Chosen option: "言語名を含まない 5 つのアプリケーション層と、言語意味論の `LangSemantics.<lang>`", because 層の役割だけを名前にすることで、どの言語のプロジェクトでも同じ構成・同じ名前を使え、言語名は意味論モデルの `<lang>` の位置にだけ現れるため。

| 名前空間 | 日本語名 | 役割 | 文書上の記号 |
| --- | --- | --- | --- |
| `LangSemantics.<lang>` | 言語意味論モデル | アプリケーションに依存しない、言語 `<lang>` の基本型・基本演算の意味論。現在定義するのは `LangSemantics.Java`（int32・IEEE 754 double・`BigDecimal` 丸め・UTF-16 文字列・`LocalDate`。[ADR 935b](935b-java-primitive-semantics.md)）と `LangSemantics.Sql`（原典が使う PostgreSQL SQL の部分集合。[ADR 5fcb](5fcb-sql-semantics-for-source-repositories.md)）。移植先言語の意味論が必要になれば同じ規則で追加する | — |
| `SourceModel` | 移植元モデル | 原典（現在は Java 版 ATRS）の観測可能な振る舞いを、原典言語の意味論ごと写したモデル | **[Source]** |
| `Spec` | 抽象モデル | 言語中立な正規の業務仕様。厳密な整数演算 | **[Spec]** |
| `Abstraction` | 抽象化証明課題 | `SourceModel` → `Spec` の関係（抽象化関数 α と、一致・差異・安全性の定理） | 課題 ID `ABS-NNN` |
| `TargetModel` | 移植先モデル | そのプロジェクトの言語による実装（ポートのアダプタ、HTTP、永続化を含む） | **[Target]** |
| `Refinement` | 具体化証明課題 | `Spec` → `TargetModel` の関係（`TargetModel` が `Spec` を満たすことの証明または検証） | 課題 ID `REF-NNN` |

規則（言語を固定しない）:

* **どの言語のプロジェクトも、この 5 つの名前をトップレベル名前空間として使う。** 別の名前のトップレベル名前空間を作ってはならない（テストドライバ・ビルド用の実行ファイルを除く）。
* `LangSemantics.<lang>` は形式化を担うプロジェクト（現在は Lean）にだけ置く。`<lang>` は言語名の UpperCamelCase（`Java`, `TypeScript`, `Rust` …）。ATRS の型・用語（運賃、会員 等）を含めてはならず、他のアプリケーションの移植にもそのまま再利用できる形で書く。
* 移植元の意味論（`LangSemantics.Java`, `LangSemantics.Sql`）は `SourceModel` と `Abstraction` が使う。移植先言語の意味論（例: `LangSemantics.TypeScript` の number = binary64）は、その言語の `TargetModel` を Lean 上で模して `Refinement` を証明する場合に使う。
* 1 つの言語プロジェクトは `TargetModel` と `Refinement` を必ず持つ。`SourceModel`・`Spec`・`Abstraction` は、そのプロジェクトが形式化（実行可能な仕様・証明）を担う場合に持つ。現在の配置は [ADR dd0f](dd0f-rust-as-target-language.md) による（Lean は `LangSemantics`・`SourceModel`・`Spec`・`Abstraction`、Rust は `spec`・`target_model`・`refinement`）。
* 他言語のプロジェクトが `Spec` を持つ場合（`TargetModel` の内部で再利用するため等）、それは正規の Lean `Spec`（[ADR 61bc](61bc-lean-spec-as-normative-source.md)）の写しであり、`Refinement` の対象は常に Lean `Spec` である。
* `Refinement` の課題は、その言語で使える検証手段で充足する。適合テストベクタの全件通過は常に必須とする。Rust での手段は [ADR dd0f](dd0f-rust-as-target-language.md)（Verus と Kani）。課題の共通一覧は [spec/refinement.md](../spec/refinement.md) に置く。
* 名前空間の綴りは言語の慣習に従って写してよい（例: Rust の `source_model` モジュール、Python の `target_model` パッケージ）。写し方は各言語プロジェクトの `README.md` に書く。
* 言語の基本演算（int32, double 等）は `LangSemantics.<lang>` に置き、`SourceModel` には置かない。抽象モデルの基本演算（`floorDiv`, 暦日等）は `Spec` の下位（`Spec.Prim`）に置く。
* 依存の向き:
  * `LangSemantics.<lang>` は他のどれにも依存しない（同じ `<lang>` 内と core・Batteries のみ）。
  * `Spec` は `LangSemantics` を含め他のどれにも依存しない。
  * `SourceModel` は `LangSemantics.Java`・`LangSemantics.Sql` と `Spec` の型に依存してよい。
  * `Abstraction` は `SourceModel`・`Spec`・`LangSemantics.Java`・`LangSemantics.Sql` に依存する。
  * `TargetModel` は `Spec` に依存してよい（型・純粋関数の再利用）。`SourceModel`・`Abstraction` に依存してはならない。
  * `Refinement` は `Spec`・`TargetModel`・`LangSemantics.<targetLang>` に依存してよい。
* 文書では [ADR a43d](a43d-two-layer-model-java-faithful-and-abstract.md) の「Java 忠実モデル」を **移植元モデル [Source]**、「抽象モデル」を **抽象モデル [Spec]**、実装を **移植先モデル [Target]** と呼ぶ。
* `Abstraction` の課題と既知差異（`D-NNN`）は [spec/abstraction.md](../spec/abstraction.md)、`Refinement` の課題は [spec/refinement.md](../spec/refinement.md) に置く。
* 適合テストベクタのディレクトリは `conformance/spec/`, `conformance/source-model/`, `conformance/shared/` とする（[ADR dc3a](dc3a-conformance-test-vectors.md)）。`TargetModel` は `spec/` と `shared/` のベクタを通す。

リポジトリ配置:

```
lean/                 Lean プロジェクト（形式化）
  LangSemantics/Java/  LangSemantics/Sql/  SourceModel/  Spec/  Abstraction/
rust/                 移植先（ADR dd0f）
  src/spec/  src/target_model/  src/refinement/
conformance/          言語中立の適合テストベクタ
```

### Consequences

* Good, because どの言語のプロジェクトを開いても同じ 5 つの名前で構成が分かる
* Good, because 新しい移植先を追加するときに作るものが `TargetModel` と `Refinement` だと明確
* Good, because 移植元を差し替える場合も `SourceModel` と `Abstraction` の中身だけが変わる
* Bad, because 移植先が `Spec` の写しを持つ場合（Rust の Verus の spec 関数など）、正規の Lean `Spec` との同期が必要になる

### Confirmation

* 各言語プロジェクトのトップレベルが上記 5 つ（Lean はさらに `LangSemantics`）とテストドライバだけであることを確認する。
* `LangSemantics` が ATRS 固有のモジュールを import していないことを CI で検査する。
* `TargetModel` から `SourceModel`・`Abstraction` への import が無いことを CI で検査する。

## Pros and Cons of the Options

### 言語名を含まない 5 つの名前空間

* Good, because 言語非依存で、層と証明の向きが明確
* Bad, because 一般的な単一ルート（`Atrs.*`）の慣習から外れ、他ライブラリと名前が衝突しうる（衝突時はパッケージ名で区別する）

### 言語名を含む名前

* Good, because 現状では直感的
* Bad, because 移植先を増やすたびに名前の規則が崩れる

### `Atrs.*` の下にまとめる

* Good, because 名前衝突を避けやすい
* Bad, because 層の役割がトップレベルで見えない

## More Information

* **本 ADR は [ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) に置き換えられた**。名前（`LangSemantics.<lang>`, `SourceModel`, `Spec`, `Abstraction`, `TargetModel`, `Refinement`）は引き継ぎ、すべてのモデルと証明を Lean に置く構成に改めた。

* 配置（どの言語プロジェクトがどの名前空間を持つか）は [ADR dd0f](dd0f-rust-as-target-language.md) で更新した。
* [ADR a43d](a43d-two-layer-model-java-faithful-and-abstract.md) の層の名前を本 ADR で確定する（二層＋証明という決定内容は変えない）。
* [spec-pivot/lean/rules.md](../../.agents/skills/spec-pivot/references/docs/lang/lean/rules.md), [spec/abstraction.md](../spec/abstraction.md), [spec/refinement.md](../spec/refinement.md)
