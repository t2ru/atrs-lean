---
type: Guide
title: "言語パックの構成と追加のしかた"
description: "言語パックの 6 ファイルの構成と、新しい言語・SQL 方言を追加するときの手順。"
tags: [language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# 言語パックの構成と追加のしかた

言語パック `references/docs/lang/<lang>/` は、その言語が **移植元にも移植先にもなれる** ように書く。役割ごとにファイルを分けない。
役割によって扱いが変わる点は、各ファイルの中に「移植元として」「移植先として」の節を設けて書く。

## 必須ファイル

| ファイル | 内容 | 移植元として使う | 移植先として使う |
| --- | --- | --- | --- |
| `semantics.md` | `LangSemantics.<Lang>` の範囲: 基本型・演算・文字列・日付・エラー・パニック/例外の意味。整数演算だけでエミュレートできる名前付き演算として定義する | `SourceModel` を書くときに使う | `TargetModel` を書くときに使う |
| `locators.md` | ロケータの `kind`・`body` の文法、インベントリの取り方（パーサ、本文の正規化規則） | `@[source]` と `source-inventory` | `@[target]` と `target-inventory` |
| `frameworks.md` | 代表的なフレームワーク・ランタイムの暗黙の効果と、その写し方。依存の版の抽出方法。版上げで起こりがちな挙動変化 | 効果を `SourceModel` に写し、`dep:` を付ける | 採用するフレームワークの効果を `TargetModel` に写し、`dep:` を付ける |
| `harness.md` | 適合テストベクタをこの言語のコードに対して実行する方法 | 原典実行（`source-model/` の期待値の採取、新旧 2 版の差分の原典実行） | 照合（`target-model/`・`shared/` を通す） |
| `verification.md` | モデル ⇔ ソースの一致を確かめる **決定論的な手段** と、各手段の **保証の限界**（[verification.md](../spec/verification.md#決定論的な手段)） | 原典実行・処理系の差分実行など、原典とモデルの一致の確かめ方 | 写しの生成と検証器など、移植先ソースとモデルの一致の確かめ方 |
| `layout.md` | ソースの構成と、Lean の名前空間との対応づけ | 原典の構成を、`SourceModel` の下位名前空間にどう写すか | 移植先ソースの構成。モデルの写しの置き場所と追跡タグの書き方 |

整備されていない項目は、ファイル内に `> **未整備:** …` と書いて残す。黙って省略してはならない。

## 追加の手順

1. `references/docs/lang/<lang>/` に上記 6 ファイルを作る。まず「移植元として」か「移植先として」の、今回必要な側から埋める。
2. `SKILL.md` の「言語パック」表に行を追加し、6 ファイルへ直接リンクする。
3. ロケータの `kind` が既存の言語と衝突しないことを確認する（[traceability.md](../spec/traceability.md)）。
4. `LangSemantics.<Lang>` を Lean で `assets/lean/LangSemantics/<Lang>/` に実装し、`assets/lean/LangSemantics.lean` から import する（[lean/rules.md](../lang/lean/rules.md)）。アプリ固有の型を入れない。
5. `assets/lean/Test/LangSemantics/<Lang>.lean` に `#guard` の検査を書き、`assets/lean/` で `lake build` が通ることを確認する。
6. `LangSemantics.<Lang>` の忠実性を、実際の処理系の結果と決定論的に突き合わせる（固定した入力の表、または全探索）。突き合わせられない演算と、突き合わせた入力の範囲は、`verification.md` に限界として書く。
7. 移植先として使う場合は、`TargetModel` から検証器向けの写しを生成する方法（生成器と対応表）を `layout.md` に書く。検証器が無い言語では、確認手段と限界を `verification.md` に書く。

## 方言（サブパック）

同じ言語でも処理系ごとに意味が異なる場合（例: SQL の DBMS）は、言語パックの下に **方言パック** `references/docs/lang/<lang>/dialects/<name>/` を置く。言語パックの 6 ファイルには処理系に依存しない共通部分を書き、処理系固有の部分を方言パックに書く。

| ファイル | 内容 |
| --- | --- |
| `semantics.md` | 方言の意味論 `LangSemantics.<Lang>.<Dialect>`（共通部分との差分だけ） |
| `engine.md` | 処理系の効果、版の記録項目、版上げで起こりがちな変化 |
| `harness.md` | ベクタの実行環境の固定方法（版・設定） |

方言を追加する手順:

1. `references/docs/lang/<lang>/dialects/<name>/` に上記 3 ファイルを作る。`<name>` は処理系名の英小文字（例 `postgresql`, `mysql`, `oracle`, `sqlserver`）。
2. 言語パックの `semantics.md`・`frameworks.md`・`harness.md` にある「方言の一覧」の表に行を追加する。
3. `SKILL.md` の言語パック表の方言の行に追加し、3 ファイルへ直接リンクする。
4. Lean に `LangSemantics.<Lang>.<Dialect>` を `assets/lean/LangSemantics/<Lang>/<Dialect>.lean` として実装し、検査を `assets/lean/Test/LangSemantics/` に足す。共通部分（`LangSemantics.<Lang>`）には依存してよいが、他の方言には依存しない。
5. ロケータは言語パックのもの（例 `sql:`）を使い、処理系の仕様の節は `lang:<name>#<節>` で指す。

## 判断の目安

- 言語仕様そのものの意味（整数の溢れ、文字列の単位）は `semantics.md` に書く。
- ライブラリ・フレームワークの意味（入力の自動変換、検証、シリアライズ）は `frameworks.md` に書く。
- データベースのように、言語と処理系の境界があいまいなものは、独立した言語パックにしてよい（例: `sql`）。
