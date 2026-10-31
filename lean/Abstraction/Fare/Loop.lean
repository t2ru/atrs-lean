import Abstraction.Fare.TotalAlpha
import Abstraction.Fare.Load
import Abstraction.Fare.BasicFareRefines

/-!
# Abstraction.Fare.Loop

`calculateTotalFare` の `for` 文（`forIn`）と、合計金額の R 課題（ABS-004）で使う補題。
-/

namespace Abstraction.Fare

open LangSemantics.Java Spec Spec.Prim Abstraction.Prim Abstraction.MasterData

/-- 2 つの列の要素ごとの関係（core に無いので置く）。 -/
inductive Forall₂ {α β : Type} (R : α → β → Prop) : List α → List β → Prop
  | nil : Forall₂ R [] []
  | cons {a : α} {b : β} {as : List α} {bs : List β} : R a b → Forall₂ R as bs → Forall₂ R (a :: as) (b :: bs)

theorem J32.ofInt_val (x : J32) : J32.ofInt x.val = x := by
  simp only [J32.ofInt, J32.val, BitVec.ofInt_toInt]

theorem j32add_ofInt {b : J32} {s v : Nat} (hb : b.val = s) (hr : s + v ≤ 2147483647) :
    (j32add b (J32.ofInt v)).val = ((s + v : Nat) : Int) := by
  have hv : (J32.ofInt v).val = v := J32.val_ofInt_of_inRange _ ⟨by simp only [J32.minValue]; omega,
    by simp only [J32.maxValue]; omega⟩
  rw [j32add_val_of_inRange _ _ (by rw [hb, hv]; simp only [J32.minValue, J32.maxValue]; omega), hb, hv]
  push_cast; rfl

/-- 和をとる `for` 文: 各要素の本体が、累積に `V k` を `int` で足す。 -/
theorem forIn_sum_eq {α κ ε : Type} {f : α → J32 → Except ε (ForInStep J32)} {V : κ → Nat} :
    ∀ (xs : List α) (ks : List κ) (init : J32) (s : Nat),
      Forall₂ (fun x k => ∀ b, f x b = .ok (.yield (j32add b (J32.ofInt (V k))))) xs ks →
      init.val = s → s + (ks.map V).sum ≤ 2147483647 →
      forIn xs init f = .ok (J32.ofInt ((s + (ks.map V).sum : Nat) : Int))
  | [], [], init, s, _, hi, _ => by
    simp only [List.forIn_nil, List.map_nil, List.sum_nil, Nat.add_zero, ← hi, J32.ofInt_val]; rfl
  | x :: xs, k :: ks, init, s, .cons hxk hr, hi, hb => by
    simp only [List.map_cons, List.sum_cons] at hb
    rw [List.forIn_cons, hxk init]
    show forIn xs (j32add init (J32.ofInt (V k))) f = _
    rw [forIn_sum_eq xs ks _ (s + V k) hr (j32add_ofInt hi (by omega)) (by omega)]
    simp only [List.map_cons, List.sum_cons, Nat.add_assoc]

/-- 数える `for` 文: 各要素の本体が、条件を満たせば累積に 1 を `int` で足す。 -/
theorem forIn_count_eq {α ε : Type} {f : α → J32 → Except ε (ForInStep J32)} {P : Nat → Bool} :
    ∀ (xs : List α) (ns : List Nat) (init : J32) (s : Nat),
      Forall₂ (fun x n => ∀ b, f x b = .ok (.yield (if P n then j32add b (J32.ofInt 1) else b))) xs ns →
      init.val = s → s + ns.length ≤ 2147483647 →
      forIn xs init f = .ok (J32.ofInt ((s + (ns.filter P).length : Nat) : Int))
  | [], [], init, s, _, hi, _ => by
    simp only [List.forIn_nil, List.filter_nil, List.length_nil, Nat.add_zero, ← hi, J32.ofInt_val]; rfl
  | x :: xs, n :: ns, init, s, .cons hxn hr, hi, hb => by
    simp only [List.length_cons] at hb
    rw [List.forIn_cons, hxn init]
    cases hP : P n
    · show forIn xs init f = _
      rw [forIn_count_eq xs ns init s hr hi (by omega)]
      simp only [List.filter_cons, hP]; rfl
    · show forIn xs (j32add init (J32.ofInt 1)) f = _
      have h1 : (j32add init (J32.ofInt 1)).val = ((s + 1 : Nat) : Int) := j32add_ofInt (v := 1) hi (by omega)
      rw [forIn_count_eq xs ns (j32add init (J32.ofInt 1)) (s + 1) hr h1 (by omega)]
      simp only [List.filter_cons, hP, ite_true, List.length_cons]
      congr 2; omega

/-- `mapM` で写した列と、各要素の関係。 -/
theorem forall₂_of_mapM {α β γ : Type} {g : α → Option β} {R : γ → β → Prop} (mk : α → γ) :
    ∀ (xs : List α) (ys : List β), xs.mapM g = some ys → (∀ x ∈ xs, ∀ y ∈ ys, g x = some y → R (mk x) y) →
      Forall₂ R (xs.map mk) ys
  | [], ys, h, _ => by
    simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; exact .nil
  | x :: xs, ys, h, hR => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, hy, ys', hys, hyy⟩ := h
    subst hyy
    exact .cons (hR x (List.mem_cons_self ..) y (List.mem_cons_self ..) hy)
      (forall₂_of_mapM mk xs ys' hys fun x' hx' y' hy' => hR x' (List.mem_cons_of_mem _ hx') y'
        (List.mem_cons_of_mem _ hy'))

theorem forall₂_of_mapM_id {α β : Type} {g : α → Option β} {R : α → β → Prop} (xs : List α) (ys : List β)
    (h : xs.mapM g = some ys) (hR : ∀ x ∈ xs, ∀ y ∈ ys, g x = some y → R x y) : Forall₂ R xs ys := by
  have := forall₂_of_mapM (R := R) id xs ys h hR
  rwa [List.map_id] at this

/-- `mapM` の結果は、各要素の値の列。 -/
theorem mapM_eq_map_getD {α β : Type} {g : α → Option β} (d : β) :
    ∀ {xs : List α} {ys : List β}, xs.mapM g = some ys → ys = xs.map fun x => (g x).getD d
  | [], ys, h => by simp only [List.mapM_nil, Option.pure_def, Option.some.injEq] at h; subst h; rfl
  | x :: xs, ys, h => by
    simp only [List.mapM_cons, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨y, hy, ys', hys, rfl⟩ := h
    simp only [List.map_cons, hy, Option.getD_some, mapM_eq_map_getD d hys]

theorem sum_map_le {α : Type} {V : α → Nat} {M : Nat} : ∀ (xs : List α), (∀ x ∈ xs, V x ≤ M) →
    (xs.map V).sum ≤ xs.length * M
  | [], _ => by simp
  | x :: xs, h => by
    have := sum_map_le xs fun y hy => h y (List.mem_cons_of_mem _ hy)
    have hx := h x (List.mem_cons_self ..)
    simp only [List.map_cons, List.sum_cons, List.length_cons, Nat.succ_mul]
    omega

end Abstraction.Fare

namespace Abstraction.Fare

open LangSemantics.Java Spec Spec.Prim Abstraction.Prim Abstraction.MasterData SourceModel.MasterData
  SourceModel.MasterQuery

/-- 読み込んだ Provider での `calculateBasicFare`: D-001 の前提の下で、[Spec] の基本運賃 `X·C/100` を返す。 -/
theorem calculateBasicFare_eq {db : SourceModel.Repository.Schema.MasterDb} {cfg : Config} {md : MasterData}
    (hm : masterDataOf db = some md) (hv : md.Valid cfg) {o : Order}
    (hppt : o.peakTime.Perm (SourceModel.Repository.MasterData.peakTimeFindAll db)) {p : Providers}
    (hpt : p.peakTime = PeakTimeProvider.load o.peakTime) {cd : BoardingClassCd} {bJ : SourceModel.Model.BoardingClass}
    (hget : p.boardingClass.boardingClassCodeMap.get cd = some bJ) {e : J32} (hex : bJ.extraCharge = some e)
    {ex : Nat} (heval : e.val = (ex : Int)) {rbJ : J32} {b : Nat} (hb : rbJ.val = (b : Int)) {dj : JLocalDate}
    {D : Spec.Prim.Date} (hD : dateOfJ dj = some D) (hX : b + ex ≤ 10000000)
    (hdev : (b + ex) * md.multiplicationRatioOn D % 100 ≠ 0 ∨ md.multiplicationRatioOn D ∉ unsafeBasicRatios) :
    ∃ v, SourceModel.Fare.calculateBasicFare p.shared rbJ (some cd) (some dj) = .ok v ∧
      v.val = (((b + ex) * md.multiplicationRatioOn D / 100 : Nat) : Int) := by
  obtain ⟨n, hn, hna⟩ := ratio_query hm hv.md4 hppt hD p.boardingClass
  simp only [answerOf?, Option.map_eq_some_iff, MasterData.Answer.ratio.injEq] at hna
  obtain ⟨c, hc, hcc⟩ := hna
  rw [natOfJ32_eq_some] at hc
  have hshared : p.shared = ⟨p.boardingClass, PeakTimeProvider.load o.peakTime⟩ := by
    rw [← hpt]; rfl
  have hadd : (j32add rbJ e).val = ((b + ex : Nat) : Int) := by
    rw [j32add_val_of_inRange _ _ (by simp only [J32.minValue, J32.maxValue]; omega), hb, heval]; push_cast; rfl
  have hc1000 := ratioOn_le hv.md8 D
  rw [← hcc] at hdev hc1000 ⊢
  have hr : (b + ex) * c < 100 * 2 ^ 28 :=
    Nat.lt_of_le_of_lt (Nat.mul_le_mul hX hc1000) (by decide)
  refine ⟨jd2i (jdmul (jd ((b + ex : Nat) : Int)) (basicFactor c)), ?_, basicFare_src_eq' hc1000 (by omega) hr hdev⟩
  simp only [SourceModel.Fare.calculateBasicFare, hshared]
  simp only [jAssert, hb, Option.isSome_some, decide_true, ite_true, ok_bind, Int.natCast_nonneg, ge_iff_le,
    getBoardingClass, pure_bind, hget, JRef.deref, hex]
  rw [hn]
  simp only [ok_bind, hadd, hc, basicFactor]
  rfl

/-- `calculateFare` の値（引数が非負で割引率が 100 以下）。 -/
theorem calculateFare_ok {bJ rJ : J32} {b r : Nat} (hb : bJ.val = (b : Int)) (hr : rJ.val = (r : Int)) (hr100 : r ≤ 100) :
    SourceModel.Fare.calculateFare bJ rJ =
      .ok (bdCeilHundredUp (jd2i (jdmul (jd (b : Int)) (fareFactor r)))) := by
  have e1 : jAssert (decide ((b : Int) ≥ 0)) "basicFare must be 0 or higher." = .ok () := by simp [jAssert]
  have e2 : jAssert (decide ((r : Int) ≥ 0)) "discountRate must be 0 or higher." = .ok () := by simp [jAssert]
  have e3 : jAssert (decide ((r : Int) ≤ 100)) "discountRate must be 100 or less." = .ok () := by
    simp [jAssert]; omega
  simp only [SourceModel.Fare.calculateFare, hb, hr, e1, e2, e3, ok_bind, SourceModel.Fare.ceilFare, fareFactor]
  rfl

end Abstraction.Fare
