/-!
# 予約履歴レポート（`Spec.Report`）

> **区分: 草案（draft）。** まだ Lean に形式化していない。形式化するときは、この章に定義を足し、本文を要約に書き換える。キューの配信保証・ファイルの原子的な公開など実行環境の要件は [`Spec.Port`](Port.lean) の規範節に従う。

会員が自分の予約の履歴を CSV のレポートとして作成・一覧・取得する機能（画面 D1）を定める。作成は非同期で、要求を
キュー（[`ReportQueue`](Port.lean#reportqueue)）に送り、受信側がレポートを生成して保存する（[`ReportStore`](Port.lean#reportstore)）。
すべての操作は権限 `MEMBER` を要し、対象はログイン中の会員自身のレポートに限る。
-/

/-!
## 作成要求（requestReport）

**[Spec=Source]** `ReportQueue.send(membershipNumber)` を行い、受付完了を返す。生成の完了を待たない。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `sendRequest`
-/

/-!
## 要求の受信（onReportRequested）

**[Spec=Source]** キューから受け取ったメッセージ `msg` について:

1. `msg` が文字列でなければ無視する（ログ `w.ar.d1.L0002`）。
2. 文字列 `n` が無い、または長さが 10 でなければ無視する（ログ `w.ar.d1.L0003`）。
3. `createReport(n)` を行う。失敗した場合は、要求を再配信する（[`Spec.Port`](Port.lean#reportqueue) の配信保証）。原典はトランザクション付きの JMS セッションで受信し、例外時はロールバックしてブローカーが再配信する。

長さ 10 の判定は、[Spec] ではスカラ値、[Source] では UTF-16 単位で数える（既知差異 [D-006](../../docs/spec/abstraction.md#既知差異)）。

重複配信により、同じ会員について別の秒のレポートが 2 本できることがある。これは仕様上許される。

出典: atrs-web/.../listener/d1/ReservationHistoryReportListener.java
-/

/-!
## レポート生成（createReport）

### 定義

1. `rows = ReservationRepository.findHistoryByRepresentative(n)`: 予約代表者の会員番号が `n` である予約と、その予約フライトの組の列。並び順は `(reserveNo の値の昇順, reserveFlightNo 昇順)`（予約番号の値は採番の自然数。表記が 10 桁の範囲では、表記の辞書順と一致する。10 桁を超える予約番号は [Source] では採番されない。既知差異 [D-009](../../docs/spec/abstraction.md#既知差異)）。
2. `name = reportFileName(n, now)`（`now` は `Clock` の現在日時）。
3. `bytes = renderCsv(rows)`。
4. `ReportStore.writeTemp("tmp_" ++ name, bytes)` の後、`ReportStore.publish(n, name)` で会員 `n` の領域へ原子的に移す。
5. 同名のレポートが既に存在する場合は `System("e.ar.d1.L0002")`（同一秒の再生成）。I/O 失敗も `System("e.ar.d1.L0002")`。

> **TODO(spec):** I/O 失敗のコード `e.ar.d1.L0002` は、[`Spec.Port`](Port.lean#トランザクション) の規範（ポートの I/O 失敗の出力は `System("e.ar.fw.9999")` の 1 つだけ）と食い違う。同名のレポートがあるときのコードとあわせて、どちらに合わせるかを決める。

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

- データ行（`rows` の各要素 1 行）: 次の 6 項目をそれぞれ `"` で囲み `,` で連結する。値の中の `"` はエスケープしない（値に `"` が含まれないことは型により保証される。`FlightName` の前提は [`Spec.Model`](Model.lean#コード値)）。

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
-/

/-!
## 一覧（listReports）

**[Spec=Source]** 会員 `n` の領域にあるファイル名の列を **降順**（Unicode スカラ値の辞書順の逆）で返す。領域が無ければ空列。ファイル名に時刻を含むため、新しいものが先頭になる。[Source] は `String` の順（UTF-16 の符号単位の順）で並べるので、補助文字と U+E000〜U+FFFF の文字を含むファイル名で並びが異なる（既知差異 [D-006](../../docs/spec/abstraction.md#既知差異)）。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `getExistingReportNameList`
-/

/-!
## 取得（getReport）

**[Spec=Source]** `getReport(n, reportName)`:

- `reportName` が無い・空白のみ、または会員 `n` の領域に `reportName` と完全一致する名前のファイルが無ければ「無し」（ログ `w.ar.d1.L0001`、ダウンロード失敗画面）。
- あればその内容（`Content-Type: text/csv`, `Content-Disposition: attachment;filename=<reportName>`。ファイル名はクォートしない）。

存在確認は、会員 `n` の領域を列挙して得た各ファイル名と `reportName` の完全一致で行い、一致したときだけ領域内のそのファイルを読む。そのため `../` やパス区切りを含む名前は一致せず、他会員の領域は参照できない（[Spec=Source]。会員番号はログイン中の会員から取る）。

出典: atrs-domain/.../service/d1/ReservationHistoryReportServiceImpl.java `getReportFilePath`, `checkReportExistence`
-/

/-!
## 根拠と対応

- 根拠: [ADR ff4d](../../docs/decision/ff4d-asynchronous-report-generation.md)（非同期のレポート生成）、[ADR 90f5](../../docs/decision/90f5-report-queue-at-least-once-delivery.md)（要求のキューの配信保証）。
- 既知差異: D-006・D-009（[一覧](../../docs/spec/abstraction.md#既知差異)）。
-/
