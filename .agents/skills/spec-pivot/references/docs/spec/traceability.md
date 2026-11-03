---
type: Specification
title: "両端の追跡（トレーサビリティ）"
description: "移植元ソース⇔SourceModel と TargetModel⇔移植先ソースの両端の追跡: ロケータ・注釈・検査済みハッシュ・インベントリ・manifest・TR 検査・道具とプロジェクトの設定。"
tags: [traceability]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:40:00+09:00
---

# 両端の追跡（トレーサビリティ）

```
移植元ソース ⇔①⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔②⇔ 移植先ソース
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側は追跡ではなく **証明**（B メソッドのリファインメント。[architecture.md](architecture.md#リファインメントb-メソッド)）でつながる。
- 追跡は「どこがどこに対応するか」を示す。「一致すること」は、決定論的な検査で示す（[verification.md](verification.md)）。両者は検査済みハッシュで結びつく。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。
- ① と ② は同じ仕組みを使う。違いは、使う言語パック（移植元の言語か、移植先の言語か）と、注釈の名前（`@[source]` / `@[target]`）だけである。

## ロケータ

ソースの位置は、版に依存しない記号的なロケータで指す。行番号は道具が版ごとに解決し、permalink を生成する。

```
locator = kind ":" body
```

- `kind` と `body` の文法は言語パックの `locators.md` が定める（例: Java の `java:`、SQL の `sql:`、Rust の `rust:`）。言語パックのロケータは、その言語が移植元・移植先のどちらでも同じ文法で使う。
- 全言語共通の kind が 2 つある。

| kind | 形式 | 例 |
| --- | --- | --- |
| `dep` | `<パッケージ座標>#<シンボル>`（フレームワーク・ライブラリ） | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText`, `dep:serde_json#from_str` |
| `lang` | `<言語>#<仕様の節>`（言語・処理系そのもの） | `lang:java#JLS-5.1.3`, `lang:rust#integer-overflow` |

- フレームワーク・処理系の挙動に依存するモデル定義は、`dep`・`lang` ロケータを **必ず** 含める。依存の版が変わると、影響する定義が自動で出る。

## 版の宣言とインベントリ

| ファイル | 内容 |
| --- | --- |
| `trace/upstream.json` | 移植元: repo・variant・release・commit、依存の版、言語・処理系の版 |
| `trace/target.json` | 移植先: ツールチェーン・検証器・依存の版 |
| `trace/source-inventory.json` | 移植元ソースを走査した、ロケータ・ファイル・行範囲・**正規化した本文ハッシュ** |
| `trace/target-inventory.json` | 移植先ソースを走査した、同じ形式の一覧 |
| `trace/manifest.json` | 全ノードと型付きのリンク（生成） |
| `trace/renames.json` | 版上げ時の、ハッシュで判別できない改名の対応（手書き） |
| `trace/checks.json` | `rehash` が実行する決定論的な検査と、それが覆うモデルの定義（手書き。検査を足すたびに登録する） |
| `trace/out-of-scope.json` | 追跡の対象外とするロケータと、根拠の意思決定記録（移植の範囲外としたもの。手書き） |
| `trace/features.json` | 機能ごとの作業項目（側ごと: `{"source": […], "target": […]}`。配列だけなら両側に共通）・ロケータの glob・モデルの名前空間・R 課題の対応表（段階導入の「機能」。手書き） |
| `trace/project.json` | スキルの道具が読む、プロジェクト固有の設定（[プロジェクトの設定](#プロジェクトの設定)。手書き） |

- インベントリの取り方（パーサ・正規化の規則）は言語パックの `locators.md` が定める。
- `dep`・`lang` の項目は、本文ハッシュの代わりに版文字列を持つ。

## 注釈（リンクの正はモデル側）

| 置き場所 | 注釈 | リンク |
| --- | --- | --- |
| `SourceModel`, 移植元の `LangSemantics` | `@[source "<ロケータ>@<検査済みハッシュ>", …]` | ① |
| `TargetModel`, 移植先の `LangSemantics` | `@[target "<ロケータ>@<検査済みハッシュ>", …]` | ② |
| 移植先ソース内のモデルの写し（例: Verus の spec 関数。生成物） | `trace: models <TargetModel の完全名> @<Lean Merkle ハッシュ>`（生成器が書く。書き方は言語パックの `layout.md`） | ②（逆向きの確認） |
| `Abstraction`, `Refinement` | `@[obligation "ABS-NNN" / "REF-NNN"]`。モデル間の対応は定理の型から自動導出する | 内側（証明） |
| 差異の述語・成分 | `@[deviation "D-NNN" / "T-NNN"]` | 内側（差異） |
| ギャップの登録簿 | `@[gap_entry]`（型 `Trace.Gap` の宣言。文書の表はここから生成する） | 内側（差異） |
| ギャップの生じる `Spec`・`SourceModel`・`TargetModel` の定義 | `@[gap "D-NNN" / "T-NNN"]` | 内側（差異の箇所） |
| `Spec` | `@[spec_doc "<仕様文書#アンカー>"]`、`@[no_source "<理由>"]` | 文書 |
| ベクタ | `modelDef`, `upstream`（[conformance.md](conformance.md)） | テスト |

属性の定義と `trace-dump` は [lean/trace-attributes.md](../lang/lean/trace-attributes.md)。

### 検査済みハッシュ

注釈のハッシュは、**その版で、その定義を対象とする決定論的な検査が合格したこと** の記録である。対象となる検査は、ベクタの照合・原典実行・差分の原典実行・検証器の証明・処理系の差分実行である。
現在の値とずれたら「要再検査」とし、検査を失敗させる。

- ハッシュの更新は道具（`rehash`）だけが行う。道具は、対象の定義にかかる決定論的な検査を実行し、すべて合格したときに限って書き換える。合格しなければ、モデルかソースを直す。
- 人や LLM の判断だけでハッシュを書き換えてはならない。
- 対象の定義を覆う検査が 1 つも無ければ、ハッシュは更新できない。先に検査を足す。
- どの検査が合格したかを、ソースの本文ハッシュとモデルの定義の Merkle ハッシュの組に対して manifest に記録する。どちらが変わっても再検査が必要になる。
- 写しのハッシュ（`trace: models`）は、生成器が書く。
- `renames.json` の改名の対応も、`rehash` が新しいロケータについて決定論的な検査を実行し、合格したときに限って受け入れる。
- 追跡の道具自身（パーサと本文の正規化）は、信頼の基盤である。正規化では、文字列リテラルの中身を保つ。

| 境界 | ずれる契機 |
| --- | --- |
| 移植元ソース → `SourceModel` | 移植元の版上げ、依存・処理系の版の変化 |
| 移植先ソース → `TargetModel` | 移植先ソースの変更 |
| `TargetModel` → 移植先ソース内の写し | Lean `TargetModel` の変更 |

### 直接接続の禁止

- 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と、どちらの側にも属さない `Spec` に、移植先の言語のロケータ（移植先の言語パックが定めるすべての kind）を書いてはならない。
- 移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）と移植先ソースに、移植元の言語のロケータ（移植元の言語パックが定めるすべての kind）を書いてはならない。
- 同じ言語が移植元と移植先の両方になる場合（例: Java から Java への移植）は、ロケータにリポジトリの区別を付ける（`java@source:` / `java@target:`）。

### 対象外

- `out-of-scope.json` に載せてよいのは、移植の範囲外とする意思決定がされたものだけである。各項目に、その意思決定記録を書く。
- 移植の範囲外のソースでも、移植元モデルの振る舞いに影響するもの（既知差異の出所になるものなど）は、対象外にしてはならない。例: 画面テンプレートの書式処理。

## 検査

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の `source-inventory` の項目が `@[source]` で覆われず、`out-of-scope.json` にも無い |
| TR-S2 | `@[source]` のハッシュが `source-inventory` と一致しない。または、定義の Merkle ハッシュが最後に検査が合格したときから変わっている（モデル側だけを直した場合も再検査を求める） |
| TR-T1 | `TargetModel` の公開定義に `@[target]` が無い。または `target-inventory` の公開項目が覆われず、対象外でもない。生成した写しは対象外とする（再生成と TR-T2 で確かめる） |
| TR-T2 | `@[target]` のハッシュが `target-inventory` と、写しのハッシュが Lean の Merkle ハッシュと一致しない。または、定義の Merkle ハッシュが最後に検査が合格したときから変わっている |
| TR-P | `SourceModel` の公開操作が、どの R 課題（`Abstraction`）の定理にも、その束（`Machine.Preserves`）にも現れない。または、`TargetModel` の公開操作が、どの R 課題（`Refinement`）の定理にも、その束にも現れない。例外は無い |
| TR-PE | `SourceModel`・`TargetModel` の公開操作が、どの **入口の** R 課題の具体機械（定義の参照の閉包）にも含まれない。入口でない R 課題（ポート実装・内部の計算）だけに現れる操作は、入口からの到達が示されていない |
| TR-D | 次のどれかに当たる。<br>- 登録簿（`@[gap_entry]`）の前提型・観測型の差異（`D-NNN` / `T-NNN`）と `@[deviation]` が 1 対 1 でない<br>- `@[deviation]` が、どの R 課題の定理の型にも現れない<br>- 差異に W 課題が無い<br>- R 課題の定理に、`@[deviation]`・PRE・INV 以外の仮定がある |
| TR-G | R 課題（型の結論が `Machine.Refines` の `@[obligation]` 定理）が、空虚化を防ぐ形と付帯の義務（[architecture.md](architecture.md#空虚化を防ぐ義務)）を備えていない。判定する規則は次の 11 個である。<br>- G0: 追跡属性を付けた定数がモデルの層にある。`Refines` を含む課題の結論が `Refines` か、必要性の形（G9）である<br>- G1: 型が閉じている<br>- G2: 制限の述語が `@[deviation]` の定数そのもので、基底が名前付きの定数<br>- G3: 抽象側の基底（と `Spec` のすべての機械。機能の機械の並置 `Machine.sum` も可）が `ofChoice`/`pure` で、選択の型の葉が `@[nondet]`。自由な選択には `FreeFrame`<br>- G4: 具体側の基底が `Dom` を設定せず、`Concrete.ofMachine` と `Spec` の関数を参照しない<br>- G5: 貼り合わせが `Glue.ofStd` の形で、β・aᵢ・aₒ が `@[std_abs]` の定数そのもの、OJ・OO が `never` か `@[deviation]` の定数そのもの<br>- G6: 同じ課題 ID・同じ機械・貼り合わせの束 `Machine.Preserves`（A preserves B）がある（式全体で照合する）。束の `ch` は、基底が `ofChoice` のときに限り `some (Choice.mk …)` で、`f`・`e₀` は基底のもの、`ce` は `@[std_abs]`。束の `outs`・`outsC` の層は、R 課題の制限の述語と、その層を外した機械（か基底）<br>- G7: `@[std_abs]` が 1 引数の関数で、核の定理（K は等号か `@[kernel]`）のある葉か、許可した構成の合成である。aₒ と `FreeFrame` の射影は核の定理を持つ<br>- G8: `@[deviation]`・`@[env_pre]` に `Nontrivial` がある<br>- G9: R 課題で使う差異の ID ごとに、それを外した R 課題の命題の否定（`¬ Refines`。基底が `ofChoice` なら `¬ (Refines ∧ Pinned)` でもよい）か、必要な差異からの被覆（`Covers`）が、少なくとも 1 つの R 課題についてある。R 課題の基底の `TotalUnder` で使う `@[env_pre]` に、その基底の `¬ TotalUnder A always` がある<br>- GP: 結論が `Machine.Preserves` の `@[obligation]` は、同じ課題 ID の R 課題と同じ機械・貼り合わせを束ねる<br>あわせて、文書と次を照合する。<br>- 環境・自由の種類<br>- 種類 R の課題の形<br>- R 課題ごとの束（OB-P）<br>- 入口の R 課題の `TotalUnder`（`@[env_pre]`）と `EnvWitness`<br>- 「出力のみ」の差異の `StateSafe`<br>- 前提型の差異の影響の登録<br>- `@[deviation]` の登録 |
| TR-K | 次のどれかに当たる。<br>- 前提型・観測型・PRE の外の登録に、`Spec` の定義の `@[gap]` と、具体側（`D-NNN` は `SourceModel`、`T-NNN` は `TargetModel`）の定義の `@[gap]` が無い<br>- モデル外の登録に `@[gap]` か `@[deviation]` がある<br>- PRE の外・未確定の登録に `@[deviation]` がある<br>- `@[deviation]` を使う R 課題が、登録の R 課題に無い<br>あわせて、登録の値と層・docstring・ID の重複を obligation-check（GK）が検査する |
| TR-N | 登録簿の `Spec` の非決定性（`N-NNN`）と `@[nondet]` が 1 対 1 でない |
| TR-V | 適合テストベクタのうち、次のどれかを満たさないものに、外に落ちる理由のラベルが無い。または、ラベルがあるのに外に落ちない。<br>- 具体側の定義域<br>- 具体側の不変条件<br>- 基底の PRE<br>- 制限した PRE（差異の前提）<br>ラベルは差異 ID か `PRE`・`INV` で、付け方は [conformance.md](conformance.md) による |
| TR-X | 直接接続の禁止に違反している |
| TR-R | 存在しない Lean 名・ロケータ・課題 ID・差異 ID への参照がある |
| TR-L1 | `Abstraction`・`Refinement` の R 課題（obligation-check の `refinements`）か W 課題（登録簿の W 課題の ID を `@[obligation]` に持つ定理）が、機能の名前空間（`<層>.<x>`。`x` は `features.json` の `lean`）に直接ない（[lean/rules.md](../lang/lean/rules.md#証明課題の配置)） |
| TR-L2 | `Abstraction`・`Refinement` の機能のモジュール（モジュール名が機能の名前空間のもの）に、`@[obligation]` の定理と、そのモジュールの R 課題の名前で始まる付帯の義務以外の定義がある |
| TR-M1 | `trace/project.json` に `source.mirror` があるとき。`java:`・`sql:` のロケータを持つ移植元のモデルの定義が、そのクラスのモジュール（[lang/java/layout.md](../lang/java/layout.md#移植元として原典を読む)）にない。またはソースツリーの根の外の定義がそれらのロケータを持つ。`shared` のクラスのロケータは除く |
| TR-M2 | （警告）ソースツリーを写すモジュールの直下の宣言の名前が、自分のロケータのメンバーの名前とも、クラスのソース（Java・Mapper の XML）の識別子とも合わない。または、モジュールのクラスがインベントリに無い。構造体の欄・自動生成の名前・`_` を含む小文字の名前（定理など）は対象にしない |
| TR-M3 | メソッドの写し（ロケータ `<Class>#<m>(…)` を持ち、名前が `<m>`。コンストラクタは `new`）の引数の名前に、原典の引数の名前が順に現れない（可変長引数は省いてよい） |
| TR-M4 | （警告）クラスの型（モジュールと同じ名前の構造体）の欄が、原典のクラスの欄に無い |

段階導入（TR-G・TR-N）: 登録簿（非決定性・入口の R 課題・前提型の差異の影響）の各行に、Lean 側を整える作業項目を書く。その項目が完了するまでは「登録簿にあって Lean にまだ無い」ことを警告にし、完了したら失敗にする。

段階導入（TR-K）: 印の不足は、登録の `backlog` の作業項目がすべて完了していれば失敗、そうでなければ警告にする。

段階導入（TR-M）: TR-M1・TR-M3 は、定義の機能の移植元側の作業項目がすべて完了していれば失敗、そうでなければ警告にする。TR-M2・TR-M4 は常に警告で、人が名前を確かめる（モデルだけの補助の定義や、環境から受ける欄がありうるため）。名前は大文字小文字と `_`・`-` を区別せずに比べる。

段階導入（側ごと）: TR-S1・TR-T1・TR-P・TR-PE・TR-D を警告にしてよいのは、該当する機能の、指摘の側の作業項目が完了していない間だけである（[ADR ab9e](../decision/ab9e-adequate-bundle-sum-and-side-staging.md)）。

- 機能の作業項目は、移植元側（`source`）と移植先側（`target`）に分けて書く。
- 移植元側の作業項目で判定する: TR-S1、`SourceModel` の操作の TR-P、`Abstraction` 層と `D-NNN` の TR-D・TR-K。
- 移植先側の作業項目で判定する: TR-T1、`TargetModel` の操作の TR-P、`Refinement` 層と `T-NNN` の TR-D・TR-K。
- 両側の作業項目で判定する: TR-PE（入口からの到達は、入口の機能に依存する）。
- 側の作業項目が無い機能では、その側の指摘は警告にとどまる。
- 移植元側を終えた機能は、移植先側を待たずに、移植元側の指摘が失敗になる。以後の機能の取り込みで、実装済みの移植元側の範囲が壊れれば CI が失敗する。
- 側の完了を宣言する時点で、その機能の、その側の全検査が失敗扱いで通っていなければならない。他の検査は最初から失敗とする。

## 道具

スキルは、追跡と検査の道具を `scripts/` に持つ（使い方は [scripts/README.md](../../../scripts/README.md)）。道具はアプリに依存せず、
プロジェクト固有の値はすべて `trace/project.json` から読む。リポジトリのルートは、作業ディレクトリから上にたどって
`trace/project.json` があるところとする（`--repo <dir>` でも指定できる）。

追跡の CLI `scripts/trace`（Rust）は次のサブコマンドを持つ。言語ごとの部分（パーサ）は言語パックの `locators.md` に従う。

| サブコマンド | 機能 |
| --- | --- |
| `inventory source` / `inventory target` `[--check]` | インベントリの生成 |
| `manifest --dump <trace-dump.json> --obligations <obligation-check.json> [--check]` | manifest と、仕様文書の生成区画（① と ② の 2 本の表、ギャップの表）の生成。`lake exe trace-dump` の出力を取り込む |
| `check --dump … --obligations … [--verbose [--feature <機能>] [--rule <TR-…>]]` | TR 検査（`scripts/ci/check_obligations.py` の結果を TR-G・TR-N として取り込む）。`--verbose` は警告を 1 件ずつ出し、機能・規則で絞り込める |
| `rehash --dump … [--dry-run]` | 決定論的な検査を実行し、合格した定義だけハッシュを更新する |
| `diff --old <file\|git:REV> [--side source\|target] [--json]` | 新旧インベントリの分類（[upgrade.md](../guide/upgrade.md)） |
| `impact --dump … --obligations … [--diff <file\|git:REV>] [--json] [<起点>…]` | 証明グラフに沿った影響一覧と、見直すギャップ |
| `review --dump … [--out <dir>]` | 原典とモデルの対照表（静的な HTML。既定は `build/review/`）。原典のクラスごとに、原典のメンバーと、それを `@[source]` で指す定義を並べ、検査済みハッシュ・ギャップの印・覆われていないメンバーを示す。生成物であり、リポジトリには置かない（CI の artifact にする） |

### プロジェクトの設定

`trace/project.json` は、道具が読むプロジェクト固有の値を集める。言語ごとのロケータの種類と `LangSemantics` の層は、
言語パックの既定から引く（例: `java` → `java`・`prop`・`msg`・`http`・`xml`・`tmpl` と `LangSemantics.Java`）。

| キー | 内容 |
| --- | --- |
| `skill` | スキルの置き場所（`scripts/`・`assets/` の親） |
| `lean.roots` | Lean のモジュールを探すルート（プロジェクトの Lean パッケージと、スキルの `assets/lean`） |
| `languages.source` / `languages.target` | 移植元・移植先の言語パックの名前（例 `["java", "sql"]`・`["rust"]`） |
| `source.root` / `source.sql_dirs` | 移植元ソースの走査のルート（`out-of-scope.json` の glob もここからの相対）と、DDL・シードの SQL を置くディレクトリ |
| `source.mirror` | 任意。移植元のモデルを原典のソースツリーの形に並べる規則（TR-M）。`lean_root`（モデルの層。例 `SourceModel`）、`package_prefix`（モジュールの名前から除くパッケージの接頭辞）、`roots`（ソースツリーを写すモジュールの、層の直下の成分）、`case`（`upper-camel` か `same`）、`shared`（どの定義から引いてもよい横断的な設定のクラス。TR-M1 の根拠にしない） |
| `target.root` / `target.src` / `target.crate` / `target.generated` | 移植先のプロジェクトのルート（TR-X の範囲）、ソースのルート、crate 名、生成した写しのディレクトリ（`src` からの相対） |
| `docs.spec` / `docs.abstraction` / `docs.refinement` / `docs.traceability` | 仕様文書のディレクトリ（「出典:」の範囲）、抽象化・具体化の課題一覧、追跡の文書（生成区画） |
| `docs.spec_lean` | 任意。仕様の散文を書いた `Spec` のモジュール文書の Lean のファイル・ディレクトリ（「出典:」の範囲に加える。[spec-documents.md](../rules/spec-documents.md#モジュール文書に書く)） |
| `book` | 任意。本の設定（`scripts/book/build.py`）: `title`・`language`、`parts`（部の列 `[{title, base, modules}]`。`base` は Lean のルート、`modules` はトップレベルのモジュール名の列で、各 `M` は `<base>/M.lean` と `<base>/M/` の下に当たる。[ADR d2b6](../decision/d2b6-book-parts-and-namespace-toc.md)）か、部の無い本では `roots`（本にする Lean のファイル・ディレクトリ）と `entry`（目次の順を決めるモジュール）、`out`（出力）、`repo_url`（本の外へのリンクの基点）、`refs`（`--check` が行き先を検査する `manifest` と `vectors`）、`okf_check`（アンカーの規則を借りる okf-bundle の道具のパス）、`fold`（任意。目次の折りたたみ `{enable, level}`。mdbook の `output.html.fold`、`level` は最初から開いておく深さ） |
| `docs.decision` / `docs.backlog` | 意思決定記録と作業項目のディレクトリ（作業項目の frontmatter の `id`・`state`。`done` が完了） |
| `conformance` | 適合テストベクタのディレクトリ |

文書の検査（スキル okf-bundle の `.okf.json`）と、意思決定記録・作業項目の検査（スキル work-records の `.work-records.json`）の設定は、それぞれのスキルの設定ファイルに置く。`trace/features.json` の作業項目の ID を work-records に検査させるときは、`.work-records.json` の `id_fields` に `{"file": "trace/features.json", "keys": ["backlog"], "kind": "backlog"}` を書く。

### 手書きのファイルの形

| ファイル | 形 |
| --- | --- |
| `trace/upstream.json` | `{repo, submodule, variant, release, commit, languages: {<名前>: {version, from}}, dependencies: [{coordinate, version, from}]}`。`dep:<coordinate>#…@<version>`・`lang:<名前>#…@<名前>-<version>` の照合に使う |
| `trace/target.json` | `upstream.json` と同じ形の `languages`・`dependencies`（移植先のツールチェーン・検証器・依存） |
| `trace/out-of-scope.json` | `{items: [{path, reason, decision}]}`。`path` は `source.root` からの相対 glob、`decision` は根拠の意思決定記録 |
| `trace/renames.json` | `{renames: [{old, new}]}`（[upgrade.md](../guide/upgrade.md)） |
| `trace/features.json` | `{features: [{name, backlog: [ID], lean: [名前空間], tasks: [R 課題], locators: [glob]}]}`。ロケータは最初に当たった機能に属する。層を書かない名前空間は 4 つの層（`SourceModel`・`Abstraction`・`TargetModel`・`Refinement`）に広げる |
| `trace/checks.json` | `{checks: [{id, description, steps: [{cwd, argv}], covers: {names: [glob], vectors: [glob]}}]}`。各 step の終了コードがすべて 0 なら合格 |

既定の細部（プロジェクトの ADR で変えてよい）:

- 本文ハッシュは、正規化した本文の SHA-256 の先頭 16 桁（Lean の Merkle ハッシュと同じ長さ）とする。
- 正規化は、構文解析器のトークン列（コメントを除く）を空白 1 つでつないだものとする。空白の違いは無視し、文字列リテラルの中身は保つ。
- 注釈の `"<ロケータ>@<ハッシュ>"` は、最後の `@` で分ける（ロケータ自身が `@` を含むことがあるため）。
- 段階導入の「機能」は、機能ごとに作業項目・ロケータの glob・モデルの名前空間・R 課題を並べた対応表で決める。どの機能にも属さない項目は失敗とする（表の抜けで指摘が消えないように）。
- 検査の登録（`checks.json`）は、検査ごとに実行するコマンドと、覆う定義（名前の glob と、ベクタの `modelDef` から参照をたどって届く定義）を持つ。終了コードが 0 なら合格とする。処理系が無くて飛ばした場合は不合格とする。
- `rehash` は、定義のモジュールのファイルの中で、注釈の文字列 `"<ロケータ>@<旧>"` を置き換える（`trace-dump` が定義のモジュールを出力する）。同じ文字列を注釈に持つ定義が同じモジュールに複数あれば、すべてが合格したときだけ置き換える。合格した組は manifest に記録する。
- 仕様文書の「出典:」に書いたロケータは、インベントリになければ失敗とする。private のメソッドはインベントリの単位ではないので、呼び出し元の公開メソッドで書く。
- 「R 課題に現れる」（TR-P・TR-PE）は、R 課題の定理（TR-P では、同じ課題 ID の束 `Machine.Preserves` も）から参照をたどって届く定義の集合に含まれることとする。
- 機能を取り込むときは、`trace check --verbose --feature <機能> [--rule <TR-…>]` で、その機能の未対応の一覧を出す。

生成区画は `<!-- BEGIN GENERATED: source-trace -->` / `<!-- END GENERATED: source-trace -->`（② は `target-trace`）で区切る。ギャップの表は `gaps-known`・`gaps-impact`・`gaps-outside-pre`・`gaps-undetermined`（具体化の課題一覧は前の 2 つ）で区切る。区画の中を手で編集してはならない。
