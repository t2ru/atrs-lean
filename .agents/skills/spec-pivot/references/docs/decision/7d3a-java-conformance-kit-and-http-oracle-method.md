---
type: Architecture Decision Record
title: "Java の適合テストの道具 conformance-kit を assets に置き、HTTP レベルのオラクルの方法を言語パックに書く"
description: "Java のオラクルに共通の部分（ベクタの読み書き・実行器・期待値の採取・反射による組み立て・HTTP の採取・組み込み Tomcat での webapp の起動）を、スキルの assets/java/conformance-kit に Maven モジュールとして置く。言語パックの harness.md に、原典のリポジトリで Provider を読む組み立て、ORM の一次キャッシュ、HTTP レベルのオラクル（web.xml を変えずに context-param で構成を差し替える）の方法を書く。with_postgres.sh に TCP で待ち受ける形を足す。"
tags: [adr, skill, java, oracle, conformance]
id: "7d3ae887-b827-4a9c-a13e-087e5bb09adc"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー（計画の承認）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# Java の適合テストの道具 conformance-kit を assets に置き、HTTP レベルのオラクルの方法を言語パックに書く

## Context and Problem Statement

言語パック [lang/java/harness.md](../lang/java/harness.md) は、移植元のオラクル（原典を実行して `source-model/` の期待値を採取・照合する）の作り方を文章で示すだけで、道具を持っていなかった。適用先 ATRS で最初の Java オラクルを作るにあたり（ATRS の backlog f18c）、次のことが分かった。

* ベクタの読み書き、ケースの実行と期待値の比較、期待値の採取（`source` と `upstream` を付けて書き出す）、DI コンテナを起動せずにフィールドへ注入する補助は、アプリに依存しない。
* Lean の実行器 `ConformanceKit.Runner` は、操作の結果を `expected.ok` と比べる（業務上の失敗は `ok` の中の値として書く）。Java の実行器も同じ約束でないと、同じベクタを両方に通せない。
* 原典の MyBatis のリポジトリを `SqlSession` 1 つで呼ぶと、一次キャッシュがケースをまたいで結果を返す（同じ文・同じ引数）。Spring の `SqlSessionTemplate` はトランザクションごとにセッションを作るので、原典ではこれが起きない。
* フレームワークの暗黙の処理（入力の変換・Bean Validation・Spring Security・Jackson・エラーページ）を確かめるには、原典の web.xml のままの webapp を起動する必要がある（DispatcherServlet が 2 つ、フィルタの並び、エラーページ）。MockMvc は DispatcherServlet を 1 つしか持たず、web.xml を読まない。
* 時計・DB・出力先の差し替えを web.xml の書き換えで行うと、原典の構成そのものが変わる。
* `with_postgres.sh` の一時クラスタは Unix ソケットだけで待ち受けるので、JDBC（PgJDBC）から接続できない。

## Decision Drivers

* アプリに依存しない道具はスキルに置く（ATRS の ADR f4e1、[ADR edc8](edc8-skill-scripts-and-generic-lean-libraries.md)）
* オラクルは原典を改変しない。差し替えた構成は保証の限界に載せる（[spec/verification.md](../spec/verification.md#保証の限界)）
* Lean の実行器と同じベクタ・同じ比較で動く

## Considered Options

* (A) conformance-kit を `assets/java/conformance-kit/` に Maven モジュールとして置き、HTTP は組み込み Tomcat で原典の web.xml を読む
* (B) ハーネスを適用先に置くだけにし、スキルは文書だけにする
* (C) HTTP レベルのオラクルを MockMvc で作る

## Decision Outcome

Chosen option: "(A)", because 汎用の部分を次の移植で使い回せ、原典の web.xml の構成（サーブレット・フィルタ・エラーページ）をそのまま動かせるからである。

| 項目 | 決定 |
| --- | --- |
| 置き場所 | `assets/java/conformance-kit/`（Maven。`dev.spec-pivot:conformance-kit`）。Java 17。依存は Jackson 2（ハーネス自身の `ObjectMapper`。原典の設定と分ける）と、任意の `tomcat-embed-core`。版は使う側の `dependencyManagement` で原典にそろえてよい |
| `Op`・`Runner` | `Op` はケースを受け、`expected.ok` と比べる値を返す（Lean の `ConformanceKit.Runner.Op` と同じ）。想定外の例外はケースの失敗。`Runner.check`（照合）、`Runner.fill`（期待値を採取し `source` を付ける）、`Runner.saveOrCompare`（`--write` で書き、`--check` で差分 0 を求める） |
| 書き出しの字面 | Python の `json.dumps(indent=2, ensure_ascii=False)` と同じ字面。生成するベクタを小さくするため、指定した深さ以上を 1 行に書ける（`Json.write(n, flatDepth)`）。数は整数だけ |
| `Reflect` | フィールドへの注入（private・package-private を問わない）、引数の無いメソッドの呼び出し（`@PostConstruct`）、インタフェースの差し替え（割り当てていないメソッドは例外） |
| `http.HttpCapture` | 要求（`method`・`path`・`query`・`headers`・`json`・`form`）を実際の HTTP で送り、応答を `{status, headers, json?}` に採取する。ヘッダは決めたものだけを小文字で残し、`Location` のホスト・ポートと `;jsessionid`、`Set-Cookie` の値を正規化する。Cookie はオブジェクトごと。転送は追わない |
| `http.WebappServer` | 原典の web.xml のままの webapp を、組み込み Tomcat で 127.0.0.1 の空いているポートに起動する。クラスは使う側のクラスパスから読む。Tomcat の既定の web.xml（JSP・DefaultServlet）は足さない。構成の差し替えは context-param を足して行い（例 Spring の `globalInitializerClasses`）、web.xml に同じ名前があれば起動を止める |
| harness.md | 組み立ての既定に「DB を起動できるなら、Provider は原典のリポジトリで読む（fixture と DB の一致を別の検査で確かめる）」を加える。ORM の一次キャッシュをケースごとに消すこと、HTTP レベルのオラクルの方法（起動・差し替え・採取・正規化・保証の限界に載せるもの）を書く |
| `with_postgres.sh` | 環境変数 `WITH_POSTGRES_TCP=1` で、一時クラスタを 127.0.0.1 の空いているポートでも待ち受けさせ、`PGHOST`・`PGPORT` を渡す |

### Consequences

* Good, because 次の Java の移植元で、ベクタの実行と採取を書き直さずに済む
* Good, because 原典の web.xml・フィルタ・エラーページが動いたまま、フレームワークの暗黙の処理を観測できる
* Bad, because 組み込み Tomcat は配備のコンテナ（例: cargo の Tomcat）と同じではない（コネクタの設定・クラスローダの構成が違う）。保証の限界に載せる
* Bad, because スキルに Maven のモジュールが加わり、Java の道具の版を保守する必要がある

### Confirmation

* 適用先 ATRS で、運賃計算・空席照会の既存のベクタ（`shared/`・`source-model/`）がすべて原典の実行と一致し、kit で採取した 1,867 件のベクタを Lean の `SourceModel` も通った（ATRS の backlog f18c）。
* 同じ原典に対して `--check` を繰り返し、採取結果の差分が 0 だった（時計・投入日の値を固定した）。

## Pros and Cons of the Options

### (B) 適用先だけに置く

* Good, because スキルの保守が増えない
* Bad, because ベクタの読み書き・比較の約束を、移植ごとに書き直す

### (C) MockMvc

* Good, because サーブレットコンテナが要らない
* Bad, because DispatcherServlet が 1 つで、web.xml のフィルタの並び・エラーページを再現しない

## More Information

* 来歴: 適用先 ATRS の ADR 81da（Java オラクルの構成と、REST の日付・ログイン時の状態更新の確認）。
* [lang/java/harness.md](../lang/java/harness.md)、[spec/conformance.md](../spec/conformance.md)、[lang/sql/dialects/postgresql/harness.md](../lang/sql/dialects/postgresql/harness.md)
