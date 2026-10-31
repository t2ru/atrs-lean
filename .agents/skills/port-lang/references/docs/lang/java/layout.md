---
type: Reference
title: "Java: ソースの構成と Lean 名前空間の対応"
description: "Java のソースの構成と、Lean の名前空間の対応。"
tags: [java, language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Java: ソースの構成と Lean 名前空間の対応

## 移植元として（原典を読む）

- 原典の層（Controller / Service / Repository / Util など）と、`SourceModel` の下位名前空間を、**業務機能単位** で対応づける。`SourceModel` はパッケージ構成を写す必要は無い。ロケータで原典の位置を指せばよい。
- 1 つの `SourceModel` 定義が、複数のメソッドに対応してよい（`@[source]` に複数のロケータを並べる）。逆に、1 つのメソッドを複数の定義で分けて写してもよい。
- SQL（MyBatis の Mapper、JPA の JPQL）は SQL パックで写し、Java 側では呼び出しと結果の対応づけだけを写す。
- 原典の `@Transactional` などの境界は、`SourceModel` のユースケースの境界として写す。

## 移植先として（Java を書く）

> **未整備:** 次の項目を、Java を移植先にするときに決める。

- パッケージ構成: 業務機能ごとのパッケージを、`TargetModel` の下位名前空間名にそろえる。
- 純粋なコアと、アダプタ（永続化・HTTP・時計）を分ける。
- `TargetModel` の JML による写しの置き場所と、追跡タグ `/** trace: models <TargetModel の完全名> @<Merkle ハッシュ> */` の書き方。
- 禁止事項: `double`/`float` の業務計算への使用、暗黙の `now()`、null を返す API。
