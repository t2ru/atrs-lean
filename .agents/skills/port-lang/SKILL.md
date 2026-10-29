---
name: port-lang
description: "Lean 4 を中間の形式化言語として、あるプログラミング言語で書かれたアプリケーションを別の言語へ移植する方法。移植元モデル（SourceModel）・抽象仕様（Spec）・移植先モデル（TargetModel）の 3 層と、抽象化（Abstraction）／具体化（Refinement）の証明、ソースとモデルの両端トレーサビリティ、言語中立な適合テストベクタ、移植元の版上げ追従を扱う。Use when porting an application between programming languages via a Lean formal specification, e.g. Java/SQL to Rust; when writing SourceModel, Spec, TargetModel, Abstraction or Refinement in Lean; when setting up traceability, conformance vectors, Java oracles, Verus or Kani checks; or when following an upstream release of the source application. Keywords: 言語間移植, language porting, migration, Lean 4, formal specification, refinement proof, abstraction, traceability, conformance test vectors, Verus, Kani, Java, SQL, Rust."
compatibility: Lean 4 と Lake が必要。言語ごとの道具（Java オラクル用の JDK、Rust ツールチェーン、Verus、Kani など）は references/<lang>/ に記載。
metadata:
  version: "0.1"
  formalization: "lean4"
  language-packs: "java sql sql/postgresql rust lean"
---

# port-lang: Lean を介した言語間移植

アプリケーションを、移植元言語から移植先言語へ **同じ振る舞いのまま** 移す。中間に Lean 4 による形式化を置く。
移植元と移植先は直接は結ばない。Lean のモデルと証明を介してだけつなぐ。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(例 Java/SQL)        (Lean)                       (Lean)            (Lean)                 (例 Rust)
```

| 層（Lean のトップレベル名前空間） | 役割 |
| --- | --- |
| `LangSemantics.<lang>` | アプリに依存しない言語・処理系の意味論（例 `Java`, `Sql`, `Rust`） |
| `SourceModel` | 移植元ソースの観測可能な振る舞いを、移植元言語の意味論ごと写す |
| `Spec` | **正規仕様**。言語中立・厳密な整数演算・実行可能 |
| `Abstraction` | `SourceModel` → `Spec` の定理（課題 `ABS-NNN`） |
| `TargetModel` | 移植先ソースの振る舞いを、移植先言語の意味論で写す |
| `Refinement` | `Spec` → `TargetModel` の定理（課題 `REF-NNN`） |

詳細: [references/architecture.md](references/architecture.md)

## 使う場面

- 既存アプリを別言語に書き直すとき、振る舞いの同一性を証明・検証付きで保ちたい。
- 移植元に偶発的な振る舞い（浮動小数の丸め、フレームワークの暗黙の処理、不具合）があり、「再現するもの」と「意図」を分けて扱いたい。
- 移植元が今後も版上げされ、それに追従し続けたい。

## 原則

1. **正規仕様は Lean の `Spec`**。`Spec` で表現できない仕様（並行性、伝送・セキュリティ方式、実行環境、非機能）だけを Markdown の仕様文書に規範として書く（[spec-documents.md](references/spec-documents.md)）。
2. **移植元を写すモデルと、意図を表すモデルを分ける**。`SourceModel` は不具合も含めて再現し、`Spec` は意図を表す。両者の差は既知差異 `D-NNN` として記録し、どの前提で一致するかを `Abstraction` で証明する。
3. **`Spec` は言語中立に書く**。任意精度整数、明示的な丸め、浮動小数禁止、Unicode スカラ値、タイムゾーンの無い暦日、順序の明示、副作用はポート経由（[portability.md](references/portability.md)）。
4. **トレースは両端の 2 本だけ**（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）。リンクはモデル側の注釈に、確認済みハッシュ付きで書く。移植元と移植先を直接つないではならない（[traceability.md](references/traceability.md)）。
5. **言語中立な適合テストベクタ** を各モデルから生成し、各ソースに通す（[conformance.md](references/conformance.md)）。
6. 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と、移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）は、互いに依存してはならない。

## 手順（要約）

詳細と完了の定義は [process.md](references/process.md)。

1. **原典を調べる**。観測可能な振る舞いを洗い出す。SQL・設定・フレームワークの暗黙の処理も対象にする（移植元の言語パックの `frameworks.md`・`layout.md`）。
2. **草案を書く**。仕様文書に [Spec] と [Source] を併記し、差異を登録する（[spec-documents.md](references/spec-documents.md)）。
3. **形式化する**。`LangSemantics.<移植元>` → `SourceModel` → `Spec` の順に書く（[lean/rules.md](references/lean/rules.md)）。
4. **抽象化を証明する**。`Abstraction` で `ABS-NNN` を証明する（一致・差異の特徴付け・安全性）。
5. **移植先モデルを書く**。`LangSemantics.<移植先>` → `TargetModel` を書き、`Refinement` で `REF-NNN` を証明する。
6. **ベクタを生成する**。`Spec`・`SourceModel`・`TargetModel` を実行して期待値を作る。`SourceModel` 側は移植元オラクルでも確かめる（[conformance.md](references/conformance.md)）。
7. **移植先ソースを書く**。`TargetModel` と同じ構造で書き（移植先の言語パックの `layout.md`）、`verification.md`・`harness.md` の手段で一致を確認する（例: Verus・Kani・照合テスト）。
8. **両端を追跡する**。`@[source]` / `@[target]` を付け、ハッシュを道具の出力で埋める（[lean/trace-attributes.md](references/lean/trace-attributes.md)）。
9. **検証する**。全ベクタ、全証明、追跡の検査 TR-*、言語ごとの検証器をすべて通す（[verification.md](references/verification.md)）。

移植元・移植先の版上げは [upgrade.md](references/upgrade.md) の手順に従う（インベントリ差分＋差分オラクル→影響を証明グラフに沿って伝播→層ごとに判断）。

## 言語パック

言語固有の情報は `references/<lang>/` にある。どの言語パックも **移植元にも移植先にもなれる** 構成で、6 ファイルからなる。
役割による違いは、各ファイルの「移植元として」「移植先として」の節に書かれている。今回の移植で使う言語の行だけを読めばよい。

| ファイル | 内容 |
| --- | --- |
| `semantics.md` | `LangSemantics.<Lang>`（基本型・演算・文字列・例外の意味） |
| `locators.md` | ロケータの文法とインベントリの取り方 |
| `frameworks.md` | フレームワーク・ランタイムの暗黙の効果、依存の版、版上げで起こりがちな変化 |
| `harness.md` | ベクタの実行（移植元ならオラクル、移植先なら照合） |
| `verification.md` | 言語内の検証器とモデル ⇔ ソースの確認 |
| `layout.md` | ソースの構成と Lean 名前空間の対応（移植先として書く／移植元として読む） |

| 言語 | 整備状況 | ファイル |
| --- | --- | --- |
| Java | 移植元として整備済み。移植先は一部未整備 | [semantics](references/java/semantics.md) · [locators](references/java/locators.md) · [frameworks](references/java/frameworks.md) · [harness](references/java/harness.md) · [verification](references/java/verification.md) · [layout](references/java/layout.md) |
| SQL（共通） | 移植元として整備済み。移植先は一部未整備 | [semantics](references/sql/semantics.md) · [locators](references/sql/locators.md) · [frameworks](references/sql/frameworks.md) · [harness](references/sql/harness.md) · [verification](references/sql/verification.md) · [layout](references/sql/layout.md) |
| └ 方言 PostgreSQL | 整備済み | [semantics](references/sql/dialects/postgresql/semantics.md) · [engine](references/sql/dialects/postgresql/engine.md) · [harness](references/sql/dialects/postgresql/harness.md) |
| Rust | 移植先として整備済み。移植元は一部未整備 | [semantics](references/rust/semantics.md) · [locators](references/rust/locators.md) · [frameworks](references/rust/frameworks.md) · [harness](references/rust/harness.md) · [verification](references/rust/verification.md) · [layout](references/rust/layout.md) |

形式化言語の Lean 4 は全プロジェクト共通である: [lean/rules.md](references/lean/rules.md), [lean/trace-attributes.md](references/lean/trace-attributes.md)。
処理系ごとに意味が異なる言語（例: SQL）は、`references/<lang>/dialects/<name>/` に方言パック（`semantics.md`・`engine.md`・`harness.md`）を置く。
新しい言語・方言を追加するときは [adding-a-language.md](references/adding-a-language.md) に従う。

## 検査（要約）

| 種類 | 内容 | 参照 |
| --- | --- | --- |
| 証明 | `ABS-NNN`, `REF-NNN` の定理が `sorry` 無し、新規 `axiom` 無し | [verification.md](references/verification.md) |
| 適合テスト | 各モデル・各ソースが担当ディレクトリのベクタを全件通す | [conformance.md](references/conformance.md) |
| 追跡 | TR-S1/S2（移植元側の網羅とハッシュ）、TR-T1/T2（移植先側）、TR-P（証明の存在）、TR-X（直接接続の禁止）、TR-R（参照切れ） | [traceability.md](references/traceability.md) |
| 依存の向き | 移植元側と移植先側の相互非依存、`Spec` の独立 | [architecture.md](references/architecture.md) |
| 言語ごと | 例: Verus・Kani・Java オラクル | 各言語パックの `verification.md`・`harness.md` |

## よくある落とし穴

- `Spec` に移植元の偶発的な振る舞い（double の丸め、UTF-16 長、未規定の並び順）を持ち込む。これらは `SourceModel` で再現し、差異として記録する。
- フレームワークの暗黙の処理（入力の前後の空白除去、検証エラーの並び、日付の JSON 形式）を見落とす。言語パックの `frameworks.md` の一覧で確認する。
- `TargetModel` で移植先ソースの最適化を抽象化してしまう。抽象化は `Refinement` の仕事であり、`TargetModel` はソースの構造をそのまま写す。
- 移植先言語の写し（例: Verus の spec 関数）を、証明済みとみなす。写しと Lean の対応は、規約・ハッシュ・ベクタで担保しているだけで、証明ではない。
- 移植元と移植先を直接結ぶ対応表を作る。版上げのたびに腐り、証明グラフと二重管理になる。
