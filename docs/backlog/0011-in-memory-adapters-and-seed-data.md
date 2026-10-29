---
type: Backlog Item
title: "Rust: インメモリアダプタとシードデータ"
description: "Rust の target_model::adapter にポートのインメモリ実装を作り、シードデータの fixture を用意して Kani で契約を検査する。"
tags: [backlog, rust, target-model, adapter, fixture]
id: "0011"
state: todo
depends_on: ["0020"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust: インメモリアダプタとシードデータ

> 2026-10-29 に Lean の TargetModel 向けから Rust 向けに範囲を変更した（[ADR 0020](../decision/0020-rust-as-target-language.md)）。

## 目的

Rust の移植先を動かせる状態にし、ポート契約（REF-005）を検査する。

## 範囲

- `target_model::adapter::in_memory`（全ポート。状態は `core` の状態型を `Mutex` で保持）
- `conformance/fixtures/master-data.json`（空港・区間・便マスタの全件転記）, `config.json`
- 参照ハッシュ `"{test}" ++ raw` と、任意で `{pbkdf2}` 互換アダプタ（採用時に依存クレートの ADR）
- Kani: 採番の一意性・書式、`publish` の原子性（REF-005）
- REF-003 のうちインメモリ分（Mutex 下の逐次実行への帰着）

## 対象外

- DB アダプタ（必要になった時点で別項目）
- HTTP

## 完了条件

- [ ] シードの全件が fixture にあり、件数が原典と一致する（空港 51・区間 20・便マスタ 126）
- [ ] REF-005 のインメモリ分を Kani で検査した

## 参照

- [ports.md](../spec/ports.md)
- [master-data.md](../spec/master-data.md)
- [refinement.md](../spec/refinement.md)
- [rules/rust.md](../rules/rust.md)
