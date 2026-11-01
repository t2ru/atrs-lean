---
type: Architecture Decision Record
title: "「オラクル」を「原典実行」（origin-run）と呼び替える"
description: "移植元のプログラムを実行して期待値を採取・照合する手段を、DBMS の Oracle と紛れない「原典実行」（識別子 origin-run）と呼ぶ。新旧 2 版を比べるものは「差分の原典実行」とする。ベクタの source の値は <移植元>-origin-run、道具のディレクトリ・クラス名もこれにそろえる。"
tags: [adr, skill, terminology, conformance]
id: "288a7e30-0a1b-4fd1-892c-5f9d510a9142"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:00:00+09:00
---

# 「オラクル」を「原典実行」（origin-run）と呼び替える

## Context and Problem Statement

スキルは、移植元のプログラムを実行して適合テストベクタの期待値を採取し、照合する手段を「オラクル」（テストオラクル）と呼んでいた（ベクタの `source` の値 `<移植元>-oracle`、言語パックの「移植元として: オラクル」、「差分オラクル」）。移植元が SQL を含み、言語パックに SQL の方言（`oracle` を含む）を置くので、DBMS の Oracle と紛れる。

## Decision Drivers

* 語から手段が分かること（何を実行するか）
* SQL の方言の名前と紛れないこと
* 既存の語「原典」（移植元のソース）と合うこと

## Considered Options

* 「原典実行」（`origin-run`）
* 「参照実行」（`reference-run`）
* 「原典プローブ」（`probe`）

## Decision Outcome

Chosen option: "「原典実行」（`origin-run`）", because 原典を実行することがそのまま語に出て、ベクタの「参照実装」（テスト用ハッシュ・採番）とも紛れないからである（プロジェクトオーナーの決定）。

| 旧 | 新 |
| --- | --- |
| オラクル（移植元オラクル） | 原典実行 |
| 差分オラクル | 差分の原典実行 |
| HTTP レベルのオラクル | HTTP レベルの原典実行 |
| ベクタの `source`: `<移植元>-oracle`（例 `java-oracle`） | `<移植元>-origin-run`（例 `java-origin-run`） |

* スキルの文書・既存の ADR・作業項目の本文も呼び替える（語の置き換えだけで、決定の内容は変えない）。過去の変更履歴の文も呼び替える。
* 一度採番したファイル名（slug）は改名しない規約なので、旧語を含むファイル名は残す。
* SQL の方言の名前としての `oracle`（DBMS）は、そのまま使う。

### Consequences

* Good, because DBMS の Oracle と紛れない
* Bad, because テストの文献の語（test oracle）と対応づけるには、この ADR を引く必要がある

### Confirmation

* `git grep -i oracle` の残りが、SQL の方言名と、改名しないファイル名・旧番号の対応表だけである。

## More Information

* 来歴: 適用先 ATRS の ADR 18ca。
* [lang/java/harness.md](../lang/java/harness.md)、[spec/conformance.md](../spec/conformance.md)、[ADR 7d3a](7d3a-java-conformance-kit-and-http-origin-run-method.md)
