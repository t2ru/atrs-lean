---
type: Backlog Item
title: "登録簿の R 課題と課題表の差異の列の一致を検査する"
description: "trace check に、ギャップの登録簿の rTasks と、課題表（証明課題の一覧）の各 R 課題の「差異」の列とが一致することの検査を足す。"
tags: [backlog, trace, tooling, gap]
id: "937d383e-b73e-4e03-8da7-83bae8f653c9"
state: todo
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 登録簿の R 課題と課題表の差異の列の一致を検査する

## 目的

TR-K は「差異の述語を使う R 課題が、登録簿のその差異の R 課題（`rTasks`）に挙がっていること」の向きだけを検査する。未着手の R 課題は述語をまだ使わないので、登録簿の `rTasks` と、課題表（手で書く証明課題の一覧）の「差異」の列が食い違っても、どの検査も気づかない。差異の棚卸しで、R 課題の ID の誤り（採番ポートの課題を指していた）がこの経路で残っていた（来歴: 適用先 ATRS の ADR f786）。

## 範囲

- `trace check` に、登録簿の各 `D-NNN`・`T-NNN` の `rTasks` と、抽象化・具体化の文書の課題表の R 行の差異の列とが、両向きに一致することの検査を足す（規則の名前は TR-K の一部か、新しい TR-*）
- 課題表の読み取り（表の見出し `ID`・`種類`・`差異`）と、読めない表の扱い
- `scripts/trace` の自己検査（正例と、片方にだけある ID の違反例）
- [spec/traceability.md](../spec/traceability.md) と [lang/lean/trace-attributes.md](../lang/lean/trace-attributes.md) の検査の節の更新

## 対象外

- 課題表の生成（表は手で書く）
- PRE の外の項目（R 課題を持たない）

## 完了条件

- [ ] 片方にだけある R 課題の ID を、`trace check` が誤りとして報告する
- [ ] 自己検査が正例と違反例を確かめる
- [ ] 文書の検査の節が更新されている

## 参照

- [ADR cb1f](../decision/cb1f-gap-inventory-procedure.md)
- [spec/traceability.md](../spec/traceability.md)
