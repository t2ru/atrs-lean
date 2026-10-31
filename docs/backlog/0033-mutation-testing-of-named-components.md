---
type: Backlog Item
title: "名前付きの成分の変異テスト"
description: "ADR 0042 の B。@[deviation]・@[env_pre]・FreeFrame の射影を仕様を強める向きに変異させて R 課題を作り直し、生き残った変異体（成分が必要以上に広い兆候）を処置の記録と突き合わせる道具を作る。"
tags: [backlog, lean, refinement, tooling]
id: "0033"
state: todo
depends_on: ["0005", "0032"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:40:00+09:00
---

# 名前付きの成分の変異テスト

## 目的

名前付きの成分の **広さ**（差異・環境の前提・自由な選択の枠が、必要以上に広くないこと）は、[ADR 0042](../decision/0042-vacuity-literature-necessity-and-mutation.md) の必要性（G9）でも確かめられない。
IronSpec・mCoq の仕様の変異テストで、広すぎる成分の兆候を機械的に見つける。
生き残った変異体の処置を記録し、処置の無い変異体を失敗とする。

最初の機能の R 課題（[backlog 0005](0005-fare-abstraction-proofs.md)）ができるまでは、変異させる対象が無いので着手しない。

## 範囲

- 道具（置き場所は未確定。`tools/ci/` か `tools/mutation/`）
  - 変異体の生成: `@[deviation]`・`@[env_pre]`・`FreeFrame` の射影の本体を、仕様を強める向きに変える
    - 前提型の差異: 前提を広げる（除外を狭める）
    - 観測型の差異: 関係を狭める
    - 環境の前提: 前提を広げる
  - 第 1 パス: 弱める変異体と同値な変異体を、自動の証明で除く
  - 第 2 パス: R 課題とその付帯の定理を作り直す。通ったものを、生き残った変異体とする
  - 処置の記録との突き合わせ
- 変異の演算子
  - 成分の除去（G9 が確かめない、複合の R 課題での冗長な使用を見つける）
  - 連言の除去
  - 境界の比較演算子の置換
  - 定数の置換
- CI への組み込み

## 未確定事項（実装のときに ADR で決める）

- 変異の演算子の集合と、Lean の構文の上で変異させるか、式の上で変異させるか
- 同値・弱化の判定に使う自動の証明（`decide`・`simp`・`omega`）と、判定できないときの扱い
- 処置の記録の形式（例: `trace/mutants.json`）と、処置の種類（狭める／理由を付けて受け入れる）
- 実行の頻度（毎回か、定期か）と、費用の上限

## 完了条件

- [ ] 道具が、フィクスチャの広すぎる差異の変異体を生き残りとして報告し、必要十分な差異の変異体をすべて殺すことを確かめた
- [ ] 運賃計算の R 課題（ABS-001・ABS-002・ABS-004）で実行し、生き残った変異体をすべて処置した
- [ ] 未確定事項を ADR に記した
- [ ] [assurance.md](../spec/assurance.md) の「名前付きの成分の広さ」の手段を更新した

## 参照

- [ADR 0042](../decision/0042-vacuity-literature-necessity-and-mutation.md)
- [backlog 0032](0032-component-necessity-witness.md)
