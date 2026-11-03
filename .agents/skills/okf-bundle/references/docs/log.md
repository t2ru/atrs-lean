# Directory Update Log

## 2026-11-03
* **Update**: `okf_check.py` が、設定 `links.lean_roots` の Lean のファイルのモジュール文書（mdgen が Markdown の地の文にする部分）のリンクと、`.lean` を指すリンクの見出しアンカーを検査するようにした（[ADR 75c9](decision/75c9-check-links-in-lean-module-docs.md)）。違反例 `scripts/fixtures/lean-docs` を足し、[rules/bundle.md](rules/bundle.md) を改めた。版を 0.2 にした。来歴: 適用先 ATRS の ADR 68a6。

## 2026-11-01
* **Creation**: スキル okf-bundle を作った。版は 0.1。
  * スキル spec-pivot の道具 `scripts/docs/okf_check.py`・`scripts/docs/docmv.py` と違反例 `scripts/ci/fixtures/okf/` を、`scripts/okf_check.py`・`scripts/docmv.py`・`scripts/fixtures/` に移した。
  * 設定を、spec-pivot の `trace/project.json` の `okf` から、リポジトリのルートの `.okf.json` に移した。形は変えていない。
  * 意思決定記録・作業項目の形の検査（A1・B1。プロファイルの `kind`）は、スキル work-records の `ids.py check` に移した。
  * [rules/bundle.md](rules/bundle.md) に、spec-pivot の rules/maintenance.md の「frontmatter」「バンドルの検査」節と、適用先の文書規約の汎用の部分をまとめた。
  * 来歴: スキル spec-pivot の ADR 22b4（道具の元の決定は spec-pivot の ADR 330e・748c）。適用先 ATRS の ADR 625d。
