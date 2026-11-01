---
type: Reference
title: "Java: LangSemantics.Java"
description: "Java の基本型を整数演算だけでエミュレートする LangSemantics.Java の名前付き演算と、処理系との突き合わせ。"
tags: [java, language-pack, lean]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Java: LangSemantics.Java

Java の基本型の意味論を、**整数演算だけでエミュレートできる名前付き演算** として Lean に定義する。
Lean 標準の `Float` は C の double に委譲される不透明な型で、性質を証明できないため使わない。
移植元として使う場合（`SourceModel`）も、移植先として使う場合（`TargetModel`）も、同じ定義を使う。

Lean の実装は `assets/lean/LangSemantics/Java/`（モジュール `LangSemantics.Java`）。検査は `assets/lean/Test/LangSemantics/Java.lean`。

## 演算（名前は仕様文書でも共通に使う）

| 名前 | Java | 意味 |
| --- | --- | --- |
| `J32` | `int` | 32 ビット 2 の補数（Lean では `BitVec 32`） |
| `J64` | `long` | 64 ビット 2 の補数 |
| `j32add`, `j32sub`, `j32mul` | `+ - *`（int） | 2^32 を法とする折り返し（JLS 15.17, 15.18） |
| `jdiv32`, `jrem32` | `/ %`（int） | 0 方向切捨て。`MIN_VALUE / -1 = MIN_VALUE`。0 除算は `ArithmeticException` |
| `j32neg`, `j64neg`, `j64add` など, `jdiv64`, `jrem64` | 単項の `-`、`long` の演算 | `int` と同じ（2^64 を法とする） |
| `JDouble` | `double` | IEEE 754 binary64（有限値・±0・±∞・NaN）。符号・仮数（`Nat`）・指数（`Int`）で表し、値の意味は有理数で与える |
| `jd n` | `(double) n` | int/long → double（\|n\| < 2^53 で正確、それ以外は最近接偶数丸め） |
| `jdLit "…"` | リテラル | 十進表記に最も近い binary64（例 `0.01` = `0x3F847AE147AE147B`）。指数表記は **未整備**（NaN になる） |
| `jdadd`, `jdsub`, `jdmul`, `jddiv` | `+ - * /`（double） | 正確な有理数の結果を round-to-nearest-even で丸める |
| `jdneg` | 単項の `-`（double） | 符号だけを反転する（`-0.0`・`-∞`。NaN は NaN） |
| `jd2i`, `jd2l` | `(int) d`, `(long) d` | NaN → 0、0 方向切捨て、範囲外は飽和（JLS 5.1.3） |
| `JBigDecimal.setScale(x, s, mode)` | `BigDecimal.setScale` | 10^(-s) 単位への丸め。`UP` は 0 から遠ざかる方向 |
| `JBigDecimal.intValue`, `bdCeilHundredUp` | `BigDecimal.intValue()`、`setScale(-2, UP).intValue()` | 整数部の下位 32 ビットへの切詰め |
| `utf16Len` | `String.length()` | UTF-16 符号単位数（補助文字は 2） |
| `jTrim` | `String.trim()` | 前後の U+0000–U+0020 を除去 |
| `jStrip` | `String.strip()` | 前後の Unicode 空白（`Character.isWhitespace`）を除去 |
| `jSplitChar` | `String.split(regex)` | 正規表現として特別な意味を持たない 1 文字の区切りに限る。末尾の空要素を除く |
| `jSubstring`, `jSubstringFrom` | `String.substring(b, e)`, `substring(b)` | 位置は UTF-16 符号単位。範囲外は `StringIndexOutOfBoundsException`。切り口が補助文字の中にある場合（結果が不対サロゲートを含む）は表さない |
| `DecimalFormat.formatGrouped sep n` | `new DecimalFormat("###,###").format(n)` | 整数を 3 桁ごとに区切る。区切り文字は既定の書式ロケールによるので引数に取る（日本語・英語では `,`）。負の数は `-` を前に付ける |
| `DecimalFormat.formatGroupedS sym n` | `new DecimalFormat("###,###", symbols).format(n)` | 書式の記号の組 `Symbols`（区切り文字・数字の 0・負の記号の文字列）で書式化する。数字は `zeroDigit` から数え、負の数は負の記号の文字列を前に付ける。`Symbols.ascii`（`,`・`0`・`-`）では `formatGrouped ','` に等しい（`formatGroupedS_ascii`） |
| `JLocalDate` | `java.time.LocalDate` | 先発グレゴリオ暦の暦日。`plusDays`, `isBefore`, `isAfter`, `ChronoUnit.YEARS.between`（満年数）。通算日数との変換は双方向に逆（`toEpochDay_ofEpochDay`、妥当な暦日で `ofEpochDay_toEpochDay`） |
| `JLocalTime`, `JLocalDateTime` | `java.time.LocalTime`, `LocalDateTime` | 時・分（秒は 0）。`JLocalTime.parseHHmm` は `LocalTime.from(DateTimeFormatter.ofPattern("HHmm").parse(s))`（SMART）で、ASCII の数字 4 文字に限る。`24:00` は 0:00 に解決し、ほかの 24 時台・25 時以上・60 分以上は `DateTimeParseException`。`localDate.atTime(t)`・`atStartOfDay()` は `JLocalDateTime.atTime d t`・`JLocalDateTime.atStartOfDay d` とし、`plusMinutes`・`isBefore` は通算の分で計算する（年の範囲を超える加算の `DateTimeException` は写さない） |
| `JList.get` | `List.get(i)` | 範囲外は `IndexOutOfBoundsException` |
| `JRef` | 参照の `null` | 参照型は `Option` で表す。`JRef.deref` は `null` で `NullPointerException` |
| `JHashMap`, `JLinkedHashMap` | `HashMap`, `LinkedHashMap` | `put` は同じキーの値を置き換える（後勝ち）。`get` は無ければ `null`。`HashMap` の反復の順序は与えない。`LinkedHashMap` は挿入順で、同じキーの `put` は位置を保つ |

- 例外は `JThrow <例外クラス> <引数>` の値として表す。`IllegalArgumentException`（`Assert` 相当）と `NullPointerException` は、「前提違反」として扱う。前提違反には α を定義しない。PRE の下で到達しないことを、リファインメントの適用可能性の証明義務で示す。
- 原典で使われている演算だけを実装すればよい。汎用の IEEE 754 は作らない（除算・平方根など、原典に無い演算は不要）。

## 式の構文 java!

移植元のモデルの式は、原典の Java の式と同じ字面で `java! e` と書く（`LangSemantics.Java.Expr`。[ADR 1f75](../../decision/1f75-java-expression-syntax-and-spring-assert.md)）。
展開した項は、上の原始関数を手で書いた項と **構文として同じ** である（`Test.LangSemantics.JavaExpr` が `#guard_expr … =ₛ …` で確かめる）。証明は原始関数について書く。

```lean
-- Java: int basicFare = (int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01));
let basicFare := java! (int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))
-- 展開: jd2i (jdmul (jd (j32add basicFareOfRoute boardingClassFare).val) (jdmul (jd multiplicationRatio.val) (jdLit "0.01")))

-- Java: int fare = boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum;
let fare ← java! boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum   -- / があるので JResult

-- Java: if (departureDate.isBefore(sysDate) || departureDate.isAfter(limitDate))
if java! d.isBefore(sysDate) || d.isAfter(limitDate) then …
```

| 項目 | 規則 |
| --- | --- |
| 優先順位・結合（JLS 15） | 低い順に `\|\|`・`&&`・`==` `!=`・`<` `<=` `>` `>=`・`+` `-`・`*` `/` `%`、単項の `-` `!` とキャスト。2 項演算子は左結合、比較は結合しない |
| リテラルの型（JLS 3.10） | `100` は `int`（`J32.ofInt 100`。範囲外は誤り）、`100L` は `long`、`0.01`・`1d` は `double`（`jdLit "0.01"`）。指数表記の `double` は誤り |
| 数値昇格（JLS 5.6.2） | どちらかが `double` なら `double`、そうでなくどちらかが `long` なら `long`。`int` から `double` は `jd x.val`（整数リテラルは値のまま `jd 1`） |
| キャスト | `(int) d` は `jd2i d`、`(long) d` は `jd2l d`、`(int) l` は `J32.ofInt l.val`、`(double) n` は `jd n.val` |
| 比較・論理 | 整数は `decide (a.val ≥ b.val)`（整数リテラルは値のまま `decide (a.val ≥ 0)`）。`boolean` の `==`・`!=`・`&&`・`\|\|`・`!`。`&&`・`\|\|` は短絡評価 |
| 呼び出し・埋め込み | `f(a, b)` は Lean の関数適用 `f a b`（`d.isBefore(s)` はドット記法）。Lean の項は `⟪t⟫` |
| 例外 | 整数の `/`・`%`（0 除算）と、`JResult` を返す呼び出しを含む式は `JResult τ`。部分式を左から `>>=` でつなぐ。それ以外は `τ` |
| 扱わないもの | `double` の比較・剰余、`float`・`char`・`short`・`byte`、参照型の `==`、代入式、`?:`（必要になった時点で足す） |

## 原典の語彙とモデルの語彙

原典を見比べやすくするため、移植元のモデルは次の対応で書く。名前は原典の識別子をそのまま使う（引数・ローカル変数・欄。TR-M3・TR-M4 が確かめる）。

| 原典（Java） | モデル（Lean） |
| --- | --- |
| `int`・`long`・`double`・`boolean` | `J32`・`J64`・`JDouble`・`Bool` |
| 参照（`null` になりうる）・`Integer` | `JRef α`（`null` は `none`） |
| `x.getFoo()`（getter）・`x.setFoo(v)` | 欄の参照 `x.foo`・構造体の更新 `{ x with foo := v }` |
| unboxing（`Integer` → `int`）・`null` の参照外し | `← x.foo.deref "foo"`（`null` で `NullPointerException`） |
| 式（演算子・リテラル・キャスト・比較） | `java! …` |
| `for (T x : xs) { … }`・`x++`・`x += y` | `for x in xs do …`・`x := java! x + 1`・`x := java! x + y` |
| `throw new E(…)`・`return` | `throw (E.new …)`・`return` |
| `new C(…)` | `C.new …`（モデルのコンストラクタ） |
| Spring の `Assert.isTrue(e, m)`・`Assert.notNull(x, m)`・`Assert.notEmpty(c, m)`・`Assert.hasText(s, m)` | `Assert.isTrue e m`・`Assert.notNull x m`・`Assert.notEmpty c m`・`Assert.hasText s m`（`LangSemantics.Java.Spring`） |
| Spring の `StringUtils.hasLength(s)`・`StringUtils.hasText(s)` | `StringUtils.hasLength s`・`StringUtils.hasText s`（`null` は偽） |
| `list.get(i)` | `← JList.get list i` |
| `Assert.notNull(x, m)` の後で `x` を使う | `let x ← Assert.notNullValue x m`（`notEmpty` は `notEmptyValue`） |
| 注入された依存（`@Inject`・`@Value`） | クラスの型の欄（`structure TicketSharedServiceImpl where boardingClassProvider : …`） |
| インスタンスメソッド `c.m(a)` | `C.m c a`（ドット記法で `c.m a`） |

## 確認

- `jdLit("0.01")` のビット表現を `decide` で確認する。
- `jdmul` などのソフトモデルを、テストドライバでネイティブ `Float` と突き合わせる。原典の値域を覆う入力を使う。
- 例: `jd2i(jdmul(jd(1430), jdsub(jd(1), jdmul(jd(30), jdLit("0.01")))))` は 1000 になる（厳密計算の 1001 と異なる）。

## 補題（assets）

リファインメントの証明に使う、アプリに依存しない補題である。

| モジュール | 主な補題 |
| --- | --- |
| `LangSemantics.Java.JDouble.Lemmas` | `jd2i_mul_nat`: 正の整数 `X` と正の因子 `F = fm·2^(−fs)` について、`(int)((double) X * F)` を閉じた形 `min J32.maxValue (rneTrunc (X·fm) (2^fs))` に書き直す。`rneTrunc_spec` は、`rneTrunc N D`（`N/D` を binary64 に丸めて切り捨てた値）の不等式の形。`ofInt_nat`・`toJ32_ofRat` |
| `LangSemantics.Java.BigDecimal` | `bdCeilHundredUp_val`: 非負の値の 100 単位の切上げ |
| `LangSemantics.Java.Int` | `j32add_val_of_inRange`・`j32sub_val_of_inRange`・`j32mul_val_of_inRange`: 値域内の加減乗算は数学的整数と一致。`jdiv32_val_of_nonneg`: 非負の被除数・正の除数の除算 |
| `LangSemantics.Java.JLocalDate.Lemmas` | `toEpochDay_ofEpochDay` |
| `LangSemantics.Java.HashMap.Lemmas` | `ofList_entries`・`get_ofList` |

double の式と、[Spec] の厳密な整数の式との差は、次の手順で定理にする。

1. 閉じた形（`jd2i_mul_nat`）で、double の式を整数の `rneTrunc` に書き直す。
2. 因子（リテラルとの積など、入力に依存しない double）の正確な値を、カーネルの評価（`decide +kernel`）で表にする。
3. 差異が起きない十分条件（例: 厳密値が整数でない、因子が厳密値以上か相対誤差が十分に小さい）を、`rneTrunc_spec` の不等式から示す。その条件を前提型の差異の前提にする。

## 抽象化（α）での写し方

| Java | `Spec` | 同一視するもの（核） |
| --- | --- | --- |
| `J32`, `J64` | `Int`（値域内なら `Nat`） | なし（単射） |
| `JDouble`（有限値） | 有理数（NaN・∞ は α を定義しない。適用可能性の証明義務で到達しないことを示すか、前提型の差異で除外する） | +0 と −0 |
| UTF-16 文字列 | スカラ値の列（不対サロゲートを含む場合は α を定義しない。扱いは NaN と同じ） | なし（単射） |
| `jLocalDate` | `Spec` の暦日 | なし（単射）。`Spec` の暦日の範囲の外には α を定義しない |
| `null` 可能な参照 | `Option` | なし（単射） |
| 例外 | 業務エラーの例外はエラー値に写す。前提違反には α を定義しない（PRE の下で到達しないことを示す） | 同じコード・引数を持つ例外のクラスの違い |
| 部分写像（上の値の組み合わせで、一部の値に定義しないもの） | 対応する `Spec` の値 | 定義域の上で単射なら `Machine.Kernel.undefOrEq`（[architecture.md](../../spec/architecture.md#空虚化を防ぐ義務)） |

- 核は、標準の抽象化の葉の核の定理（`KernelIs`）で示す。核に当たる値の違いは、リファインメントでは観測されない。

## 移植先として使う場合

`TargetModel` を Java の意味論で書き、`Refinement` で int の溢れが起きないこと、double を使わないことなどを証明する。
移植先として Java のコードを書く規約は [layout.md](layout.md)。
