/-!
# 用語集（`Spec.Glossary`）

> **区分: メタ情報（meta）。** 本書の用語と、Lean の識別子の対応を示す。定義は各章にある。

業務の用語は原典の日本語に合わせ、初めて使うところで英語の識別子を添える。識別子は Lean の型・関数・欄の名前で、
原典の Java の名前と同じ綴りのものが多い。

| 用語 | 識別子 | 説明 |
| --- | --- | --- |
| 空港 | `Airport` | 3 文字の空港コード（`HND` 等）と空港名、表示順を持つ |
| 区間（路線） | `Route` | 出発空港と到着空港の組。区間ごとに路線基本運賃を持つ |
| 路線基本運賃 | `Route.basicFare` | 区間に設定された運賃（円）。[`Spec.Fare`](Fare.lean) の入力 |
| 便 / 便マスタ | `FlightMaster` | 便名（`NTT001` 等）・区間・出発時刻・到着時刻・機材 |
| フライト | `Flight` | 搭乗日 × 便名 × 搭乗クラス × 運賃種別 ごとの空席数 |
| 搭乗日 | `departureDate`, `depDate` | フライトの出発日 |
| 搭乗クラス | `BoardingClass`, `BoardingClassCd` | 一般席 `N`、特別席 `S`。加算料金を持つ |
| 加算料金 | `BoardingClass.extraCharge` | 搭乗クラスごとに路線基本運賃に加える金額 |
| 運賃種別 | `FareType`, `FareTypeCd` | 片道運賃・往復運賃・予約割 等。割引率と予約可能期間を持つ |
| 割引率 | `FareType.discountRate` | 百分率の整数（30 は 30%） |
| 予約可能期間 | `rsrvAvailableStartDayNum`, `rsrvAvailableEndDayNum` | 搭乗日の何日前から何日前まで予約できるか |
| 利用可能最少人数 | `FareType.passengerMinNum` | グループ割等で必要な最少搭乗者数 |
| ピーク時期 | `PeakTime` | 期間と積算比率。期間内の搭乗日は運賃が割増される |
| 積算比率 | `PeakTime.multiplicationRatio` | 百分率の整数（140 は 1.4 倍）。ピーク時期外は 100 |
| 基本運賃 | `basicFare` | 路線基本運賃＋加算料金に積算比率を掛けたもの |
| 運賃 | `fare` | 基本運賃に割引率を適用し 100 円未満を切り上げたもの（大人 1 名分） |
| 合計金額 | `totalFare` | 予約全体の支払額 |
| 小児運賃比率 | `childFareRate` | 大人運賃に対する小児運賃の比率（%）。設定値 60 |
| フライト種別 | `FlightType` | 往復 `RT`、片道 `OW` |
| 往路 / 復路 | `OUTWARD` / `HOMEWARD`（`LineType`） | 往復予約の 1 便目 / 2 便目 |
| 照会可能限界日 | `searchLimitDate` | 今日 + 照会可能限界日数（`limitDay`） |
| 予約 | `Reservation` | 予約番号・予約日・合計金額・予約代表者情報と、予約の便と搭乗者（`ReserveFlights`。片道は 1 便、往復は往路・復路の 2 便で、搭乗者の列は便に共通） |
| 予約番号 | `ReserveNo`, `reserveNo` | 採番した自然数。表記は 10 桁にゼロ埋めした十進文字列（10^10 以上なら 11 桁以上。[Source] との違いは D-009） |
| 予約フライト | `ReserveFlight` | 予約に含まれる 1 便分。予約フライト番号とフライトの主キー。搭乗者番号は便ごとに搭乗者へ振る |
| 搭乗者 | `Passenger` | 姓名（カナ）・年齢・性別・会員番号（任意） |
| 予約代表者 | `rep*` | 予約の代表者。18 歳以上 |
| 会員 | `Member` | 会員番号・氏名（漢字/カナ）・生年月日・性別・連絡先・カード情報 |
| 会員番号 | `MembershipNumber`, `membershipNumber`（DB 列 `customer_no`） | 10 桁の数字文字列。ログイン ID |
| 会員ログイン情報 | `MemberLogin` | パスワードハッシュ・前回パスワード・ログイン日時・ログインフラグ |
| クレジットカード種別 | `CreditType` | `VIS`, `MTR`, `JCB`, `DNS`, `AMX` |
| 予約履歴レポート | — | 会員の予約履歴の CSV（[`Spec.Report`](Report.lean)） |
| 支払期限 | `paymentDate` | 往路搭乗日 |
| 業務エラー | `AtrsError.business` | 利用者の入力や状況により業務規則を満たさないエラー（[`Spec.Error`](Error.lean)） |
| 改竄検知 | `AtrsError.invalidRequest` | 画面から通常は送られない値（パラメータ改竄）の検知 |
| 抽象状態 | `World` | フライト・会員・予約・採番の状態（[`Spec.World`](World.lean)） |
| 環境 | `Config`, `MasterData` | 設定とマスタ。操作の間で変わらない入力（[`Spec.Env`](Env.lean)） |
-/
