---
name: okf-bundle
description: "OKF（Open Knowledge Format）v0.2 の Knowledge Bundle として Markdown の文書を管理する方法と道具。frontmatter（YAML の部分集合）・type・index.md・log.md の形、バンドルごとのプロファイルの規則（必須キー・値・必須の節）、索引の網羅、Markdown の相対リンクと見出しアンカーを検査し（okf_check.py）、文書を移すときにリンクとパスの言及を張り直す（docmv.py）。Use when writing or maintaining documents in an OKF bundle (docs/ or a skill's references/docs/), adding/renaming/moving documents, updating index.md or log.md, writing frontmatter, or checking links and anchors. Keywords: OKF, Open Knowledge Format, Knowledge Bundle, frontmatter, index.md, log.md, documentation lint, link check, anchor check, docs move."
compatibility: Python 3（uv で実行。標準ライブラリだけ）と git。
metadata:
  version: "0.2"
---

# okf-bundle: OKF v0.2 のバンドルの管理

Markdown の文書の集まりを **OKF v0.2 の Knowledge Bundle** として保つ。バンドルは、ルートの `index.md`（索引）と `log.md`（変更履歴）、frontmatter を持つ文書からなる。
形とリンクは道具で検査し、人やエージェントの注意に頼らない。

## 使う場面

- バンドル（例: リポジトリの `docs/`、スキルの `references/docs/`）に文書を足す・改める・改名する・廃止する。
- frontmatter を書く。`index.md`・`log.md` を更新する。
- 文書やディレクトリを移し、リンクを張り直す。
- 相対リンクと見出しアンカーの切れを見つける。

## 規則（要約）

詳細は [references/docs/rules/bundle.md](references/docs/rules/bundle.md)。

1. `index.md`・`log.md` 以外の `.md` は、YAML の **部分集合** の frontmatter を持ち、空でない `type` を持つ。
2. `title` は本文の `#` 見出しと同じにし、`title`・`description` はダブルクォートで囲む。`status` は OKF のライフサイクル（`draft` / `stable` / `deprecated`）だけに使う。
3. AI が書いた文書は `generated: {by, at}` を持つ。人のレビューは `verified` に残す。
4. 文書を足す・改名する・廃止するときは、ルートの `index.md`（題名・説明は frontmatter と一致させる）と `log.md`（新しい順の `## YYYY-MM-DD`）を必ず更新する。
5. リンクは相対パスで書き、`/` で始めない。見出しを改めたら、そのアンカーを指すリンクも直す。
6. 文書を移すときは `docmv.py` を使い、手でリンクを直さない。

バンドルごとの規則（パスごとの `type`・必須キー・値・必須の節）は **プロファイル** に書く。プロファイルはリポジトリの設定 `.okf.json` に直接書くか、JSON のファイルにしてそのパスを書く。

## 道具（scripts）

| 道具 | 内容 |
| --- | --- |
| `scripts/okf_check.py` | バンドルの形（OKF の適合条件・プロファイルの規則・索引の網羅）と、Markdown の相対リンク・見出しアンカーの検査。Lean のモジュール文書（mdgen が Markdown にする `/-! … -/`）のリンクと、`.lean` の見出しアンカーも検査できる（設定 `links.lean_roots`）。`--self-test` で違反例（`scripts/fixtures/`）を確かめる |
| `scripts/docmv.py` | バンドルの中でファイル・ディレクトリを移し（`git mv`）、リポジトリの Markdown の相対リンクと、テキストの中のパスの言及を一度に張り直す。`--dry-run` で確かめてから実行する。`--self-test` |

```bash
uv run python -I <okf-bundle>/scripts/okf_check.py              # 違反で終了コード 1
uv run python -I <okf-bundle>/scripts/okf_check.py --self-test
uv run python -I <okf-bundle>/scripts/docmv.py --dry-run --root docs guide/a.md rules/a.md
uv run python -I <okf-bundle>/scripts/docmv.py --self-test
```

`<okf-bundle>` は、このスキルの置き場所である。`okf_check.py` は、作業ディレクトリから上にたどって `.okf.json` があるところをリポジトリのルートとする（`--repo <dir>` でも指定できる）。設定の形は [rules/bundle.md](references/docs/rules/bundle.md#設定) にある。

## 関連するスキル

意思決定記録（ADR）と作業項目（backlog）をバンドルの中に置く場合は、スキル **work-records** が記録の形・ID・参照を扱う。このスキルのプロファイルでは、記録のディレクトリの `type`・必須キー・節の順だけを書く。

## スキルの文書と記録

`references/docs/` は、このスキル自身の OKF のバンドルである（索引 [references/docs/index.md](references/docs/index.md)、変更履歴 [log.md](references/docs/log.md)）。
このスキルの意思決定記録は [references/docs/decision/](references/docs/decision/README.md)、作業項目は [references/docs/backlog/](references/docs/backlog/README.md) に置く。
スキルは他のリポジトリへ持ち出して使う。文書のリンクはスキルのディレクトリの外へ出さない。
