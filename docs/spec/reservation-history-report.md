---
type: Specification
title: "予約履歴レポート（D1）"
description: "レポート作成要求の受付、非同期生成、CSV のバイト仕様、ファイル名、一覧と取得。"
tags: [spec, report, d1]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:52:11+09:00
---

# 予約履歴レポート（D1）

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。ただしキューの配信保証・ファイルの原子的な公開など実行環境の要件は [ports.md](ports.md) の規範節に従う。

非同期処理の構成は [ADR ff4d](../decision/ff4d-asynchronous-report-generation.md)、ポートは [ports.md](ports.md#reportqueue) を参照。
すべての操作は権限 `MEMBER` を要し、対象はログイン中の会員自身のレポートに限る。

## 作成要求（requestReport）

**[Spec=Source]** `ReportQueue.send(membershipNumber)` を行い、受付完了を返す。生成の完了を待たない。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `sendRequest`

## 要求の受信（onReportRequested）

**[Spec=Source]** キューから受け取ったメッセージ `msg` について:

1. `msg` が文字列でなければ無視する（ログ `w.ar.d1.L0002`）。
2. 文字列 `n` が無い、または長さが 10 でなければ無視する（ログ `w.ar.d1.L0003`）。
3. `createReport(n)` を行う。失敗した場合は、要求を再配信する（[ports.md](ports.md#reportqueue) の配信保証。[ADR 90f5](../decision/90f5-report-queue-at-least-once-delivery.md)）。原典はトランザクション付きの JMS セッションで受信し、例外時はロールバックしてブローカーが再配信する。

長さ 10 の判定は、[Spec] ではスカラ値、[Source] では UTF-16 単位で数える（既知差異 [D-006](abstraction.md#既知差異)）。

重複配信により、同じ会員について別の秒のレポートが 2 本できることがある。これは仕様上許される。

出典: atrs-web/.../listener/d1/ReservationHistoryReportListener.java

## レポート生成（createReport）

### 定義

1. `rows = ReservationRepository.findHistoryByRepresentative(n)`: 予約代表者の会員番号が `n` である予約と、その予約フライトの組の列。並び順は `(reserveNo 昇順, reserveFlightNo 昇順)`（文字列 `reserveNo` は 10 桁固定なので辞書順＝数値順）。
2. `name = reportFileName(n, now)`（`now` は `Clock` の現在日時）。
3. `bytes = renderCsv(rows)`。
4. `ReportStore.writeTemp("tmp_" ++ name, bytes)` の後、`ReportStore.publish(n, name)` で会員 `n` の領域へ原子的に移す。
5. 同名のレポートが既に存在する場合は `System("e.ar.d1.L0002")`（同一秒の再生成）。I/O 失敗も `System("e.ar.d1.L0002")`。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `createReport`, `generateReport`

### reportFileName

**[Spec=Source]** `reportFileName(n, now) = "atrs_report_" ++ n ++ "_" ++ fmtTimestamp(now) ++ ".csv"`

例: `atrs_report_0000000001_20261029213809.csv`

### renderCsv

**[Spec=Source]** 出力は UTF-8（BOM 無し）のバイト列で、各行の終わりに CRLF（`\r\n`）を置く。最終行の後にも CRLF を置く。

- ヘッダ行（固定）:

```
"Reserve No","Reservation Date","Total Fare","Reservation Flight Date","Reservation Flight No","Reservation Flight Name"
```

- データ行（`rows` の各要素 1 行）: 次の 6 項目をそれぞれ `"` で囲み `,` で連結する。値の中の `"` はエスケープしない（値に `"` が含まれないことは型により保証される。`FlightName` の前提は [domain-model.md](domain-model.md#コード値)）。

| 列 | 値 |
| --- | --- |
| Reserve No | `reserveNo` |
| Reservation Date | `fmtDate(reserveDate)`（`yyyy/MM/dd`） |
| Total Fare | `totalFare` の十進表記（区切り無し） |
| Reservation Flight Date | `fmtDate(departureDate)` |
| Reservation Flight No | `reserveFlightNo` の十進表記 |
| Reservation Flight Name | `flightName` |

列見出しの順と値の順が一致することに注意（原典の見出しは「Reservation Flight Date, No, Name」の順で、値も departureDate, reserveFlightNo, flightName の順）。

例（往復予約 1 件）:

```
"Reserve No","Reservation Date","Total Fare","Reservation Flight Date","Reservation Flight No","Reservation Flight Name"\r\n
"0000000001","2026/10/29","39200","2026/11/10","1","NTT001"\r\n
"0000000001","2026/10/29","39200","2026/11/12","2","NTT061"\r\n
```

出典: atrs-domain/.../repository/reservation/ReservationHistoryDto.java `toCsvLineString`, ReservationRepository.xml `findAllByMembershipNumberForReport`

## 一覧（listReports）

**[Spec=Source]** 会員 `n` の領域にあるファイル名の列を **降順**（Unicode スカラ値の辞書順の逆）で返す。領域が無ければ空列。ファイル名に時刻を含むため、新しいものが先頭になる。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `getExistingReportNameList`

## 取得（getReport）

**[Spec=Source]** `getReport(n, reportName)`:

- `reportName` が無い・空白のみ、または会員 `n` の領域に `reportName` と完全一致する名前のファイルが無ければ「無し」（ログ `w.ar.d1.L0001`、ダウンロード失敗画面）。
- あればその内容（`Content-Type: text/csv`, `Content-Disposition: attachment;filename=<reportName>`。ファイル名はクォートしない）。

存在確認は、会員 `n` の領域を列挙して得た各ファイル名と `reportName` の完全一致で行い、一致したときだけ領域内のそのファイルを読む。そのため `../` やパス区切りを含む名前は一致せず、他会員の領域は参照できない（[Spec=Source]。会員番号はログイン中の会員から取る）。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `getReportFilePath`, `checkReportExistence`
