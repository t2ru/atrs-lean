# Java: LangSemantics.Java

Java の基本型の意味論を、**整数演算だけでエミュレートできる名前付き演算** として Lean に定義する。
Lean 標準の `Float` は C の double に委譲される不透明な型で、性質を証明できないため使わない。
移植元として使う場合（`SourceModel`）も、移植先として使う場合（`TargetModel`）も、同じ定義を使う。

Lean の実装は `assets/lean/LangSemantics/Java/`（モジュール `LangSemantics.Java`）。検査は `assets/lean/LangSemanticsTest/Java.lean`。

## 演算（名前は仕様文書でも共通に使う）

| 名前 | Java | 意味 |
| --- | --- | --- |
| `J32` | `int` | 32 ビット 2 の補数（Lean では `BitVec 32`） |
| `J64` | `long` | 64 ビット 2 の補数 |
| `j32add`, `j32sub`, `j32mul` | `+ - *`（int） | 2^32 を法とする折り返し（JLS 15.17, 15.18） |
| `jdiv32`, `jrem32` | `/ %`（int） | 0 方向切捨て。`MIN_VALUE / -1 = MIN_VALUE`。0 除算は `ArithmeticException` |
| `JDouble` | `double` | IEEE 754 binary64（有限値・±0・±∞・NaN）。符号・仮数（`Nat`）・指数（`Int`）で表し、値の意味は有理数で与える |
| `jd n` | `(double) n` | int/long → double（\|n\| < 2^53 で正確、それ以外は最近接偶数丸め） |
| `jdLit "…"` | リテラル | 十進表記に最も近い binary64（例 `0.01` = `0x3F847AE147AE147B`）。指数表記は **未整備**（NaN になる） |
| `jdadd`, `jdsub`, `jdmul`, `jddiv` | `+ - * /`（double） | 正確な有理数の結果を round-to-nearest-even で丸める |
| `jd2i`, `jd2l` | `(int) d`, `(long) d` | NaN → 0、0 方向切捨て、範囲外は飽和（JLS 5.1.3） |
| `JBigDecimal.setScale(x, s, mode)` | `BigDecimal.setScale` | 10^(-s) 単位への丸め。`UP` は 0 から遠ざかる方向 |
| `JBigDecimal.intValue`, `bdCeilHundredUp` | `BigDecimal.intValue()`、`setScale(-2, UP).intValue()` | 整数部の下位 32 ビットへの切詰め |
| `utf16Len` | `String.length()` | UTF-16 符号単位数（補助文字は 2） |
| `jTrim` | `String.trim()` | 前後の U+0000–U+0020 を除去 |
| `jStrip` | `String.strip()` | 前後の Unicode 空白（`Character.isWhitespace`）を除去 |
| `jSplitChar` | `String.split(regex)` | 正規表現として特別な意味を持たない 1 文字の区切りに限る。末尾の空要素を除く |
| `JLocalDate` | `java.time.LocalDate` | 先発グレゴリオ暦の暦日。`plusDays`, `isBefore`, `isAfter`, `ChronoUnit.YEARS.between`（満年数） |
| `JRef` | 参照の `null` | 参照型は `Option` で表す。`JRef.deref` は `null` で `NullPointerException` |
| `JHashMap`, `JLinkedHashMap` | `HashMap`, `LinkedHashMap` | `put` は同じキーの値を置き換える（後勝ち）。`get` は無ければ `null`。`HashMap` の反復の順序は与えない。`LinkedHashMap` は挿入順で、同じキーの `put` は位置を保つ |

- 例外は `JThrow <例外クラス> <引数>` の値として表す。`IllegalArgumentException`（`Assert` 相当）と `NullPointerException` は、「前提違反」として扱う。前提違反には α を定義しない。PRE の下で到達しないことを、リファインメントの適用可能性の証明義務で示す。
- 原典で使われている演算だけを実装すればよい。汎用の IEEE 754 は作らない（除算・平方根など、原典に無い演算は不要）。

## 確認

- `jdLit("0.01")` のビット表現を `decide` で確認する。
- `jdmul` などのソフトモデルを、テストドライバでネイティブ `Float` と突き合わせる。原典の値域を覆う入力を使う。
- 例: `jd2i(jdmul(jd(1430), jdsub(jd(1), jdmul(jd(30), jdLit("0.01")))))` は 1000 になる（厳密計算の 1001 と異なる）。

## 補題（assets）

リファインメントの証明に使う、アプリに依存しない補題である。

| モジュール | 主な補題 |
| --- | --- |
| `LangSemantics.Java.DoubleLemmas` | `jd2i_mul_nat`: 正の整数 `X` と正の因子 `F = fm·2^(−fs)` について、`(int)((double) X * F)` を閉じた形 `min J32.maxValue (rneTrunc (X·fm) (2^fs))` に書き直す。`rneTrunc_spec` は、`rneTrunc N D`（`N/D` を binary64 に丸めて切り捨てた値）の不等式の形。`ofInt_nat`・`toJ32_ofRat` |
| `LangSemantics.Java.BigDecimal` | `bdCeilHundredUp_val`: 非負の値の 100 単位の切上げ |
| `LangSemantics.Java.LocalDateLemmas` | `toEpochDay_ofEpochDay` |
| `LangSemantics.Java.HashMapLemmas` | `ofList_entries`・`get_ofList` |

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
| 部分写像（上の値の組み合わせで、一部の値に定義しないもの） | 対応する `Spec` の値 | 定義域の上で単射なら `Machine.undefOrEq`（[architecture.md](../architecture.md#空虚化を防ぐ義務)） |

- 核は、標準の抽象化の葉の核の定理（`KernelIs`）で示す。核に当たる値の違いは、リファインメントでは観測されない。

## 移植先として使う場合

`TargetModel` を Java の意味論で書き、`Refinement` で int の溢れが起きないこと、double を使わないことなどを証明する。
移植先として Java のコードを書く規約は [layout.md](layout.md)。
