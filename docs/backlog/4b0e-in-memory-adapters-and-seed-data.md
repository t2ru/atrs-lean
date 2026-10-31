---
type: Backlog Item
title: "Rust: インメモリアダプタとシードデータ"
description: "Rust にポートのインメモリ実装を作り、シードデータの fixture を用意し、Kani と結合テストで契約を確認する。"
tags: [backlog, rust, adapter, fixture]
id: "4b0e2070-e086-4966-95f8-9e366f4324a0"
state: todo
depends_on: ["9c1b5a33-ee88-4bd7-87f3-05094c95b55b", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Rust: インメモリアダプタとシードデータ

> 2026-10-29 に ADR 796c（モデルは Lean、Rust は移植先ソース）と ADR 81ab（両端の追跡）に合わせて範囲を改めた。

## 目的

Rust の移植先ソースを動かせる状態にし、ポート契約（SRC-004, SRC-005）を確認する。

## 範囲

- `rust/src/adapter/in_memory`（全ポート。状態は `Mutex` で保持。`verus!` の中で書き、生成した写しとの一致を Verus で証明する）と、対応する `TargetModel` のポート実装（`@[target]` 付き。REF-008）
- `conformance/fixtures/master-data.json`（空港・区間・便マスタの全件転記）, `config.json`
- 参照ハッシュ `"{test}" ++ raw`。`{pbkdf2}` 互換アダプタは任意（採用時に依存クレートの ADR）
- 採番の一意性・書式、`publish` の原子性は、REF-008（Lean）と Verus（SRC-003）で示す。`Mutex` の層のパニックの無さは Kani で示す（SRC-004）。SRC-005 のうちインメモリ分

## 対象外

- DB・ファイル・時計のアダプタ（[backlog 9c04](9c04-rust-external-adapters.md)）
- HTTP

## 完了条件

- [ ] シードの全件が fixture にあり、件数が原典と一致する（空港 51・区間 20・便マスタ 126）
- [ ] インメモリのアダプタを Verus で証明した（SRC-003）。`verus!` の外の部分を Kani で確認した（SRC-004）
- [ ] REF-008・REF-010（マスタ・設定の読み込み）を証明した
- [ ] TR-T1・TR-T2 が通る（SRC-007・SRC-008）
- [ ] Kani のハーネスの境界を [assurance.md](../spec/assurance.md) の付録に記入した

## 参照

- [ports.md](../spec/ports.md)
- [master-data.md](../spec/master-data.md)
- [refinement.md](../spec/refinement.md)
- [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/docs/lang/rust/layout.md)
