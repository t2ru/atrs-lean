---
type: Architecture Decision Record
title: "同じ状態を共有する機能の合成子 Machine.alt、トランザクションの取消、LocalTime・List.get・StringUtils・TIMESTAMP の写し"
description: "状態の成分を共有する 2 つの機能の機械を、同じ状態の上で入力と出力を和にして並置する合成子 Machine.alt（と Concrete・Glue・Refines・Preserves.core の alt）を足す（実装は適用先の段に合わせる）。状態を変える移植元の計算のために、トランザクションの取消 LangSemantics.Sql.Transaction.run を置く。言語パックに java.time.LocalTime（HHmm の SMART 解決）・LocalDateTime、List.get、Spring の StringUtils、PostgreSQL の TIMESTAMP を足す。"
tags: [adr, skill, machine, sql, java, transaction]
id: "a303b59c-1377-43b0-82b1-f2232f7930ff"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:00:00+09:00
---

# 同じ状態を共有する機能の合成子 Machine.alt、トランザクションの取消、LocalTime・List.get・StringUtils・TIMESTAMP の写し

## Context and Problem Statement

`Machine.sum` は、機能の機械を並置するとき、状態を積（`σ₁ × σ₂`）にする。一方の 1 歩は、他方の状態の成分を変えない。
そのため、状態の成分を共有する 2 つの機能を `sum` で並置すると、それぞれが別の写しを持ってしまう。例は、照会（状態を読むだけ）と登録（同じ成分を書く）である。照会が登録の結果を見ない。

状態を変える移植元の計算には、トランザクションの取消も要る。例外で終わったら表を開始時に戻し、シーケンスの前進は戻さない。
`LangSemantics.Sql.Sequence` は「巻き戻らないことは、呼び出し側が取消の対象に含めないことで表す」とだけ定めていた。取消そのものの演算は無かった。

適用先（ATRS の予約。backlog aedf）で、言語パックに次の不足も見つかった。

* `java.time.LocalTime`（`DateTimeFormatter.ofPattern("HHmm")` の解決）と `LocalDateTime` の分の加算・比較
* `java.util.List.get`（範囲外の例外）
* Spring の `StringUtils.hasLength`・`hasText`
* PostgreSQL の `TIMESTAMP` の列

## Decision Drivers

* 原則 B: 機能の機械は、トップレベルの主定理で並置される（[spec/architecture.md](../spec/architecture.md#トップレベルの主定理)）。
* 既存の機能の R 課題の証明を、あとから状態を共有する機能のために作り直さない。
* 言語パックの意味は、処理系と決定論的に突き合わせる（Java は JVM の表）。
* 適用先に固有の定義を assets に置かない。

## Considered Options

* 共有状態の並置
  * (a) 合成子 `Machine.alt` を足す。同じ状態 σ の上で、入力と出力を和にする。
  * (b) 共有する機能を、1 つの機械に組み直す（入力の和を 1 つの `ofChoice` で扱う）。
* 取消
  * (a) `EStateM` の計算に対する汎用の `Transaction.run restore body`
  * (b) 適用先ごとに書く

## Decision Outcome

Chosen option: "共有状態の並置 (a)・取消 (a)"。理由は次のとおりである。

* (a) なら、すでに証明した機能の R 課題を、状態の型を合わせるだけで並置に使える。
* 取消は、どの適用先でも同じ形（表は開始時、シーケンスは終了時）になる。

並置の方式は、プロジェクトオーナーが適用先 ATRS の ADR 4c45 で決めた。

### 決定

| 項目 | 決定 |
| --- | --- |
| `Machine.alt` | `alt (A₁ : Machine σ ι₁ ο₁) (A₂ : Machine σ ι₂ ο₂) : Machine σ (ι₁ ⊕ ι₂) (ο₁ ⊕ ο₂)`。<br>- `Inv`: 両方の `Inv` の積<br>- `Init`: 両方の `Init` の積<br>- `Pre`・`step`・`run`: 入力の側で振り分ける<br>あわせて次を置く。<br>- `Concrete.alt`: 同じ状態 τ<br>- `Glue.alt g₁ g₂`: 2 つの貼り合わせの `J` が等しいことを引数に取る<br>- `Refines.alt`<br>- `Preserves.core.alt`<br>例と反例は `Test/Machine/Alt.lean` に置く（`sum` だと読む操作が更新を見ないこと、`alt` だと見ること、`Refines.alt` の使用例）。適用先の予約の第 2 段の初めに実装した（版 0.24 に含める） |
| `LangSemantics.Sql.Transaction.run` | `run (restore : σ → σ → σ) (body : EStateM ε σ α) : EStateM ε σ α`。<br>- 正常に終われば確定する。<br>- 例外で終われば、状態を `restore 開始時 終了時` にして例外を伝える。<br>- どの成分を戻すかは、呼び出し側が `restore` で決める（表は開始時、シーケンスは終了時など）。<br>- 行ロックと分離レベルは写さない。逐次の実行では観測されず、並行実行はモデルの外である |
| `LangSemantics.Java.JLocalTime`・`JLocalDateTime` | `JLocalTime`（時・分）と `JLocalDateTime`（暦日と時・分）。モジュールを分け、`localDate.atTime(t)` は `JLocalDateTime.atTime d t` とする（宣言をモジュール名の下に置く）。<br>- `JLocalTime.parseHHmm`: `LocalTime.from(DateTimeFormatter.ofPattern("HHmm").parse(s))`（SMART）。ASCII の数字 4 文字に限る。`24:00` は 0:00。ほかの 24 時台・25 時以上・60 分以上は `DateTimeParseException`。<br>- `atTime`・`atStartOfDay`・`plusMinutes`・`isBefore`: 通算の分で計算する。<br>- JVM の表（`Test/LangSemantics/jvm/JavaTable.java`）で突き合わせる |
| `LangSemantics.Java.JList.get` | `list.get(index)`。範囲外は `IndexOutOfBoundsException`。適用先の `SourceModel` は `]!` を使えないので、Java の `get` はこれで写す |
| `StringUtils.hasLength`・`hasText` | `LangSemantics.Java.Spring` に置く。`null` を受けて偽を返す |
| `PgTimestamp` | PostgreSQL の `TIMESTAMP`（タイムゾーン無し）。1970-01-01 0:00 からのマイクロ秒で、`DATE` と同じ下限から 294276 年の末までを持つ。列の型として使う（格納の関数は、要る適用先で足す） |
| 版 | 0.24（スキルの分割の 0.23 の後） |

### Consequences

* Good, because 照会と登録のように状態を共有する機能を、既存の R 課題を作り直さずに並置できる
* Good, because 状態を変える移植元の計算の取消を、どの適用先でも同じ演算で書ける
* Bad, because `alt` で並置する機能は、同じ不変条件・初期状態・貼り合わせを共有しなければならない。片方を証明した後で状態を広げると、その証明も状態の型に合わせて直すことになる

### Confirmation

* `assets/lean` の `lake build` が通り、`LocalTime` の表（22 の文字列と、`plusMinutes`・`isBefore`）が JVM と一致する。
* `Machine.alt` の例と反例が `Test/Machine/Alt.lean` で証明され、公理が `#guard_msgs` で固定されている（`Test/Machine/Axioms.lean`）。

## More Information

* 来歴: 適用先 ATRS の ADR 4c45（予約の第 1 段）
* [spec/architecture.md](../spec/architecture.md#トップレベルの主定理)、[lang/java/semantics.md](../lang/java/semantics.md)、[lang/sql/semantics.md](../lang/sql/semantics.md)
