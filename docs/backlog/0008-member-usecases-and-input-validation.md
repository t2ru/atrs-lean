---
type: Backlog Item
title: "会員（C1/C2）と入力検証"
description: "会員登録・変更と、全画面の入力検証（前処理・文字クラス・単項目・相関）を両モデルで実装する。"
tags: [backlog, spec, source-model, member, validation]
id: "0008"
state: todo
depends_on: ["0003"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 会員（C1/C2）と入力検証

## 目的

入力検証は全画面に共通であり、文字列長の差異（D-006）を含むため早めに確定させる。

## 範囲

- `Spec.Validation`, `SourceModel.Validation`
- `Spec.UseCase.Member`, `SourceModel.UseCase.Member`
- `Email` 判定規則の書き下し（[input-validation.md](../spec/input-validation.md) の TODO）
- 単項目違反が複数ある場合の並び順の決定（同 TODO）
- ABS-030

## 対象外

- なし

## 完了条件

- [ ] [input-validation.md](../spec/input-validation.md) の TODO(spec) を解消した
- [ ] 文字クラス境界値のベクタが通る

## 参照

- [member.md](../spec/member.md)
- [input-validation.md](../spec/input-validation.md)
- [ADR 0010](../decision/0010-text-length-and-character-classes.md)
