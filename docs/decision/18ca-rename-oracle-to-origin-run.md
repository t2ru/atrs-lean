---
type: Architecture Decision Record
title: "「オラクル」を「原典実行」（origin-run）と呼び替える（ATRS）"
description: "Java の原典を実行して期待値を採取・照合する手段を「原典実行」（識別子 origin-run）と呼び替え、ATRS の文書・既存の ADR と作業項目の本文・ベクタの source の値・道具（tools/origin-run、tools/ci/java_origin_run.sh、mise の origin-run:*）をそろえる。改名しない規約の backlog のファイル名（f18c・773f）は残す。"
tags: [adr, terminology, conformance, origin-run]
id: "18cae8cb-99e8-4a29-8f72-a7df72d70ade"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:00:00+09:00
---

# 「オラクル」を「原典実行」（origin-run）と呼び替える（ATRS）

## Context and Problem Statement

ATRS は、原典（Java）を実行して [Source] の期待値を採取・照合する手段を「Java オラクル」と呼んでいた（[backlog f18c](../backlog/f18c-java-oracle-harness.md)、[backlog 773f](../backlog/773f-differential-oracle.md) の「差分オラクル」）。ATRS は PostgreSQL を使う SQL を移植元に含み、「オラクル」は DBMS の Oracle と紛れる。

## Decision Drivers

* 用語の誤解を避ける（プロジェクトオーナーの指摘）
* スキルの用語と一致させる（[スキルの ADR 288a](../../.agents/skills/spec-pivot/references/docs/decision/288a-rename-oracle-to-origin-run.md)）

## Considered Options

* 「原典実行」（`origin-run`）にすべての箇所で呼び替える
* 新しい文書と道具だけを呼び替え、既存の ADR は旧語のまま残す

## Decision Outcome

Chosen option: "「原典実行」（`origin-run`）にすべての箇所で呼び替える", because 語が混ざると、同じ手段が 2 つあるように読めるからである（プロジェクトオーナーの決定）。

| 対象 | 新しい名前 |
| --- | --- |
| 手段 | Java の原典実行（ドメイン層・HTTP レベル）、差分の原典実行（backlog 773f） |
| ベクタの `source` | `java-origin-run` |
| 生成するベクタ | `conformance/source-model/<feature>/origin-run-*.json` |
| 道具 | `tools/origin-run/`（Java のパッケージ `atrsoriginrun`）、`tools/ci/java_origin_run.sh`、mise の `origin-run:domain`・`origin-run:http`・`origin-run:gen`・`ci:java-origin-run`、`trace/checks.json` の `java-origin-run` |
| 採取結果 | `tools/origin-run/http/*.json` |

* 既存の ADR・作業項目・仕様文書・変更履歴の本文の語を置き換えた。決定の内容は変えていない（[decision-records.md](../rules/decision-records.md#状態) の「補足情報の追記・修正」の範囲）。
* backlog f18c・773f のファイル名（slug）は改名しない規約なので、`oracle` を含むまま残す。旧番号の対応表 `tools/docs/legacy-ids.json` も残す。
* 今回の変更で足した ADR 81da・7d3a は、未マージなのでファイル名も改めた。

### Consequences

* Good, because DBMS の Oracle と紛れない
* Bad, because backlog f18c・773f のファイル名だけに旧語が残る

### Confirmation

* `git grep -i oracle` の残りが、backlog f18c・773f のファイル名（とそのリンク）、`legacy-ids.json`、SQL の方言名だけである。

## More Information

* [ADR 81da](81da-java-origin-run-domain-and-http.md)、[スキルの ADR 288a](../../.agents/skills/spec-pivot/references/docs/decision/288a-rename-oracle-to-origin-run.md)
