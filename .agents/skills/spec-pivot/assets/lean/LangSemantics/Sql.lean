import LangSemantics.Sql.Core
import LangSemantics.Sql.Query
import LangSemantics.Sql.Sequence
import LangSemantics.Sql.Transaction
import LangSemantics.Sql.QueryLemmas

/-!
# LangSemantics.Sql

SQL の言語意味論モデル（DBMS に依存しない共通部分）。方言は `LangSemantics.Sql.<Dbms>` に置く。
説明は spec-pivot スキルの `references/docs/lang/sql/semantics.md`。
-/
