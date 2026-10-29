---
type: Backlog Item
title: "Rust: インメモリアダプタとシードデータ"
description: "Rust にポートのインメモリ実装を作り、シードデータの fixture を用意し、Kani と結合テストで契約を確認する。"
tags: [backlog, rust, adapter, fixture]
id: "0011"
state: todo
depends_on: ["0020"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust: インメモリアダプタとシードデータ

> 2026-10-29 に ADR 0022（モデルは Lean、Rust は移植先ソース）と ADR 0023（両端の追跡）に合わせて範囲を改めた。

## 目的

Rust の移植先ソースを動かせる状態にし、ポート契約（SRC-004, SRC-005）を確認する。

## 範囲

- `rust/src/adapter/in_memory`（全ポート。状態は `Mutex` で保持）と、対応する `TargetModel` のポート実装（`@[target]` 付き）
- `conformance/fixtures/master-data.json`（空港・区間・便マスタの全件転記）, `config.json`
- 参照ハッシュ `"{test}" ++ raw`。`{pbkdf2}` 互換アダプタは任意（採用時に依存クレートの ADR）
- Kani: 採番の一意性・書式、`publish` の原子性（SRC-004）。SRC-005 のうちインメモリ分

## 対象外

- DB アダプタ（必要になった時点で別項目）
- HTTP

## 完了条件

- [ ] シードの全件が fixture にあり、件数が原典と一致する（空港 51・区間 20・便マスタ 126）
- [ ] SRC-004 のインメモリ分を Kani で確認した
- [ ] TR-T1・TR-T2 が通る

## 参照

- [ports.md](../spec/ports.md)
- [master-data.md](../spec/master-data.md)
- [refinement.md](../spec/refinement.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)
