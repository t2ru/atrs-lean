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

/-- N-001: 排他制御の失敗 `Conflict` が起きるか（環境）。起きると、採番以外の状態は変わらない（SPEC-004）。 -/
@[nondet "N-001", spec_doc "docs/spec/ports.md#トランザクション"]
inductive ConflictChoice where
  | none
  | conflict
  deriving DecidableEq, Repr

/-- 標準の値: 衝突は起きない。 -/
def ConflictChoice.std : ConflictChoice := .none

/-- N-002: ポートの I/O の失敗 `System("e.ar.fw.9999")` が起きるか（環境）。I/O 失敗のコードはこの 1 つだけである。 -/
@[nondet "N-002", spec_doc "docs/spec/ports.md#トランザクション"]
inductive IoFailureChoice where
  | none
  | failure
  deriving DecidableEq, Repr

/-- 標準の値: I/O は失敗しない。 -/
def IoFailureChoice.std : IoFailureChoice := .none

/-- N-003: レポート要求の配信（環境）。再配信の上限（1 以上。配備の設定）、次に配信する待ち行列の位置（配信の順序は
保証しない）、その要求を待ち行列に残したまま配信するか（重複配信）。 -/
@[nondet "N-003", spec_doc "docs/spec/ports.md#reportqueue"]
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
@[nondet "N-004", spec_doc "docs/spec/http-contract.md"]
structure InvalidRequestDetail where
  override : Option String
  deriving DecidableEq, Repr

/-- 標準の値: [Spec] の定義の詳細。 -/
def InvalidRequestDetail.std : InvalidRequestDetail := ⟨none⟩

/-- N-005: `PasswordHasher.hash` の値（自由）。`matches(raw, hash(raw)) = true` で、異なる `raw` では偽という契約は、
`hash` が単射であることで表す（`matches raw h := hash raw = h`）。変えうるのは保存するハッシュ値だけである。 -/
@[nondet "N-005", spec_doc "docs/spec/ports.md#passwordhasher"]
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
