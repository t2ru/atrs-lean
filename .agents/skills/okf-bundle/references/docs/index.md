---
okf_version: "0.2"
---

# Rules

* [OKF のバンドルの書き方と検査](rules/bundle.md) - OKF v0.2 の Knowledge Bundle の形（index.md・log.md・frontmatter・YAML の部分集合）、バンドルごとのプロファイル、リポジトリの設定 .okf.json、okf_check.py の検査と docmv.py による文書の移動。

# Decisions

* [スキルの意思決定記録](decision/README.md) - スキル okf-bundle の意思決定記録（MADR 4.0）の索引。
* [Lean のモジュール文書のリンクと、.lean の見出しアンカーを検査する](decision/75c9-check-links-in-lean-module-docs.md) - okf_check.py が、設定 links.lean_roots の Lean のファイルについて、mdgen が Markdown の地の文にする部分（列 0 から始まる /-! -/ と /- -/）を文書として読み、その中のリンクを L1・L2 で検査する。.lean を指すリンクの見出しアンカーも、同じ地の文の見出しから作って検査する。

# Backlog

* [スキルの作業項目](backlog/README.md) - スキル okf-bundle の作業項目の索引。状態と依存関係。
