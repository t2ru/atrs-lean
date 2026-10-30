import MachineTest.Nondet
import MachineTest.Counter
import MachineTest.Adequacy

/-!
# MachineTest.Axioms

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

/-- info: 'MachineTest.Nondet.halve_refines_chooseLe' depends on axioms: [propext] -/
#guard_msgs in
#print axioms MachineTest.Nondet.halve_refines_chooseLe

/-- info: 'MachineTest.Nondet.bagQuery_refines_anyOrder' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Nondet.bagQuery_refines_anyOrder

/-- info: 'MachineTest.Nondet.bagQuery_not_refines_fixedOrder' depends on axioms: [propext] -/
#guard_msgs in
#print axioms MachineTest.Nondet.bagQuery_not_refines_fixedOrder

/-- info: 'MachineTest.Nondet.bagQuery_refines_fixedOrder_mod_order' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Nondet.bagQuery_refines_fixedOrder_mod_order

/-- info: 'MachineTest.Nondet.succWithHeader_not_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Nondet.succWithHeader_not_refines

/-- info: 'MachineTest.Nondet.succWithHeader_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Nondet.succWithHeader_refines

/-- info: 'MachineTest.Nondet.succConcrete_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Nondet.succConcrete_refines

/-- info: 'MachineTest.Counter.counter_sound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms MachineTest.Counter.counter_sound

/-- info: 'MachineTest.Counter.counter8_not_refines' does not depend on any axioms -/
#guard_msgs in
#print axioms MachineTest.Counter.counter8_not_refines

/-- info: 'MachineTest.Counter.counter8_refines' depends on axioms: [propext] -/
#guard_msgs in
#print axioms MachineTest.Counter.counter8_refines

/-- info: 'MachineTest.Counter.counter8_refines_trans' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms MachineTest.Counter.counter8_refines_trans

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
