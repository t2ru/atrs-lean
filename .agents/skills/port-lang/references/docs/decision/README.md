---
type: Overview
title: "スキルの意思決定記録"
description: "スキル port-lang の意思決定記録（MADR 4.0）の索引。"
tags: [adr, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
---

# スキルの意思決定記録

書き方は [maintenance.md](../rules/maintenance.md#意思決定記録decision)。並びは日付の順。

| ID | 題名 | decision_status | 日付 |
| --- | --- | --- | --- |
| 6edf | [スキル port-lang の Lean パッケージを assets/lean/ に置く](6edf-lean-package-under-skill-assets-lean.md) | accepted | 2026-10-30 |
| 0eea | [追跡の道具の未確定事項（本文ハッシュ・正規化・ロケータの細部・機能と backlog の対応）を決める](0eea-trace-tooling-unresolved-details.md) | accepted | 2026-10-30 |
| 9cd9 | [rehash・diff・impact の細部（検査の登録・注釈の書き換え・改名・出典の検査）を決める](9cd9-rehash-diff-impact-details.md) | accepted | 2026-10-31 |
| 0b83 | [移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う](0b83-porting-conditions-and-workflow.md) | accepted | 2026-10-31 |
| 7fe4 | [追跡属性の仕組み（Trace）をスキル port-lang の assets に移す](7fe4-move-trace-attributes-to-skill.md) | accepted | 2026-10-31 |
| edc8 | [アプリに依存しない道具と Lean のライブラリをスキル port-lang へ移し、ATRS 固有の値を trace/project.json に集める](edc8-skill-scripts-and-generic-lean-libraries.md) | accepted | 2026-10-31 |
| 87b9 | [スキルの文書を references/docs/ の OKF バンドルにし、スキルの決定と作業項目をスキルで持つ](87b9-skill-docs-as-okf-bundle.md) | accepted | 2026-10-31 |
| 330e | [OKF バンドルとリンクの検査の道具 okf_check.py を置き、規則を設定のプロファイルで与える](330e-okf-bundle-check-tool.md) | accepted | 2026-10-31 |
| 748c | [スキルの文書を spec/・rules/・guide/・lang/ に分け、移動の道具 docmv.py を置く](748c-skill-docs-category-directories.md) | accepted | 2026-10-31 |
