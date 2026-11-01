---
type: Specification
title: "保証の限界"
description: "ソース⇔モデルの一致を確かめる決定論的な手段と、手段の届かない部分（保証の限界）・信頼の基盤を境界ごとにすべて列挙する。"
tags: [spec, assurance, verification, traceability]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 保証の限界

> **区分: メタ情報（meta）。** 基本原則（[ADR c336](../decision/c336-foundational-principles.md)）の原則 1 は、2 つのことを求める。1 つは、両端の一致を決定論的な検証または変換で確かめることである。もう 1 つは、手段の届かない部分を文書に明示することである。本書はその一覧である。

- **本書に無い限界があってはならない。** 次のときは、同じ変更で本書に追記する。
  - 新しい手段を採用したとき
  - 手段の対象外を作ったとき（ハーネスの対象外、Kani の境界、ベクタに無い入力の範囲、`#[verifier::external]` など）
- 人や LLM のレビューは、ここでは手段として数えない（補助にとどまる）。
- 手段の一般的な説明は、スキル spec-pivot の [verification.md](../../.agents/skills/spec-pivot/references/docs/spec/verification.md) と各言語パックの `verification.md` による。
- 「（付録に記入）」とある行は、詳細な範囲を付録の表に記入する。記入する backlog 項目を付録に示す。

## 移植元ソース ⇔ SourceModel

| 対象 | 決定論的な手段 | 保証しないこと | 信頼の基盤 |
| --- | --- | --- | --- |
| ドメイン層の計算（運賃・空席照会の集約・予約など） | Java の原典実行（DI コンテナを起動せず、原典の MyBatis の設定・Mapper とサービスを組み立てる。[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)）で、運賃計算・空席照会・予約の `shared/`・`source-model/` のベクタを原典で照合する。予約では、原典の `TicketReserveServiceImpl` を Spring の `TransactionInterceptor` で包み（`@Transactional` の取消を原典のとおりに働かせる）、ケースごとに状態の表とシーケンスを初期化する。予約確認は、シードの範囲から抽出した 76 件の期待値を原典から採取する（[ADR 4c45](../decision/4c45-reservation-stage1-shared-state-and-source-model.md)）。運賃はシードの範囲を全探索し、合計金額と空席照会は抽出して、期待値を原典から採取する（`conformance/source-model/*/origin-run-*.json`。範囲は付録）。採取したベクタは `lake test` が `SourceModel` と照合する（`mise run origin-run:domain`・CI） | ベクタと採取の範囲の外の入力。予約確定の採取（`shared/reservation` の手書きのケースだけを照合する）。会員・認証・レポートのドメイン層（[4e0e](../backlog/4e0e-member-usecases-and-input-validation.md)・[44f8](../backlog/44f8-authentication-usecases.md)・[ac71](../backlog/ac71-reservation-history-report.md) で足す）。`trace/manifest.json` にある運賃・空席照会の合格の記録は `lake-test` によるもので、`java-origin-run`（`trace/checks.json`）は次に `trace rehash` の対象になった組から記録される | JVM（`trace/upstream.json` の版）、MyBatis（原典の版） |
| フレームワークの暗黙の処理（Spring MVC の入力の変換、Bean Validation、Spring Security、Jackson） | HTTP レベルの原典実行（原典の web.xml のままの webapp を組み込み Tomcat で起動し、要求を送って応答と DB の変化を採取する。[ADR 81da](../decision/81da-java-origin-run-domain-and-http.md)、`mise run origin-run:http`・CI）。採取結果は `tools/origin-run/http/`。`SourceModel.Http`・`SourceModel.Validation` との照合は [4e0e](../backlog/4e0e-member-usecases-and-input-validation.md)・[a89e](../backlog/a89e-http-contract-adapter.md) で行う | ベクタの入力の外。いまの採取は REST の予約（日付の表現）とログイン時の状態更新だけ。起動できない構成（外部のメール・本番のキュー）。ハーネスが差し替えた構成（付録）。組み込み Tomcat と、配備のコンテナ（cargo の Tomcat）との違い（コネクタ・クラスローダの構成） | Spring の各版、Tomcat |
| リポジトリ（MyBatis の SQL） | SQL の差分実行: PostgreSQL での実行結果と `LangSemantics.Sql` の評価結果を、同じデータで照合する（[backlog c7e8](../backlog/c7e8-lang-semantics-sql.md)）。予約の文（`exists`・`findOneForUpdate`・`update`・`MemberRepository.findOne`・3 つの挿入と `selectKey`）は 75 件と、シードの会員の表（`LOGIN_DATE_TIME` を除く）を照合する（`conformance/sql/reservation.json`、[ADR ca17](../decision/ca17-reservation-stage2-machines-seed-nondet-advance.md)） | 照合したデータとパラメータの外。SQL の写しは手で翻訳している（文ごとの範囲は付録に記入） | PostgreSQL（`trace/upstream.json` の版） |
| 画面テンプレート（Thymeleaf の書式） | HTTP レベルの原典実行で、描画結果の該当部分を照合する（D-019 の曜日など） | ベクタの入力の外。HTML の構造全体は照合しない（[ADR 84bf](../decision/84bf-porting-scope.md) で範囲外） | Thymeleaf |
| 版上げ時の振る舞いの変化 | 差分の原典実行（新旧 2 版。入力は除外しない。[ADR 3f36](../decision/3f36-following-upstream-releases.md)、[backlog 773f](../backlog/773f-differential-oracle.md)） | ベクタの入力の外の変化 | 同上 |
| 改名の対応（`trace/renames.json`） | `trace rehash` が、新しいロケータについて決定論的な検査を実行し、合格したときだけ受け入れる | 検査がベクタの入力の外を確かめないこと（上の行と同じ） | spec-pivot の `scripts/trace` |
| 環境（障害・衝突・配備の設定）を入力とする振る舞い（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)） | 原典実行は障害の無い環境で実行する | 障害・衝突を注入した原典の振る舞い。`SourceModel` の障害の経路は、`LangSemantics` の写しとしてだけ確かめる |
| マスタ・設定を入力として写すこと | SQL の差分実行と Java の原典実行は、上流のシードを投入した DB で実行する（fixture と DB の一致は `Tests.MasterSql`）。原典実行の設定は原典の `atrs.properties` から読む | 実行中にマスタが変わらないこと（不変の入力とみなせること）は前提とする |
| 「今日」に依存する処理 | 原典実行を JST（`-Duser.timezone=Asia/Tokyo`）で実行し、原典の `dateFactory` を止めた時計（`FixedClockFactory`。`fixed`・`tick` とも決めた時刻）に差し替える。ドメイン層はケースの今日の 10:00、HTTP は 2026-11-03T10:00 | 時計を固定できない操作。JST 以外のタイムゾーンで動く原典（モデル外の差異 [D-023](abstraction.md#既知差異)）。日付をまたいで実行されたユースケース（前提型の差異 [D-014](abstraction.md#既知差異) の前提の外） | 時計を差し替える仕組み |
| 予約を含む状態の抽象化（暫定） | なし。backlog aedf の第 1 段では、空席照会の α `worldOfDb` を、会員・予約の表とシーケンスが使われていない状態に限っている（[ADR 4c45](../decision/4c45-reservation-stage1-shared-state-and-source-model.md)） | 会員・予約を含む状態での空席照会のリファインメント（トップレベルの主定理の 5 番目の成分）。上流のシード（00230 の会員）を投入した状態も、この α の定義域の外である。aedf の第 3 段で、全表の α に置き換えて解消する | — |
| 並行実行 | なし。モデルでは各ユースケースを原子的に扱う | 原典の実際の並行実行とモデルとの一致。原典は READ COMMITTED で動く（モデル外の差異 [D-025](abstraction.md#既知差異)）。会員情報変更は照合と更新が別トランザクションである（[D-013](abstraction.md#既知差異)）。予約確定は検査と登録が別トランザクションである（[D-037](abstraction.md#既知差異)） | — |
| セッション・Cookie・トランザクショントークン・CSRF（規範節） | HTTP レベルの原典実行で、ステータスと遷移先を照合する | セッション ID の扱い（[D-016](abstraction.md#既知差異)）、Cookie 属性（[D-024](abstraction.md#既知差異)）。トークンの値そのもの | Spring Security |
| REST の Basic 認証・日付の JSON 表現・エラー画面への遷移（規範節） | HTTP レベルの原典実行。日付の JSON 表現（`"yyyy-MM-dd"`）と、Basic 認証の成功でログイン状態が更新されること（[D-028](abstraction.md#既知差異)）は採取で確かめた（`tools/origin-run/http/postTicket.json`・`login.json`） | ベクタの入力の外。誤った資格情報の 401 とエラー画面への遷移は、まだ採取していない（[a89e](../backlog/a89e-http-contract-adapter.md)） | Spring Security、Jackson |
| 採番（シーケンス）の一意性・巻き戻らないこと | SQL の差分実行（`nextval` の結果） | 最大値に達した後（前提型の差異 [D-009](abstraction.md#既知差異) の前提の外） | PostgreSQL のシーケンス |
| ReportStore の `publish` の原子性・ReportQueue の配信保証のうち、プロセスの異常終了に対するもの（規範節） | なし（原典は ActiveMQ Artemis を内蔵し、ファイルの移動に OS を使う） | 異常終了をまたぐ配信回数と、ファイルの原子的な移動 | ActiveMQ Artemis、OS のファイル操作 |
| パスワードの照合（PBKDF2）・パスワードハッシュの互換（規範節） | なし。`SourceModel` は `PasswordEncoder` を raw について単射な符号化として写し（ABS-024）、パスワードを扱う操作のベクタの原典実行では `{test}` 形式に差し替える（[conformance.md](conformance.md)）。HTTP レベルの原典実行のログインは、原典の `DelegatingPasswordEncoder` とシードの `{pbkdf2}` のハッシュのまま実行する | ベクタの照合では、原典の `{pbkdf2}` の経路は実行されない。PBKDF2 の衝突（モデルは衝突しないものとして写す） | PBKDF2 の衝突困難性 |
| `LangSemantics.Java` | double は、Lean のネイティブ `Float`（ホストの IEEE 754 binary64）とビット単位で突き合わせる（`lean/Tests/JavaDouble.lean`、`lake test`。常時の段で実行する。[checks.md](../rules/checks.md)）。範囲は運賃計算の [Source] の式で、次の 4,006,212 件である。<br>- 因子 `q × 0.01`（q = 0..1000）・`1 − r × 0.01`（r = 0..100）の全件<br>- 全因子 × 金額 0..2,000 の全件<br>- 積算比率 100・125・140 と割引率 0・5・10・20・30 × 金額 0..100,000 の全件<br>- 全因子 × 値域の上限（基本運賃 10,000,000、運賃 100,000,000）までの疑似乱数 1,000,000 件<br>`BigDecimal`（`setScale(-2, mode)` の全丸めモード、`intValue` の切詰め）・`String`（`length`・`trim`・`strip`・`split`）・`LocalDate`（`plusDays`・`minusDays`・`isBefore`・`isAfter`・`DAYS`/`YEARS.between`・`toEpochDay`・`ofEpochDay`。負の年・400 年の境界・PostgreSQL の日付の範囲の端を含む）・double（リテラル・`*`・`-`・`(int)`・特殊値）は、固定の入力表で JVM の実行結果と突き合わせる。表は `JavaTable.java` が JVM で生成した 845 件の `#guard` で、CI（Temurin 17）で再生成して差分が無いことを確かめる（[backlog a8be](../backlog/a8be-lang-semantics-java.md)） | 突き合わせた入力の範囲の外 | ホストの IEEE 754 binary64 が JVM の `double`（Java 17 以降は常に strictfp）と同じであること、JVM |
| `LangSemantics.Sql`・`LangSemantics.Sql.Postgresql` | PostgreSQL 16.15（照合順序 C・UTF8・UTC）の実行結果と、固定の入力表で突き合わせる。表は `pg_table.py` が PostgreSQL で生成した 373 件の `#guard` で、CI で再生成して差分が無いことを確かめる（[backlog c7e8](../backlog/c7e8-lang-semantics-sql.md)）。範囲は次のとおり。<br>- 三値論理（AND・OR・NOT の全組合せ）<br>- 比較（`=`・`<`・`<=`。整数・文字列（ASCII・かな・漢字・補助文字・空文字列）・真偽・NULL）・`BETWEEN`・`IN`・`IS NULL`<br>- `ORDER BY`（同順位・NULL の位置・昇順と降順・複数キー。順序が未規定の照会は、処理系の結果が許される順列に含まれること）と照合順序 C の文字列の並び<br>- `TO_CHAR`（`FM` と `0`・`9` の書式 7 種 × 11 値）<br>- `int2`・`int4`・`int8` の範囲の境界と、`int4` の加算の溢れ<br>- `VARCHAR(n)` への格納（超過分が空白のときの切詰めを含む）<br>- シーケンス（`CYCLE`・尽きたときのエラー・`START`・`INCREMENT`）<br>- `UPDATE` の右辺が更新前の行で評価されること、`WHERE` の UNKNOWN<br>型の異なる値の比較（暗黙の型変換）と、日付の演算は突き合わせていない | 突き合わせた値の範囲の外。版の異なる PostgreSQL | PostgreSQL |

## TargetModel ⇔ 移植先ソース

| 対象 | 決定論的な手段 | 保証しないこと | 信頼の基盤 |
| --- | --- | --- | --- |
| `rust/src/model/`（Verus の写し）と、各実行関数の `requires pre_x`・`ensures r == model::x` の形 | `TargetModel` から生成する（SRC-002）。形を `gen-verus --check-contracts` で検査する（SRC-003） | — | 生成器（[backlog d77c](../backlog/d77c-verus-mirror-generator.md)）と、スキルの assets から写す対応表 `rust/src/model_prelude.rs`（例による照合だけ） |
| 純粋な計算・ユースケースの中核・インメモリのアダプタの状態遷移 | Verus で、全入力について `model/` との一致と溢れが無いことを証明する（SRC-003）。`target-model/` のベクタを照合する（SRC-001） | なし（`verus!` の中） | Verus、vstd、rustc |
| `#[verifier::external]` の境界 | 一覧（下表）に載せたものに限る。CI で一覧と一致することを確かめる | 各境界の行を参照 | — |
| インメモリのアダプタの `Mutex` の層（external） | Kani（SRC-004） | Kani の境界の外（付録に記入） | Rust 標準の `Mutex` |
| `verus!` の外のコード（JSON の変換・HTTP の接続） | Kani（SRC-004）と、HTTP レベルのベクタ（SRC-006） | Kani の境界の外（付録に記入）。ベクタの入力の外 | Kani、rustc、採用したクレート（`trace/target.json`） |
| DB のアダプタ（external） | SQL の差分実行で `TargetModel.Adapter` の SQL の式と照合し（SRC-010）、固定フィクスチャで結合テストする（SRC-005） | 照合したデータ・テストの入力の外（付録に記入） | PostgreSQL |
| ファイル・時計のアダプタ（external） | 固定フィクスチャの結合テスト（SRC-005）。時計は Asia/Tokyo の変換を固定した時刻で照合する | テストの入力の外。`publish` の原子性は OS の rename に依存する | OS のファイル操作、タイムゾーンのデータ |
| 並行実行（直列化可能性） | インメモリでは、`Mutex` の下で操作を 1 つずつ実行する。DB では SERIALIZABLE と再試行を指定し、照会は `READ ONLY DEFERRABLE` で実行する。固定の実行順で結合テストする（SRC-005） | テストしていない実行順 | PostgreSQL の SERIALIZABLE の実装、Rust 標準の `Mutex` |
| 活性（`Conflict`・I/O 失敗を返さないこと） | ベクタと結合テストで、失敗が出ないことを確かめる | 常に失敗を返す実装もリファインメントになる（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md#活性の限界)）。テストしていない状況での失敗の頻度 | — |
| HTTP の規範節（セッション・Cookie・CSRF・トランザクショントークン・Basic 認証・エラー画面） | HTTP レベルのベクタ（SRC-006） | ベクタの入力の外 | 採用した Web フレームワーク |
| 禁止 API（`std::time`・浮動小数点型など） | clippy の `disallowed-methods` / `disallowed-types`（SRC-009） | 一覧に載っていない API | clippy |
| `LangSemantics.Rust` | rustc でビルドした実行結果との突き合わせ（[backlog a936](../../.agents/skills/spec-pivot/references/docs/backlog/a936-lang-semantics-rust.md)） | 突き合わせた入力の範囲の外 | rustc |
| パスワードの照合 | インメモリの参照実装は契約を厳密に満たす（Verus） | 本番のハッシュ関数の衝突 | 採用したハッシュ関数の衝突困難性 |
| Verus の `assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` | 使わない（CI で数える） | （現在なし。使う場合は [refinement.md](refinement.md#未証明の前提) とここに列挙する） | — |

### `#[verifier::external]` の一覧

| 場所 | 理由 | 確かめる手段 |
| --- | --- | --- |
| `rust/src/adapter/in_memory` の `Mutex` の層 | std の `Mutex` を Verus で扱わない | Kani（SRC-004） |
| `rust/src/adapter/db` | DB との通信 | SQL の差分実行（SRC-010）、結合テスト（SRC-005） |
| `rust/src/adapter/file`・`rust/src/adapter/clock` | OS・時計との通信 | 結合テスト（SRC-005） |
| `rust/src/adapter/http` | Web フレームワークとの接続 | Kani（SRC-004）、HTTP レベルのベクタ（SRC-006） |

## モデル間（Lean の証明）

| 対象 | 手段 | 信頼の基盤 |
| --- | --- | --- |
| `Abstraction`・`Refinement`・`Spec` の定理（ABS・REF・SPEC） | Lean の型検査（`sorry`・新規 `axiom`・`native_decide`・`bv_decide` 無し） | Lean の核、公理 `propext`・`Quot.sound`・`Classical.choice`、`Machine` の定義（[backlog 1ae4](../../.agents/skills/spec-pivot/references/docs/backlog/1ae4-machine-refinement-framework.md)） |
| ベクタの期待値 | Lean のモデルの実行（`spec/` は `Spec` の標準の選択）。評価を速くする実装は、元の定義と等しいことの定理を付けた `@[csimp]` で差し替える（SQL の写しの結合。スキルの [ADR b187](../../.agents/skills/spec-pivot/references/docs/decision/b187-proven-csimp-for-evaluating-models.md)） | Lean のコンパイラ（実行のみ。証明には使わない。`@[csimp]` の差し替えを正しく行うことを含む） |
| 証明・検証器の規則の順守（`sorry`・`axiom`・`native_decide`・`bv_decide`・Verus の禁止構文の数） | CI の検査（`#print axioms`、構文の数え上げ） | CI の検査スクリプト |
| R 課題の形と、空虚化を防ぐ付帯の義務（TR-G・TR-N。[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)。成分の必要性 G9 は [ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)） | `lake exe obligation-check`、spec-pivot の `scripts/ci/check_obligations.py` | 2 つの検査器（スキルの `assets/lean/Test/Trace/ObligationFixture.lean` と `tools/ci/fixtures/obligations/` の例による確認だけ） |
| ギャップ（既知差異・PRE の外・未確定）の登録簿・箇所の印・証明の状態の裏付け（TR-D・TR-K・GK。[ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)・[ADR 6ab4](../decision/6ab4-gap-evidence-states-without-axioms.md)） | `@[gap_entry]` の値の検査、`lake exe obligation-check`、`trace check`、表の生成（`trace manifest --check`） | 検査器と生成器（`Test/Trace/` のフィクスチャと spec-pivot の `scripts/trace` の自己テストによる確認だけ）。印をどの定義に付けるか（ギャップの箇所として十分か）は人の判断である。形式化していない主張（`opaque`）の中身は docstring にあり、Lean は何も主張しない |

### モデル間の保証の限界

リファインメント（`Machine.Refines` と [ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md) の付帯の義務）が証明するのは、次のことである。

- 名前付きの差異・非決定性を除けば、具体側の結果は [Spec] の結果と一致する（`Refines.complete`）。
- 名前付きの差異は、ID ごとに、少なくとも 1 つの R 課題で必要である（外すと R 課題の命題が偽になる）か、必要な差異に覆われる（成分の必要性。[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）。
- 入口の機械では、差異の前提を保つ軌跡が [Spec] の軌跡で模倣される（`Refines.run`）。

証明の届かない部分は次のとおりである。

| 対象 | 確かめる手段 | 保証しないこと |
| --- | --- | --- |
| 仕様の妥当性 | 仕様文書の例を、期待値を手で書いた検査（意図から書く例。[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）で [Spec] に照らす。`spec/` のベクタ（標準の選択 `run` の実行結果）を人が読む | [Spec] の標準の選択が、業務の意図どおりであること。B メソッドでも、仕様の妥当性は証明の外である |
| 名前付きの成分の広さ（前提型の差異の述語、観測型の差異の成分、[Spec の非決定性](abstraction.md#spec-の非決定性n-nnn) の選択の型と `FreeFrame` の核、入口の環境の前提 `@[env_pre]`） | 形の制限（TR-G）、両向きの例（W 課題・`Nontrivial`）、成分の必要性（G9）、`EnvWitness`、ベクタの前提のラベル（TR-V）。成分の変異テスト（[backlog 0d1a](../backlog/0d1a-mutation-testing-of-named-components.md)。未実装） | 成分が必要以上に広く、本来の差異を覆い隠していないこと。広さの判断は、登録簿の各行と ADR による。変異テストができた後も、変異の演算子で作れない広さは人の判断である。W 課題の両向きの例のうち「成り立たない例」の側が実際に差を示していることは、定理の文面を人が読んで確かめる |
| 標準の抽象化の核 | 葉ごとの `KernelIs`（ABS-048・REF-012）と、α・β の表の「同一視するもの」 | 表に書いた同一視（例: double の ±0、HTML の構造）が、業務上観測されないこと。`@[kernel]` の関係と表の記述が一致することは、人が確かめる。β・aᵢ の合成（射影で一部を落とすもの）には核を課さない（落とした部分は、aₒ の核と `J` の保存を通してだけ観測に現れる） |
| 活性（環境の非決定性 N-001〜N-003） | `Pinned`（障害の無い環境では選ばない）、ベクタ、結合テスト | 実際の配備で、環境が障害・衝突を示す頻度。環境が常に障害を示せば、具体側は常に失敗しうる（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md#活性の限界)） |
| 「中断」の前提型の差異（[前提型の差異の影響](abstraction.md#前提型の差異の影響)） | 差異の W 課題 | 前提を破る 1 歩の後の軌跡（状態が [Spec] から離れうる）。「出力のみ」と「中断」の分類は人の判断である（迷う場合は「中断」とする） |
| 入口の値域の外の入力 | なし（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md) により、値域の外は差異ではない） | 入口の環境の前提（入力の値域）の外の入力での [Source]・[Target] の振る舞い |
| SPEC-008（標準の環境で、環境に固有の結果を返さない） | 機能ごとの定理 | 定理の文面が SPEC-008 を表していること（検査器は形を確かめない） |
| 入口でない R 課題の PRE | 入口の R 課題の証明で使われること | 入口から到達しない使われ方での振る舞い |
| R 課題の合成 | 主定理を具体機械と [Spec] の間で直接に述べる | `Refines.trans` で合成した貼り合わせは `Glue.ofStd` の形にならず、TR-G の対象にならない |
| 成分の必要性（G9）の範囲 | 差異の ID ごとに、少なくとも 1 つの R 課題についての必要性か被覆の定理 | 次のこと。<br>- 差異を引き継ぐ複合の R 課題（例: ABS-045 の D-001）で、その差異が冗長でないこと（変異テストの「除去」で報告する予定）<br>- 被覆された差異（`.covered`。現在は該当なし）が、覆う差異を取り消した後も要ること（取り消すときに必要性を示し直す）<br>- 必要性の証人の状態が到達可能であること（INV と `J` を満たせばよい）。αᵢ の未定義だけで必要性が成り立つ場合に、移植元が実際に違うこと<br>- 必要性を示した R 課題が、登録簿でその差異を挙げた R 課題であること<br>- 環境の前提の強さ（必要性は、基底の PRE が全域でないことしか示さない） |
| 検査器 TR-G の構文の判定 | `obligation-check` の正例・違反例（スキルの `assets/lean/Test/Trace/ObligationFixture.lean`） | 違反例に無い迂回（例: `@[reducible]` 以外の展開、未知の定数名の付け替え）。検査器は Lean の式の形を見るだけで、意味を見ない |
| シードの妥当性（入口の環境の前提の証拠） | 定理 `Spec.EnvPre.seed_env`（生成した `Spec.Seed` に対する検査関数 `validB` のカーネルの評価と、その正しさ `validB_sound`）。生成物が fixture と一致することは CI の `seed_lean.py --check`。[ADR cd33](../decision/cd33-spec-nondet-types-and-env-pre.md) | fixture（`master_fixture.py` が上流のシードから生成）が DB に投入される値と一致すること。到着時刻 2415 の便マスタ 2 行も `Spec.Seed` に含む（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)） |
| 前提型の差異の前提が十分条件であること（D-001・D-002） | 差異が起きない十分条件の定理（`Abstraction.Fare.Factors.basicFare_src_eq`・`fare_src_eq`）と、安全でない因子の一覧（`basicFactor_unsafe`・`fareFactor_unsafe`。カーネルの評価）。[ADR e9bc](../decision/e9bc-fare-double-analysis.md) | 前提の外の入力で、差異が実際に起きること。安全でない因子でも差異が起きない入力（開発中の探索では、積算比率 447 と割引率 68・92 で差異が見つからなかった）は、R 課題の適用範囲の外になる |

## 追跡の道具

| 対象 | 手段 | 信頼の基盤 |
| --- | --- | --- |
| インベントリと本文ハッシュ | `trace inventory`（tree-sitter-java・tree-sitter-rust、Mapper XML・`web.xml`・SQL ファイル・properties・テンプレートの簡易パーサ）。正規化はコメントを除いたトークン列で、空白の違いを無視し、文字列リテラルの中身は保つ。ハッシュは SHA-256 の先頭 16 桁（[ADR 0eea](../../.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md)） | パーサと正規化の規則（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)） |
| Lean の Merkle ハッシュ | `lake exe trace-dump`。同じ層と、依存する `LangSemantics`・`Machine` の定数を合成する | Lean の `Expr` のハッシュ |
| TR 検査と検査済みハッシュの更新 | `trace check`・`trace rehash`（ソースの本文ハッシュとモデルの Merkle ハッシュの組ごとに、合格した検査を記録する） | spec-pivot の `scripts/trace` |
| 検査の選択（変更時の段を飛ばすこと） | コミット前と PR の CI は、常時の段と、変更が範囲（`tools/ci/check-scopes.toml` のパスの glob と Lean の import の閉包）に当たった長い段だけを実行する（`tools/ci/select_checks.py`。[ADR 9c1c](../decision/9c1c-check-tiers-and-change-scoped-long-checks.md)）。範囲の glob とモジュールの実在、段の分類の漏れは常時の段で検査する。範囲に漏れがあると、PR では飛ばした段の失敗を検出できない。main への push・週次・backlog の完了・版上げの全数（`mise run ci`）で検出する | 範囲の宣言が段の入力を覆うこと（[checks.md](../rules/checks.md#長い段の基準と範囲)）、`git diff` |

## 仕様の外（規範節）の対応

[Spec] の外の規範節（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）は、リファインメントの証明の対象にならない。各規範節を確かめる行は次のとおり。

| 規範節 | 移植元側の行 | 移植先側の行 |
| --- | --- | --- |
| [トランザクション](ports.md#トランザクション) | 並行実行 | 並行実行 |
| [ReportStore の `publish` の原子性](ports.md#reportstore)・[ReportQueue の配信保証](ports.md#reportqueue)（プロセスの異常終了に対するもの） | ReportStore・ReportQueue | ファイル・時計のアダプタ |
| [Clock のタイムゾーン](ports.md#clock) | 「今日」に依存する処理 | ファイル・時計のアダプタ |
| [セッション](http-contract.md#セッション)・CSRF・トランザクショントークン | セッション・Cookie・トランザクショントークン・CSRF | HTTP の規範節 |
| REST の Basic 認証・日付の JSON 表現・エラー画面（[http-contract.md](http-contract.md)） | REST の Basic 認証・日付の JSON 表現・エラー画面への遷移 | HTTP の規範節 |
| パスワードハッシュの互換（[ADR 2d1f](../decision/2d1f-password-hashing-port.md)） | パスワードの照合 | パスワードの照合 |

## 付録: 範囲の詳細（記入待ち）

| 対象 | 記入する内容 | 記入する backlog |
| --- | --- | --- |
| SQL の差分実行（文ごと） | 文、照合したデータ（境界・NULL・同順位を含むか）、パラメータ。マスタの文（区間・便マスタ・搭乗クラス・運賃種別・ピーク時期の `findAll` と、コードリストの SQL 4 つ）は、シードの DB（投入日 2026-11-01）だけで照合した（パラメータ無し。NULL・同順位の行は含まない。`conformance/sql/master-data.json`） | [25f7](../backlog/25f7-fare-calculation-both-models.md)、[0be7](../backlog/0be7-flight-search-usecase.md)、[aedf](../backlog/aedf-reservation-usecase.md)、[4e0e](../backlog/4e0e-member-usecases-and-input-validation.md)、[c7e8](../backlog/c7e8-lang-semantics-sql.md)、[9c04](../backlog/9c04-rust-external-adapters.md) |
| Kani のハーネス（ハーネスごと） | `kani::any()` の範囲、ループの展開数、保証しないこと | [4b0e](../backlog/4b0e-in-memory-adapters-and-seed-data.md)、[a89e](../backlog/a89e-http-contract-adapter.md) |
| 原典実行のハーネスの対象外 | 差し替えた構成: 時計（`dateFactory` を止めた時計に）、DB の接続先（`database.*`）、レポートの出力先（`report.dir` を一時ディレクトリに）、JVM のタイムゾーン（Asia/Tokyo）と書式ロケール（`ja_JP`。D-032 の既定）、原典のログの設定（出さない）、サーブレットコンテナ（組み込み Tomcat）。シードの投入日の値（00230 の `localtimestamp`・00240 の `current_timestamp`・00250 の `current_date` を 2026-11-01 に）。ドメイン層は DI コンテナ・トランザクション・AOP（`ResultMessagesLoggingInterceptor`）を起動しない。範囲: 運賃は全探索（区間の運賃 10 種 × 搭乗クラス 2 × 搭乗日 47 日 = 940 件、その基本運賃 60 種 × 割引率 5 種 = 300 件）、合計金額は抽出（便マスタのある区間 7 の代表便 × 搭乗クラス × 運賃種別 × 搭乗者の型 4 × 2 日 = 544 件）、空席照会は抽出（区間 20 × 搭乗クラス 2 × 片道・往復、搭乗日 2026-11-11 と照会可能期間の境界 3 件 = 83 件）。HTTP は REST の予約 2 件・ログイン 3 件。固定できない操作: なし（時計を読む操作は止めた時計で動く）。障害の注入は行わない | [f18c](../backlog/f18c-java-oracle-harness.md) |
| 言語意味論の突き合わせ | 演算ごとの入力の範囲 | [a8be](../backlog/a8be-lang-semantics-java.md)、[c7e8](../backlog/c7e8-lang-semantics-sql.md)、[a936](../../.agents/skills/spec-pivot/references/docs/backlog/a936-lang-semantics-rust.md) |
