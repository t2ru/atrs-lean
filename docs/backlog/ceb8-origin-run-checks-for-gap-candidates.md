---
type: Backlog Item
title: "差異の候補を HTTP レベルの原典実行で確かめる"
description: "差異の棚卸し（ADR f786）で保留にした、ライブラリの内部の挙動に拠る差異の候補を、HTTP レベルの Java の原典実行で採取して確かめ、差異・Spec の修正・見送りを判断する。"
tags: [backlog, java, origin-run, gap, http]
id: "ceb83a6b-c9ae-4e57-9431-e38ac222f518"
state: todo
depends_on: ["f18c3c0f-4007-42c1-ba25-102fb385a16c"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 差異の候補を HTTP レベルの原典実行で確かめる

## 目的

[ADR f786](../decision/f786-gap-inventory-and-registry-fixes.md) の棚卸しで、Spring・Jackson・Hibernate Validator の内部の挙動に拠る差異の候補は、コードを読むだけでは確定できなかった。原典実行で採取し、決定論的な根拠のうえで、差異として登録するか、[Spec] を原典に合わせるか、見送るかを判断する。

## 範囲

- `tools/origin-run/http/` に次の要求を足して採取する（[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md) の HTTP レベルの原典実行）。
  - 10 文字の空白（U+3000 など）のログイン ID でのログイン（失敗の画面か 500 か。Ajax の 401 か）
  - 予約履歴レポートの取得で、空・空白だけの `reportName` と、パラメータの欠落
  - 画面の整数の欄（`repAge`・`passengerFormList[i].age`）に、内部に空白・`0x`・`#`・`+`・全角数字を含む値
  - REST の JSON の `Integer` の欄に小数、`LocalDate` の欄に配列・数・日時の文字列、5 桁以上・符号付き・0 以下の年（D-021・D-041 の拡大の候補）
  - `Digits` の違反のメッセージの引数の順、REST の予約で `gender`・`boardingClassCd` を欠いたときのメッセージ
  - JVM の既定のロケールを ja 以外にしたときのログインのメッセージ
  - 変換に失敗した欄だけを持つ搭乗者の行
  - 変換に失敗する入力での `POST ?redo`（B2・C1・C2）と B2 の `GET ?form`
  - `GET /api/v1/ticket/check` の `reserveNo` の欠落（ApiError の `details` の有無）
- 結果ごとに、差異の登録（`@[gap_entry]`）・[Spec] の修正・見送りをオーナーに諮り、ADR に記録する
- レポートの公開の移動の原子性（[assurance.md](../spec/assurance.md#移植元ソース--sourcemodel)）を原典で確かめられるかを調べ、確かめられなければモデル外の差異にするかを諮る

## 対象外

- 確定した差異の述語と W 課題（各機能の backlog で作る）
- 予約・会員・認証・レポートの `SourceModel`

## 完了条件

- [ ] 範囲の各要求の採取が `tools/origin-run/http/` にあり、CI の原典実行で再現する
- [ ] 各候補の判断が ADR に記録され、登録した差異が登録簿にある
- [ ] [abstraction.md](../spec/abstraction.md) の表と仕様文書が、判断に合わせて更新されている

## 参照

- [ADR f786](../decision/f786-gap-inventory-and-registry-fixes.md)
- [ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)
- [backlog f18c](f18c-java-oracle-harness.md)
