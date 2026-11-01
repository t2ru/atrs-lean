---
type: Guideline
title: "スキルの文書の保守"
description: "references/docs（OKF v0.2 のバンドル）の構成と置き場所、スキル okf-bundle・work-records による形式と記録の検査、持ち出せること、適用先との分担。"
tags: [documentation, okf, adr, backlog]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:40:00+09:00
---

# スキルの文書の保守

`references/docs/` は Open Knowledge Format (OKF) v0.2 の Knowledge Bundle である。スキルの方法の文書と、スキル自身の意思決定記録・作業項目を置く（[ADR 87b9](../decision/87b9-skill-docs-as-okf-bundle.md)）。
この文書は、スキルを保守する人とエージェントのためのものである。移植の方法を使うだけなら読まなくてよい。

バンドルの形式と検査はスキル **okf-bundle** の rules/bundle.md、意思決定記録と作業項目の書き方・ID・検査はスキル **work-records** の rules/records.md に従う（[ADR 22b4](../decision/22b4-split-okf-and-records-skills.md)）。この文書には、このバンドルに固有の事項だけを書く。

## バンドルの構成

| パス | `type` | 内容 |
| --- | --- | --- |
| [index.md](../index.md) | （予約） | 索引。frontmatter は `okf_version: "0.2"` だけ。本文は `#` 見出しと `* [題名](相対パス) - 説明` の箇条書きだけ |
| [log.md](../log.md) | （予約） | 変更履歴。frontmatter は無し。新しい順に、`## YYYY-MM-DD` 見出しの下に `* **Creation**: …` / `* **Update**: …` / `* **Deprecation**: …` を書く |
| `spec/` | `Specification` | 方法の規範: 層・リファインメントと義務・追跡・ベクタの形式・検証の使い分け・Spec に課す制約 |
| `rules/` | `Guideline` | 書き方の規約: 仕様文書の書き方、このバンドルの保守 |
| `guide/` | `Guide` | 手順と進め方: 移植の手順・作業の進め方・版上げ・言語パックの追加 |
| `lang/<lang>/`（`lang/sql/dialects/<dbms>/` を含む） | `Reference` | 言語パック。言語・処理系ごとの意味論・効果・構成・ロケータ・ベクタの実行・検証器（[adding-a-language.md](../guide/adding-a-language.md)） |
| [decision/](../decision/README.md) | `Architecture Decision Record` | スキルの意思決定記録 |
| [backlog/](../backlog/README.md) | `Backlog Item` | スキルの作業項目 |
| 各ディレクトリの `README.md` | `Overview` | 索引 |

## frontmatter

frontmatter のキー（`type`・`title`・`description`・`tags`・`status`・`generated`・`verified`・`sources`）と YAML の部分集合は、スキル okf-bundle の規則に従う。このバンドルに固有の事項は次のとおり。

- `type` は、上の表の値にする。
- 方法の文書は、規範（守るべき構成・義務・形式）なら `spec/`、書き方の規約なら `rules/`、手順・進め方なら `guide/` に置く。どこにも当たらない種類が増えたら、新しいディレクトリとプロファイルの規則を足す（意思決定記録を残す）。
- 文書を足す・改名する・廃止するときは、`index.md` と `log.md` を必ず更新する。
- 文書を移す・ディレクトリを組み替えるときは、スキル okf-bundle の `scripts/docmv.py` を使う。リポジトリのリンクとパスの言及を一度に張り直す。
- スキルの改訂は `SKILL.md` の `metadata.version` で管理する。版を上げたら `log.md` に書く。

## バンドルの検査

スキル okf-bundle の `scripts/okf_check.py` が、このバンドルの形と Markdown のリンクを検査する。

```bash
uv run python -I <okf-bundle>/scripts/okf_check.py
```

- このバンドルの規則（プロファイル）は `references/okf-profile.json` にある。適用先の `.okf.json` の `bundles` から、そのパスを指す。
- 意思決定記録の `Decision Outcome` には、`Chosen option: "…", because …` か `採択: …` で始まる行を置く。適用先の `.work-records.json` の `outcome_markers` に `採択` を加える。

## 意思決定記録（`decision/`）

書き方・状態・ID はスキル work-records の規則に従う。節見出しは英語、本文は日本語とする。次の判断は記録に残す。

- 方法（層・手順・証明の義務・追跡・版上げ）の変更
- 言語パックの構成の変更
- スキルの道具・Lean のライブラリの構成や設定の形の変更
- スキルの構成の変更

## 作業項目（`backlog/`）

書き方・状態・ID はスキル work-records の規則に従う。状態を変えたら、[backlog/README.md](../backlog/README.md) の表を更新する。

## ID と参照

採番と検査には、スキル work-records の `scripts/ids.py` を使う。

```bash
uv run python -I <work-records>/scripts/ids.py new adr <slug> --dir <skill>/references/docs/decision
uv run python -I <work-records>/scripts/ids.py new backlog <slug> --dir <skill>/references/docs/backlog
uv run python -I <work-records>/scripts/ids.py check
```

- 適用先の `.work-records.json` の `kinds` に、適用先の置き場所とこのバンドルの置き場所（`references/docs/decision`・`references/docs/backlog`）を並べ、ID の空間を 1 つにする。

## 持ち出せること

スキルは他のリポジトリへ持ち出して使う。適用先の `.work-records.json` の `isolated` にこのバンドル（`{"bundle": "<skill>/references/docs", "root": "<skill>"}`）を挙げると、`ids.py check` が検査する（規則はスキル work-records の rules/records.md）。このバンドルに固有の事項は次のとおり。

- 方法の文書と言語パックには、アプリ固有の語（適用先の機能・コード・commit・文書へのリンク）を書かない。
- `decision/`・`backlog/` と、それを要約する `index.md`・`log.md` には **来歴** を書いてよい。適用先で作った記録を移した場合や、適用先の判断をきっかけにした場合が当たる。来歴は、適用先の名前を添えてリンク無しで書く（例: `<適用先の名前> の ADR xxxx`）。
- 他のスキル（okf-bundle・work-records）の文書へもリンクを張らない。名前を文字で書く。

## 適用先との分担

| 判断・作業 | 置き場所 |
| --- | --- |
| アプリに依存しない移植の方法の判断・作業（方法、道具、Lean のライブラリ、スキルの構成） | このバンドルの `decision/`・`backlog/` |
| 文書の管理の道具・規則の判断・作業 | スキル okf-bundle・work-records のバンドル |
| 適用先に固有の判断・作業（ドメインの規則、言語の組、配置、適用の仕方） | 適用先の記録 |
| 両方にかかるもの | 分けて両方に書く。適用先の記録からは、スキルの記録へリンクしてよい |

- 適用先にも影響するスキルの改訂は、適用先にも記録を残す（適用先の規約に従う）。
- 適用先の項目が `depends_on` でスキルの項目を指すのはよい。逆は書かない。
