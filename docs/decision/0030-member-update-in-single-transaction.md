---
type: Architecture Decision Record
title: "会員情報変更は現在パスワードの照合と更新を 1 つのトランザクションで行う"
description: "原典では別トランザクションである照合と更新を、Spec では 1 つの直列化可能なトランザクションにまとめ、差を既知差異 D-013 とする。"
tags: [adr, member, transaction]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:40:00+09:00
---

# 会員情報変更は現在パスワードの照合と更新を 1 つのトランザクションで行う

## Context and Problem Statement

原典の会員情報変更は、コントローラが `checkMemberPassword`（現在パスワードの照合）を呼んだ後、別のサービス呼び出し `updateMember` で更新する。両者は別のトランザクションである。
そのため、照合の後・更新の前に、別のセッションが同じ会員のパスワードを変えると、古いパスワードで照合したまま更新が通る。
一方 [spec/ports.md](../spec/ports.md#トランザクション) は「会員情報変更」全体を原子的かつ直列化可能に行うよう求めており、[spec/member.md](../spec/member.md#会員情報変更update) と矛盾していた。

## Decision Drivers

* [Spec] の要件を一貫させること
* 認証に関わる処理で、競合による不正な更新を許さないこと

## Considered Options

* [Spec] は照合と更新を 1 つのトランザクションで行う
* 原典どおり分け、ports.md の要件を「更新の部分だけ原子的」に弱める

## Decision Outcome

Chosen option: "[Spec] は照合と更新を 1 つのトランザクションで行う", because 照合と更新の間の競合は原典の不具合とみなせ、[Spec] を安全な側にそろえるほうが移植先の実装も単純になるため。

* [spec/member.md](../spec/member.md#会員情報変更update) の手順 1（照合）と手順 2（更新）を、1 つの直列化可能なトランザクションにまとめる。
* [Source] との差は既知差異 [D-013](../spec/abstraction.md#既知差異) とする。一致の前提は「照合から更新までの間に、同じ会員のパスワードを他のトランザクションが変更しない」である。
* あわせて、原子性が要求されるユースケースの一覧を [spec/ports.md](../spec/ports.md#トランザクション) と [ADR 0011](0011-persistence-and-transaction-semantics.md) でそろえる（レポート生成を含める）。

### Consequences

* Good, because 古いパスワードでの照合が通る競合が無くなる
* Bad, because 原典と異なり、照合の失敗（`e.ar.c2.2001`）もトランザクションの中で判定される

### Confirmation

* `Abstraction` の課題 ABS-034 で、D-013 の前提の下で [Source] と [Spec] の結果が一致することを証明する。

## Pros and Cons of the Options

### 1 つのトランザクション

* Good, because 一貫していて安全
* Bad, because 既知差異が 1 件増える

### 原典どおり分ける

* Good, because 原典と一致する
* Bad, because 競合による不正な更新を仕様として許すことになる

## More Information

* [ADR 0011](0011-persistence-and-transaction-semantics.md) の補足である
* [spec/member.md](../spec/member.md), [spec/ports.md](../spec/ports.md), [spec/abstraction.md](../spec/abstraction.md)
