import Trace

/-!
# Spec.Nondet

[Spec] が許す非決定性（`docs/spec/abstraction.md#spec-の非決定性n-nnn`）の選択の型と、標準の値。
各型に `@[nondet "N-NNN"]` を 1 つ付ける（SPEC-005。登録簿との 1 対 1 は TR-N で検査する）。

- **環境の選択**（N-001〜N-003）: 実行環境が決める。[Source]・[Target] では入力の環境の成分として表し、`Pinned` で
  固定する。標準の値は、障害の無い環境・参照の配備の設定の値である。
- **自由な選択**（N-004・N-005）: 実装が決めてよい。標準の選択 `run` は標準の値を選ぶ。自由な選択が変えうる部分は、
  各機能の機械で `FreeFrame` の射影の核として示す。

`Machine.ofChoice` の選択の型 `E × F` は、各機能の機械が、使う葉の型だけを積（`×`）で組み合わせて作る
（例: 予約確定は `ConflictChoice × IoFailureChoice` と `Unit`）。標準の値は、各葉の `std` の組である。
-/

namespace Spec.Nondet

/-- 失敗したユースケースの中で進んだ採番の数（会員・予約・予約フライト・搭乗者）。採番は失敗したトランザクションでも
巻き戻らない（`lean/Spec/Port.lean#idgenerator`）。N-001・N-002 の選択の成分（backlog aedf。プロジェクトオーナーの確認待ち）。 -/
structure SeqAdvance where
  member : Nat := 0
  reserve : Nat := 0
  reserveFlight : Nat := 0
  passenger : Nat := 0
  deriving DecidableEq, Repr

/-- N-001: 排他制御の失敗 `Conflict` が起きるか（環境）。起きると、採番以外の状態は変わらない（SPEC-004）。
採番は、失敗するまでに進んだ数（`adv`）だけ進む。 -/
@[nondet "N-001", spec_doc "lean/Spec/Port.lean#トランザクション"]
inductive ConflictChoice where
  | none
  | conflict (adv : SeqAdvance := {})
  deriving DecidableEq, Repr

/-- 標準の値: 衝突は起きない。 -/
def ConflictChoice.std : ConflictChoice := .none

/-- N-002: ポートの I/O の失敗 `System("e.ar.fw.9999")` が起きるか（環境）。I/O 失敗のコードはこの 1 つだけである。 -/
@[nondet "N-002", spec_doc "lean/Spec/Port.lean#トランザクション"]
inductive IoFailureChoice where
  | none
  | failure (adv : SeqAdvance := {})
  deriving DecidableEq, Repr

/-- 標準の値: I/O は失敗しない。 -/
def IoFailureChoice.std : IoFailureChoice := .none

/-- 障害の位置の記述（環境の選択 N-001・N-002 のうち、実行環境が前もって決める部分）: I/O の失敗の位置と、排他の失敗の
位置。位置が無ければ、その障害は起きない。位置があっても、障害が実際に起きるかと、起きるまでに進んだ採番は、実行で
決まる（ADR ab93 の 3d・スキル spec-pivot の ADR 61e6）。 -/
abbrev FaultSpec := Option Nat × Option Nat

/-- 障害の位置の記述 `d` が許す環境の選択: I/O の失敗の位置が無ければ I/O の失敗を選ばず、排他の失敗の位置が無ければ
衝突を選ばない。 -/
@[spec_doc "lean/Spec/Port.lean#トランザクション"]
def admits (d : FaultSpec) (e : ConflictChoice × IoFailureChoice) : Prop :=
  (d.1 = none → e.2 = .none) ∧ (d.2 = none → e.1 = .none)

/-- 障害の位置の無い記述が許すのは、標準の環境の選択だけ。 -/
theorem admits_none {e : ConflictChoice × IoFailureChoice} (h : admits (none, none) e) :
    e = (ConflictChoice.std, IoFailureChoice.std) := by
  obtain ⟨h1, h2⟩ := h
  have e1 := h1 rfl
  have e2 := h2 rfl
  cases e
  simp only at e1 e2
  rw [e1, e2]
  rfl

/-- N-003: レポート要求の配信（環境）。再配信の上限（1 以上。配備の設定）、次に配信する待ち行列の位置（配信の順序は
保証しない）、その要求を待ち行列に残したまま配信するか（重複配信）。 -/
@[nondet "N-003", spec_doc "lean/Spec/Port.lean#reportqueue"]
structure ReportDeliveryChoice where
  retryLimit : Nat
  retryLimit_pos : 1 ≤ retryLimit
  next : Nat
  duplicate : Bool

instance : DecidableEq ReportDeliveryChoice := fun a b =>
  if h : a.retryLimit = b.retryLimit ∧ a.next = b.next ∧ a.duplicate = b.duplicate then
    isTrue (by cases a; cases b; obtain ⟨h1, h2, h3⟩ := h; simp_all)
  else isFalse (by intro e; subst e; exact h ⟨rfl, rfl, rfl⟩)

/-- 標準の値: 上限は参考値の 10（ActiveMQ Artemis の既定 `maxDeliveryAttempts`）、先頭（送信順）、重複なし。 -/
def ReportDeliveryChoice.std : ReportDeliveryChoice := ⟨10, by decide, 0, false⟩

/-- N-004: `InvalidRequest` のメッセージの詳細（自由）。`none` なら [Spec] の各操作が定める詳細、`some s` なら任意の文字列 `s`。
変えうるのは詳細の文字列だけである。 -/
@[nondet "N-004", spec_doc "lean/Spec/Http.lean"]
structure InvalidRequestDetail where
  override : Option String
  deriving DecidableEq, Repr

/-- 標準の値: [Spec] の定義の詳細。 -/
def InvalidRequestDetail.std : InvalidRequestDetail := ⟨none⟩

/-- N-005: `PasswordHasher.hash` の値（自由）。`matches(raw, hash(raw)) = true` で、異なる `raw` では偽という契約は、
`hash` が単射であることで表す（`matches raw h := hash raw = h`）。変えうるのは保存するハッシュ値だけである。 -/
@[nondet "N-005", spec_doc "lean/Spec/Port.lean#passwordhasher"]
structure PasswordHashChoice where
  hash : String → String
  injective : ∀ a b, hash a = hash b → a = b

/-- 標準の値: 参照の符号化 `"{test}" ++ raw`（ADR 2d1f の参照アダプタの例）。 -/
def PasswordHashChoice.std : PasswordHashChoice where
  hash raw := "{test}" ++ raw
  injective a b h := by
    have := congrArg String.toList h
    simp only [String.toList_append] at this
    exact String.ext (List.append_cancel_left this)

end Spec.Nondet
