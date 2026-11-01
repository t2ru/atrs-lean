---
type: Architecture Decision Record
title: "PR は draft で作り、人間のレビューを求める段で ready にする"
description: "自分で作ったブランチの PR は draft で作成し、作業が終わって確認と CI が通り、作成者の側で残る作業が無くなって人間にレビューを求める段になったら、作成者が draft から ready for review に変える。レビューで大きな作業が差し戻されたら draft に戻してよい。マージはプロジェクトオーナーが行う。"
tags: [adr, rules, git, pull-request, review]
id: "8bb705f3-5415-417e-90ae-3b52b040e905"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:00:00+09:00
---

# PR は draft で作り、人間のレビューを求める段で ready にする

## Context and Problem Statement

[version-control.md](../rules/version-control.md) は、自分で作ったブランチから PR を作成してよいと定めるだけで、PR の draft と ready for review の使い分けを定めていなかった。AI エージェントは作業環境の指示で PR を draft で作るが、いつ ready にするかが決まっていないため、作業の途中の PR と、人間のレビューを待つ PR との区別が GitHub の上で付かない。どの時点で人間にレビューを求めるかを、PR の状態で示す規則が要る。

## Decision Drivers

* 人間がレビューすべき PR を、PR の一覧だけで見分けられること（プロジェクトオーナーの指示）
* エージェントの作業環境が PR を draft で作ることと矛盾しないこと
* レビューの依頼の時点を、作業の完了の定義（[backlog.md](../rules/backlog.md#完了の定義definition-of-done)・[コミット前の確認](../rules/version-control.md#コミット前の確認)）と結びつけること

## Considered Options

* PR を draft で作り、人間のレビューを求める段で ready for review に変える
* PR を最初から ready for review で作る
* PR は状態を変えず、コメントやラベルでレビューを依頼する

## Decision Outcome

Chosen option: "PR を draft で作り、人間のレビューを求める段で ready for review に変える", because GitHub の PR の状態そのものがレビューの依頼の印になり、一覧・通知・フィルタでそのまま見分けられるからである。最初から ready で作ると途中の PR と区別が付かず、コメントやラベルは付け忘れと付け外しの手間が増える。

* PR は draft で作成する（人間・AI エージェントとも）。
* 次のすべてを満たしたら、人間にレビューを求める段とし、PR の作成者が draft から ready for review に変える。
  * 依頼された作業、または backlog 項目の完了条件を満たした（[「一通りの作業」](../rules/version-control.md#一通りの作業とは)）。
  * [コミット前の確認](../rules/version-control.md#コミット前の確認)をすべて通し、push 済みで、CI が通っている。
  * 作成者の側で残る作業が無い。人間の判断を待つ事項や未完了の事項は、PR の説明に書いたうえで ready にしてよい。
* レビューで大きな作業の追加・やり直しを求められたら、draft に戻してよい。その作業を終えたら、同じ条件で再び ready にする。
* ready への変更はレビューとマージの依頼であり、マージはこれまでどおりプロジェクトオーナーが行う。

### Consequences

* Good, because 人間がレビューすべき PR が GitHub の状態だけで分かる
* Good, because レビューの依頼の時点が、完了の定義と CI の結果に結びつく
* Bad, because 作成者は CI の結果を待ってから状態を変える手間がある

### Confirmation

* オーナーが PR を見るとき、ready for review の PR が上の条件を満たしていることを確かめる。機械の検査は置かない。

## More Information

* [version-control.md](../rules/version-control.md#原則) に規則を置いた。
