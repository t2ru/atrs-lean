---
type: Backlog Item
title: "Java オラクルハーネス"
description: "原典の Java クラスを直接呼び出し、[Source] ベクタの期待値を採取するハーネスを作る。"
tags: [backlog, java, oracle, testing]
id: "f18c3c0f-4007-42c1-ba25-102fb385a16c"
state: todo
depends_on: ["a8ef4e5b-1870-4669-9398-1916a439a6f7"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:13:09+09:00
---

# Java オラクルハーネス

## 目的

[Source] の正しさを原典そのもので確認する。

## 範囲

- 原典のドメイン層（Spring 不要な部分）を呼ぶ小さな Java プログラム
- HTTP レベルのオラクル: Spring を起動した原典（MockMvc など）に要求を送り、応答を照合する。対象はフレームワークの暗黙の処理（入力の変換・Bean Validation・Spring Security・Jackson）と、テンプレートの書式（D-019）
- ベクタの `input` から呼び出し、`expected` を出力（`source: java-oracle`）
- REST の日付 JSON 表現の確認（[http-contract.md](../spec/http-contract.md#rest-apiapiv1) の TODO。ソースの読解では `"yyyy-MM-dd"` の見込み）
- 画面ログインで `loginDateTime`・`loginFlg` が更新されるかの確認（[authentication.md](../spec/authentication.md#ログインlogin) の TODO）

## 対象外

- 原典の改変

## 完了条件

- [ ] 運賃計算の [Source] ベクタが Java オラクルと一致する（[backlog bbcc](bbcc-fare-abstraction-proofs.md) から移した。[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）
- [ ] http-contract.md と authentication.md の TODO(spec) を解消した
- [ ] HTTP レベルのハーネスで、Spring を起動した原典に要求を送り、応答をベクタの形式で採取できる（`SourceModel.Http`・`SourceModel.Validation` との照合は、[backlog 4e0e](4e0e-member-usecases-and-input-validation.md)・[a89e](a89e-http-contract-adapter.md) で行う）
- [ ] ハーネスの対象外とした操作と、ベクタの範囲を [assurance.md](../spec/assurance.md) に記載した

## 参照

- [port-lang/java/harness.md](../../.agents/skills/port-lang/references/java/harness.md)
