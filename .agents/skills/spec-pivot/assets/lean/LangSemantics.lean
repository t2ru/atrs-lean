import LangSemantics.Core
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import LangSemantics.Rust

/-!
# LangSemantics

spec-pivot スキルが提供する、アプリに依存しない言語意味論モデル。
プロジェクトの Lean パッケージに `lean/LangSemantics/` として写して（または Lake の依存として）使う。

| 言語 | モジュール |
| --- | --- |
| 言語に依存しない列・`Option` の補題 | `LangSemantics.Core` |
| Java | `LangSemantics.Java` |
| SQL（共通） | `LangSemantics.Sql` |
| SQL（PostgreSQL 方言） | `LangSemantics.Sql.Postgresql` |
| Rust | `LangSemantics.Rust` |
-/
