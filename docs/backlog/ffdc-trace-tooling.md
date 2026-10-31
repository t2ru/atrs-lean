---
type: Backlog Item
title: "追跡の道具（tools/trace）"
description: "インベントリ生成・Lean ダンプの取り込み・manifest と表の生成・TR 検査・差分・影響分析を行う Rust 製の道具を作る。"
tags: [backlog, tooling, traceability]
id: "ffdc480d-eaf2-42a0-9818-0b128e9403d4"
state: done
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8", "455ffb21-3a0e-4833-b82c-2d972bfec450"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T06:36:39+09:00
---

# 追跡の道具（tools/trace）

## 目的

両端の追跡（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)）を機械的に保守・検査できるようにする。

## 範囲

- `tools/trace/`（独立 Cargo プロジェクト、stable ツールチェーン）
- `inventory source`（tree-sitter-java、Mapper XML・DDL・properties・pom の簡易パーサ、正規化した本文ハッシュ）
- `inventory target`（tree-sitter-rust と doc タグの行走査）
- `ingest-lean`（`lake exe trace-dump` の取り込み）, `manifest`（`trace/manifest.json` と traceability.md の生成区画）
- `check`（TR-S1〜TR-R と TR-D。警告にしてよいのは、backlog で完了していない機能だけ）
- `check` から、実装済みの TR-G・TR-N（`lake exe obligation-check` と `tools/ci/check_obligations.py`。[backlog f7b7](f7b7-refinement-non-vacuity.md)）を呼ぶ。TR-PE（入口の R 課題の具体機械による網羅。[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）を加える
- `rehash`（決定論的な検査を実行し、合格した定義だけハッシュを更新する）, `diff`（新旧インベントリの分類）, `impact`（証明グラフに沿った影響一覧）
- `tmpl:` ロケータ（Thymeleaf テンプレートの式）のインベントリ
- 最初の `trace/source-inventory.json` の生成（[backlog 455f](455f-upstream-submodule-and-inventory.md) の submodule から）
- 本文の正規化で文字列リテラルの中身を保つこと。`renames.json` の対応を `rehash` で検査すること
- 既存草案の「出典:」のパス表記をロケータ表記に書き換える（運賃計算・空席照会・予約から）

## 対象外

- 移植元ソースと移植先ソースを直接結ぶ機能（作ってはならない）

## 完了条件

- [x] CI で `tools/trace check` が走る
- [x] [traceability.md](../spec/traceability.md) の生成区画が埋まる
- [x] 最初の `trace/source-inventory.json` を生成し、件数（Java メソッド・SQL 文・設定キー・メッセージキー）を記録した
- [x] 故意に入れた TR-X 違反（`TargetModel` に `java:` を書く）を検出できる
- [x] 故意に入れた TR-D 違反（文書の D-NNN に対応する `@[deviation]` が無い、R 課題に無名の仮定がある）を検出できる
- [x] `tools/trace check` が TR-G・TR-N（`obligation-check`・`check_obligations.py`）の結果を含める
- [x] 故意に入れた TR-PE 違反（入口でない R 課題にしか現れない公開操作）を検出できる
- [x] 検査が合格していない定義のハッシュを `rehash` が更新しないことを確認した

## 進め方

2 段に分けた（2026-10-30 の決定）。第 2 段で `done` にした。

- **第 1 段（済み）**
  - インベントリ（`inventory source`・`inventory target`）
  - Lean の出力の取り込み（`manifest`・`check` の `--dump`・`--obligations`）
  - `check`（TR-S1・TR-S2・TR-T1・TR-T2・TR-P・TR-PE・TR-D・TR-X・TR-R と、TR-G・TR-N の取り込み）
  - `manifest` と生成区画、CI、`trace/features.json`
  - 未確定だった細部は [ADR 0eea](../decision/0eea-trace-tooling-unresolved-details.md) で決めた
- **第 2 段（済み）**。細部は [ADR 9cd9](../decision/9cd9-rehash-diff-impact-details.md) で決めた
  - `rehash`。決定論的な検査を実行し、合格した組（本文ハッシュと Merkle）だけを manifest に記録して注釈のハッシュを更新する。完了条件の最後の項目
  - `diff`・`impact`
  - `renames.json` の検査
  - 既存草案の「出典:」のロケータ表記への書き換え（運賃計算・空席照会・予約から）
  - 初期の予定対応の表（traceability.md）の削除。`trace/features.json` と生成表に置き換えた

## 第 1 段の結果

- 最初の `trace/source-inventory.json`: 1963 件。うち対象外（`out-of-scope.json`）は 640 件で、対象範囲は 1323 件。

  | 種類 | 件数 |
  | --- | --- |
  | Java のメソッド・コンストラクタ・定数（`java:`） | 1024 |
  | HTTP のハンドラ（`http:`） | 48 |
  | Mapper の SQL 文（`sql:`） | 21 |
  | DDL（`ddl:`） | 48 |
  | 初期データ（`seed:`） | 11 |
  | 設定キー（`prop:`） | 23 |
  | メッセージキー（`msg:`） | 174 |
  | テンプレートの要素（`tmpl:`） | 585 |
  | `web.xml` の要素（`xml:`） | 29 |

  内訳の補足:
  - 対象外 640 件は、`tmpl:` 585・`xml:` 29・`java:` 14・`prop:` 12 である。
  - `tmpl:` と `xml:` は `atrs-web/src/main/webapp/**` にある。
- `trace/target-inventory.json`: 0 件（`rust/` が無いため。[backlog fb50](fb50-rust-project-scaffold.md) で埋まる）。
- 現在の木での `tools/trace check`: 誤り 0 件。警告 1368 件は、すべて未完了の機能の段階導入による。
  - TR-S1: 1323 件
  - TR-D: 32 件（`@[deviation]` と W 課題がまだ無い）
  - TR-G・TR-N: 13 件（`check_obligations.py` の段階導入の警告）
- 違反例の検出は `cargo test` で確かめる（`tools/trace/src/check.rs` の試験）。対象は次のとおり。
  - TR-X: `TargetModel` に `java:` を書いた定義と、`rust/` の中の移植元のロケータ
  - TR-D: 文書の D-NNN に `@[deviation]` が無いこと、R 課題に無名の仮定（G1）があること、文書に無い `@[deviation]`
  - TR-PE: 入口でない R 課題にしか現れない公開操作
  - TR-S1・TR-S2・TR-R

## 第 2 段の結果

- `rehash`
  - `trace/checks.json` に登録した検査のうち、対象を覆うものを実行する。
  - すべて合格した組だけ、注釈を書き換えて manifest に記録する。
  - 覆う検査が無い、または不合格の組については、ファイルも manifest も変えない。
  - 最初の登録は `lake-test`・`jvm-table`・`pg-table` の 3 つ。
  - `tools/ci/jvm_table.sh`・`pg_table.sh` は、`lean.sh` から切り出して共用する。
  - `trace-dump` は、定義の `module` も出力する。
- `diff`
  - 新旧のインベントリを、不変・本文変更・移動/改名・追加・削除・版の変化に分類する（`--old git:<rev>`）。
  - 現在の木を `git:HEAD` と比べると 1963 件すべてが不変、本項目の第 1 段より前と比べると 1963 件すべてが追加になる。
- `impact`: 証明のグラフに沿って、`SourceModel` → `Abstraction` → `Spec` → （`Spec` を変える場合）`Refinement` → `TargetModel` → `rust:` の順に影響を示す。
- `check` の TR-R に、2 つの検査を足した。
  - `renames.json` の参照切れ
  - 「出典:」のロケータの参照切れ
- 「出典:」の書き換え
  - 運賃計算（4 行）・空席照会（4 行）・予約（8 行）をロケータ表記にした。
  - private のメソッド（`getMultiplicationRatio`・`createFlightVacantInfoList`・`createReservation`・`validateAndUpdateVacancy`）は、呼び出し元の公開メソッドで書いた。
  - 残りの草案のパス表記は、各機能の backlog で書き換える。
- 確認
  - `cargo test` の 31 件。rehash の合格・不合格・覆う検査なし・共有の注釈・改名・記録済みの 6 件を含む。
  - 一時ディレクトリでの `rehash` の通し。合格した定義だけが書き換わり、不合格の定義が残ることを確かめた。
  - `tools/ci/lean.sh` の全段
- 実データでの最初の `rehash` は、運賃計算（[backlog 25f7](25f7-fare-calculation-both-models.md)・[f18c](f18c-java-oracle-harness.md)）で `@[source]` とベクタができてからになる。

## 参照

- [ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)、[ADR 0eea](../decision/0eea-trace-tooling-unresolved-details.md)、[ADR 9cd9](../decision/9cd9-rehash-diff-impact-details.md)
- [traceability.md](../spec/traceability.md)
