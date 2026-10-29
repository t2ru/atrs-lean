# Java: フレームワーク・ランタイムの効果

フレームワークは移植しない。その **効果** をモデルに写し、`dep:` ロケータを付ける。

- 移植元として: 原典が暗黙に受けている効果を `SourceModel` に写す。
- 移植先として: 採用するフレームワークの効果を `TargetModel` に写す。

## 確認する効果の一覧

| 分類 | 効果 | 写し方 | `dep:` の例 |
| --- | --- | --- | --- |
| 入力の前処理 | Spring `StringTrimmerEditor(true)`: 前後を `String.trim()` で除去し、空文字を null にする（Spring 6.2 時点。版で `strip()` に変わる可能性を版上げで確認する） | 入力検証の前処理関数 | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText` |
| 型変換 | 数値・日付・列挙への変換失敗は `typeMismatch` エラーになり、その項目の他の検証は行わない | 入力検証 | `dep:org.springframework:spring-beans#TypeConverter` |
| 宣言的な検証 | Bean Validation: `@Size` 等は null を合格とする。`@Size` の長さは UTF-16 単位。1 項目の複数違反の並びは保証されない。`@NotEmpty` は null と空文字を不合格とする | 制約ごとの関数と、エラーの集め方 | `dep:org.hibernate.validator:hibernate-validator#…` |
| 相関検証 | Spring `Validator` の登録は `@InitBinder("<名前>")` の名前一致で決まる。一致しないと適用されない | 適用の有無をモデルに含める | `dep:org.springframework:spring-web#InitBinder` |
| メッセージ | `{0}` は項目の表示名に置換される。`@Size` は `{1}` が max、`{2}` が min | メッセージ解決関数 | `dep:org.springframework:spring-context#MessageSource` |
| JSON | Jackson: `java.time.LocalDate` の表現は `ObjectMapper` の設定に依存する（`WRITE_DATES_AS_TIMESTAMPS`）。`@DateTimeFormat` は効かない | シリアライズ関数 | `dep:com.fasterxml.jackson.core:jackson-databind#ObjectMapper` |
| 永続化 | MyBatis: `selectKey` の実行順、結果の対応づけ。SQL そのものは SQL パックで写す | リポジトリ関数 | `dep:org.mybatis:mybatis#…` |
| トランザクション | `@Transactional`: 実行時例外でロールバック、既定では検査例外でコミット | ユースケースの原子性 | `dep:org.springframework:spring-tx#Transactional` |
| セキュリティ | フォームログインの前処理（ユーザー名の `trim`）、パスワードエンコーダの `{id}` 前置き | 認証の手順 | `dep:org.springframework.security:spring-security-web#UsernamePasswordAuthenticationFilter` |
| 時刻 | `Clock` を注入せず `now()` を直接呼ぶ箇所 | Clock ポートの入力として抽象化 | `lang:java#java.time` |

## 依存の版の抽出

- Maven: `pom.xml` の依存解決結果（`mvn dependency:list` の出力、または BOM の版）を `trace/upstream.json` に記録する。
- Gradle: `dependencies` タスクの出力を使う。

## 版上げで起こりがちな変化

- Spring のメジャー版上げに伴う、パッケージの `javax.*` → `jakarta.*` の移行（メッセージキーも変わる）。
- 文字列処理の `trim()` / `strip()` の切り替え。
- Jackson の既定設定の変更（日付・null の扱い）。
- Bean Validation の実装の版による、エラーメッセージの既定文言の変化。
