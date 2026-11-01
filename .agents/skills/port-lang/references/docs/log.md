# Directory Update Log

## 2026-11-01

* **Update**: `LangSemantics.Java` に `String.substring`（`jSubstring`・`jSubstringFrom`。UTF-16 の位置と補助文字の扱いの補題 `charsBeforeUtf16_bmp`）と、`DecimalFormat` の 3 桁区切りの整数の書式（`LangSemantics.Java.DecimalFormat.formatGrouped`）を足した。JVM との突き合わせ表（`Test/LangSemantics/JavaJvm.lean`。生成器 `jvm/JavaTable.java`）に行を足した。スキルの版を 0.15 にした。
  * [lang/java/semantics.md](lang/java/semantics.md#演算名前は仕様文書でも共通に使う) を改めた。
  * 来歴: 適用先 ATRS の空席照会（ATRS の ADR ce36・backlog 0be7）。

## 2026-10-31

* **Creation**: [ADR 6b4b](decision/6b4b-preserves-refines-abstracts.md) で、義務の束 `Machine.Adequate` を廃止し、`Machine.Refines`（B refines A。B メソッドのリファインメント）・`Machine.Preserves`（A preserves B。R 課題の空虚化を防ぐ意味的な義務のすべて。`Refines` を含まない）・`Machine.Abstracts`（A abstracts B = A preserves B ∧ B refines A）に分けた。[ADR ab9e](decision/ab9e-adequate-bundle-sum-and-side-staging.md) を置き換えた（並置と側ごとの段階導入は引き継ぐ）。スキルの版を 0.14 にした。
  * assets: `Machine.Preserves`（`Choice`・`OutLayer`・`OutLayerC`、条件付きの成分 `pinned`・`noFault`・`freeFrame`・`stateSafe`・`stateSafeC`）・`Machine.Abstracts` と、その並置。モジュール `Machine.Adequacy`・`Machine.{Machine,Concrete,Glue,Refines}.Adequacy` を `Machine.Preserves.Pred`・`Machine.{Machine,Glue,Refines}.Preserves`・`Machine.{Machine,Concrete}.Run` に改めた。`Refines.run`・`Refines.complete` は `Abstracts.run_of`・`Abstracts.complete_of` に改めた。
  * 検査: obligation-check の G6（束の `ch`・`outs` の照合）と GP（旧 GA）、`check_obligations.py` の OB-P（旧 OB-A。フィクスチャ `r-without-preserves`）、`scripts/trace` の `preserves`。
  * [architecture.md](spec/architecture.md#空虚化を防ぐ義務)（B との照合、`Preserves`・`Abstracts` の定義、外に残る義務、トップレベルの主定理）、[traceability.md](spec/traceability.md#検査)、[lean/rules.md](lang/lean/rules.md)・[trace-attributes.md](lang/lean/trace-attributes.md)・`SKILL.md` を改めた。
  * 来歴: 適用先 ATRS のオーナーの依頼（ATRS の ADR 91be・backlog cb23）。

* **Creation**: [ADR 1a30](decision/1a30-lean-module-namespace-layout.md) で、Lean の宣言をモジュール名の下に置く規則（NS-1。例外 E1〜E4）と、機能の証明課題を機能のモジュールに置く規則（TR-L1・TR-L2）を定めた（[backlog ce23](backlog/ce23-lean-module-namespace-layout.md)）。スキルの版を 0.13 にした。
  * [lean/rules.md](lang/lean/rules.md#モジュールと名前空間)・[architecture.md](spec/architecture.md#層)・[traceability.md](spec/traceability.md#検査)・[trace-attributes.md](lang/lean/trace-attributes.md)・`scripts/README.md` を改めた。
  * 道具: `Trace.Layout` と `lake exe layout-check`、属性 `@[ns_exception]`、`trace check` の TR-L、改名の道具 `scripts/lean/rename.py`。
  * assets の宣言を書き換えた。型名のモジュール（`LangSemantics.Java.JDouble`・`JLocalDate`・`Machine.Machine`・`Machine.Glue`・`Trace.Gap`）、`Machine.Adequacy`・`Machine.Sum` の型ごとの分割、`Machine.Adequate`、`Machine.Sum.sumPred`、`LangSemantics.Java.DoubleOps`、`Machine.Concrete.ofMachine`（旧 `Machine.toConcrete`）。
  * 来歴: 適用先 ATRS のオーナーの依頼。ATRS の側の書き換えは ATRS の backlog 9ed8 にある。

* **Creation**: [ADR ab9e](decision/ab9e-adequate-bundle-sum-and-side-staging.md) で、義務の束・機械の並置・側ごとの段階導入を決めた。スキルの版を 0.12 にした。
  * `assets/lean/Machine/Adequacy.lean`: 義務の束 `Machine.Adequate` と系 `run_init`・`exists_ok`、`Refines.complete_fun`。`assets/lean/Machine/Sum.lean`（新設）: `Machine.sum`・`Concrete.sum`・`Glue.sum`・`sumPred`、`Refines.sum`・`Adequate.sum`・`Adequate.congrPre`。
  * obligation-check（`assets/lean/Trace/Obligation.lean`）の GA と、G3' の並置。`scripts/ci/check_obligations.py` の OB-A（フィクスチャ `r-without-adequate`）。`scripts/trace` の側ごとの段階導入、TR-P の束の閉包、`check --verbose` の `--feature`・`--rule`。`scripts/docs/ids.py` の側ごとの作業項目。
  * [architecture.md](spec/architecture.md#空虚化を防ぐ義務)（義務の束・トップレベルの主定理）、[traceability.md](spec/traceability.md#検査)（TR-P・TR-G・段階導入・`features.json`）を改めた。
  * 来歴: ATRS の ADR a41d・backlog 76a6。
* **Update**: 文書を性格ごとのディレクトリに分けた（[ADR 748c](decision/748c-skill-docs-category-directories.md)、[backlog 97a7](backlog/97a7-skill-docs-category-directories.md)）。スキルの版を 0.11 にした。
  * 方法の文書を `spec/`（[architecture.md](spec/architecture.md)・[portability.md](spec/portability.md)・[traceability.md](spec/traceability.md)・[conformance.md](spec/conformance.md)・[verification.md](spec/verification.md)。`type: Specification`）、`rules/`（[spec-documents.md](rules/spec-documents.md)・[maintenance.md](rules/maintenance.md)。`Guideline`）、`guide/`（[process.md](guide/process.md)・[workflow.md](guide/workflow.md)・[upgrade.md](guide/upgrade.md)・[adding-a-language.md](guide/adding-a-language.md)。`type: Guide`）に移した。
  * 言語パック `java/`・`sql/`・`rust/`・`lean/` を `lang/` の下に移した。ファイル名と中の構成は変えていない。
  * [index.md](index.md) の節、[maintenance.md](rules/maintenance.md#バンドルの構成) の表、プロファイル `scripts/docs/profiles/port-lang.json` の規則を改めた。
  * 移動とリンクの張り直しの道具 `scripts/docs/docmv.py` を足した（`scripts/README.md`）。スキル・適用先の文書のリンクと、コード・設定の中のパスの言及を、これで張り直した。
* **Creation**: [ADR c08b](decision/c08b-test-namespace-for-skill-asset-tests.md) で、`assets/lean` の検査 `LangSemanticsTest`・`MachineTest`・`ConformanceKitTest`・`TraceTest` を `Test.LangSemantics`・`Test.Machine`・`Test.ConformanceKit`・`Test.Trace`（ディレクトリ `assets/lean/Test/`）に改めた。Lake のライブラリを `Test` の 1 つにし、`scripts/ci/check_lean.py` が `Test` を `Tests` の層として扱うようにした。スキルの版を 0.10 にした。
  * [lean/rules.md](lang/lean/rules.md)・[architecture.md](spec/architecture.md#層)・`SKILL.md`・`scripts/README.md`・言語パックの文書の名前とパスを改めた。
  * 来歴: 適用先 ATRS のオーナーの依頼。
* **Creation**: [ADR 330e](decision/330e-okf-bundle-check-tool.md) で、OKF のバンドルとリンクの検査の道具 `scripts/docs/okf_check.py` を置いた（[backlog a49c](backlog/a49c-okf-bundle-check-tool.md)）。スキルの版を 0.9 にした。
  * このバンドルの規則を `scripts/docs/profiles/port-lang.json` にした。違反例を `scripts/ci/fixtures/okf/` に置いた。
  * [maintenance.md](rules/maintenance.md#バンドルの検査)（検査と YAML の部分集合）・[traceability.md](spec/traceability.md#プロジェクトの設定)（設定の `okf`）・`scripts/README.md` を改めた。
  * 来歴: ATRS の backlog ddbd。ATRS の側の決定は ATRS の ADR 920d にある。
* **Creation**: このバンドル（`references/docs/`）を作った（[ADR 87b9](decision/87b9-skill-docs-as-okf-bundle.md)、[backlog de90](backlog/de90-skill-docs-okf-bundle-and-records.md)）。スキルの版を 0.8 にした（0.7 はギャップの証明の状態 `Trace.Evidence` の追加。ATRS の ADR 6ab4 で入った）。
  * `references/*.md` と言語パック（`java/`・`sql/`・`rust/`・`lean/`）をここへ移し、OKF v0.2 の frontmatter を付けた。方法の文書は `Guideline`、言語パックは `Reference` とした。
  * [index.md](index.md)・log.md・[maintenance.md](rules/maintenance.md)（保守の規則）・[decision/README.md](decision/README.md)・[backlog/README.md](backlog/README.md) を作った。
* **Creation**: ATRS の `docs/` から、スキルの記録を移した。ID とファイル名は変えていない。ATRS へのリンクは来歴の文に直した。
  * 意思決定記録: [ADR 6edf](decision/6edf-lean-package-under-skill-assets-lean.md)、[ADR 0eea](decision/0eea-trace-tooling-unresolved-details.md)、[ADR 9cd9](decision/9cd9-rehash-diff-impact-details.md)、[ADR 0b83](decision/0b83-porting-conditions-and-workflow.md)、[ADR 7fe4](decision/7fe4-move-trace-attributes-to-skill.md)、[ADR edc8](decision/edc8-skill-scripts-and-generic-lean-libraries.md)
  * 作業項目: [backlog 1ae4](backlog/1ae4-machine-refinement-framework.md)、[backlog a936](backlog/a936-lang-semantics-rust.md)。ATRS の backlog be49 への `depends_on` を外した。a936 の完了条件を、適用先に依存しない形にした。
* **Update**: `scripts/docs/ids.py` を改めた。
  * 種類ごとに複数の置き場所を持てるようにした（`ids.kinds` の配列）。
  * 持ち出すバンドルを検査するようにした（`ids.isolated`）。
  * `new --dir` と `move` を足した。
  * あわせて [traceability.md](spec/traceability.md#プロジェクトの設定) と `scripts/README.md` を改めた。
