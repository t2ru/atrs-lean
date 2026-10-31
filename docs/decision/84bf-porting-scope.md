---
type: Architecture Decision Record
title: "移植スコープをドメイン・ユースケース・HTTP 契約とする"
description: "移植対象をドメイン・ユースケース・HTTP 契約とし、Thymeleaf の HTML 等を対象外とする。"
tags: [adr, scope]
id: "84bfbea8-5da1-49a5-ace7-f38db5992d26"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
sources:
  - id: atrs-upstream
    resource: https://github.com/terasolunaorg/atrs/tree/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf
    title: TERASOLUNA ATRS (JavaConfig-Thymeleaf)
---

# 移植スコープをドメイン・ユースケース・HTTP 契約とする

## Context and Problem Statement

ATRS（`JavaConfig-Thymeleaf`）は、ドメイン層（サービス・マスタ・SQL）、Web 層（Spring MVC のコントローラ・フォーム検証・Thymeleaf 画面）、
REST API、Spring Security による認証、JMS による非同期レポート作成から成る。
すべてを同じ粒度で移植すると、言語中立な仕様に落とし込めない部分（テンプレートの HTML、フレームワークの内部挙動）に工数を取られる。
どこまでを仕様化・実装の対象とするかを決める必要がある。

上流ソース: <https://github.com/terasolunaorg/atrs> `JavaConfig-Thymeleaf/`、branch `release/5.11.0.RELEASE`、commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`。

## Decision Drivers

* 他言語へ同一ロジックを移植できること（最終目標）
* 業務的に意味のある振る舞い（運賃・空席・予約・会員・認証・レポート）を漏れなく捉えること
* フレームワーク固有の挙動に仕様が引きずられないこと

## Considered Options

* ドメイン + ユースケース + HTTP 契約（画面遷移と REST JSON）
* ドメイン + ユースケースのみ
* 画面（HTML）を含めた完全再現

## Decision Outcome

Chosen option: "ドメイン + ユースケース + HTTP 契約", because 業務ロジックの全体と、外部から観測できる入出力の契約までを言語中立に定義でき、HTML の見た目という移植価値の低い部分を除外できるため。

対象と対象外は次のとおり。

| 区分 | 対象 | 仕様 |
| --- | --- | --- |
| A1/A2 ログイン・ログアウト（ログイン状態の更新、資格情報の事前検査） | 対象 | [authentication.md](../spec/authentication.md) |
| B1 空席照会 | 対象 | [flight-search.md](../spec/flight-search.md) |
| B0/B2 フライト検証・予約 | 対象 | [reservation.md](../spec/reservation.md) |
| C1/C2 会員登録・会員情報変更 | 対象 | [member.md](../spec/member.md) |
| D1 予約履歴レポート（要求・生成・一覧・取得） | 対象 | [reservation-history-report.md](../spec/reservation-history-report.md) |
| フォーム入力検証（Bean Validation と相関検証の効果） | 対象 | [input-validation.md](../spec/input-validation.md) |
| 画面遷移（URL・メソッド・パラメータ・遷移先・エラー画面） | 対象（契約として） | [http-contract.md](../spec/http-contract.md) |
| REST API（`/api/v1/*`, `/api/flights` 等）の JSON 形状とステータス | 対象（契約として） | [http-contract.md](../spec/http-contract.md) |
| Thymeleaf テンプレートの HTML 構造・CSS・JavaScript | **対象外** | — |
| ログ出力の文言・形式、アクセスログ、MDC | **対象外**（ログ ID のみ参考として記録） | — |
| CSRF・トランザクショントークン・セッション Cookie の実装方式 | **対象外**（契約上の要件としてのみ記述） | [http-contract.md](../spec/http-contract.md) |
| パスワードハッシュのアルゴリズム実装 | **対象外**（ポートとして抽象化） | [ADR 2d1f](2d1f-password-hashing-port.md) |
| Selenium テスト、環境設定（Tomcat, ActiveMQ, PostgreSQL） | **対象外** | — |

### Consequences

* Good, because 仕様の大部分が純粋関数と状態遷移で書ける
* Good, because HTTP 契約があるので、他言語実装でも外形的な互換性を検証できる
* Bad, because 画面上の表示文言（ラベル・案内文）の一部は仕様から漏れる。必要になった場合は本 ADR を置換して範囲を広げる

### Confirmation

* [traceability.md](../spec/traceability.md) で、対象のすべての Java クラスが spec の節に対応付けられていることを確認する。

## Pros and Cons of the Options

### ドメイン + ユースケース + HTTP 契約

* Good, because 業務ロジックと外部契約の両方を言語中立に定義できる
* Bad, because Web 層の調査・記述の工数がかかる

### ドメイン + ユースケースのみ

* Good, because 最小の工数で始められる
* Bad, because 入力検証・画面遷移の業務規則（例: 搭乗者は最大 6 名、往復時は復路搭乗日必須）が仕様から漏れる

### 画面（HTML）を含めた完全再現

* Good, because 原典と見分けのつかない移植ができる
* Bad, because HTML・JavaScript は言語中立な仕様にしにくく、移植価値が低い

## More Information

* スコープ追加時は本 ADR を置換する新 ADR を作る（[decision-records.md](../rules/decision-records.md)）。
