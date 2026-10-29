# Java: LangSemantics.Java

Java の基本型の意味論を、**整数演算だけでエミュレートできる名前付き演算** として Lean に定義する。
Lean 標準の `Float` は C の double に委譲される不透明な型で、性質を証明できないため使わない。
移植元として使う場合（`SourceModel`）も、移植先として使う場合（`TargetModel`）も、同じ定義を使う。

## 演算（名前は仕様文書でも共通に使う）

| 名前 | Java | 意味 |
| --- | --- | --- |
| `J32` | `int` | 32 ビット 2 の補数（Lean では `BitVec 32`） |
| `J64` | `long` | 64 ビット 2 の補数 |
| `j32add`, `j32sub`, `j32mul` | `+ - *`（int） | 2^32 を法とする折り返し（JLS 15.17, 15.18） |
| `jdiv32`, `jrem32` | `/ %`（int） | 0 方向切捨て。`MIN_VALUE / -1 = MIN_VALUE`。0 除算は `ArithmeticException` |
| `JDouble` | `double` | IEEE 754 binary64（有限値・±0・±∞・NaN）。符号・仮数（`Nat`）・指数（`Int`）で表し、値の意味は有理数で与える |
| `jd(n)` | `(double) n` | int/long → double（\|n\| < 2^53 で正確、それ以外は最近接偶数丸め） |
| `jdLit("…")` | リテラル | 十進表記に最も近い binary64（例 `0.01` = `0x3F847AE147AE147B`） |
| `jdadd`, `jdsub`, `jdmul`, `jddiv` | `+ - * /`（double） | 正確な有理数の結果を round-to-nearest-even で丸める |
| `jd2i`, `jd2l` | `(int) d`, `(long) d` | NaN → 0、0 方向切捨て、範囲外は飽和（JLS 5.1.3） |
| `bdSetScale(n, s, mode)` | `BigDecimal.setScale` | 10^(-s) 単位への丸め。`UP` は 0 から遠ざかる方向 |
| `bdIntValue` | `BigDecimal.intValue()` | 整数部の下位 32 ビットへの切詰め |
| `utf16Len` | `String.length()` | UTF-16 符号単位数（補助文字は 2） |
| `jTrim` | `String.trim()` | 前後の U+0000–U+0020 を除去 |
| `jStrip` | `String.strip()` | 前後の Unicode 空白（`Character.isWhitespace`）を除去 |
| `jSplit` | `String.split(regex)` | 末尾の空要素を除く分割（正規表現は使用する固定文字列だけを定義する） |
| `jLocalDate` | `java.time.LocalDate` | 先発グレゴリオ暦の暦日。`plusDays`, `isBefore`, `isAfter`, `ChronoUnit.YEARS.between`（満年数） |
| `jNull` | 参照の `null` | 参照型はすべて `Option` で表す。`null` の参照外しは `NullPointerException` |

- 例外は `JThrow <例外クラス> <引数>` の値として表す。`IllegalArgumentException`（`Assert` 相当）と `NullPointerException` は、抽象化の際に「前提違反」に写す。
- 原典で使われている演算だけを実装すればよい。汎用の IEEE 754 は作らない（除算・平方根など、原典に無い演算は不要）。

## 確認

- `jdLit("0.01")` のビット表現を `decide` で確認する。
- `jdmul` などのソフトモデルを、テストドライバでネイティブ `Float` と突き合わせる。原典の値域を覆う入力を使う。
- 例: `jd2i(jdmul(jd(1430), jdsub(jd(1), jdmul(jd(30), jdLit("0.01")))))` は 1000 になる（厳密計算の 1001 と異なる）。

## 抽象化（α）での写し方

| Java | `Spec` |
| --- | --- |
| `J32`, `J64` | `Int`（値域内なら `Nat`） |
| `JDouble`（有限値） | 有理数（NaN・∞ は α 未定義） |
| UTF-16 文字列 | スカラ値の列（不対サロゲートを含む場合は α 未定義） |
| `jLocalDate` | `Spec.Prim.Date` |
| `null` 可能な参照 | `Option` |
| 例外 | エラー値（前提違反を含む） |

## 移植先として使う場合

`TargetModel` を Java の意味論で書き、`Refinement` で int の溢れが起きないこと、double を使わないことなどを証明する。
移植先として Java のコードを書く規約は [layout.md](layout.md)。
