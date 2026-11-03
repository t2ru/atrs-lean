---
type: Architecture Decision Record
title: "Java の原典実行の構成（ドメイン層と HTTP レベル）と、REST の日付・ログイン時の状態更新の確認"
description: "backlog f18c の Java の原典実行を、原典を複写してビルドしたものに対して動かす。ドメイン層は DI コンテナを起動せずに原典の MyBatis とサービスを組み立て、運賃計算・空席照会のベクタを照合し、シードの範囲のベクタを採取する。HTTP レベルは、原典の web.xml のままの webapp を組み込み Tomcat で起動し、時計・DB・report.dir だけを差し替える。REST の LocalDate は yyyy-MM-dd であり、画面ログインは MEMBER_LOGIN を更新せず REST の Basic 認証は更新することを確かめ、D-028 を観測型の既知差異にした。f18c の依存から a8ef を外す。"
tags: [adr, origin-run, java, conformance, source-model, gap, authentication, http]
id: "81da860a-bf12-4088-89ee-cfb680e343bb"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー（a8ef の依存を外すこと、両方の原典実行を CI にかけること、計画の承認）。D-028 の種類（観測型）と、REST の Basic 認証での状態更新を同じ差異に含めることは、計画の後に作業の中で決めた（プロジェクトオーナーの確認待ち）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# Java の原典実行の構成（ドメイン層と HTTP レベル）と、REST の日付・ログイン時の状態更新の確認

## Context and Problem Statement

[backlog f18c](../backlog/f18c-java-oracle-harness.md) は、[Source]（`SourceModel`）の正しさを原典そのもので確かめる。完了条件は次のとおりである。

1. 運賃計算の [Source] ベクタが Java の原典実行と一致する（[ADR e9bc](e9bc-fare-double-analysis.md) で bbcc から移した）
2. 空席照会の [Source] ベクタが Java の原典実行と一致する（[ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md) で 0be7 から移した）
3. [`Spec.Http`](../../lean/Spec/Http.lean#rest-apiapiv1)（REST の日付の JSON 表現）と [`Spec.Authentication`](../../lean/Spec/Authentication.lean#ログインlogin)（ログイン時の状態更新。D-028 は未確定）の TODO(spec) を解消する
4. HTTP レベルのハーネスで、Spring を起動した原典に要求を送り、応答をベクタの形で採取できる
5. 対象外とした操作とベクタの範囲を [assurance.md](../spec/assurance.md) に書く

着手にあたって、次の問題があった。

1. f18c の `depends_on` は a8ef（適合テストベクタの生成と検査。todo）を持つ。規約（[backlog.md](../rules/backlog.md)）では着手できない。
2. 原典は Spring の DI コンテナ・MyBatis・PostgreSQL・組み込みの ActiveMQ・Spring Security で動く。ドメイン層の計算を確かめるのに、どこまで起動するか。
3. HTTP レベルでは、フレームワークの暗黙の処理（web.xml の 2 つの DispatcherServlet、フィルタの並び、エラーページ、Jackson の版の選択）をそのまま動かしたい。一方で、DB の接続先・時計・レポートの出力先はハーネスが決める必要がある。
4. 開発環境から Maven Central に届かないことがある（HTTP 429）。

## Decision Drivers

* 基本原則 1（[ADR c336](c336-foundational-principles.md)）: 移植元プログラムと移植元モデルの一致を、決定論的な検証で確かめる
* 原典を改変しない（f18c の対象外）。差し替えた構成は保証の限界に載せる
* アプリに依存しない道具はスキルに置く（[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md)）
* 既存の実行器（`lake test` の `ConformanceKit.Runner`）とベクタの形を変えない

## Considered Options

* 依存: (a) a8ef を外して着手する、(b) 先に a8ef を済ませる、(c) f18c を分割する
* ドメイン層の組み立て: (a) DI 無しで原典のクラスを組み立て、原典の MyBatis で PostgreSQL を読む、(b) Spring のルートの文脈を起動する、(c) リポジトリを fixture から作る Proxy にする
* HTTP レベル: (a) 組み込み Tomcat に原典の web.xml のままの webapp を載せ、context-param で差し替える、(b) MockMvc、(c) web.xml を書き換える

## Decision Outcome

Chosen option: "依存 (a)・組み立て (a)・HTTP (a)", because 原典実行に要るのはベクタの形（[ADR dc3a](dc3a-conformance-test-vectors.md)）と既存の実行器だけで、原典の SQL・MyBatis の写像・web.xml を改変せずに動かせ、差し替えが 3 つ（時計・DB・出力先）に収まるからである（プロジェクトオーナーの決定。両方の原典実行を CI にかけることも同じ）。

| 項目 | 決定 |
| --- | --- |
| a8ef の依存 | f18c の `depends_on` から外す。生成したベクタへの `outsidePre` の付与（TR-V）は a8ef に残す。原典実行が生成したベクタは、既存の `source-model/fare/fare.json` と同じく、ファイルの `differences` だけを持つ |
| 原典のビルド | `tools/origin-run/build-upstream.sh` が `upstream/atrs/JavaConfig-Thymeleaf/atrs` を `tools/origin-run/target/upstream/` へ複写し、`mvn -pl atrs-web -am install` する。atrs-web（war）の classes は分類子 `classes` の jar として入れ、ハーネスはそれに依存して推移的な依存を得る。ハーネスの pom の親は原典のルートの pom（`jp.co.ntt.atrs:atrs`）で、依存の版が原典とそろう |
| 道具の分担 | アプリに依存しない部分はスキルの `assets/java/conformance-kit`（[スキルの ADR 7d3a](../../.agents/skills/spec-pivot/references/docs/decision/7d3a-java-conformance-kit-and-http-origin-run-method.md)）。ATRS のハーネスは `tools/origin-run/`（`atrsoriginrun`）。入口は `tools/ci/java_origin_run.sh [domain\|http\|all] [--write]`、mise のタスクは `origin-run:domain`・`origin-run:http`・`origin-run:gen` と、一括検査の `ci:java-origin-run` |
| ドメイン層の組み立て | 原典の `MybatisConfig.configuration()` に PostgreSQL の環境を付け、Mapper の XML をそのまま登録する。Provider は原典のリポジトリを注入して `load()` を呼ぶ（fixture と DB の一致は既存の `Tests.MasterSql`）。サービスと `TicketHelper` は `new` で作って注入し、`@Value` は jar の中の `atrs.properties` から読む。`dateFactory` は、ケースの今日の 10:00 JST に止めた時計。JVM は `Asia/Tokyo`・`ja_JP`（D-023・D-032）。MyBatis の一次キャッシュはケースごとに消す（Spring ではトランザクションごとにセッションが作られるため） |
| DB | `SeedDb` が上流のシードを投入する。投入日に依存する値は 2026-11-01 で展開する（00230 の `localtimestamp`、00240 の `current_timestamp`、00250 の `current_date`。[ADR 9ee4](9ee4-clock-timezone-and-fixture-base-date.md)）。ドメイン層はマスタだけの DB で、空席照会のケースごとに FLIGHT 表を入力の行にする。接続は `with_postgres.sh` の `WITH_POSTGRES_TCP=1`（CI はサービスコンテナ） |
| 照合 | `conformance/{shared,source-model}/{fare,flight-search}/` の全ケースを原典で実行し、期待値と比べる。`source-model/fare/fare.json` の既存のケースは、一致を確かめて `source: "java-origin-run"` に改めた |
| 採取（シードの範囲） | `conformance/source-model/fare/origin-run-basicFare.json`（区間の運賃 × 搭乗クラス × 搭乗日（投入日と、各ピーク時期の前日・初日・末日・翌日）の全組。940 件）、`origin-run-fare.json`（その基本運賃のすべて × シードの割引率のすべて。300 件）、`origin-run-totalFare.json`（便マスタのある区間の代表便 × 搭乗クラス × 運賃種別 × 搭乗者の型 × 2 日の抽出。544 件）、`source-model/flight-search/origin-run-searchFlight.json`（区間 × 搭乗クラス × 片道・往復、搭乗日 2026-11-11 と、照会可能期間の境界。83 件）。`lake test` が SourceModel と照合する（`lean/Tests/Main.lean` に `source-model/flight-search` を足した）。`--check` は再生成して差分 0 を求める |
| HTTP レベル | 組み込み Tomcat（`tomcat-embed-core`。原典の BOM の版）に、複写した `atrs-web/src/main/webapp` を `/atrs` で載せる。context-param `globalInitializerClasses` で `OriginRunContextInitializer` を足し、`database.*`・`report.dir` を環境の PropertySource で上書きし、`dateFactory` を 2026-11-03T10:00 JST に止めた時計にする。ActiveMQ は原典どおり内蔵のものを起動する |
| HTTP の採取結果 | `tools/origin-run/http/postTicket.json`・`login.json`（ベクタの形。`modelDef` は `null`）。`SourceModel.Http` がまだ無く、`conformance/` に置くと TR-R に掛かるため、backlog 4e0e・a89e で `conformance/source-model/http/` へ移す |
| Maven のミラー | CI は Maven Central のまま。ローカルで届かないときは、環境変数 `MAVEN_SETTINGS` に `mvn -s` の設定（例: Google のミラー）を与える。設定はリポジトリに置かない |
| 追跡 | `trace/checks.json` に `java-origin-run`（`mise run origin-run:domain`・`mise run lean:test`。運賃計算・空席照会のベクタ）を登録した。`trace rehash` は、ハッシュの変わった組か記録の無い組だけを対象にするので、既存の組の記録（`lake-test`）はそのままで、次に対象になったときに `java-origin-run` も実行される |

### 確認の結果

| 対象 | 結果 |
| --- | --- |
| 運賃計算・空席照会の既存のベクタ | すべて原典の実行と一致した（`shared/fare` 13 件、`source-model/fare` 1 件、`shared/flight-search` 21 件）。採取した 1,867 件を Lean の `SourceModel` も通った |
| REST の日付（http-contract.md の TODO） | `POST /api/v1/ticket` の要求の `depDate` を `"yyyy-MM-dd"` で送ると予約され（201）、応答の `paymentDate`・`selectFlightResourceList[].depDate` も `"yyyy-MM-dd"`。`"yyyy/MM/dd"` は Jackson 3 の `LocalDateDeserializer` で失敗し 400（`e.ar.fw.9999`）。ソースの読解のとおりで、規範節は変えない |
| ログイン時の状態更新（authentication.md の TODO） | 画面ログイン（`POST /auth/dologin`。302 で `/atrs/` へ）の前後で、`MEMBER_LOGIN` の `LOGIN_DATE_TIME`・`LOGIN_FLG` は変わらない。REST の HTTP Basic 認証（`GET /api/v1/flight`）が成功すると、`LOGIN_DATE_TIME := 今日`・`LOGIN_FLG := true` に更新される |

D-028 は、未確定から **観測型** の既知差異に改めた（`lean/Abstraction/Gap.lean`）。成分は `obs_D028`（予定）: 貼り合わせで、会員のログイン状態を対応させない。R 課題は ABS-043（認証）と ABS-045（HTTP。REST の Basic 認証）、W 課題は ABS-128 とし、成分と証明は backlog 44f8（と a89e）で置く。証明の状態は「未証明」。
前提型にしないのは、前提で避けられる入力が無い（画面ログインでは常に更新されない）からである。REST の Basic 認証での更新は、同じ状態の欄の違いなので、同じ差異に含めた。

### Consequences

* Good, because 運賃計算・空席照会の [Source] の期待値が、原典の実行で確かめられ、シードの範囲の 1,867 件で SourceModel との一致が CI で続けて確かめられる
* Good, because 原典の web.xml・フィルタ・Jackson の版の選択が動いたまま、HTTP の振る舞いを観測できる。D-028 が確定し、REST の Basic 認証での状態更新という読解に無かった振る舞いが見つかった
* Bad, because CI に Maven のビルドと原典の起動が加わり、時間が延びる（`~/.m2` をキャッシュする）
* Bad, because 差し替えた構成（時計・DB・`report.dir`・組み込み Tomcat）の下での振る舞いであり、配備の構成との違いは保証の限界に残る

### Confirmation

* `mise run origin-run:domain`・`mise run origin-run:http`（`--check`）が OK で、`mise run lean:test` が通る。
* `mise run trace:check`・`mise run trace:manifest`・`docs:okf`・`docs:ids` が通る。D-028 の新しい警告（TR-D・TR-K）は、44f8 の段階導入の警告である。

## Pros and Cons of the Options

### 組み立て (b) Spring のルートの文脈を起動する

* Good, because 注入の配線を書かなくてよい
* Bad, because JMS・トランザクション・AOP まで起動し、ケースごとの今日の固定が bean の差し替えになる

### 組み立て (c) リポジトリを fixture から作る

* Good, because DB が要らない
* Bad, because 空席照会の SQL（`findByVacantSeatSearchCriteria`）を、ハーネスが書き直すことになる

### HTTP (b) MockMvc

* Bad, because DispatcherServlet が 1 つで、web.xml のフィルタ・エラーページを読まない

### HTTP (c) web.xml を書き換える

* Bad, because 原典の構成そのものが変わる

## More Information

* [スキルの ADR 7d3a](../../.agents/skills/spec-pivot/references/docs/decision/7d3a-java-conformance-kit-and-http-origin-run-method.md)（conformance-kit と HTTP レベルの原典実行の方法）
* [ADR e9bc](e9bc-fare-double-analysis.md)・[ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md)（完了条件を f18c に移した決定）、[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)（`source-model/` の期待値の暫定措置）、[ADR cc24](cc24-gap-registry-as-lean-attributes.md)・[ADR 6ab4](6ab4-gap-evidence-states-without-axioms.md)（ギャップの登録簿と証明の状態）
