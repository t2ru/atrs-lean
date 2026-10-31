---
type: Architecture Decision Record
title: "Lean の Spec を正規仕様とし、Spec で表現できない仕様だけを docs/spec で定義する"
description: "正規仕様の所在を Lean の Spec 名前空間に移し、docs/spec は Spec の外にある要件と文書メタ情報に限定する。ADR 3b0a を置き換える。"
tags: [adr, spec, normative]
id: "61bce953-a515-42f0-a216-a3af9ef39e1d"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# Lean の Spec を正規仕様とし、Spec で表現できない仕様だけを docs/spec で定義する

## Context and Problem Statement

[ADR 3b0a](3b0a-spec-as-normative-source.md) では、`docs/spec`（Markdown）を唯一の正規仕様とし、Lean はそれに従う参照実装とした。
しかし同じ業務規則を Markdown と Lean の両方に書くと、二重管理になり食い違いが生じる。
Lean の `Spec` は実行でき、型検査され、`Abstraction` の証明の対象でもある。
プロジェクトオーナーから「`Spec` で表現できない仕様は `docs/spec` で定義する」との指示があった。正規仕様の所在と、`docs/spec` の役割を改める。

## Decision Drivers

* 業務規則の定義を一箇所にすること
* 正規仕様が機械的に検査・実行・証明できること
* Lean で書けない要件（非機能・実行環境・セキュリティ方式など）も漏らさないこと

## Considered Options

* Lean `Spec` を正規とし、`Spec` で表現できない仕様だけを `docs/spec` で定義する
* `docs/spec` を正規のまま維持する（ADR 3b0a）
* Lean `Spec` だけを正規とし、Lean で書けない要件は扱わない

## Decision Outcome

Chosen option: "Lean `Spec` を正規とし、`Spec` で表現できない仕様だけを `docs/spec` で定義する", because 業務規則を形式的な一箇所に集約しつつ、形式化できない要件も正規の場所を持たせられるため。

### 正規性の序列

1. Lean `Spec`（型・関数・定理）: 業務規則の正規の定義
2. `docs/spec` の **規範節**: `Spec` で表現できない仕様の正規の定義
3. 適合テストベクタ `conformance/`: `spec/` の期待値は Lean `Spec` を実行して生成する
4. 移植先モデル `TargetModel`（Lean）と移植先ソース（Rust）: 上記に従う（[ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md)）
5. Java 原典: 移植元モデル `SourceModel` を検証するためのオラクル

### docs/spec に置くもの

`docs/spec` の各節は、次のいずれかとして冒頭で区分を明示する（[port-lang/spec-documents.md](../../.agents/skills/port-lang/references/docs/spec-documents.md)）。

| 区分 | 内容 | 例 |
| --- | --- | --- |
| **規範（Spec 外）** | Lean の `Spec` の型・関数・定理として書けない、または書くべきでない仕様 | 並行実行での原子性・直列化可能性の要件、HTTP の伝送とセキュリティの方式（CSRF、トークン、Cookie、認証方式）、ポート実装の運用要件（ファイル配置、キュー、文字コード、パスワードハッシュの互換）、非機能要件 |
| **メタ情報** | 仕様そのものではなく、仕様と検証を運用するための情報 | 用語集、追跡表、テストベクタの形式、証明課題の一覧、既知差異の説明 |
| **形式化前の草案** | `Spec` で表現できるが、まだ Lean に形式化されていない業務規則 | 現在の運賃計算・空席照会・予約・会員・入力検証・エラー文言など |

* **形式化前の草案** は、Lean `Spec` に形式化した時点で `docs/spec` から定義を取り除き、Lean の定義へのリンクと非規範の要約だけを残す。形式化が完了した節に Markdown で規範的な定義を書き足してはならない。
* 草案の段階では、草案が Lean 形式化の入力である。形式化中に草案と食い違う判断をした場合は、草案を直してから形式化する。
* 「表現できるか」の判断に迷ったら、まず Lean `Spec` で書くことを試みる。書けなかった理由を規範節に記録する。

### Consequences

* Good, because 業務規則が実行・検査・証明できる一箇所に定まる
* Good, because 適合テストベクタの期待値を Lean `Spec` から生成でき、手計算の誤りが入らない
* Bad, because 移植者が業務規則を読むには Lean を読む必要がある（非規範の要約で補う）
* Bad, because 形式化の進み具合に応じて `docs/spec` の区分を保守する必要がある

### Confirmation

* `docs/spec` の各文書の冒頭に区分が書かれていることをレビューで確認する。
* 形式化が完了した機能の文書に、規範的な定義（計算式・手順）が残っていないことをレビューで確認する。

## Pros and Cons of the Options

### Lean Spec を正規 + Spec 外を docs/spec

* Good, because 単一の正規定義と、形式化できない要件の受け皿を両立する
* Bad, because 移植者に Lean の読解を求める

### docs/spec を正規のまま

* Good, because Lean を読まずに移植できる
* Bad, because 業務規則が Markdown と Lean に二重化する

### Lean Spec だけを正規

* Good, because 最も単純
* Bad, because 非機能・セキュリティ・実行環境の要件が正規の場所を失う

## More Information

* 本 ADR は [ADR 3b0a](3b0a-spec-as-normative-source.md) を置き換える。
* [ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md)（移植先モデルと移植先ソースの構成）
* [spec/README.md](../spec/README.md)
