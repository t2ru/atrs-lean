---
name: port-lang
description: "Lean 4 を中間の形式化言語として、あるプログラミング言語で書かれたアプリケーションを別の言語へ移植する方法。移植元モデル（SourceModel）・抽象仕様（Spec）・移植先モデル（TargetModel）の 3 層と、抽象化（Abstraction）／具体化（Refinement）の証明、ソースとモデルの両端トレーサビリティ、言語中立な適合テストベクタ、移植元の版上げ追従を扱う。Use when porting an application between programming languages via a Lean formal specification, e.g. Java/SQL to Rust; when writing SourceModel, Spec, TargetModel, Abstraction or Refinement in Lean; when setting up traceability, conformance vectors, Java oracles, Verus or Kani checks; or when following an upstream release of the source application. Keywords: 言語間移植, language porting, migration, Lean 4, formal specification, refinement proof, abstraction, traceability, conformance test vectors, Verus, Kani, Java, SQL, Rust."
compatibility: Lean 4 と Lake が必要（assets の Lean モデルは Lean 4.35.0・core のみで検証済み）。言語ごとの道具（Java オラクル用の JDK、Rust ツールチェーン、Verus、Kani など）は references/<lang>/ に記載。
metadata:
  version: "0.3"
  formalization: "lean4"
  language-packs: "java sql sql/postgresql rust lean"
---

# port-lang: Lean を介した言語間移植

アプリケーションを、移植元言語から移植先言語へ **同じ振る舞いのまま** 移す。中間に Lean 4 による形式化を置く。
移植元と移植先は直接は結ばない。Lean のモデルと証明を介してだけつなぐ。
両端（ソース ⇔ モデル）は決定論的な検証または変換でつなぐ。内側（モデル ⇔ `Spec`）は B メソッドのリファインメントの証明でつなぐ。両者の違いは、すべて名前を付けて証明と文書に出す。

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(例 Java/SQL)        (Lean)                       (Lean)            (Lean)                 (例 Rust)
```

| 層（Lean のトップレベル名前空間） | 役割 |
| --- | --- |
| `LangSemantics.<lang>` | アプリに依存しない言語・処理系の意味論（例 `Java`, `Sql`, `Rust`） |
| `SourceModel` | 移植元ソースの観測可能な振る舞いを、移植元言語の意味論ごと写す |
| `Spec` | **正規仕様**。言語中立・厳密な整数演算・実行可能 |
| `Abstraction` | `SourceModel` が `Spec` を B メソッドの意味でリファインする定理（課題 `ABS-NNN`） |
| `TargetModel` | 移植先ソースの振る舞いを、移植先言語の意味論で写す |
| `Refinement` | `TargetModel` が `Spec` を B メソッドの意味でリファインする定理（課題 `REF-NNN`） |

詳細: [references/architecture.md](references/architecture.md)

## 使う場面

- 既存アプリを別言語に書き直すとき、振る舞いの同一性を証明・検証付きで保ちたい。
- 移植元に偶発的な振る舞い（浮動小数の丸め、フレームワークの暗黙の処理、不具合）があり、「再現するもの」と「意図」を分けて扱いたい。
- 移植元が今後も版上げされ、それに追従し続けたい。

## 原則

次の 3 つを基本原則とし、以下の規則のすべてに優先させる。

- **A. 両端は決定論的に一致させる。** 移植元ソースと `SourceModel`、移植先ソースと `TargetModel` の一致は、**決定論的な検証または変換** で確認する。決定論的とは、機械が実行し、同じ入力に同じ判定を返すことをいう（[verification.md](references/verification.md#決定論的な手段)）。
  - 人や LLM の判断は、一致の根拠にしない。
  - 使える手段は言語ごとに異なる。言語パックの `verification.md` に手段と **保証の限界** を書く。プロジェクトは、残る限界をすべて一つの文書に列挙する。
  - トレーサビリティを保つ（[traceability.md](references/traceability.md)）。
- **B. 内側は B メソッドのリファインメントで結ぶ。** `SourceModel` と `TargetModel` は、それぞれ抽象機械 `Spec` をリファインする。リファインメントは、貼り合わせ不変条件と 3 つの証明義務（初期化・適用可能性・正しさ）で示す（[architecture.md](references/architecture.md#リファインメントb-メソッド)）。
- **C. 差異はすべて明示する。** `Spec` とモデルが一致しない点は、既知差異（移植元側 `D-NNN`、移植先側 `T-NNN`）として、次の両方に置く。
  - 文書の登録簿
  - リファインメント定理の名前付きの仮定、または貼り合わせ関係の名前付きの成分（`@[deviation]`）

  どちらか一方だけにある差異があってはならない。

1. **正規仕様は Lean の `Spec`**。`Spec` で表現できない仕様（並行性、伝送・セキュリティ方式、実行環境、非機能）だけを Markdown の仕様文書に規範として書く（[spec-documents.md](references/spec-documents.md)）。
2. **移植元を写すモデルと、意図を表すモデルを分ける**。`SourceModel` は不具合も含めて再現し、`Spec` は意図を表す。両者の差は既知差異 `D-NNN` として記録し、`Abstraction` のリファインメント定理に名前付きの仮定（前提型）または成分（観測型）として出す。さらに、差異の証拠の定理を証明する。
3. **`Spec` は言語中立に書く**。任意精度整数、明示的な丸め、浮動小数禁止、Unicode スカラ値、タイムゾーンの無い暦日、順序の明示、副作用はポート経由（[portability.md](references/portability.md)）。
4. **トレースは両端の 2 本だけ**（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）。リンクはモデル側の注釈に書き、**検査済みハッシュ**（決定論的な検査が合格した版）を付ける。移植元と移植先を直接つないではならない（[traceability.md](references/traceability.md)）。
5. **言語中立な適合テストベクタ** を各モデルから生成し、各ソースに通す（[conformance.md](references/conformance.md)）。移植先言語の検証器が使える場合は、`TargetModel` から検証器向けの写しを **生成** し、検証器でソースとの一致を証明する。写しを手で書いてはならない。
6. 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と、移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）は、互いに依存してはならない。

## 手順（要約）

詳細と完了の定義は [process.md](references/process.md)。

1. **原典を調べる**。観測可能な振る舞いを洗い出す。SQL・設定・フレームワークの暗黙の処理も対象にする（移植元の言語パックの `frameworks.md`・`layout.md`）。
2. **草案を書く**。仕様文書に [Spec] と [Source] を併記し、差異を登録する（[spec-documents.md](references/spec-documents.md)）。
3. **形式化する**。`LangSemantics.<移植元>` → `SourceModel` → `Spec` の順に書く（[lean/rules.md](references/lean/rules.md)）。
4. **抽象化を証明する**。`Abstraction` で `ABS-NNN` を証明する。課題は、リファインメントの主定理（R）と差異の証拠（W）が必須で、補題（L）・特徴付け（C）は補助である。
5. **移植先モデルを書く**。`LangSemantics.<移植先>` → `TargetModel` を書き、`Refinement` で `REF-NNN`（R・W）を証明する。
6. **ベクタを生成する**。`Spec`・`SourceModel`・`TargetModel` を実行して期待値を作る。`SourceModel` 側は移植元オラクルでも確かめる（[conformance.md](references/conformance.md)）。
7. **移植先ソースを書く**。`TargetModel` と同じ構造で書く（移植先の言語パックの `layout.md`）。一致は `verification.md`・`harness.md` の決定論的な手段で確認する。例: 生成した写しに対する Verus の証明、Kani、照合テスト。
8. **両端を追跡する**。`@[source]` / `@[target]` を付ける。ハッシュは、決定論的な検査が合格したときに道具が書き込む（[traceability.md](references/traceability.md#検査済みハッシュ)、[lean/trace-attributes.md](references/lean/trace-attributes.md)）。
9. **検証し、限界を記録する**。全ベクタ、全証明、追跡の検査 TR-*（TR-D を含む）、言語ごとの検証器をすべて通す。手段の届かない部分を、保証の限界の文書に列挙する（[verification.md](references/verification.md)）。

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
### Lean の言語意味論モデルと Machine（assets）

`assets/` は、言語パックの `semantics.md` を Lean で実装した **そのまま使えるモデル** で、core だけに依存する Lake パッケージである。

| モジュール | ファイル |
| --- | --- |
| `LangSemantics.Java`（int/long、double のソフトモデル、BigDecimal、String、LocalDate、例外） | `assets/LangSemantics/Java/` |
| `LangSemantics.Sql`（値・三値論理・バッグ照会・ORDER BY・シーケンス・更新） | `assets/LangSemantics/Sql/` |
| `LangSemantics.Sql.Postgresql`（整数型・VARCHAR・TO_CHAR・既定の整列・シーケンス） | `assets/LangSemantics/Sql/Postgresql.lean` |
| `LangSemantics.Rust`（固定長整数とプロファイル、パニック、char・String・Vec） | `assets/LangSemantics/Rust/` |
| `Machine`（抽象機械、具体機械、貼り合わせ、B メソッドのリファインメント `Refines` と証明義務、差異による制限、推移性、空虚化を防ぐ義務 `Machine.Adequacy`） | `assets/Machine/` |
| Verus 向けの `LangSemantics.Rust` の写し（`model_prelude.rs`）。**未整備** | `assets/verus/`（予定） |

- 使い方: プロジェクトの `lean/LangSemantics/` に写すか、Lake の依存として取り込む。LSP から import を解決させるには、リポジトリのルートを Lake ワークスペースにして `require langSemantics from "<このスキルの置き場所>/assets"` とする（[lean/rules.md](references/lean/rules.md#ルートのワークスペースlsp-用)）。写した後にアプリ固有の定義を足してはならない（不足は assets 側に足す）。
- 検査: `assets/` で `lake build` を実行すると、`LangSemanticsTest/` の `#guard` が走る。Java の double モデルはネイティブ `Float` とビット単位で突き合わせている。`MachineTest/` では、リファインメントの例と反例を証明し、公理を `#guard_msgs` で固定している。反例は、具体側の非決定性が抽象側より大きい場合と、`Refines` が空虚・自明に成り立つ抜け道（`MachineTest/Adequacy.lean`）である。`LangSemanticsTest/JavaJvm.lean` は JVM で計算した突き合わせ表（生成物）で、`java LangSemanticsTest/jvm/JavaTable.java > LangSemanticsTest/JavaJvm.lean` で再生成する。CI では再生成して差分が無いことを確かめる。

処理系ごとに意味が異なる言語（例: SQL）は、`references/<lang>/dialects/<name>/` に方言パック（`semantics.md`・`engine.md`・`harness.md`）を置く。
新しい言語・方言を追加するときは [adding-a-language.md](references/adding-a-language.md) に従う。

## 検査（要約）

| 種類 | 内容 | 参照 |
| --- | --- | --- |
| 証明 | `ABS-NNN`, `REF-NNN`, `Spec` 自身の課題の定理が、`sorry` 無し・新規 `axiom` 無し・`native_decide` と `bv_decide` 無し。R 課題は `Machine.Refines` の形で、空虚化を防ぐ付帯の義務を持つ | [verification.md](references/verification.md)、[architecture.md](references/architecture.md#空虚化を防ぐ義務) |
| 適合テスト | 各モデル・各ソースが担当ディレクトリのベクタを全件通す | [conformance.md](references/conformance.md) |
| 追跡 | TR-S1/S2（移植元側の網羅とハッシュ）、TR-T1/T2（移植先側）、TR-P（R 課題の存在）、TR-D（差異の文書と `@[deviation]` の対応）、TR-G（R 課題の形と付帯の義務）、TR-N（非決定性の文書と `@[nondet]` の対応）、TR-V（ベクタの前提のラベル）、TR-X（直接接続の禁止）、TR-R（参照切れ） | [traceability.md](references/traceability.md) |
| 依存の向き | 移植元側と移植先側の相互非依存、`Spec` の独立 | [architecture.md](references/architecture.md) |
| 言語ごと | 例: 写しの再生成で差分が無いこと・Verus・Kani・Java オラクル・SQL の差分実行 | 各言語パックの `verification.md`・`harness.md` |
| 保証の限界 | 決定論的な手段の届かない部分が、プロジェクトの限界の文書にすべて載っている | [verification.md](references/verification.md#保証の限界) |

## よくある落とし穴

- `Spec` に移植元の偶発的な振る舞い（double の丸め、UTF-16 長、未規定の並び順）を持ち込む。これらは `SourceModel` で再現し、差異として記録する。
- フレームワークの暗黙の処理（入力の前後の空白除去、検証エラーの並び、日付の JSON 形式）を見落とす。言語パックの `frameworks.md` の一覧で確認する。
- `TargetModel` で移植先ソースの最適化を抽象化してしまう。抽象化は `Refinement` の仕事であり、`TargetModel` はソースの構造をそのまま写す。
- 移植先言語の写し（例: Verus の spec 関数）を手で書く・手で直す。写しは `TargetModel` から生成し、再生成で差分が無いことを CI で確かめる。
- 人の確認だけで追跡のハッシュを更新する。ハッシュは、決定論的な検査が合格した記録である。
- 差異を文書や意思決定記録だけに書き、リファインメント定理の仮定・成分に出さない（またはその逆）。
- 具体側に抽象側より大きな非決定性を持たせる（例: 順序不定の結果を、定順の `Spec` と直接比べる）。観測型の差異として明示する。
- 移植元と移植先を直接結ぶ対応表を作る。版上げのたびに腐り、証明グラフと二重管理になる。
