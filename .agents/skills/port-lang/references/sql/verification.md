# SQL: 検証

## 移植元として

原典の SQL を `LangSemantics.Sql` の式として 1 文ずつ写し、`Abstraction` で、`Spec` の純粋関数と照会結果が一致することを証明する。
一致の前提（整列キーの単射性、マスタの不変条件など）を定理の仮定として明示する。

## 移植先として

- 移植先が SQL を使う場合、移植先の SQL も `LangSemantics.Sql` の式として `TargetModel.Repository.*` に写し、`Refinement` で `Spec` との一致を証明する。
- 実行する SQL と `TargetModel` の写しの対応は、追跡注釈（[locators.md](locators.md)）と `target-model/` のベクタで確認する。
- 移植元と移植先で DBMS が異なる場合は、両方の方言（`LangSemantics.Sql.<Dbms>`）で写し、方言の差（採番・型変換・照合順序）を `Refinement` の前提または証明課題として明示する。
- 並行実行の性質（直列化可能性）は Lean では扱わない。分離レベルとロックの設計レビューと、結合テストで確認する。

> **未整備:** 照会の同値性を自動で確かめる道具（例: SQL 同値性の検査器）の採用。
