import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.Schema

/-!
# SourceModel.Db.Tx

状態の表に対する計算（Mapper の文の実行・トランザクション・Clock の読み出し）と実行環境。原典のクラスではないので、
原典のソースツリーの外に置く（`SourceModel.Db.MyBatis` と同じ）。

- 計算は `EStateM JThrow St` で書く。例外で終わっても、その時点の状態（表とシーケンス）を返す。
- `sql f`: 行ロックを取る Mapper の文（更新・挿入・採番）を 1 回実行する。実行環境が、その文で I/O の失敗（N-002 に
  当たる）や排他の失敗（N-001 に当たる）を起こすと決めていれば、Spring の `DataAccessException` を投げる。文の SQL の
  エラーも、Spring の例外の変換で `DataAccessException` になる。
- `lockQuery f`: 行ロック付きの読み出し（`SELECT … FOR UPDATE`）。`sql` と同じく、I/O の失敗と排他の失敗を起こしうる。
- `query f`: 読むだけの文（行ロックを取らない）。I/O の失敗だけを起こしうる。行ロックを取らない文は、ロック待ちの
  タイムアウトやデッドロックによる排他の失敗を起こさない（ADR ab93 の 3d。予約確認は読むだけの文しか実行しない）。
- `transactional body`: `@Transactional` のメソッドの呼び出し。`body` が例外で終わったら、表を開始時に戻す（シーケンスは
  戻さない。`LangSemantics.Sql.Transaction.run`）。業務例外（`BusinessException`）も `RuntimeException` なので取り消す。
- `now`: `LocalDate.now(dateFactory.tick())`。実行環境の Clock の `i` 回目の読み出しの値を返す（既知差異 D-014）。

逐次の実行だけを写す。行ロック（`FOR UPDATE`）と分離レベル（READ COMMITTED）が並行実行で起こすこと（D-025）は写さない。
-/

namespace SourceModel.Db.Tx
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Sql.Core SourceModel.Db.Schema

/-- 実行環境: Clock の読み出しの値、I/O の失敗・排他の失敗を起こす文の位置（0 から数えた Mapper の文の実行の順）。 -/
structure Env where
  clock : Nat → JLocalDate
  ioFailAt : Option Nat := none
  conflictAt : Option Nat := none

/-- 障害の無い、Clock がいつも `today` を返す実行環境。 -/
def Env.fixed (today : JLocalDate) : Env := { clock := fun _ => today }

/-- 計算の状態: 表とシーケンス、実行環境、Clock の読み出しの回数、文の実行の回数。 -/
structure St where
  db : FlightDb
  env : Env
  clockReads : Nat := 0
  sqlCalls : Nat := 0

/-- 状態の表に対する計算。 -/
abbrev DbM := EStateM JThrow St

/-- I/O の失敗のときの例外のクラス（接続の失敗など）。 -/
def ioFailureClass : LangSemantics.Java.Exception.JClassName := cls!"org.springframework.dao.DataAccessResourceFailureException"
/-- 排他の失敗のときの例外のクラス（デッドロック・ロック待ちのタイムアウトなど）。 -/
def conflictClass : LangSemantics.Java.Exception.JClassName := cls!"org.springframework.dao.PessimisticLockingFailureException"
/-- 一意制約違反の例外のクラス。 -/
def duplicateKeyClass : LangSemantics.Java.Exception.JClassName := cls!"org.springframework.dao.DuplicateKeyException"
/-- その他の制約違反・値の範囲外の例外のクラス。 -/
def integrityClass : LangSemantics.Java.Exception.JClassName := cls!"org.springframework.dao.DataIntegrityViolationException"

/-- SQL のエラーを Spring の例外に変換する（`SQLErrorCodeSQLExceptionTranslator`）。 -/
@[source "dep:org.springframework:spring-jdbc#SQLErrorCodeSQLExceptionTranslator@spring-jdbc-7.0.3",
  "dep:org.mybatis:mybatis-spring#MyBatisExceptionTranslator@mybatis-spring-4.0.0"]
def translate : SqlError → JThrow
  | .uniqueViolation c => .other duplicateKeyClass c
  | e => .other integrityClass (reprStr e)

/-- `JResult` の計算を持ち上げる（状態を変えない）。 -/
def lift {α : Type} (r : JResult α) : DbM α :=
  match r with
  | .ok a => pure a
  | .error e => throw e

/-- Mapper の文を 1 回実行する。 -/
def sql {α : Type} (f : FlightDb → SqlResult (α × FlightDb)) : DbM α := do
  let s ← get
  let k := s.sqlCalls
  set { s with sqlCalls := k + 1 }
  if s.env.ioFailAt = some k then throw (.other ioFailureClass s!"I/O failure at statement {k}")
  if s.env.conflictAt = some k then throw (.other conflictClass s!"lock failure at statement {k}")
  match f s.db with
  | .ok (a, db') => modify fun s => { s with db := db' }; pure a
  | .error e => throw (translate e)

/-- 読むだけの文（行ロックを取らない）。I/O の失敗だけを起こしうる。 -/
def query {α : Type} (f : FlightDb → SqlResult α) : DbM α := do
  let s ← get
  let k := s.sqlCalls
  set { s with sqlCalls := k + 1 }
  if s.env.ioFailAt = some k then throw (.other ioFailureClass s!"I/O failure at statement {k}")
  match f s.db with
  | .ok a => pure a
  | .error e => throw (translate e)

/-- 行ロック付きの読み出し（`SELECT … FOR UPDATE`）。I/O の失敗と排他の失敗を起こしうる。 -/
def lockQuery {α : Type} (f : FlightDb → SqlResult α) : DbM α := sql fun db => (f db).map fun a => (a, db)

/-- `@Transactional` のメソッドの呼び出し。例外で終わったら、表を開始時に戻す（シーケンスは戻さない）。 -/
@[source "dep:org.springframework:spring-tx#Transactional@spring-tx-7.0.3"]
def transactional {α : Type} (body : DbM α) : DbM α :=
  LangSemantics.Sql.Transaction.run (fun s s' => { s' with db := FlightDb.rollback s.db s'.db }) body

/-- `LocalDate.now(dateFactory.tick())`。 -/
@[source "dep:org.terasoluna.gfw:terasoluna-gfw-common#ClockFactory.tick@terasoluna-gfw-common-5.11.0.RELEASE", gap "D-014"]
def now : DbM JLocalDate := do
  let s ← get
  set { s with clockReads := s.clockReads + 1 }
  pure (s.env.clock s.clockReads)

/-- 計算を実行する。 -/
def runOn {α : Type} (m : DbM α) (db : FlightDb) (env : Env) : JResult α × FlightDb :=
  match m.run { db, env } with
  | .ok a s => (.ok a, s.db)
  | .error e s => (.error e, s.db)

end SourceModel.Db.Tx
