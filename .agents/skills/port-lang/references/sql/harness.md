# SQL: ベクタの実行

SQL は単独では実行されず、呼び出し側の言語のハーネスの中で実行される。ここでは、データベースを含むベクタの実行条件を定める。

## 共通

- ベクタの `world`（実行前の状態）からテーブルを作り、データを投入する。実行後の状態を `worldAfter` と比べる。
- DBMS の版・照合順序・タイムゾーンを固定する。具体的な設定は方言パックの `harness.md` に従う。

| DBMS | 方言パック |
| --- | --- |
| PostgreSQL | [dialects/postgresql/harness.md](dialects/postgresql/harness.md) |

- 採番の初期値は `world` で指定する。

## 差分実行の結果

`LangSemantics.Sql` の写しと DBMS の実行結果を同じデータで照合するには、DBMS で実行した結果を JSON に保存し、
Lean のテストで写しの評価結果と比べる（再生成して差分が無いことを CI で確かめる）。形は次のとおりである。

```json
{
  "upstream": { "release": "…", "commit": "…" },
  "postgresql": "16.15",
  "loadTimestamp": "2026-01-01T00:00:00",
  "tables": { "<表>": { "columns": ["<列>", …], "rows": [["値" | null, …], …] } },
  "statements": [
    { "id": "<文の ID>", "locator": "sql:<…>", "sql": "<実行した文>", "ordered": false,
      "columns": ["<列>", …], "rows": [["値" | null, …], …] }
  ]
}
```

- 値は、DBMS の文字列表現（`null` は SQL の NULL）とする。数値・日付も文字列のまま保存し、読み取り側で型の範囲を検査する。
- `ordered` が `false` の文の結果はバッグとして比べる。`true` の文（`ORDER BY` の同順位が無いもの）は列として比べる。同順位がありうる文は、許される順列（`isAllowedOrder`）の中にあることを比べる。
- `tables` は投入したデータで、共有入力（`conformance/fixtures/`）と一致することも確かめる。
- Lean での読み取りには、スキルの `ConformanceKit.SqlTable`（`table`・`col`・`vcol`・`icol`）を使う。

## 移植元として

- 呼び出し側（例: Java のハーネス）が原典の SQL をそのまま実行する。`ORDER BY` の同順位のように非決定的な結果は、ベクタの `{"oneOf": […]}` で受ける。
- 差分オラクルでは、新旧 2 版の SQL を同じ `world` に対して実行する。DBMS の版も変わる場合は、新旧それぞれの版の DBMS で実行する。

## 移植先として

- 移植先の SQL を、`target-model/` のベクタで照合する。照合は呼び出し側の言語のテストとして実装する。
- 移植元と移植先で DBMS が異なる場合（例: PostgreSQL から別の DBMS へ）は、両方の方言パックを使い、`Spec` と一致しなくなる方言の差を、移植先の既知差異 `T-NNN` として扱う（[verification.md](verification.md)）。

> **未整備:** SQL だけを対象にした独立のハーネス（SQL ファイルとベクタを直接結ぶ形式）。
