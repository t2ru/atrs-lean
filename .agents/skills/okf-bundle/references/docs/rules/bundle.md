---
type: Guideline
title: "OKF のバンドルの書き方と検査"
description: "OKF v0.2 の Knowledge Bundle の形（index.md・log.md・frontmatter・YAML の部分集合）、バンドルごとのプロファイル、リポジトリの設定 .okf.json、okf_check.py の検査と docmv.py による文書の移動。"
tags: [documentation, okf, lint]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# OKF のバンドルの書き方と検査

Open Knowledge Format (OKF) v0.2 の Knowledge Bundle は、ルートの `index.md`・`log.md` と、frontmatter を持つ Markdown の文書からなるディレクトリである。
この文書は、バンドルの書き方と、その検査・保守の道具の使い方を定める。

## バンドルの形

| パス | 形 |
| --- | --- |
| `index.md`（ルート） | 索引。frontmatter は `okf_version: "0.2"` だけ。本文は `#` 見出しと `* [題名](相対パス) - 説明` の箇条書きだけ。バンドルのすべての文書（`index.md`・`log.md` 以外の `.md`）を列挙する |
| `log.md`（ルート） | 変更履歴。frontmatter は無し。`# ` の題名の下に、新しい順に `## YYYY-MM-DD` 見出しを重複なく置き、その下に `* **Creation**: …` / `* **Update**: …` / `* **Deprecation**: …` を書く |
| サブディレクトリの `index.md` | 置いてもよい。置いた場合は同じ形にする（frontmatter は持たない） |
| 他の `.md`（`README.md` を含む） | frontmatter を持つ文書 |

- `index.md`・`log.md` を、通常の文書の名前に使わない。
- 文書を足す・改名する・廃止するときは、`index.md` と `log.md` を必ず更新する。

## frontmatter

| キー | 必須 | 内容 |
| --- | --- | --- |
| `type` | MUST | 文書の種類。値はプロファイルで決める |
| `title` | SHOULD | 本文の `#` 見出しと同じ。ダブルクォートで囲む |
| `description` | SHOULD | 1 文の要約。`index.md` の説明と一致させる。ダブルクォートで囲む |
| `tags` | SHOULD | 英小文字の配列 |
| `status` | SHOULD | OKF のライフサイクル（`draft` / `stable` / `deprecated`。省略は `stable`）。他の意味に使わない |
| `generated` | AI が書いた場合 MUST | `{by: <producer>/<version>, at: <ISO 8601 オフセット付き>}` |
| `verified` | 任意 | 人のレビューの記録 `[{by: human:<id>, at: …}]` |
| `sources` | 任意 | 出典 `[{id, resource, title}]`。本文から脚注 `[^id]` で引く |

- `title`・`description` を引用符で囲むのは、`[`・`:` などで始まる値を YAML が別の型に読むのを避けるためである。
- AI が文書を作成・更新したら `generated` を更新する。`verified` に `human:` の無い文書は、未レビューとして扱う。

### YAML の部分集合

frontmatter は、次の部分集合だけで書く。部分集合の外の書き方は、YAML として正しくても違反とする（道具を標準ライブラリだけで動かすため）。

- ブロックのマッピング（`key: value`。キーは英数字・`_`・`-`）と、ブロックの列（`- value`、`- key: value`）。字下げは空白（タブ不可）。列は親のキーより深く字下げする。
- スカラ: ダブルクォート（`\"`・`\\`・`\n`・`\t`・`\uXXXX`）、シングルクォート、1 行のプレーン（`: ` を含まず、指示子で始まらない）。`null`・`~`・`true`・`false`・整数は型付きで読む。
- 要素がスカラだけのフローの列 `[a, "b"]`。行全体のコメント `# …` と、値の後の ` # …`。
- 使わないもの: フローのマッピング `{…}`、ブロックのスカラ `|`・`>`、複数行のプレーン、アンカー・別名・タグ、キーの重複、複数文書。

## リンク

- リポジトリの中へのリンクは相対パスで書く。`/` で始まるリンク（OKF のバンドル相対）は、GitHub などで解決されないため使わない（設定 `links.absolute` で許せる）。
- 見出しアンカーは GitHub の規則で作る（英字は小文字に、空白は `-` に、記号は除く）。見出しを改めるときは、そのアンカーを指すリンクも直す。
- 他のリポジトリへ持ち出すバンドル（例: スキル）からは、持ち出す範囲の外へリンクを張らない。外の文書は、名前を文字で書く。

## プロファイル

プロファイルは、バンドルの規則を JSON で書いたものである。

| キー | 内容 |
| --- | --- |
| `okf_version` | true なら、ルートの `index.md` の frontmatter が `okf_version: "0.2"` であることを確かめる |
| `index_complete` | true なら、ルートの `index.md` がすべての文書を列挙し、題名・説明が frontmatter と一致することを確かめる |
| `common` | すべての文書に課す規則（下の規則のキーのうち `required`・`quoted`・`enum`・`title_heading`） |
| `rules` | パスごとの規則の列。`match` はバンドルのルートからの glob（`*`・`?`・`**/`） |

規則のキー:

| キー | 内容 |
| --- | --- |
| `match` | 当てはめるパス |
| `type` | `type` の値 |
| `required` | 必須のキー |
| `quoted` | ダブルクォートで囲むキー |
| `enum` | キーごとの許される値 `{key: [値...]}` |
| `title_heading` | `#` 見出しが 1 つで、`title` と一致する |
| `sections` | 必須の `##` 節（この順。間に別の節を置いてよい） |

最初に当たった規則を使う。`rules` があるのに、どの規則にも当たらない文書は違反（K1）とする。`common` は、規則に当たった文書に課す。

## 設定

リポジトリのルートに `.okf.json` を置く。道具は、作業ディレクトリから上にたどって `.okf.json` があるところをリポジトリのルートとする。

```json
{
  "bundles": [
    {"root": "docs", "profile": {"okf_version": true, "index_complete": true, "rules": [{"match": "**/README.md", "type": "Overview"}]}},
    {"root": ".agents/skills/<skill>/references/docs", "profile": ".agents/skills/<skill>/references/okf-profile.json"}
  ],
  "links": {"roots": ["AGENTS.md", "docs", ".agents"], "lean_roots": ["lean/Spec"], "skip": [], "absolute": false},
  "skip": [".agents/skills/okf-bundle/scripts/fixtures/"]
}
```

| キー | 内容 |
| --- | --- |
| `bundles` | 検査するバンドルの列 `[{root, profile}]`。`profile` はプロファイルか、その JSON のパス（リポジトリのルートから） |
| `links.roots` | リンクを検査する Markdown の範囲（ファイルかディレクトリ） |
| `links.lean_roots` | リンクを検査する Lean のファイルの範囲（ファイルかディレクトリ。任意）。Lean のファイルでは、mdgen が Markdown の地の文にする部分（列 0 から始まる `/-! … -/` と `/- … -/`。`/-- … -/` の文書コメントは除く）だけを文書として読む |
| `links.skip` | リンクの検査から外すパスの接頭辞 |
| `links.absolute` | `/` で始まるリンクを許すか |
| `skip` | すべての検査から外すパスの接頭辞（例: 道具の違反例） |

スキルのバンドルの規則は、スキルの中の JSON（例: `references/okf-profile.json`）に置き、適用先の `.okf.json` からそのパスを指す。

## 検査

`scripts/okf_check.py` が検査する。違反はすべて失敗扱いで、終了コード 1 を返す。

| 符号 | 内容 |
| --- | --- |
| F1 | `index.md`・`log.md` 以外の `.md` に frontmatter が無い、または YAML の部分集合として読めない |
| F2 | 空でない文字列の `type` が無い |
| R1 | `index.md` の形 |
| R2 | `log.md` の形 |
| K1 | `type` が規則の値と違う |
| K2 | 規則の必須キーが無い |
| K3 | キーの値が不正（`status`・`generated`・`verified`・`sources`・`tags` の形、規則の `enum`） |
| K4 | `quoted` のキーがダブルクォートで囲まれていない |
| H1 | `#` 見出しが 1 つでない、または `title` と違う |
| S1 | 必須の節が無い、または順序が違う |
| I1 | ルートの `index.md` が文書を列挙していない |
| I2 | `index.md` の題名・説明が、文書の `title`・`description` と違う |
| L1 | 相対リンクの指す先が無い |
| L2 | 見出しアンカーが、指す Markdown（または Lean のファイルの、上の地の文）に無い |
| L3 | `/` で始まるリンク（`links.absolute` が false のとき） |

コードブロックとインラインのコードの中は、リンク・見出しとして扱わない。
`.lean` を指すリンクの見出しアンカーは、そのファイルの地の文（`links.lean_roots` と同じ読み方）の見出しから作る。Lean のファイルを mdgen と mdbook で本にするときも、同じアンカーになる。

`--self-test` は、YAML の部分集合の読み取り、アンカーの規則、`scripts/fixtures/` の例（違反なしの `ok`、各符号の違反を含む `violations`、Lean のファイルのリンクとアンカーの `lean-docs`）を確かめる。検査を足すときは、違反例も足す。

## 文書の移動

文書やディレクトリを移すときは、`scripts/docmv.py` を使う。

```bash
uv run python -I <okf-bundle>/scripts/docmv.py --dry-run --root <bundle> <old> <new> [<old> <new> ...]
```

- `<old>`・`<new>` は `--root`（バンドルのルート。リポジトリのルートからの相対）からの相対パスである。ディレクトリは、その下のファイルに展開する。
- リポジトリの Markdown の相対リンク（`.md` のファイルと、`.lean` のファイルのモジュール文書。`okf_check.py` がリンクを検査する範囲と同じ）を張り直し、テキストの中の `<バンドルの末尾 2 成分>/<old>` の形の言及も直す。コードブロック・インラインのコードの中のリンクは張り直さない。
- 最後に、リンクの外に残った相対パスの言及を表示する。文脈で意味が決まるので、手で確かめる。
- 移した後は `okf_check.py` を通す。
