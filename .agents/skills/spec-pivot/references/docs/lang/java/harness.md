---
type: Reference
title: "Java: ベクタの実行（オラクル／照合）"
description: "Java のコードに適合テストベクタを当てるハーネス（オラクル／照合）の作り方。"
tags: [java, language-pack, conformance]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Java: ベクタの実行（オラクル／照合）

`conformance/` のベクタを Java のコードに対して実行する小さなプログラム（ハーネス）を作る。

## 共通の構成

- ベクタの `operation` ごとに、対象のクラス・メソッドを呼ぶアダプタを書く。
- フレームワークの起動は最小限にする。DI コンテナを起動しないで済む純粋なクラスは直接生成する。マスタのキャッシュ（Provider 等）は fixture から組み立てる。
- 「今日」は、原典が注入できる `Clock` があればそれで固定する。無ければ実行環境の時計を固定する（例: `-Duser.timezone` と時計を差し替えるエージェント）。固定できない操作は、ハーネスの対象外とする。その操作は、プロジェクトの保証の限界の文書に載せる（[verification.md](../../spec/verification.md#保証の限界)）。
- JSON の読み書きは、ベクタの値の表現（[conformance.md](../../spec/conformance.md#値の表現)）に合わせる。

## 移植元として: オラクル

- `source-model/` の期待値を原典から採取する（`source: "java-oracle"`、`upstream` に版を記録する）。
- 採取した値と Lean `SourceModel` の値が一致しなければ、`SourceModel` 側の不具合とみなす。
- **差分オラクル**（版上げ時）: 旧版と新版の原典を別々のクラスパスで構築し、同じ入力を流して出力を比べる。結果はケースごとの差分一覧として出し、[upgrade.md](../../guide/upgrade.md) の手順 5 に渡す。
- 同じ commit を新旧に指定して差分 0 になること、を最初の確認にする。

## 移植先として: 照合

- `target-model/` と `shared/` の全ベクタを、移植先の Java コードに通す（JUnit のパラメータ化テストとして実装する）。

## 道具の例

- JDK（原典の要求する版）、Maven または Gradle。
- JSON: Jackson（ハーネス自身の設定は固定し、原典の `ObjectMapper` 設定と分ける）。
