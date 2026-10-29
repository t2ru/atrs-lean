import LangSemantics.Sql.Core

/-!
# LangSemantics.Sql.Query

照会と更新の意味論。行の集まりは **バッグ（多重集合）** であり、リストで表すが順序には意味が無い。
`ORDER BY` の結果は「許される順列の集合」として、判定関数 `isAllowedOrder` で与える。

lang: `lang:sql#ISO-9075-2-7.12`（query specification）, `lang:sql#ISO-9075-2-10.10`（sort specification）
-/

namespace LangSemantics.Sql

/-- 行の集まり（バッグ）。リストの順序に意味は無い。 -/
abbrev Bag (α : Type) := List α

namespace Bag

/-- 2 つのバッグが等しい（要素ごとの個数が一致する）か。 -/
def bagEq {α : Type} [BEq α] (a b : Bag α) : Bool :=
  a.length == b.length && a.all (fun x => a.count x == b.count x)

/-- `WHERE p`。 -/
def select {α : Type} (p : α → Truth) (rows : Bag α) : Bag α := rows.filter (fun r => (p r).holds)

/-- `SELECT f(row)`（射影）。 -/
def project {α β : Type} (f : α → β) (rows : Bag α) : Bag β := rows.map f

/-- 直積（`FROM a, b`）。 -/
def cross {α β : Type} (a : Bag α) (b : Bag β) : Bag (α × β) := a.flatMap (fun x => b.map (x, ·))

/-- 内部結合。 -/
def innerJoin {α β : Type} (on : α → β → Truth) (a : Bag α) (b : Bag β) : Bag (α × β) :=
  (cross a b).filter (fun p => (on p.1 p.2).holds)

/-- `SELECT EXISTS (…)`。 -/
def exists' {α : Type} (rows : Bag α) : Bool := !rows.isEmpty

/-- `COUNT(*)`。 -/
def countAll {α : Type} (rows : Bag α) : Nat := rows.length

end Bag

/-- 整列キーの 1 項目の向き。 -/
inductive SortDir where
  | asc
  | desc
  deriving Repr, BEq, DecidableEq

/-- 整列の設定（方言が与える）。 -/
structure SortConfig where
  collation : Collation
  /-- 昇順で NULL を先にするか（PostgreSQL は昇順で NULL が後）。 -/
  nullsFirstAsc : Bool

/-- 1 項目の比較（NULL の位置を含む）。 -/
def compareKey (cfg : SortConfig) (dir : SortDir) (a b : SqlValue) : Ordering :=
  let base : Ordering :=
    match a, b with
    | .null, .null => .eq
    | .null, _ => if cfg.nullsFirstAsc then .lt else .gt
    | _, .null => if cfg.nullsFirstAsc then .gt else .lt
    | _, _ => (a.cmp cfg.collation b).getD .eq
  match dir with
  | .asc => base
  | .desc => base.swap

/-- 複数項目の辞書式比較。 -/
def compareKeys (cfg : SortConfig) (dirs : List SortDir) : List SqlValue → List SqlValue → Ordering
  | a :: as, b :: bs =>
    match dirs with
    | d :: ds => match compareKey cfg d a b with
      | .eq => compareKeys cfg ds as bs
      | o => o
    | [] => .eq
  | _, _ => .eq

/-- `ORDER BY` の結果として `out` が許されるか: `rows` の並べ替えであり、整列キーについて非減少である。
キーが等しい行の相対順序は問わない（未規定）。 -/
def isAllowedOrder {α : Type} [BEq α] (cfg : SortConfig) (dirs : List SortDir)
    (key : α → List SqlValue) (rows out : List α) : Bool :=
  let sorted := (out.zip out.tail).all (fun p => compareKeys cfg dirs (key p.1) (key p.2) != .gt)
  Bag.bagEq rows out && sorted

/-- 許される順列のうちの 1 つ（挿入ソートによる安定整列）。テストや参照実装に使う。 -/
def orderByStable {α : Type} (cfg : SortConfig) (dirs : List SortDir) (key : α → List SqlValue)
    (rows : List α) : List α :=
  let insert (x : α) : List α → List α :=
    let rec go : List α → List α
      | [] => [x]
      | y :: ys => if compareKeys cfg dirs (key x) (key y) == .lt then x :: y :: ys else y :: go ys
    go
  rows.foldl (fun acc x => insert x acc) []

/-- `UPDATE … SET … WHERE p`。右辺 `set` は更新前の行で評価する。更新件数を返す。 -/
def updateWhere {α : Type} (p : α → Truth) (set : α → α) (rows : List α) : List α × Nat :=
  rows.foldr (fun r (acc, n) => if (p r).holds then (set r :: acc, n + 1) else (r :: acc, n)) ([], 0)

/-- `DELETE … WHERE p`。削除件数を返す。 -/
def deleteWhere {α : Type} (p : α → Truth) (rows : List α) : List α × Nat :=
  let kept := rows.filter (fun r => !(p r).holds)
  (kept, rows.length - kept.length)

/-- 主キー `pk` の一意性を保って挿入する。 -/
def insertUnique {α κ : Type} [BEq κ] (pk : α → κ) (constraintName : String) (row : α) (rows : List α) :
    SqlResult (List α) :=
  if rows.any (fun r => pk r == pk row) then .error (.uniqueViolation constraintName) else .ok (rows ++ [row])

end LangSemantics.Sql
