---
type: Guideline
title: "意思決定記録（ADR）規約"
description: "ADR（MADR 4.0 + OKF frontmatter）の命名・状態・テンプレート・作成基準。"
tags: [rules, adr]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# 意思決定記録（ADR）規約

設計上の判断はすべて `docs/decision/` に **MADR 4.0 形式** の ADR として記録する（[ADR d845](../decision/d845-record-architecture-decisions-with-madr.md)）。

## ファイル名

```
docs/decision/<ID の先頭 4 文字>-<slug>.md
```

- ID は UUID v4（小文字 16 進、ハイフン付きの 36 文字）。frontmatter の `id` に書く。`uv run python -I .agents/skills/spec-pivot/scripts/docs/ids.py new adr <slug>` が ID とファイル名を出す（[ADR f57e](../decision/f57e-uuid-ids-for-decisions-and-backlog.md)）。
- ファイル名の先頭は ID の先頭 4 文字。他の ADR と重なってもよい（slug で区別する）。
- `<slug>` は英小文字・数字・ハイフンのみ。決定内容を表す短い句（例: `two-layer-model-java-faithful-and-abstract`）。
- 一度採番したファイルは **改名・削除しない**。不要になった ADR は状態を変更する。
- 本文での参照の書き方は [documentation.md](documentation.md#リンク)。ID 全体を書く箇所（`superseded_by` など）と先頭 4 文字を書く箇所を区別する。
- 作成の順序はファイル名から分からない。`date` で追う。

## スキルの ADR

アプリに依存しない判断（移植の方法、スキルの道具・Lean のライブラリ・構成）は、ATRS の `docs/decision/` ではなく、スキル spec-pivot の [`references/docs/decision/`](../../.agents/skills/spec-pivot/references/docs/decision/README.md) に書く（[ADR 50f9](../decision/50f9-move-skill-records-to-skill-bundle.md)）。書き方はスキルの [maintenance.md](../../.agents/skills/spec-pivot/references/docs/rules/maintenance.md) に従う。

- 採番は `uv run python -I .agents/skills/spec-pivot/scripts/docs/ids.py new adr <slug> --dir .agents/skills/spec-pivot/references/docs/decision`。ID の空間は ATRS と共通である。
- スキルの ADR から ATRS の文書へはリンクを張らない。ATRS の記録は、来歴としてリンク無しで書く（「ATRS の ADR xxxx」）。
- 判断が ATRS にも影響する場合は、ATRS 側にも ADR を書き、スキルの ADR へリンクする（[ADR f4e1](../decision/f4e1-extract-porting-method-as-agent-skill.md)）。
- ATRS とスキルの両方にかかる既存の ADR を分けて移すときは、`ids.py move <stem> <dir>` でリンクを張り直す。

## 状態

MADR の状態は frontmatter の **`decision_status`** に書く。OKF の `status` キーは文書のライフサイクルに予約されているため、MADR の値を書いてはならない（[ADR a0f1](../decision/a0f1-documentation-format-okf-v0-2.md)）。

| `decision_status` | 意味 | 遷移先 | OKF `status` |
| --- | --- | --- | --- |
| `proposed` | 提案中。実装はこれに依存してはならない | `accepted`, `rejected` | `draft` |
| `accepted` | 採択済み。規範的 | `deprecated`, `superseded` | `stable` |
| `rejected` | 不採択。記録として残す | — | `deprecated` |
| `deprecated` | 廃止。代替なし | — | `deprecated` |
| `superseded` | 後継 ADR に置換された。`superseded_by: "<後継の ID>"` を併記する | — | `deprecated` |

- `accepted` の ADR の **決定内容** を書き換えてはならない。変更するときは新しい ADR を作り、旧 ADR を `decision_status: superseded` / `superseded_by: "<新 ADR の ID>"` / `status: deprecated` にし、新 ADR の「More Information」に旧 ADR へのリンクを書く。
- 誤字修正・リンク修正・補足情報の追記は書き換えてよい。
- ADR を追加・置換したら [docs/index.md](../index.md) と [docs/log.md](../log.md) を更新し、`uv run python -I .agents/skills/spec-pivot/scripts/docs/ids.py check` を通す。

## テンプレート

frontmatter は OKF v0.2 のキー（[documentation.md](documentation.md#okf-v02)）と MADR のキーを併せ持つ。
節見出しは英語（MADR 準拠）、本文は日本語で書く。
`Considered Options` は最低 2 つ、`Decision Outcome` には採択した選択肢と理由を書く。`Decision Outcome` には、`Chosen option: "…", because …` か `採択: …` で始まる行を置く。`Pros and Cons of the Options` は省いてよい。節と状態の対応は `okf_check.py` が検査する（[documentation.md](documentation.md#検査)）。

```markdown
---
type: Architecture Decision Record
title: "<決定を表す短い題名>"
description: "<1 文の要約>"
tags: [adr, <分野>]
id: "<UUID v4>"
status: draft
decision_status: proposed
date: YYYY-MM-DD
decision-makers: <名前またはロール>
consulted: <任意>
informed: <任意>
generated:
  by: <producer>/<version>
  at: YYYY-MM-DDThh:mm:ss+09:00
sources:
  - id: <任意の ID>
    resource: <URL またはパス>
---

# <決定を表す短い題名>

## Context and Problem Statement

<背景と問題。2〜5 文。必要なら原典の出典を書く>

## Decision Drivers

* <判断基準 1>
* <判断基準 2>

## Considered Options

* <選択肢 1>
* <選択肢 2>

## Decision Outcome

Chosen option: "<選択肢 1>", because <理由>.

### Consequences

* Good, because <良い影響>
* Bad, because <悪い影響>

### Confirmation

<この決定が守られていることをどう確認するか（レビュー、テスト、CI、証明など）>

## Pros and Cons of the Options

### <選択肢 1>

* Good, because …
* Bad, because …

### <選択肢 2>

* Good, because …
* Bad, because …

## More Information

<関連 ADR、spec、backlog、外部資料へのリンク>
```

## いつ ADR を書くか

次のいずれかに当たるときは **必ず** ADR を書く。

- 仕様（抽象モデル）の振る舞いが Java 原典と異なることになる判断
- 型・数値・文字列・日付などの意味論の選択
- 依存ライブラリ・ツールチェーンの追加や変更
- ディレクトリ構成・モジュール境界の変更
- 規約（`docs/rules/`）の方針変更
- スコープの追加・削除
