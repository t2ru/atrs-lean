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
  at: 2026-10-29T23:52:11+09:00
---

# 会員（C1/C2）と入力検証

## 目的

入力検証は全画面に共通であり、文字列長の差異（D-006）を含むため早めに確定させる。

## 範囲

- `Spec.Validation`, `SourceModel.Validation`
- `Spec.UseCase.Member`, `SourceModel.UseCase.Member`
- `Email` 判定規則の形式化（[input-validation.md](../spec/input-validation.md#email)、[ADR 0026](../decision/0026-email-validation-rule.md)）
- エラーの並び（[Spec] は列、[Source] は多重集合。[ADR 0027](../decision/0027-validation-error-ordering.md)）の形式化
- 会員情報変更を 1 トランザクションにする（[ADR 0030](../decision/0030-member-update-in-single-transaction.md)）
- ABS-030, ABS-032, ABS-033, ABS-034

## 対象外

- なし

## 完了条件

- [x] [input-validation.md](../spec/input-validation.md) の TODO(spec) を解消した（2026-10-29。ADR 0026・0027）
- [ ] Email の境界値（ローカル部 64/65 文字、末尾のドット、`[IPv4]`、`[IPv6:…]`、引用符付きローカル部）のベクタが通る
- [ ] 文字クラス境界値のベクタが通る

## 参照

- [member.md](../spec/member.md)
- [input-validation.md](../spec/input-validation.md)
- [ADR 0010](../decision/0010-text-length-and-character-classes.md)
