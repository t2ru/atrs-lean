#!/usr/bin/env python3
"""LangSemantics.Sql と PostgreSQL の突き合わせ表の生成器。

    uv run python -I pg_table.py [--expect-version 16.15] > ../PostgresqlDb.lean

接続先は psql の環境変数（PGHOST・PGPORT・PGUSER・PGDATABASE）で与える。データベースは照合順序 C・
UTF8 で、セッションのタイムゾーンは UTC とする（references/docs/lang/sql/dialects/postgresql/harness.md）。
固定の入力について PostgreSQL で値を計算し、Lean の `#guard` 行を標準出力に書く。出力はコミットし、
CI で再生成して差分が無いことを確かめる。出力に処理系の版は含めない。
"""
import csv
import io
import os
import subprocess
import sys

NULL = "\\N"


def psql(sql: str):
    """1 文を実行する。成功なら行のリスト（各行は値のリスト、NULL は None）、失敗なら SQLSTATE。"""
    env = dict(os.environ, PGTZ="UTC", PGCLIENTENCODING="UTF8")
    r = subprocess.run(
        ["psql", "-X", "-q", "--csv", "-t", "-P", f"null={NULL}", "-v", "ON_ERROR_STOP=1",
         "-c", "\\set VERBOSITY sqlstate", "-c", sql],
        capture_output=True, text=True, encoding="utf-8", env=env)
    if r.returncode != 0:
        err = r.stderr.strip().splitlines()
        return ("error", err[-1] if err else "?")
    # NULL は \N と表示する。1 列の空文字列は空行になる（csv.reader は [] を返す）
    rows = [[None if v == NULL else v for v in (rec or [""])] for rec in csv.reader(io.StringIO(r.stdout))]
    return ("ok", rows)


def one(sql: str):
    st, rows = psql(sql)
    if st != "ok" or len(rows) != 1 or len(rows[0]) != 1:
        sys.exit(f"pg_table.py: unexpected result for {sql!r}: {st} {rows}")
    return rows[0][0]


out = []


def line(s=""):
    out.append(s)


def lean_str(s: str) -> str:
    b = ['"']
    for ch in s:
        cp = ord(ch)
        if ch == '"':
            b.append('\\"')
        elif ch == "\\":
            b.append("\\\\")
        elif cp < 0x20 or cp == 0x7F:
            b.append(f"\\x{cp:02x}")
        else:
            b.append(ch)
    b.append('"')
    return "".join(b)


def lean_int(v: int) -> str:
    return f"({v})" if v < 0 else str(v)


def sql_lit(v):
    """Lean の SqlValue（タグ付き）を SQL のリテラルに。"""
    tag, x = v
    if tag == "null":
        return "NULL"
    if tag == "int":
        return f"({x})::int8"
    if tag == "text":
        return "'" + x.replace("'", "''") + "'::text"
    if tag == "bool":
        return "TRUE" if x else "FALSE"
    raise ValueError(tag)


def lean_val(v):
    tag, x = v
    if tag == "null":
        return ".null"
    if tag == "int":
        return f"(.int {lean_int(x)})"
    if tag == "text":
        return f"(.text {lean_str(x)})"
    if tag == "bool":
        return f"(.bool {'true' if x else 'false'})"
    raise ValueError(tag)


def truth_of(s):
    return {None: ".unknown", "t": ".true", "f": ".false"}[s]


def three_valued():
    line()
    line("/-! ## 三値論理 -/")
    line()
    tv = [("TRUE", ".true"), ("FALSE", ".false"), ("NULL::boolean", ".unknown")]
    for a, la in tv:
        line(f"#guard Truth.not {la} == {truth_of(one(f'SELECT NOT {a}'))}")
        for b, lb in tv:
            line(f"#guard Truth.and {la} {lb} == {truth_of(one(f'SELECT {a} AND {b}'))}")
            line(f"#guard Truth.or {la} {lb} == {truth_of(one(f'SELECT {a} OR {b}'))}")


def comparisons():
    line()
    line("/-! ## 比較・BETWEEN・IN・IS NULL（照合順序 C） -/")
    line()
    vals = [("int", 1), ("int", 2), ("int", -5), ("null", None), ("text", "a"), ("text", "B"), ("text", "ab"),
            ("text", ""), ("text", "あ"), ("text", "𠮷"), ("bool", True), ("bool", False)]
    ops = [("=", "SqlValue.eq"), ("<", "SqlValue.lt"), ("<=", "SqlValue.le")]
    for a in vals:
        for b in vals:
            if a[0] != b[0] and "null" not in (a[0], b[0]):
                continue  # 型の異なる比較は SQL では型エラー（方言の暗黙の変換は扱わない）
            for op, f in ops:
                r = one(f"SELECT {sql_lit(a)} {op} {sql_lit(b)}")
                line(f"#guard {f} coll {lean_val(a)} {lean_val(b)} == {truth_of(r)}")
    triples = [(("int", 5), ("int", 1), ("int", 10)), (("int", 1), ("int", 1), ("int", 10)), (("int", 10), ("int", 1), ("int", 10)),
               (("int", 0), ("int", 1), ("int", 10)), (("int", 11), ("int", 1), ("int", 10)), (("int", 5), ("int", 10), ("int", 1)),
               (("null", None), ("int", 1), ("int", 10)), (("int", 5), ("null", None), ("int", 10)), (("int", 0), ("null", None), ("int", 10)),
               (("text", "b"), ("text", "a"), ("text", "c")), (("text", "B"), ("text", "a"), ("text", "c"))]
    for x, lo, hi in triples:
        r = one(f"SELECT {sql_lit(x)} BETWEEN {sql_lit(lo)} AND {sql_lit(hi)}")
        line(f"#guard between coll {lean_val(x)} {lean_val(lo)} {lean_val(hi)} == {truth_of(r)}")
    ins = [(("int", 1), [("int", 1), ("int", 2)]), (("int", 3), [("int", 1), ("int", 2)]), (("int", 3), [("int", 1), ("null", None)]),
           (("int", 1), [("int", 1), ("null", None)]), (("null", None), [("int", 1)]), (("text", "a"), [("text", "A"), ("text", "a")])]
    for x, vs in ins:
        r = one(f"SELECT {sql_lit(x)} IN ({', '.join(sql_lit(v) for v in vs)})")
        line(f"#guard inList coll {lean_val(x)} [{', '.join(lean_val(v) for v in vs)}] == {truth_of(r)}")
    for x in [("int", 1), ("null", None), ("text", "")]:
        r = one(f"SELECT {sql_lit(x)} IS NULL")
        line(f"#guard isNull {lean_val(x)} == {truth_of(r)}")


def order_by():
    line()
    line("/-! ## ORDER BY（同順位・NULL の位置・照合順序 C） -/")
    line()
    # 行は (id, k1, k2)。PostgreSQL の結果の id の並びが、Lean の許される順列に含まれることを確かめる。
    data = [(1, ("int", 2), ("text", "b")), (2, ("null", None), ("text", "a")), (3, ("int", 1), ("text", "c")),
            (4, ("int", 2), ("text", "a")), (5, ("null", None), ("null", None)), (6, ("int", 2), ("text", "b")),
            (7, ("int", -1), ("text", "B"))]
    rows_lean = "[" + ", ".join(f"({i}, {lean_val(a)}, {lean_val(b)})" for i, a, b in data) + "]"
    values = ", ".join(f"({i}, {sql_lit(a)}, {sql_lit(b)})" for i, a, b in data)
    line(f"def rows : List (Nat × SqlValue × SqlValue) := {rows_lean}")
    line("def byId (ids : List Nat) : List (Nat × SqlValue × SqlValue) := ids.filterMap fun i => rows.find? (·.1 == i)")
    specs = [("k1", "[.asc]", "fun r => [r.2.1]"), ("k1 DESC", "[.desc]", "fun r => [r.2.1]"),
             ("k2", "[.asc]", "fun r => [r.2.2]"), ("k2 DESC", "[.desc]", "fun r => [r.2.2]"),
             ("k1, k2", "[.asc, .asc]", "fun r => [r.2.1, r.2.2]"), ("k1 DESC, k2", "[.desc, .asc]", "fun r => [r.2.1, r.2.2]"),
             ("k1, k2 DESC, id", "[.asc, .desc, .asc]", "fun r => [r.2.1, r.2.2, .int r.1]")]
    for order, dirs, key in specs:
        st, res = psql(f"SELECT id FROM (VALUES {values}) AS t(id, k1, k2) ORDER BY {order}")
        ids = "[" + ", ".join(r[0] for r in res) + "]"
        line(f"-- ORDER BY {order}")
        line(f"#guard isAllowedOrder (sortConfig) {dirs} ({key}) rows (byId {ids})")
        if order.endswith("id"):
            line(f"#guard orderByStable (sortConfig) {dirs} ({key}) rows == byId {ids}")
    texts = ["b", "B", "a", "A", "", "ab", "aB", "あ", "ア", "亜", "𠮷", "_", "1", " ", "z", "Ａ"]
    values = ", ".join(f"({i}, {sql_lit(('text', t))})" for i, t in enumerate(texts))
    st, res = psql(f"SELECT s FROM (VALUES {values}) AS t(i, s) ORDER BY s")
    pg = [r[0] for r in res]
    line("-- 照合順序 C（データベースの既定）")
    line(f"#guard orderByStable (sortConfig) [.asc] (fun s => [.text s]) [{', '.join(lean_str(t) for t in texts)}] == "
         f"[{', '.join(lean_str(t) for t in pg)}]")


def to_char():
    line()
    line("/-! ## TO_CHAR（FM と 0・9 の書式） -/")
    line()
    fmts = ["FM0999999999", "FM9999", "FM9909", "FM0999", "FM00", "FM9", "FM999990"]
    ns = [0, 5, 42, 123, 9999, 12345, 9999999999, 12345678901, -42, -12345, 1000000]
    for f in fmts:
        for n in ns:
            r = one(f"SELECT to_char({n}::int8, '{f}')")
            line(f"#guard toChar {lean_int(n)} {lean_str(f)} == some {lean_str(r)}")


def int_ranges():
    line()
    line("/-! ## 整数型の範囲 -/")
    line()
    cases = [("int2", 32767), ("int2", 32768), ("int2", -32768), ("int2", -32769),
             ("int4", 2147483647), ("int4", 2147483648), ("int4", -2147483648), ("int4", -2147483649),
             ("int8", 9223372036854775807), ("int8", 9223372036854775808), ("int8", -9223372036854775808),
             ("int8", -9223372036854775809)]
    for ty, v in cases:
        st, _ = psql(f"SELECT '{v}'::{ty}")
        pat = ".ok _" if st == "ok" else ".error .numericOutOfRange"
        line(f"#guard {ty} {lean_int(v)} matches {pat}")
    # 演算の溢れ（int4 + int4 は int4）
    for a, b in [(2147483647, 1), (2147483646, 1), (-2147483648, -1)]:
        st, _ = psql(f"SELECT ({a})::int4 + ({b})::int4")
        pat = ".ok _" if st == "ok" else ".error .numericOutOfRange"
        line(f"#guard int4 ({lean_int(a)} + {lean_int(b)}) matches {pat}")


def dates():
    line()
    line("/-! ## DATE の範囲（1970-01-01 を 0 とする通算日数） -/")
    line()
    lo = int(one("SELECT '4714-11-24 BC'::date - '1970-01-01'::date"))
    hi = int(one("SELECT '5874897-12-31'::date - '1970-01-01'::date"))
    line(f"#guard dateMin == {lean_int(lo)} && dateMax == {lean_int(hi)}")
    for v in [lo, hi]:
        st, _ = psql(f"SELECT '1970-01-01'::date + ({v})")
        line(f"#guard date {lean_int(v)} matches " + (".ok _" if st == "ok" else ".error .dateOutOfRange"))
    for v in [lo - 1, hi + 1]:
        st, _ = psql(f"SELECT '1970-01-01'::date + ({v})")
        line(f"#guard date {lean_int(v)} matches " + (".ok _" if st == "ok" else ".error .dateOutOfRange"))


def varchar():
    line()
    line("/-! ## VARCHAR(n) への格納 -/")
    line()
    cases = [(3, "abc"), (2, "abc"), (3, "𠮷𠮷𠮷"), (2, "𠮷𠮷𠮷"), (2, "ab "), (2, "ab  "), (2, "a b"), (2, " ab"), (0, ""),
             (5, "あいうえお"), (4, "あいうえお")]
    for n, v in cases:
        if n == 0:
            continue  # varchar(0) は定義できない
        st, res = psql(f"CREATE TEMP TABLE t (c varchar({n})); INSERT INTO t VALUES ({sql_lit(('text', v))}); SELECT c FROM t")
        if st == "ok":
            line(f"#guard (varchar \"c\" {n} {lean_str(v)}).toOption == some {lean_str(res[0][0])}")
        else:
            line(f"#guard varchar \"c\" {n} {lean_str(v)} matches .error (.stringTooLong _)")


def sequences():
    line()
    line("/-! ## シーケンス -/")
    line()
    defs = [("MAXVALUE 3 CYCLE", "{ name := \"s\", maxValue := 3, cycle := true }", 5),
            ("MAXVALUE 3", "{ name := \"s\", maxValue := 3 }", 5),
            ("START 5 INCREMENT 2 MAXVALUE 10", "{ name := \"s\", start := 5, increment := 2, maxValue := 10 }", 5),
            ("START 2 MINVALUE 1 MAXVALUE 3 CYCLE", "{ name := \"s\", start := 2, maxValue := 3, cycle := true }", 5)]
    for opts, lean_def, n in defs:
        got = []
        st, res = psql(f"CREATE TEMP SEQUENCE s {opts}; " + "; ".join("SELECT nextval('s')" for _ in range(n)))
        if st == "ok":
            got = [r[0] for r in res]
            line(f"#guard (nextvals ({lean_def} : SequenceDef) {n}).toOption == some [{', '.join(got)}]")
        else:
            # 何番目で尽きるかを調べる
            k = 0
            while True:
                st2, _ = psql(f"CREATE TEMP SEQUENCE s {opts}; " + "; ".join("SELECT nextval('s')" for _ in range(k + 1)))
                if st2 != "ok":
                    break
                k += 1
            line(f"#guard (nextvals ({lean_def} : SequenceDef) {k}).isOk && "
                 f"(nextvals ({lean_def} : SequenceDef) {k + 1}) matches .error (.sequenceExhausted _)")


def updates():
    line()
    line("/-! ## UPDATE（右辺は更新前の行で評価する。WHERE の UNKNOWN は偽） -/")
    line()
    st, res = psql("CREATE TEMP TABLE t (id int, a int, b int); "
                   "INSERT INTO t VALUES (1, 1, 2), (2, 3, NULL), (3, 5, 6); "
                   "UPDATE t SET a = b, b = a WHERE b > 1; SELECT id, a, b FROM t ORDER BY id")
    after = [(int(r[0]), r[1], r[2]) for r in res]

    def v(x):
        return ".null" if x is None else f"(.int {x})"
    line("def urows : List (Nat × SqlValue × SqlValue) := [(1, .int 1, .int 2), (2, .int 3, .null), (3, .int 5, .int 6)]")
    line("#guard (updateWhere (fun r => SqlValue.lt coll (.int 1) r.2.2) (fun r => (r.1, r.2.2, r.2.1)) urows).1 == "
         f"[{', '.join(f'({i}, {v(a)}, {v(b)})' for i, a, b in after)}]")


def main():
    expect = None
    if "--expect-version" in sys.argv:
        expect = sys.argv[sys.argv.index("--expect-version") + 1]
    ver = one("SHOW server_version").split(" ")[0]
    if expect and ver != expect:
        sys.exit(f"pg_table.py: server version {ver} != expected {expect}")
    coll = one("SELECT datcollate FROM pg_database WHERE datname = current_database()")
    enc = one("SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()")
    if coll != "C" or enc != "UTF8":
        sys.exit(f"pg_table.py: database must be LC_COLLATE=C, UTF8 (got {coll}, {enc})")
    line("import LangSemantics.Sql.Postgresql")
    line()
    line("/-!")
    line("# Test.LangSemantics.PostgresqlDb")
    line()
    line("**生成物（手で編集しない）。** `Test/LangSemantics/pg/pg_table.py` が PostgreSQL（照合順序 C・UTF8・UTC）で")
    line("計算した値と、`LangSemantics.Sql`・`LangSemantics.Sql.Postgresql` の結果を突き合わせる。")
    line("再生成: `uv run python -I Test/LangSemantics/pg/pg_table.py > Test/LangSemantics/PostgresqlDb.lean`")
    line("-/")
    line()
    line("open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.Sequence")
    line("open LangSemantics.Sql.Postgresql")
    line()
    line("namespace Test.LangSemantics.PostgresqlDb")
    line()
    line("def coll := collationC")
    line()
    line("/-- `NEXTVAL` を n 回呼んだ値の列。 -/")
    line("def nextvals (s : SequenceDef) : Nat → SqlResult (List Int)")
    line("  | 0 => .ok []")
    line("  | n + 1 => go s none (n + 1)")
    line("where go (s : SequenceDef) (st : SequenceState) : Nat → SqlResult (List Int)")
    line("  | 0 => .ok []")
    line("  | k + 1 => do let (v, st') ← nextval s st; let vs ← go s st' k; pure (v :: vs)")
    three_valued()
    comparisons()
    order_by()
    to_char()
    int_ranges()
    dates()
    varchar()
    sequences()
    updates()
    line()
    line("end Test.LangSemantics.PostgresqlDb")
    sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))


if __name__ == "__main__":
    main()
