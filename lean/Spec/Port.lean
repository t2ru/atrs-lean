/-!
# ポートと実行環境の要件（`Spec.Port`）

> **区分: 草案（draft）と規範（normative）の混在。** 節ごとに示す。この章には Lean の定義は無い。

ユースケースが外界に触れる口（ポート）のうち、リポジトリと採番は抽象状態 `World` に対する関数として
[`Spec.World`](World.lean) で定める。本章は、残りのポートと、`Spec` の関数として表せない実行環境への要件を定める。

| 節 | 内容 | 区分 |
| --- | --- | --- |
| [Clock](#clock) | 今日の日付と現在時刻。タイムゾーン | 草案。タイムゾーンは規範 |
| [PasswordHasher](#passwordhasher) | パスワードのハッシュと照合 | 草案 |
| [ReportStore](#reportstore) | レポートのファイルの保存と公開 | 草案。異常終了に対する公開の原子性は規範 |
| [ReportQueue](#reportqueue) | レポート作成要求のキュー | 草案。配信保証は規範 |
| [トランザクション](#トランザクション) | 原子性・直列化可能性、排他の失敗と I/O の失敗 | 規範（非決定的な結果は `Spec.Nondet` の要約） |

規範の節に書いた要件はリファインメントの証明の対象外で、確かめ方は [保証の限界](../../docs/spec/assurance.md) に挙げる。
-/

/-!
## Clock

**区分: 草案（draft）。** 規範の段落を除く。

| 操作 | 結果 |
| --- | --- |
| `today()` | Date |
| `now()` | DateTime（秒まで） |

[Spec] の各ユースケースは、初めに 1 回だけ `today()` を読み、その値を使う。[Source] は呼ぶたびに読むので、日付をまたぐ実行で異なりうる（既知差異 [D-014](../../docs/spec/abstraction.md#既知差異)）。

**規範（実行環境の要件）**: 本番の `Clock` アダプタは、現在時刻を **Asia/Tokyo**（UTC+9、夏時間なし）の暦日・時刻として返す。実行環境の既定のタイムゾーンに依存してはならない（[ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)。[Source] は JVM の既定のタイムゾーンで決める。既知差異 [D-023](../../docs/spec/abstraction.md#既知差異)）。テストでは任意の固定値を注入してよい。
-/

/-!
## PasswordHasher

**区分: 草案（draft）。** 会員・認証の機能（[`Spec.Member`](Member.lean)・[`Spec.Auth`](Auth.lean)）が使う。ハッシュの選び方は
`Spec` の非決定性 N-005（[`Spec.Nondet`](Nondet.lean)）である。

| 操作 | 契約 |
| --- | --- |
| `hash(raw)` | PasswordHash（非決定的でよい） |
| `matches(raw, hash)` | `matches(raw, hash(raw)) = true`。異なる `raw` では偽 |

この契約は理想化である。リファインメント定理はこの契約を仮定に置かず、各モデルのポート実装が契約を満たすことを証明する（証明課題 ABS-024・REF-008）。
- 参照実装（インメモリ）と各モデルの写し（raw について単射な符号化）は、この契約を厳密に満たす。
- 実際のハッシュ関数（原典の PBKDF2 など）は、衝突の確率が無視できる程度にしか満たさない。モデルとの違いは保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
-/

/-!
## ReportStore

**区分: 草案（draft）。** ただし `publish` の原子性のうち、プロセスの異常終了に対するもの（途中で止まっても、会員の領域に
書きかけのファイルが現れない）は **規範（normative）** である。論理的な原子性は、形式化するときに `Spec` で表す。
予約履歴レポート（[`Spec.Report`](Report.lean)）が使う。

| 操作 | 契約 |
| --- | --- |
| `writeTemp(name, bytes)` | 一時領域に書く |
| `publish(membershipNumber, name)` | 一時領域の `"tmp_" ++ name` を会員の領域の `name` へ原子的に移す。同名が既にあれば失敗 |
| `list(membershipNumber)` | 会員の領域のファイル名の集合（順序は呼び出し側で決める） |
| `read(membershipNumber, name)` | バイト列または無し |
-/

/-!
## ReportQueue

**区分: 草案（draft）。** ただし配信保証のうち、プロセスの異常終了をまたぐもの（要求を失わない）は **規範（normative）** で
ある。再配信の上限の選び方は `Spec` の非決定性（[`Spec.Nondet`](Nondet.lean)）で表す。

| 操作 | 契約 |
| --- | --- |
| `send(membershipNumber)` | 要求を末尾に追加する。呼び出し側のトランザクションとは独立 |
| 受信 | 1 件ずつ取り出し `onReportRequested`（[`Spec.Report`](Report.lean)）に渡す。同時に処理するのは 1 件 |

**規範（配信保証）**

- 少なくとも 1 回配信する。`onReportRequested` が失敗した要求は再配信する。
- 再配信の回数には上限を設ける。上限は 1 以上の値で、実装（配備の設定）が選ぶ。[Spec] はどの値も許す（抽象側の非決定性）。上限を超えた要求は破棄してログに残す。参考値は 10 回（原典が組み込みで使う ActiveMQ Artemis の既定 `maxDeliveryAttempts = 10`。デッドレターの宛先は設定されておらず、超えた要求は破棄される）。
- 同じ要求が重複して配信されてもよい。配信の順序は保証しない。
-/

/-!
## トランザクション

**区分: 規範（normative）。** 非決定的な結果（`Conflict`・I/O 失敗）は、[`Spec.Nondet`](Nondet.lean) の選択の型として形式化した
もの（N-001・N-002）の要約である。

**[Spec]** 状態を変更するユースケース（予約確定・会員登録・会員情報変更・ログイン/ログアウト状態更新・レポート生成）は、それぞれ原子的かつ直列化可能に実行されなければならない。この一覧を正とする。
会員情報変更は、現在パスワードの照合（[`Spec.Member`](Member.lean#現在パスワードの照合checkmemberpassword)）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-013](../../docs/spec/abstraction.md#既知差異)）。予約確定は、予約内容の検査（`validateReservation`）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-037](../../docs/spec/abstraction.md#既知差異)）。
移植先は、この性質を満たす限り任意の実装（RDB のトランザクション、単一スレッド、楽観ロック等）を選んでよい。
- 各モデル（`Spec`・`SourceModel`・`TargetModel`）では、各ユースケースを抽象機械の 1 つの操作として原子的に扱う。
- 実際の並行実行がどれかの逐次実行と一致することは、モデルの外の要件である。確認は確認課題 SRC-005（[refinement.md](../../docs/spec/refinement.md)）の決定論的な手段で行い、確かめきれない部分は保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
- [Source] は PostgreSQL の既定の分離レベル READ COMMITTED で動き、この要件を一般には満たさない（モデル外の既知差異 [D-025](../../docs/spec/abstraction.md#既知差異)）。

状態を変更するユースケースの [Spec] は、通常の結果に加えて、次の非決定的な結果を許す（[`Spec.Error`](Error.lean#分類atrserror)）。
- 出力は `Conflict`。
- `World.sequences` を除く状態は変わらない。

実装は、デッドロック・ロック待ちのタイムアウト・直列化失敗・楽観ロックの衝突を、再試行などで吸収できない場合に、この結果を選ぶ。実行可能な [Spec] の標準の選択は `Conflict` を選ばない。

同様に、ポートの I/O の失敗も、ポートの操作の非決定的な結果である。失敗しうる操作は、`FlightRepository`・`MemberRepository`・`ReservationRepository`・`IdGenerator` の全操作と、`ReportStore`・`ReportQueue` の全操作である。`Clock` と `PasswordHasher` は失敗しない。このとき、そのユースケースは次のようになる。
- 出力は `System("e.ar.fw.9999")`（I/O 失敗のコードは、この 1 つだけとする。他のコードの `System` は非決定的な結果に含まれない）。
- `World.sequences` を除く状態は変わらない。
- 標準の選択は、この結果を選ばない。

常に失敗を返す実装もリファインメントになる。活性は [assurance.md](../../docs/spec/assurance.md) の限界とする。
-/

/-!
## 根拠と対応

- 根拠: [ADR f0e4](../../docs/decision/f0e4-functional-core-with-ports.md)（純粋な核とポート）、
  [ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)（時計のタイムゾーン）、
  [ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)（パスワードのハッシュのポート）、
  [ADR 90f5](../../docs/decision/90f5-report-queue-at-least-once-delivery.md)（キューの配信保証）、
  [ADR 97f9](../../docs/decision/97f9-persistence-and-transaction-semantics.md)・
  [ADR 578b](../../docs/decision/578b-member-update-in-single-transaction.md)（トランザクションの範囲）、
  [ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md)（排他と I/O の失敗を非決定的な結果とする）
- 既知差異: D-013・D-014・D-023・D-025・D-037（[abstraction.md](../../docs/spec/abstraction.md#既知差異)）
- 規範の要件の確かめ方: [assurance.md](../../docs/spec/assurance.md)、確認課題 SRC-005（[refinement.md](../../docs/spec/refinement.md)）
-/
