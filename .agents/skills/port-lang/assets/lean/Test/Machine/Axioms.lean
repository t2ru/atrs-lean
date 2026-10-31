import Test.Machine.Nondet
import Test.Machine.Counter
import Test.Machine.Adequacy

/-!
# Test.Machine.Axioms

`Machine` の補題と例が、`propext`・`Classical.choice`・`Quot.sound` 以外の公理に依存しないことを
`#guard_msgs` で固定する。
-/

/-- info: 'Machine.Refines.refl' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.refl

/-- info: 'Machine.Refines.trans' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Machine.Refines.trans

/-- info: 'Machine.Refines.of_pure' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.of_pure

/-- info: 'Machine.Refines.restrict' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.restrict

/-- info: 'Machine.Refines.restrictConcrete' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.restrictConcrete

/-- info: 'Machine.Machine.Sound.restrict' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Machine.Sound.restrict

/-- info: 'Test.Machine.Nondet.halve_refines_chooseLe' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Test.Machine.Nondet.halve_refines_chooseLe

/-- info: 'Test.Machine.Nondet.bagQuery_refines_anyOrder' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Nondet.bagQuery_refines_anyOrder

/-- info: 'Test.Machine.Nondet.bagQuery_not_refines_fixedOrder' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Test.Machine.Nondet.bagQuery_not_refines_fixedOrder

/-- info: 'Test.Machine.Nondet.bagQuery_refines_fixedOrder_mod_order' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Nondet.bagQuery_refines_fixedOrder_mod_order

/-- info: 'Test.Machine.Nondet.succWithHeader_not_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Nondet.succWithHeader_not_refines

/-- info: 'Test.Machine.Nondet.succWithHeader_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Nondet.succWithHeader_refines

/-- info: 'Test.Machine.Nondet.succConcrete_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Nondet.succConcrete_refines

/-- info: 'Test.Machine.Counter.counter_sound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms Test.Machine.Counter.counter_sound

/-- info: 'Test.Machine.Counter.counter8_not_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms Test.Machine.Counter.counter8_not_refines

/-- info: 'Test.Machine.Counter.counter8_refines' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Test.Machine.Counter.counter8_refines

/-- info: 'Test.Machine.Counter.counter8_refines_trans' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Test.Machine.Counter.counter8_refines_trans

/-- info: 'Machine.Refines.run' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.run

/-- info: 'Machine.Refines.complete' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.complete

/-- info: 'Machine.Refines.congr' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.congr

/-- info: 'Machine.Refines.Pinned.correct' does not depend on any axioms -/
#guard_msgs in
#print axioms Machine.Refines.Pinned.correct

/-- info: 'Machine.Glue.ofStd_input_total' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Machine.Glue.ofStd_input_total
