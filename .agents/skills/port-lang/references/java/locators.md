# Java: ロケータとインベントリ

移植元として使う場合は `@[source]`・`source-inventory` に、移植先として使う場合は `@[target]`・`target-inventory` に、同じ文法を使う。

## ロケータ

| kind | body | 例 |
| --- | --- | --- |
| `java` | `<FQCN>#<メソッド名>(<引数の単純型名,…>)`。コンストラクタは `<init>`、フィールドは `<FQCN>.<名前>`、クラス全体は `<FQCN>` | `java:com.example.billing.PriceService#unitPrice(int,Plan,LocalDate)` |
| `prop` | `<ファイル名>#<キー>`（`.properties`） | `prop:application.properties#app.limitDay` |
| `msg` | `<ファイル名>#<キー>`（メッセージリソース） | `msg:messages_ja.properties#e.app.0001` |
| `http` | `<METHOD> <パス>[?<判別パラメータ>]`（Web フレームワークのハンドラ） | `http:POST /orders?confirm` |
| `xml` | `<ファイル名>#<XPath 風の要素パス>`（Spring XML 設定など） | `xml:web.xml#error-page[code=404]` |
| `tmpl` | `<テンプレートのパス>#<要素の id、または th: 属性を持つ要素の XPath 風パス>`（Thymeleaf・JSP などの画面テンプレート） | `tmpl:templates/order/confirm.html#span[@th:text='${#temporals.format(…)}']` |

- 引数型は単純型名で書く。同名の型が衝突する場合だけ完全名にする。
- 内部クラスは `Outer$Inner` と書く。
- Java から Java への移植（移植元と移植先が同じ言語）では、`java@source:` / `java@target:` と区別する。

## インベントリ

- パーサ: tree-sitter-java（`.java`）、標準の properties パーサ、XML パーサ（テンプレートは HTML/XML として読む）。
- 単位: public / protected / package-private のメソッド・コンストラクタ、`static final` 定数、properties のキー、メッセージキー、Web ハンドラ（`@RequestMapping` 系の注釈から抽出）、テンプレートの式を持つ要素（`th:*` 属性）。
- 本文ハッシュの正規化: コメントを除き、連続する空白を 1 つにし、注釈の並び順は保つ。properties は値の前後の空白を除いた値のハッシュ。
- private メソッドは、それを呼ぶ公開メソッドのロケータに含めて扱う（呼び出し先の本文変更でも、呼び出し元のハッシュが変わるように、呼び出し先の本文を連結してハッシュする）。

> **未整備:** ラムダ・匿名クラスのロケータ。現時点では外側のメソッドに含める。
