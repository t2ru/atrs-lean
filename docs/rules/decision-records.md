---
type: Guideline
title: "意思決定記録（ADR）規約"
description: "ADR（MADR 4.0 + OKF frontmatter）の ATRS での置き場所・命名・状態・テンプレートと作成基準。形式と道具はスキル work-records に従う。"
tags: [rules, adr]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:40:00+09:00
---

# 意思決定記録（ADR）規約

設計上の判断はすべて `docs/decision/` に **MADR 4.0 形式** の ADR として記録する（[ADR d845](../decision/d845-record-architecture-decisions-with-madr.md)）。
ADR の形式（ID・ファイル名・参照・状態・節）と道具は、スキル [work-records](../../.agents/skills/work-records/SKILL.md) の [records.md](../../.agents/skills/work-records/references/docs/rules/records.md) に従う（[ADR 625d](../decision/625d-adopt-okf-bundle-and-work-records-skills.md)）。本書は、ATRS での当てはめと追加の事項を書く。

## ファイル名

```
docs/decision/<ID の先頭 4 文字>-<slug>.md
```

- ID は UUID v4（[ADR f57e](../decision/f57e-uuid-ids-for-decisions-and-backlog.md)）。`uv run python -I .agents/skills/work-records/scripts/ids.py new adr <slug>` が ID とファイル名を出す。
- `<slug>` は決定内容を表す短い句（例: `two-layer-model-java-faithful-and-abstract`）。一度採番したファイルは改名・削除しない。
- 本文での参照の書き方は [documentation.md](documentation.md#リンク)。
- 設定は `.work-records.json`（ADR・backlog の置き場所、持ち出すバンドル、検査の範囲、`trace/features.json` の backlog の欄）。

## スキルの ADR

アプリに依存しない判断は、ATRS の `docs/decision/` ではなく、スキルの `references/docs/decision/` に書く（[ADR 50f9](../decision/50f9-move-skill-records-to-skill-bundle.md)）。

| 判断 | 置き場所 |
| --- | --- |
| 移植の方法、spec-pivot の道具・Lean のライブラリ・構成 | スキル spec-pivot の [`references/docs/decision/`](../../.agents/skills/spec-pivot/references/docs/decision/README.md)（書き方はスキルの [maintenance.md](../../.agents/skills/spec-pivot/references/docs/rules/maintenance.md)） |
| OKF のバンドルの形式・検査の道具 | スキル okf-bundle の [`references/docs/decision/`](../../.agents/skills/okf-bundle/references/docs/decision/README.md) |
| ADR・backlog の形式・ID の道具 | スキル work-records の [`references/docs/decision/`](../../.agents/skills/work-records/references/docs/decision/README.md) |

- 採番は `uv run python -I .agents/skills/work-records/scripts/ids.py new adr <slug> --dir <スキル>/references/docs/decision`。ID の空間は ATRS とスキルで共通である。
- スキルの ADR から ATRS の文書へはリンクを張らない。ATRS の記録は、来歴としてリンク無しで書く（「ATRS の ADR xxxx」）。スキル同士も互いにリンクしない。
- 判断が ATRS にも影響する場合は、ATRS 側にも ADR を書き、スキルの ADR へリンクする（[ADR f4e1](../decision/f4e1-extract-porting-method-as-agent-skill.md)）。
- ATRS とスキルの両方にかかる既存の ADR を分けて移すときは、`ids.py move <stem> <dir>` でリンクを張り直す。

## 状態

状態は frontmatter の `decision_status` に書き、OKF の `status` を対応させる（表はスキル work-records の [records.md](../../.agents/skills/work-records/references/docs/rules/records.md#意思決定記録adr)。[ADR a0f1](../decision/a0f1-documentation-format-okf-v0-2.md)）。

- `accepted` の ADR の決定内容を書き換えてはならない。変更するときは新しい ADR を作り、旧 ADR を `superseded` にする。誤字修正・リンク修正・補足情報の追記は書き換えてよい。
- ADR を追加・置換したら [docs/index.md](../index.md) と [docs/log.md](../log.md) を更新し、`mise run docs:ids`（`ids.py check`）と `mise run docs:okf` を通す。

## テンプレート

雛形はスキル work-records の [assets/templates/adr.md](../../.agents/skills/work-records/assets/templates/adr.md)。ATRS では次のとおり当てはめる。

- frontmatter は OKF v0.2 のキー（[documentation.md](documentation.md#okf-v02)）と MADR のキーを併せ持つ。`generated.at` は `+09:00` のオフセットで書いてよい。
- 節見出しは英語（MADR 準拠）、本文は日本語で書く。`Pros and Cons of the Options` は省いてよい。
- `Decision Outcome` には、`Chosen option: "…", because …` か `採択: …` で始まる行を置く（`.work-records.json` の `outcome_markers`）。
- `Context and Problem Statement` には、必要なら原典の出典（[documentation.md](documentation.md#出典移植元ロケータの記法)）を書く。

## いつ ADR を書くか

次のいずれかに当たるときは **必ず** ADR を書く。

- 仕様（抽象モデル）の振る舞いが Java 原典と異なることになる判断
- 型・数値・文字列・日付などの意味論の選択
- 依存ライブラリ・ツールチェーンの追加や変更
- ディレクトリ構成・モジュール境界の変更
- 規約（`docs/rules/`）の方針変更
- スコープの追加・削除
