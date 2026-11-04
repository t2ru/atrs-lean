/-!
# ポートと実行環境の要件（`Spec.Port`）

> **区分: 規範（normative）と草案（draft）の混在。** 節ごとに示す。

ユースケースが状態と外界に触れる口（ポート）のうち、抽象状態 `World` の関数として定めたもの（リポジトリ・採番）は
[`Spec.World`](World.lean) にある。本章は、それ以外のポート（時計・パスワードのハッシュ・レポートの保存と要求のキュー）の
契約と、`Spec` の関数として表せない実行環境への要件（タイムゾーン、ファイルの原子的な公開、配信保証、並行実行での
トランザクション）を定める。規範の節に書いた要件はリファインメントの証明の対象外で、確かめ方は
[保証の限界](../../docs/spec/assurance.md) に挙げる。
-/

/-!
## Clock

| 操作 | 結果 |
| --- | --- |
| `today()` | Date |
| `now()` | DateTime（秒まで） |

[Spec] の各ユースケースは、初めに 1 回だけ `today()` を読み、その値を使う。[Source] は呼ぶたびに読むので、日付をまたぐ実行で異なりうる（既知差異 [D-014](../../docs/spec/abstraction.md#既知差異)）。

**規範（実行環境の要件）**: 本番の `Clock` アダプタは、現在時刻を **Asia/Tokyo**（UTC+9、夏時間なし）の暦日・時刻として返す。実行環境の既定のタイムゾーンに依存してはならない（[ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)。[Source] は JVM の既定のタイムゾーンで決める。既知差異 [D-023](../../docs/spec/abstraction.md#既知差異)）。テストでは任意の固定値を注入してよい。
-/

/-!
## PasswordHasher

[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)。

| 操作 | 契約 |
| --- | --- |
| `hash(raw)` | PasswordHash（非決定的でよい） |
| `matches(raw, hash)` | `matches(raw, hash(raw)) = true`。異なる `raw` では偽 |

この契約は理想化である。リファインメント定理はこの契約を仮定に置かず、各モデルのポート実装が契約を満たすことを証明する（ABS-024・REF-008）。
- 参照実装（インメモリ）と各モデルの写し（raw について単射な符号化）は、この契約を厳密に満たす。
- 実際のハッシュ関数（原典の PBKDF2 など。[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)）は、衝突の確率が無視できる程度にしか満たさない。モデルとの違いは保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
-/

/-!
## ReportStore

| 操作 | 契約 |
| --- | --- |
| `writeTemp(name, bytes)` | 一時領域に書く |
| `publish(membershipNumber, name)` | 一時領域の `"tmp_" ++ name` を会員の領域の `name` へ原子的に移す。同名が既にあれば失敗 |
| `list(membershipNumber)` | 会員の領域のファイル名の集合（順序は呼び出し側で決める） |
| `read(membershipNumber, name)` | バイト列または無し |
-/

/-!
## ReportQueue

| 操作 | 契約 |
| --- | --- |
| `send(membershipNumber)` | 要求を末尾に追加する。呼び出し側のトランザクションとは独立 |
| 受信 | 1 件ずつ取り出し `onReportRequested`（[`Spec.Report`](Report.lean)）に渡す。同時に処理するのは 1 件 |

**規範（配信保証。[ADR 90f5](../../docs/decision/90f5-report-queue-at-least-once-delivery.md)）**

- 少なくとも 1 回配信する。`onReportRequested` が失敗した要求は再配信する。
- 再配信の回数には上限を設ける。上限は 1 以上の値で、実装（配備の設定）が選ぶ。[Spec] はどの値も許す（抽象側の非決定性）。上限を超えた要求は破棄してログに残す。参考値は 10 回（原典が組み込みで使う ActiveMQ Artemis の既定 `maxDeliveryAttempts = 10`。デッドレターの宛先は設定されておらず、超えた要求は破棄される）。
- 同じ要求が重複して配信されてもよい。配信の順序は保証しない。
-/

/-!
## トランザクション

**[Spec]** 状態を変更するユースケース（予約確定・会員登録・会員情報変更・ログイン/ログアウト状態更新・レポート生成）は、それぞれ原子的かつ直列化可能に実行されなければならない。この一覧を正とする（[ADR 97f9](../../docs/decision/97f9-persistence-and-transaction-semantics.md) の一覧にレポート生成を加えたもの。[ADR 578b](../../docs/decision/578b-member-update-in-single-transaction.md)）。
会員情報変更は、現在パスワードの照合（[`Spec.Member`](Member.lean#現在パスワードの照合checkmemberpassword)）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-013](../../docs/spec/abstraction.md#既知差異)）。予約確定は、予約内容の検査（`validateReservation`）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-037](../../docs/spec/abstraction.md#既知差異)）。
移植先は、この性質を満たす限り任意の実装（RDB のトランザクション、単一スレッド、楽観ロック等）を選んでよい。
- 各モデル（`Spec`・`SourceModel`・`TargetModel`）では、各ユースケースを抽象機械の 1 つの操作として原子的に扱う。
- 実際の並行実行がどれかの逐次実行と一致することは、モデルの外の要件である。確認は確認課題 SRC-005（[refinement.md](../../docs/spec/refinement.md)）の決定論的な手段で行い、確かめきれない部分は保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
- [Source] は PostgreSQL の既定の分離レベル READ COMMITTED で動き、この要件を一般には満たさない（モデル外の既知差異 [D-025](../../docs/spec/abstraction.md#既知差異)）。

状態を変更するユースケースの [Spec] は、通常の結果に加えて、次の非決定的な結果を許す（[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md)、[`Spec.Error`](Error.lean#分類atrserror)）。
- 出力は `Conflict`。
- `World.sequences` を除く状態は変わらない。

実装は、デッドロック・ロック待ちのタイムアウト・直列化失敗・楽観ロックの衝突を、再試行などで吸収できない場合に、この結果を選ぶ。実行可能な [Spec] の標準の選択は `Conflict` を選ばない。

同様に、ポートの I/O の失敗も、ポートの操作の非決定的な結果である。失敗しうる操作は、`FlightRepository`・`MemberRepository`・`ReservationRepository`・`IdGenerator` の全操作と、`ReportStore`・`ReportQueue` の全操作である。`Clock` と `PasswordHasher` は失敗しない。このとき、そのユースケースは次のようになる（[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md#実行環境の失敗)）。
- 出力は `System("e.ar.fw.9999")`（I/O 失敗のコードは、この 1 つだけとする。他のコードの `System` は非決定的な結果に含まれない）。
- `World.sequences` を除く状態は変わらない。
- 標準の選択は、この結果を選ばない。

常に失敗を返す実装もリファインメントになる。活性は [assurance.md](../../docs/spec/assurance.md) の限界とする。
-/
