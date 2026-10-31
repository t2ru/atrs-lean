---
name: port-lang
description: "Lean 4 を中間の形式化言語として、あるプログラミング言語で書かれたアプリケーションを別の言語へ移植する方法。移植元モデル（SourceModel）・抽象仕様（Spec）・移植先モデル（TargetModel）の 3 層と、抽象化（Abstraction）／具体化（Refinement）の証明、ソースとモデルの両端トレーサビリティ、言語中立な適合テストベクタ、移植元の版上げ追従を扱う。Use when porting an application between programming languages via a Lean formal specification, e.g. Java/SQL to Rust; when writing SourceModel, Spec, TargetModel, Abstraction or Refinement in Lean; when setting up traceability, conformance vectors, Java oracles, Verus or Kani checks; or when following an upstream release of the source application; when assessing whether a port can be justified, or reviewing a porting claim adversarially. Keywords: 言語間移植, language porting, migration, modernization, assessment, 移植が成り立つ条件, Lean 4, formal specification, refinement proof, abstraction, traceability, conformance test vectors, adversarial review, Verus, Kani, Java, SQL, Rust."
compatibility: Lean 4 と Lake が必要（assets の Lean モデルは Lean 4.35.0・core のみで検証済み）。言語ごとの道具（Java オラクル用の JDK、Rust ツールチェーン、Verus、Kani など）は references/docs/<lang>/ に記載。
metadata:
  version: "0.8"
  formalization: "lean4"
  language-packs: "java sql sql/postgresql rust lean"
---

# port-lang: Lean を介した言語間移植

アプリケーションを、移植元言語から移植先言語へ、`Spec` が定める振る舞いのまま移す。`Spec` と移植元・移植先との違いは、すべて名前を付けて明示する。中間に Lean 4 による形式化を置く。
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

詳細: [references/docs/architecture.md](references/docs/architecture.md)

## 使う場面

- 既存アプリを別言語に書き直すとき、振る舞いの同一性を証明・検証付きで保ちたい。
- 移植元に偶発的な振る舞い（浮動小数の丸め、フレームワークの暗黙の処理、不具合）があり、「再現するもの」と「意図」を分けて扱いたい。
- 移植元が今後も版上げされ、それに追従し続けたい。

## 移植が成り立つ条件

この方法で主張できる移植の中身は、下の「言えること」にまとめた。主張が成り立つのは、適用した範囲で **成立の条件** をすべて満たすときに限る。
**適用の前提** は、成立の条件を満たすための典型的な前提である。評価の目安として使う（参考）。

### 適用の前提（参考）

対象（機能・モジュール）ごとに確かめる。前提を欠く対象には、多くの場合、表の右列のように扱う。

| # | 前提 | 欠けたときの典型的な扱い |
| --- | --- | --- |
| P1 | 移植元ソースが手元にあり、版を固定できる | その対象には適用できない。追跡（[traceability.md](references/docs/traceability.md)）が成り立たない |
| P2 | 観測可能な振る舞いを、入力・出力・ポートの効果として区切れる | 区切れない振る舞いは、規範の仕様文書に書く（[spec-documents.md](references/docs/spec-documents.md)） |
| P3 | 移植元とモデルの一致を、決定論的な手段（[verification.md](references/docs/verification.md#決定論的な手段)。例: オラクル、処理系の差分実行）で確かめられる | 確かめられない部分は、保証の限界になる |
| P4 | 使う言語の意味を、`LangSemantics` に書け、処理系と突き合わせられる | 言語パックを追加・拡充する（[adding-a-language.md](references/docs/adding-a-language.md)）。突き合わせられない演算は、保証の限界になる |
| P5 | 移植先ソースとモデルの一致を、決定論的な手段（例: 生成した写しと検証器、ベクタを通すハーネス）で確かめられる | 確かめられない部分は、保証の限界になる |
| P6 | 業務規則を、言語中立な `Spec`（[portability.md](references/docs/portability.md)）で表せる | 表せない性質（並行性・非機能など）は、規範節と保証の限界で扱う。リファインメントの証明の対象にはならない |

- 前提を満たす範囲にだけ適用してよい（例: 中核の純粋な計算だけ）。
- 外した範囲は、移植の範囲外とする意思決定とともに、範囲外の一覧に載せる（[traceability.md](references/docs/traceability.md#対象外)）。ただし、残す範囲の振る舞いに影響するソースは外せない。
- 対象が大きいときは、手順 0 の評価で前提を確かめてから範囲を決めるとよい（[workflow.md](references/docs/workflow.md#評価)）。この方法を使わない判断もありうる。

### 成立の条件

成立の条件は、下の原則と、[process.md](references/docs/process.md#完了の定義機能ごと) の完了の定義を、主張の側から並べ直したものである。新しい義務は足していない。食い違う場合は、原則と完了の定義が優先する。
適用した範囲のすべての機能について、次をすべて満たさなければならない。

| # | 条件 | 対応する規則 |
| --- | --- | --- |
| S1 | **両端**（原則 A）: 各モデル・各ソースが担当のベクタを全件通す。両端の一致を、言語パックの決定論的な手段で確かめている。移植先の検証器を使う場合は、写しを再生成して差分が無いことも確かめる | 完了の定義、言語パックの `verification.md`・`harness.md` |
| S2 | **内側**（原則 B）: `ABS-NNN`・`REF-NNN` の R 課題・W 課題が、`Machine.Refines` の形と空虚化を防ぐ義務を備えて証明されている。W 課題は両向きの例と差異の必要性を持つ。`sorry`・新規 `axiom`・`native_decide`・`bv_decide` が無い。`Spec` 自身の義務が証明されている。移植元側と移植先側が互いに依存せず、`Spec` は他の層に依存しない | [verification.md](references/docs/verification.md#証明の運用)、[architecture.md](references/docs/architecture.md#空虚化を防ぐ義務)、[依存の向き](references/docs/architecture.md#依存の向き) |
| S3 | **差異**（原則 C）: `Spec` との差異が、すべて登録簿（Lean の `@[gap_entry]`。文書の表はそこから生成する）とリファインメント定理の両方にある。差異の生じる定義に箇所の印 `@[gap]` がある。`Spec` の非決定性は、登録簿と `@[nondet]` が対応している | 検査 TR-D・TR-G（G8）、非決定性は TR-N |
| S4 | **追跡**: 追跡の検査 TR-* が、警告ではなく失敗扱いで通る（網羅・被覆・陳腐化・直接接続の禁止・参照切れ）。生成表が更新されている | [traceability.md](references/docs/traceability.md#検査) |
| S5 | **仕様文書**: 該当節が informative に置き換わり、規範節には `Spec` で表せないものだけが残っている | 完了の定義、[spec-documents.md](references/docs/spec-documents.md) |
| S6 | **限界**: 決定論的な手段と証明の届かない部分が、保証の限界の文書にすべて載っている。少なくとも、[verification.md](references/docs/verification.md#保証の限界) が必ず載せるとする項目を含む。信頼している基盤の例: Lean の核、`Machine` の定義、検証器、生成器、検査器、処理系とその版 | verification.md |

S6 のうち、`Spec` が業務の意図どおりか、名前付きの成分が広すぎないかは、証明でも検査でも決まらない。そのため、限界の文書に載せる。どう判断し、どう記録するかの既定は [workflow.md](references/docs/workflow.md#判断を記録する事項) にある。

### 言えること・言えないこと

成立の条件を満たすとき、次のことが言える。

- **モデルについて（証明）**: `SourceModel` は差異 `D-NNN` の下で、`TargetModel` は差異 `T-NNN` の下で、それぞれ同じ `Spec` をリファインする。具体的には次のとおり。
  - 前提: 抽象側の状態が不変条件を満たし、具体側の状態と貼り合わせ不変条件で結ばれている。入力は、具体側の定義域にあり、`Spec` の事前条件と差異の前提を満たす。
  - その前提の下で、具体側は結果を持ち、どの結果も正常終了である（パニック・前提違反・溢れが無い）。
  - 具体側の正常終了は、`Spec` が許す結果で模倣される。環境を標準の抽象化で固定すれば、`Spec` の標準の結果と一致する（`Refines.complete`）。
  - ここでの「一致」は、貼り合わせと出力の対応を通したものである。標準の抽象化の核（`@[kernel]`）が同一視するものは区別しない。
  - 入口の機械では、環境の前提を満たす入力の列について、具体側の軌跡が `Spec` の軌跡で模倣される（`Refines.run`）。
- **ソースについて**: 移植元ソースと移植先ソースは、S1 の手段が確かめた範囲で、それぞれのモデルと一致する。その範囲の外は、保証の限界の文書に載っている。

次のことは言えない。

- 移植元ソースと移植先ソースが、直接に同じ振る舞いをすること。両者は、`Spec` の非決定性と差異の範囲で異なりうる。
- 事前条件・環境の前提の外の入力での振る舞い。
- 「中断」の前提型の差異の前提を破った後の軌跡。
- 活性。障害の無い環境では環境の失敗を選べない（`Refines.Pinned`・`NoFaultReachable`）が、環境が常に障害を示す配備では、常に失敗しうる（[architecture.md](references/docs/architecture.md#関数型コアとポート)）。
- `Spec` が業務の意図どおりであること。
- 保証の限界の文書に載った部分。

## 原則

次の 3 つを基本原則とし、以下の規則のすべてに優先させる。

- **A. 両端は決定論的に一致させる。** 移植元ソースと `SourceModel`、移植先ソースと `TargetModel` の一致は、**決定論的な検証または変換** で確認する。決定論的とは、機械が実行し、同じ入力に同じ判定を返すことをいう（[verification.md](references/docs/verification.md#決定論的な手段)）。
  - 人や LLM の判断は、一致の根拠にしない。
  - 使える手段は言語ごとに異なる。言語パックの `verification.md` に手段と **保証の限界** を書く。プロジェクトは、残る限界をすべて一つの文書に列挙する。
  - トレーサビリティを保つ（[traceability.md](references/docs/traceability.md)）。
- **B. 内側は B メソッドのリファインメントで結ぶ。** `SourceModel` と `TargetModel` は、それぞれ抽象機械 `Spec` をリファインする。リファインメントは、貼り合わせ不変条件と 3 つの証明義務（初期化・適用可能性・正しさ）で示す（[architecture.md](references/docs/architecture.md#リファインメントb-メソッド)）。
- **C. 差異はすべて明示する。** `Spec` とモデルが一致しない点は、既知差異（移植元側 `D-NNN`、移植先側 `T-NNN`）として、次の両方に置く。
  - 登録簿（Lean の `@[gap_entry]` の宣言。文書の表はそこから生成する。[lean/trace-attributes.md](references/docs/lean/trace-attributes.md#ギャップの登録簿)）
  - リファインメント定理の名前付きの仮定、または貼り合わせ関係の名前付きの成分（`@[deviation]`）

  どちらか一方だけにある差異があってはならない。

1. **正規仕様は Lean の `Spec`**。`Spec` で表現できない仕様（並行性、伝送・セキュリティ方式、実行環境、非機能）だけを Markdown の仕様文書に規範として書く（[spec-documents.md](references/docs/spec-documents.md)）。
2. **移植元を写すモデルと、意図を表すモデルを分ける**。`SourceModel` は不具合も含めて再現し、`Spec` は意図を表す。両者の差は既知差異 `D-NNN` として記録し、`Abstraction` のリファインメント定理に名前付きの仮定（前提型）または成分（観測型）として出す。さらに、差異の証拠の定理を証明する。
3. **`Spec` は言語中立に書く**。任意精度整数、明示的な丸め、浮動小数禁止、Unicode スカラ値、タイムゾーンの無い暦日、順序の明示、副作用はポート経由（[portability.md](references/docs/portability.md)）。
4. **トレースは両端の 2 本だけ**（移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース）。リンクはモデル側の注釈に書き、**検査済みハッシュ**（決定論的な検査が合格した版）を付ける。移植元と移植先を直接つないではならない（[traceability.md](references/docs/traceability.md)）。
5. **言語中立な適合テストベクタ** を各モデルから生成し、各ソースに通す（[conformance.md](references/docs/conformance.md)）。移植先言語の検証器が使える場合は、`TargetModel` から検証器向けの写しを **生成** し、検証器でソースとの一致を証明する。写しを手で書いてはならない。
6. 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と、移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）は、互いに依存してはならない。

## 手順（要約）

詳細と完了の定義は [process.md](references/docs/process.md)。
人と AI エージェントの作業の進め方の既定は [workflow.md](references/docs/workflow.md) にある。評価、判断を記録する事項、検査ゲート、未着手の可視化、独立した敵対的レビュー、記録を扱う。プロジェクトは、自分の規約で置き換えてよい。

0. **評価する**（任意）。対象ごとに適用の前提を確かめ、適用する範囲を決める（[workflow.md](references/docs/workflow.md#評価)）。
1. **原典を調べる**。観測可能な振る舞いを洗い出す。SQL・設定・フレームワークの暗黙の処理も対象にする（移植元の言語パックの `frameworks.md`・`layout.md`）。
2. **草案を書く**。仕様文書に [Spec] と [Source] を併記し、差異を登録する（[spec-documents.md](references/docs/spec-documents.md)）。
3. **形式化する**。`LangSemantics.<移植元>` → `SourceModel` → `Spec` の順に書く（[lean/rules.md](references/docs/lean/rules.md)）。
4. **抽象化を証明する**。`Abstraction` で `ABS-NNN` を証明する。課題は、リファインメントの主定理（R）と差異の証拠（W）が必須で、補題（L）・特徴付け（C）は補助である。
5. **移植先モデルを書く**。`LangSemantics.<移植先>` → `TargetModel` を書き、`Refinement` で `REF-NNN`（R・W）を証明する。
6. **ベクタを生成する**。`Spec`・`SourceModel`・`TargetModel` を実行して期待値を作る。`SourceModel` 側は移植元オラクルでも確かめる（[conformance.md](references/docs/conformance.md)）。
7. **移植先ソースを書く**。`TargetModel` と同じ構造で書く（移植先の言語パックの `layout.md`）。一致は `verification.md`・`harness.md` の決定論的な手段で確認する。例: 生成した写しに対する Verus の証明、Kani、照合テスト。
8. **両端を追跡する**。`@[source]` / `@[target]` を付ける。ハッシュは、決定論的な検査が合格したときに道具が書き込む（[traceability.md](references/docs/traceability.md#検査済みハッシュ)、[lean/trace-attributes.md](references/docs/lean/trace-attributes.md)）。
9. **検証し、限界を記録する**。全ベクタ、全証明、追跡の検査 TR-*（TR-D を含む）、言語ごとの検証器をすべて通す。手段の届かない部分を、保証の限界の文書に列挙する（[verification.md](references/docs/verification.md)）。

移植元・移植先の版上げは [upgrade.md](references/docs/upgrade.md) の手順に従う（インベントリ差分＋差分オラクル→影響を証明グラフに沿って伝播→層ごとに判断）。

## 言語パック

言語固有の情報は `references/docs/<lang>/` にある。どの言語パックも **移植元にも移植先にもなれる** 構成で、6 ファイルからなる。
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
| Java | 移植元として整備済み。移植先は一部未整備 | [semantics](references/docs/java/semantics.md) · [locators](references/docs/java/locators.md) · [frameworks](references/docs/java/frameworks.md) · [harness](references/docs/java/harness.md) · [verification](references/docs/java/verification.md) · [layout](references/docs/java/layout.md) |
| SQL（共通） | 移植元として整備済み。移植先は一部未整備 | [semantics](references/docs/sql/semantics.md) · [locators](references/docs/sql/locators.md) · [frameworks](references/docs/sql/frameworks.md) · [harness](references/docs/sql/harness.md) · [verification](references/docs/sql/verification.md) · [layout](references/docs/sql/layout.md) |
| └ 方言 PostgreSQL | 整備済み | [semantics](references/docs/sql/dialects/postgresql/semantics.md) · [engine](references/docs/sql/dialects/postgresql/engine.md) · [harness](references/docs/sql/dialects/postgresql/harness.md) |
| Rust | 移植先として整備済み。移植元は一部未整備 | [semantics](references/docs/rust/semantics.md) · [locators](references/docs/rust/locators.md) · [frameworks](references/docs/rust/frameworks.md) · [harness](references/docs/rust/harness.md) · [verification](references/docs/rust/verification.md) · [layout](references/docs/rust/layout.md) |

形式化言語の Lean 4 は全プロジェクト共通である: [lean/rules.md](references/docs/lean/rules.md), [lean/trace-attributes.md](references/docs/lean/trace-attributes.md)。
### Lean の言語意味論モデルと Machine・Trace（assets）

`assets/lean/` は、言語パックの `semantics.md` を Lean で実装した **そのまま使えるモデル** で、core だけに依存する Lake パッケージである。`assets/` の下は資産の種類ごとに分け、Lean 以外の資産（例: `assets/verus/`）は `assets/lean/` の外に置く。

| モジュール | ファイル |
| --- | --- |
| `LangSemantics.Core`（言語に依存しない列・`mapM`・文字列の補題。どの言語パック・層からも使える） | `assets/lean/LangSemantics/Core/` |
| `LangSemantics.Java`（int/long、double のソフトモデルと百分率の因子の比較、値域内の int の演算と `for` 文の補題、BigDecimal、String、LocalDate、例外と `JResult` の補題、HashMap） | `assets/lean/LangSemantics/Java/` |
| `LangSemantics.Sql`（値・三値論理・バッグ照会・ORDER BY・シーケンス・更新、結合と許される順列の補題） | `assets/lean/LangSemantics/Sql/` |
| `LangSemantics.Sql.Postgresql`（整数型・VARCHAR・TO_CHAR・既定の整列・シーケンス） | `assets/lean/LangSemantics/Sql/Postgresql.lean` |
| `LangSemantics.Rust`（固定長整数とプロファイル、パニック、char・String・Vec） | `assets/lean/LangSemantics/Rust/` |
| `Machine`（抽象機械、具体機械、貼り合わせ、B メソッドのリファインメント `Refines` と証明義務、差異による制限、推移性、空虚化を防ぐ義務 `Machine.Adequacy`、標準の抽象化の汎用の核 `Machine.undefOrEq`） | `assets/lean/Machine/` |
| `Trace`（追跡属性、ギャップの登録簿 `Trace.Gap`、`trace-dump`・`obligation-check` の本体。道具の入口 `main` はプロジェクトの側に置く。[lean/trace-attributes.md](references/docs/lean/trace-attributes.md)） | `assets/lean/Trace/` |
| `ConformanceKit`（適合テストベクタの実行器と、SQL の差分実行の結果の表の読み取り。メタ層。[conformance.md](references/docs/conformance.md)） | `assets/lean/ConformanceKit/` |
| Verus 向けの `LangSemantics.Rust` の写し（`model_prelude.rs`）。**未整備** | `assets/verus/`（予定） |

- 使い方: プロジェクトの `lean/LangSemantics/` に写すか、Lake の依存として取り込む。LSP から import を解決させるには、リポジトリのルートを Lake ワークスペースにして `require langSemantics from "<このスキルの置き場所>/assets/lean"` とする（[lean/rules.md](references/docs/lean/rules.md#ルートのワークスペースlsp-用)）。写した後にアプリ固有の定義を足してはならない（不足は assets 側に足す）。
- 検査: `assets/lean/` で `lake build` を実行すると、`LangSemanticsTest/` の `#guard` が走る。Java の double モデルはネイティブ `Float` とビット単位で突き合わせている。`ConformanceKitTest/` では実行器をメモリ上のベクタで確かめる。`TraceTest/` では追跡属性の引数の誤りを `#guard_msgs` で確かめ、`lake exe trace-test` で `trace-dump`・`obligation-check` の処理をフィクスチャにかける。`MachineTest/` では、リファインメントの例と反例を証明し、公理を `#guard_msgs` で固定している。反例は、具体側の非決定性が抽象側より大きい場合と、`Refines` が空虚・自明に成り立つ抜け道（`MachineTest/Adequacy.lean`）である。`LangSemanticsTest/JavaJvm.lean` は JVM で計算した突き合わせ表（生成物）で、`java LangSemanticsTest/jvm/JavaTable.java > LangSemanticsTest/JavaJvm.lean` で再生成する。CI では再生成して差分が無いことを確かめる。同様に `LangSemanticsTest/PostgresqlDb.lean` は PostgreSQL で計算した突き合わせ表で、`python3 -I LangSemanticsTest/pg/pg_table.py > LangSemanticsTest/PostgresqlDb.lean` で再生成する（接続先は psql の環境変数。[sql/dialects/postgresql/harness.md](references/docs/sql/dialects/postgresql/harness.md)）。

### 道具（scripts）

`scripts/` は、追跡と検査の **そのまま使える道具** である（[scripts/README.md](scripts/README.md)）。追跡の CLI `scripts/trace`（Rust）、Lean の静的検査 `scripts/ci/check_lean.py`、課題一覧との突き合わせ `scripts/ci/check_obligations.py`、上流の版の検査、PostgreSQL・JVM の突き合わせ表の検査、意思決定記録・作業項目の ID の道具（任意）を持つ。
道具はアプリに依存せず、プロジェクト固有の値（移植元・移植先の配置、crate 名、文書のパス、言語の組、Lean のルート）を、プロジェクトの `trace/project.json` から読む（[traceability.md](references/docs/traceability.md#プロジェクトの設定)）。プロジェクトの CI は、これらを一括検査のスクリプトから呼ぶ。

処理系ごとに意味が異なる言語（例: SQL）は、`references/docs/<lang>/dialects/<name>/` に方言パック（`semantics.md`・`engine.md`・`harness.md`）を置く。
新しい言語・方言を追加するときは [adding-a-language.md](references/docs/adding-a-language.md) に従う。

## 検査（要約）

| 種類 | 内容 | 参照 |
| --- | --- | --- |
| 証明 | `ABS-NNN`, `REF-NNN`, `Spec` 自身の課題の定理が、`sorry` 無し・新規 `axiom` 無し・`native_decide` と `bv_decide` 無し。R 課題は `Machine.Refines` の形で、空虚化を防ぐ付帯の義務を持つ。W 課題は両向きの例と差異の必要性を持つ | [verification.md](references/docs/verification.md)、[architecture.md](references/docs/architecture.md#空虚化を防ぐ義務) |
| 適合テスト | 各モデル・各ソースが担当ディレクトリのベクタを全件通す | [conformance.md](references/docs/conformance.md) |
| 追跡 | TR-S1/S2（移植元側の網羅とハッシュ）、TR-T1/T2（移植先側）、TR-P（R 課題の存在）、TR-D（差異の登録簿と `@[deviation]` の対応）、TR-K（差異の箇所の印 `@[gap]`）、TR-G（R 課題の形と付帯の義務）、TR-N（非決定性の文書と `@[nondet]` の対応）、TR-V（ベクタの前提のラベル）、TR-X（直接接続の禁止）、TR-R（参照切れ） | [traceability.md](references/docs/traceability.md) |
| 依存の向き | 移植元側と移植先側の相互非依存、`Spec` の独立 | [architecture.md](references/docs/architecture.md) |
| 言語ごと | 例: 写しの再生成で差分が無いこと・Verus・Kani・Java オラクル・SQL の差分実行 | 各言語パックの `verification.md`・`harness.md` |
| 保証の限界 | 決定論的な手段の届かない部分が、プロジェクトの限界の文書にすべて載っている | [verification.md](references/docs/verification.md#保証の限界) |

## よくある落とし穴

- `Spec` に移植元の偶発的な振る舞い（double の丸め、UTF-16 長、未規定の並び順）を持ち込む。これらは `SourceModel` で再現し、差異として記録する。
- フレームワークの暗黙の処理（入力の前後の空白除去、検証エラーの並び、日付の JSON 形式）を見落とす。言語パックの `frameworks.md` の一覧で確認する。
- `TargetModel` で移植先ソースの最適化を抽象化してしまう。抽象化は `Refinement` の仕事であり、`TargetModel` はソースの構造をそのまま写す。
- 移植先言語の写し（例: Verus の spec 関数）を手で書く・手で直す。写しは `TargetModel` から生成し、再生成で差分が無いことを CI で確かめる。
- 人の確認だけで追跡のハッシュを更新する。ハッシュは、決定論的な検査が合格した記録である。
- 差異を文書や意思決定記録だけに書き、リファインメント定理の仮定・成分に出さない（またはその逆）。
- 具体側に抽象側より大きな非決定性を持たせる（例: 順序不定の結果を、定順の `Spec` と直接比べる）。観測型の差異として明示する。
- 移植元と移植先を直接結ぶ対応表を作る。版上げのたびに腐り、証明グラフと二重管理になる。
- 完了を、検査の実行結果ではなく自己申告（「実装した」「確認した」）で宣言する。
- 大きな対象で、適用の前提を確かめずに全体へ一度に適用する。形式化の工数は、対象の大きさに応じて増える。
- 機械で再び検出できる誤りの指摘を、文章の注意書きだけで済ませる。指摘は、できる限り反例・検査・限界の行・差異の登録に落とす。

## スキルの文書と記録

`references/docs/` は OKF v0.2 の Knowledge Bundle である。索引は [references/docs/index.md](references/docs/index.md)、変更履歴は [log.md](references/docs/log.md) にある。
スキル自身の意思決定記録は [references/docs/decision/](references/docs/decision/README.md)、作業項目は [references/docs/backlog/](references/docs/backlog/README.md) にある。
アプリに依存しない判断・作業はここに記録し、適用先に固有の判断は適用先に記録する。
スキルを保守するときの規則（frontmatter・ID・持ち出せること・適用先との分担）は、[references/docs/maintenance.md](references/docs/maintenance.md) にある。
