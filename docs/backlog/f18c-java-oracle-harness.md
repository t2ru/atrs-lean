---
type: Backlog Item
title: "Java の原典実行ハーネス"
description: "原典の Java クラスを直接呼び出し、[Source] ベクタの期待値を採取するハーネスを作る。"
tags: [backlog, java, origin-run, testing]
id: "f18c3c0f-4007-42c1-ba25-102fb385a16c"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# Java の原典実行ハーネス

> 2026-11-01 に `depends_on` から a8ef を外した。原典実行に要るのはベクタの形と既存の実行器だけで、生成したベクタへの `outsidePre` の付与（TR-V）は a8ef に残す（プロジェクトオーナーの決定。[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)）。

## 目的

[Source] の正しさを原典そのもので確認する。

## 範囲

- 原典のドメイン層（Spring 不要な部分）を呼ぶ小さな Java プログラム
- HTTP レベルの原典実行: Spring を起動した原典（組み込み Tomcat に原典の web.xml のままの webapp を載せる。[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)）に要求を送り、応答を照合する。対象はフレームワークの暗黙の処理（入力の変換・Bean Validation・Spring Security・Jackson）と、テンプレートの書式（D-019）
- ベクタの `input` から呼び出し、`expected` を出力（`source: java-origin-run`）
- REST の日付 JSON 表現の確認（[http-contract.md](../spec/http-contract.md#rest-apiapiv1) の TODO。ソースの読解では `"yyyy-MM-dd"` の見込み）
- 画面ログインで `loginDateTime`・`loginFlg` が更新されるかの確認（[authentication.md](../spec/authentication.md#ログインlogin) の TODO）

## 対象外

- 原典の改変
- テンプレートの書式（D-019）と、誤った資格情報の 401・エラー画面への遷移の採取（ハーネスはできた。採取と照合は [backlog a89e](a89e-http-contract-adapter.md) で行う）

## 完了条件

- [x] 運賃計算の [Source] ベクタが Java の原典実行と一致する（[backlog bbcc](bbcc-fare-abstraction-proofs.md) から移した。[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）
- [x] 空席照会の [Source] ベクタ（`shared/flight-search`・`source-model/flight-search`）が Java の原典実行と一致する（[backlog 0be7](0be7-flight-search-usecase.md) から移した。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）
- [x] http-contract.md と authentication.md の TODO(spec) を解消した
- [x] HTTP レベルのハーネスで、Spring を起動した原典に要求を送り、応答をベクタの形式で採取できる（`SourceModel.Http`・`SourceModel.Validation` との照合は、[backlog 4e0e](4e0e-member-usecases-and-input-validation.md)・[a89e](a89e-http-contract-adapter.md) で行う）
- [x] ハーネスの対象外とした操作と、ベクタの範囲を [assurance.md](../spec/assurance.md) に記載した

## 結果

- 第 1 段（ドメイン層）: 既存の `shared/fare`・`source-model/fare`・`shared/flight-search` の 35 件が原典の実行と一致した。シードの範囲から 1,867 件のベクタ（`conformance/source-model/{fare,flight-search}/origin-run-*.json`）を原典から採取し、`lake test` で `SourceModel` も一致した。
- 第 2 段（HTTP レベル）: REST の `LocalDate` は `"yyyy-MM-dd"`（`"yyyy/MM/dd"` は 400）。画面ログインは `MEMBER_LOGIN` を更新せず、REST の Basic 認証は更新する。D-028 を観測型の既知差異にした（成分 `obs_D028` と W 課題 ABS-128 は [backlog 44f8](44f8-authentication-usecases.md)）。採取結果は `tools/origin-run/http/`。
- 道具: スキルの `assets/java/conformance-kit`（[スキルの ADR 7d3a](../../.agents/skills/spec-pivot/references/docs/decision/7d3a-java-conformance-kit-and-http-origin-run-method.md)）、`tools/origin-run/`、`tools/ci/java_origin_run.sh`、mise の `origin-run:*`・`ci:java-origin-run`、`trace/checks.json` の `java-origin-run`。

## 参照

- [ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)

- [spec-pivot/java/harness.md](../../.agents/skills/spec-pivot/references/docs/lang/java/harness.md)
