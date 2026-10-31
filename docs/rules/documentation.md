---
type: Guideline
title: "文書規約"
description: "文書の言語・規範語・出典記法・リンク・OKF v0.2 準拠の規則。"
tags: [rules, documentation, okf]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
---

# 文書規約

## 言語

- 本文は **日本語** で書く（[ADR d845](../decision/d845-record-architecture-decisions-with-madr.md)）。
- 型名・関数名・フィールド名・列挙値・エラーコード・ファイル名・URL は **英語（原典の綴り）** のまま書き、コード書式（`` ` ``）で囲む。
- ATRS の業務用語は原典の日本語を使い、初出時に英語識別子を併記する。対応は [spec/glossary.md](../spec/glossary.md) に集約する。
  - 例: 運賃種別（`FareType`）、搭乗クラス（`BoardingClass`）

## 規範的な語

仕様・規約では RFC 2119 / RFC 8174 に準じ、次の語を太字で使う。

| 語 | 意味 |
| --- | --- |
| **MUST** / **しなければならない** | 絶対的要件 |
| **MUST NOT** / **してはならない** | 絶対的禁止 |
| **SHOULD** / **すべきである** | 正当な理由がある場合のみ逸脱可。逸脱理由を記録する |
| **MAY** / **してもよい** | 任意 |

規範的な語を含まない文は説明（informative）として扱う。

## 出典（移植元ロケータ）の記法

原典を参照するときは、**移植元ロケータ**（スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/docs/traceability.md#ロケータ) と、ATRS が使う種別の一覧 [traceability.md](../spec/traceability.md#方式)）で書く。ロケータは版に依存しない記号的な位置で、道具が検査・解決できる。

```
出典: `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)`
```

- 「出典:」の行のロケータは、移植元のインベントリになければならない（`trace check` の TR-R。[ADR 9cd9](../../.agents/skills/port-lang/references/docs/decision/9cd9-rehash-diff-impact-details.md)）。private のメソッドはインベントリの単位ではないので、呼び出し元の公開メソッドで書き、「（private の `getMultiplicationRatio` を含む）」のように補う。
- 既存の草案にあるパス表記（`atrs-domain/.../service/b0/TicketSharedServiceImpl.java` 等。`...` は定型部分の省略）は、順次ロケータ表記に書き換える。運賃計算・空席照会・予約は書き換え済み（[backlog ffdc](../backlog/ffdc-trace-tooling.md)）。残りは、各機能の backlog で `SourceModel` を書くときに書き換える。
- 追従中の上流の版は `trace/upstream.json` に宣言する。版を更新する場合はスキルの [upgrade.md](../../.agents/skills/port-lang/references/docs/upgrade.md) の手順に従う。
- 原典のコードを長く転載しない。式・条件は仕様の記法で書き直す。

## リンク

- リポジトリ内のリンクは **相対パス** で書く（OKF は `/` 始まりのバンドル相対リンクも認めるが、GitHub 上で解決されないため使わない）。
- ADR は `[ADR xxxx](../decision/xxxx-<slug>.md)`、backlog は `[backlog yyyy](../backlog/yyyy-<slug>.md)` の形で参照する。リンクの文字列は ID の先頭 4 文字とする。リンクを張れない箇所（コードのコメントなど）は `ADR xxxx`・`backlog yyyy` と書く。先頭 4 文字が同じ種類の他の項目と重なる項目は、リンクの無い参照では stem（`ADR xxxx-<slug>`）で書く（[ADR f57e](../decision/f57e-uuid-ids-for-decisions-and-backlog.md)）。
- スキルの ADR・backlog も、同じ形でスキルのバンドルへの相対パスで書く。ATRS の記録と紛らわしいときは「スキルの ADR xxxx」と書く。
- 道具が読む箇所（frontmatter の `id`・`depends_on`・`superseded_by`、`trace/features.json`、登録簿の backlog の列）には ID 全体を書く。参照は `python3 -I .agents/skills/port-lang/scripts/docs/ids.py check` で検査する。
- 仕様節への参照はファイル名＋見出しアンカーで書く（例: `fare-calculation.md#基本運賃`）。

## OKF v0.2

`docs/` は **Open Knowledge Format (OKF) v0.2** の Knowledge Bundle である（[ADR a0f1](../decision/a0f1-documentation-format-okf-v0-2.md)）。
バンドルのルートは `docs/` で、リポジトリ直下の `AGENTS.md`・`CLAUDE.md` はバンドル外である。
スキル port-lang の文書は、別のバンドル [`.agents/skills/port-lang/references/docs/`](../../.agents/skills/port-lang/references/docs/index.md) である（規則はスキルの [maintenance.md](../../.agents/skills/port-lang/references/docs/maintenance.md)）。`docs/` からはリンクで参照してよいが、逆向きのリンクは張らない。

### 予約ファイル

| ファイル | 形式 |
| --- | --- |
| [`docs/index.md`](../index.md) | 文書インデックス。frontmatter は `okf_version: "0.2"` のみ。本文は `#` 見出しと箇条書き `* [題名](相対パス) - 説明` だけで構成する。文書を追加・改名したら **必ず更新する** |
| [`docs/log.md`](../log.md) | 変更履歴。frontmatter なし。新しい順、`## YYYY-MM-DD` 見出しの下に `* **Creation**: …` / `* **Update**: …` / `* **Deprecation**: …` の箇条書き |

`index.md`・`log.md` を概念文書（通常の文書）の名前に使ってはならない。サブディレクトリに `index.md` を置いてもよいが、置いた場合も同じ形式に従う。

### frontmatter

`index.md`・`log.md` 以外の `docs/` 配下の `.md`（`README.md` を含む）は、先頭に YAML frontmatter を持たなければならない。

| キー | 必須 | 内容 |
| --- | --- | --- |
| `type` | **MUST** | 文書種別。下表の値を使う |
| `title` | SHOULD | 題名（本文の `#` 見出しと同じ） |
| `description` | SHOULD | 1 文の要約。`docs/index.md` の説明と一致させる |
| `tags` | SHOULD | 英小文字の配列 |
| `status` | SHOULD | OKF のライフサイクル: `draft` / `stable` / `deprecated`（省略時は `stable`）。**他の意味に使ってはならない** |
| `generated` | AI が書いた場合 MUST | `{by: <producer>/<version>, at: <ISO 8601 オフセット付き>}`（例: `by: claude-code/claude-opus-5-5`） |
| `verified` | 任意 | レビュー記録の配列 `[{by: human:<id>, at: …}]`。人がレビューしたら追加する |
| `sources` | 任意 | 出典の配列 `[{id, resource, title}]`。本文から脚注 `[^id]` で引用してよい |

`title`・`description` の値は YAML として安全なように **常にダブルクォートで囲む**（`[Spec]` などで始まる値はクォートしないと YAML の配列と解釈される）。

| ディレクトリ | `type` | 種別固有のキー |
| --- | --- | --- |
| `decision/` | `Architecture Decision Record` | `id`, `decision_status`, `superseded_by`, `date`, `decision-makers`, `consulted`, `informed`（[decision-records.md](decision-records.md)） |
| `spec/` | `Specification` | `models`（その文書が扱うモデル: `spec`, `source`, `target`）、`spec_role`（`normative` / `meta` / `draft` / `informative`。[port-lang/spec-documents.md](../../.agents/skills/port-lang/references/docs/spec-documents.md#区分)） |
| `rules/` | `Guideline` | — |
| `backlog/` | `Backlog Item` | `id`, `state`, `depends_on`（[backlog.md](backlog.md)） |
| 各ディレクトリの `README.md` | `Overview` | — |

### 来歴と信頼

- AI が文書を作成・更新したら `generated` を更新する。
- 人がレビューしたら `verified` に自分の `human:<id>` を追加する。`verified` に `human:` が無い文書は **未レビュー** として扱い、仕様の根拠にする場合は注意する。
- 来歴の変更（作成・大きな更新・廃止）は [`docs/log.md`](../log.md) に 1 行追記する。

## 書式

- Markdown（CommonMark + GFM 表）。1 ファイル 1 主題。
- 見出しレベルは `#` を 1 つだけ（タイトル）とし、以降 `##` から。
- 表・数式は等幅で読める形を優先する。数式は `floor(x / 100)` のような関数記法で書き、LaTeX は使わない。
- 日付は ISO 8601（`2026-10-29`）。ただし原典の書式仕様を述べる場合は原典の書式（`yyyy/MM/dd`）をそのまま書く。
