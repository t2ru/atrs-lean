---
type: Architecture Decision Record
title: "差異の登録簿の棚卸しの手順を方法の文書に置く"
description: "差異の登録簿が実装と原典に合っているかを全範囲で確かめる棚卸しの手順と観点（G1〜G9）を、guide/gap-inventory.md に置く。登録簿の R 課題と課題表の一致の検査は作業項目にする。"
tags: [adr, skill, gap, workflow]
id: "cb1fd0ec-ca23-4733-bbb2-86e9e73a6fac"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 差異の登録簿の棚卸しの手順を方法の文書に置く

## Context and Problem Statement

差異の登録簿は、機能を取り込むたびに項目を足して育つ。TR-D・TR-K・GK は登録簿と Lean の宣言の形の対応を確かめるが、PRE の各成分が項目に結びついていること、説明の文がいまの宣言と原典を正しく述べていること、未着手の機能の違いが漏れなく登録されていること、未着手の R 課題について登録簿と課題表が一致していることは確かめない。
適用先 ATRS の棚卸し（ATRS の ADR f786）では、R 課題の ID の誤り、存在しない欄を指す前提の文、誤った不変条件の名前を注記した PRE の成分、欠けた箇所の印、未登録の原典の振る舞いが見つかった。棚卸しを繰り返せるように、手順と観点をどこに置くかを決める。

## Decision Drivers

* アプリに依存しない手順として、他の適用先でも使えること
* 機械で検出できる取りこぼしは、検査に落とすこと（文章の注意だけで済ませない）
* 判断を要する変更（差異の追加・拡大）で作業を止める既定（[workflow.md](../guide/workflow.md#判断を記録する事項)）と矛盾しないこと

## Considered Options

* 手順と観点を `guide/gap-inventory.md` に置き、検査にできる観点は作業項目にする
* 手順を `guide/workflow.md` の節として書く
* 手順を書かず、検査だけを足す

## Decision Outcome

Chosen option: "手順と観点を `guide/gap-inventory.md` に置き、検査にできる観点は作業項目にする", because 棚卸しは移植の手順の外の点検であり、観点の表が長くなるので、独立した文書のほうが引きやすいからである。workflow.md の節にすると、既定の進め方の文書が点検の詳細で膨らむ。検査だけでは、原典の読み比べ（観点 G1・G8）を機械にできない。

* 観点は G1〜G9（PRE の成分の結びつき、証拠の宣言、箇所の印、述語と欄、R 課題、箇所の参照、文書の引用、原典との突き合わせ、観測の形）とする。
* 判断を要する候補は一件ずつ判断を求め、ライブラリの内部の挙動に拠る候補は原典実行で確かめる作業項目に回す。
* 観点 G5（登録簿の R 課題と課題表の差異の列の一致）は検査にできるので、作業項目 [backlog 937d](../backlog/937d-rtasks-task-table-consistency-check.md) にした。
* [workflow.md](../guide/workflow.md) から参照する。スキルの版を 0.26 にした。

### Consequences

* Good, because 棚卸しを、適用先によらず同じ観点で繰り返せる
* Good, because 観点の表が、検査に落とせる取りこぼしを見つける手がかりになる
* Bad, because 観点 G1・G8 は人やエージェントの読み比べに頼り、一致の根拠にはならない

### Confirmation

* スキル okf-bundle の `okf_check.py` が文書の形とリンクを検査する。観点 G5 は backlog 937d の検査で確かめる。

## More Information

* 来歴: 適用先 ATRS の ADR f786（差異の棚卸し）。
