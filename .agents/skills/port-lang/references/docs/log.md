# Directory Update Log

## 2026-10-31

* **Creation**: [ADR 330e](decision/330e-okf-bundle-check-tool.md) で、OKF のバンドルとリンクの検査の道具 `scripts/docs/okf_check.py` を置いた（[backlog a49c](backlog/a49c-okf-bundle-check-tool.md)）。スキルの版を 0.9 にした。
  * このバンドルの規則を `scripts/docs/profiles/port-lang.json` にした。違反例を `scripts/ci/fixtures/okf/` に置いた。
  * [maintenance.md](maintenance.md#バンドルの検査)（検査と YAML の部分集合）・[traceability.md](traceability.md#プロジェクトの設定)（設定の `okf`）・`scripts/README.md` を改めた。
  * 来歴: ATRS の backlog ddbd。ATRS の側の決定は ATRS の ADR 920d にある。
* **Creation**: このバンドル（`references/docs/`）を作った（[ADR 87b9](decision/87b9-skill-docs-as-okf-bundle.md)、[backlog de90](backlog/de90-skill-docs-okf-bundle-and-records.md)）。スキルの版を 0.8 にした（0.7 はギャップの証明の状態 `Trace.Evidence` の追加。ATRS の ADR 6ab4 で入った）。
  * `references/*.md` と言語パック（`java/`・`sql/`・`rust/`・`lean/`）をここへ移し、OKF v0.2 の frontmatter を付けた。方法の文書は `Guideline`、言語パックは `Reference` とした。
  * [index.md](index.md)・log.md・[maintenance.md](maintenance.md)（保守の規則）・[decision/README.md](decision/README.md)・[backlog/README.md](backlog/README.md) を作った。
* **Creation**: ATRS の `docs/` から、スキルの記録を移した。ID とファイル名は変えていない。ATRS へのリンクは来歴の文に直した。
  * 意思決定記録: [ADR 6edf](decision/6edf-lean-package-under-skill-assets-lean.md)、[ADR 0eea](decision/0eea-trace-tooling-unresolved-details.md)、[ADR 9cd9](decision/9cd9-rehash-diff-impact-details.md)、[ADR 0b83](decision/0b83-porting-conditions-and-workflow.md)、[ADR 7fe4](decision/7fe4-move-trace-attributes-to-skill.md)、[ADR edc8](decision/edc8-skill-scripts-and-generic-lean-libraries.md)
  * 作業項目: [backlog 1ae4](backlog/1ae4-machine-refinement-framework.md)、[backlog a936](backlog/a936-lang-semantics-rust.md)。ATRS の backlog be49 への `depends_on` を外した。a936 の完了条件を、適用先に依存しない形にした。
* **Update**: `scripts/docs/ids.py` を改めた。
  * 種類ごとに複数の置き場所を持てるようにした（`ids.kinds` の配列）。
  * 持ち出すバンドルを検査するようにした（`ids.isolated`）。
  * `new --dir` と `move` を足した。
  * あわせて [traceability.md](traceability.md#プロジェクトの設定) と `scripts/README.md` を改めた。
