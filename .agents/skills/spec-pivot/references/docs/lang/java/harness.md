---
type: Reference
title: "Java: ベクタの実行（オラクル／照合）"
description: "Java のコードに適合テストベクタを当てるハーネス（オラクル／照合）の作り方。"
tags: [java, language-pack, conformance]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# Java: ベクタの実行（オラクル／照合）

`conformance/` のベクタを Java のコードに対して実行する小さなプログラム（ハーネス）を作る。

## 共通の構成

- ベクタの `operation` ごとに、対象のクラス・メソッドを呼ぶアダプタを書く。
- フレームワークの起動は最小限にする。DI コンテナを起動しないで済む純粋なクラスは直接生成し、フィールドへ注入する（`@Inject`・`@Value`。値は原典の設定ファイルから読む）。
- マスタのキャッシュ（Provider 等）は fixture から組み立てる。DB を起動できるなら、原典のリポジトリ（ORM の設定と写像の定義をそのまま使う）を注入して、原典の読み込み（`@PostConstruct`）を呼んでもよい。その場合は、fixture と DB の一致を別の検査で確かめる。
- ORM の一次キャッシュ（MyBatis の `SqlSession` など）は、ケースごとに消す。原典の DI コンテナ（Spring の `SqlSessionTemplate`）はトランザクションごとにセッションを作るので、キャッシュはケースをまたがない。
- 「今日」は、原典が注入できる `Clock` があればそれで固定する。無ければ実行環境の時計を固定する（例: `-Duser.timezone` と時計を差し替えるエージェント）。固定できない操作は、ハーネスの対象外とする。その操作は、プロジェクトの保証の限界の文書に載せる（[verification.md](../../spec/verification.md#保証の限界)）。
- JSON の読み書きは、ベクタの値の表現（[conformance.md](../../spec/conformance.md#値の表現)）に合わせる。

## 移植元として: オラクル

- `source-model/` の期待値を原典から採取する（`source: "java-oracle"`、`upstream` に版を記録する）。
- 採取した値と Lean `SourceModel` の値が一致しなければ、`SourceModel` 側の不具合とみなす。
- **差分オラクル**（版上げ時）: 旧版と新版の原典を別々のクラスパスで構築し、同じ入力を流して出力を比べる。結果はケースごとの差分一覧として出し、[upgrade.md](../../guide/upgrade.md) の手順 5 に渡す。
- 同じ commit を新旧に指定して差分 0 になること、を最初の確認にする。

## 移植元として: HTTP レベルのオラクル

フレームワークの暗黙の処理（入力の変換・Bean Validation・認証と認可・JSON の変換・エラーページ・テンプレートの書式）は、ドメイン層のオラクルでは観測できない。原典の webapp を起動し、HTTP の要求を送って応答を採取する。

- **起動**: 原典の配備記述子（web.xml）を変えずに読み、サーブレットコンテナで起動する（組み込み Tomcat など）。DispatcherServlet・フィルタの並び・エラーページを原典のまま動かすためである。モックの DispatcherServlet（MockMvc など）は、web.xml を読まないので使わない。
- **差し替え**: DB の接続先・出力先・時計など、ハーネスが決める構成だけを、web.xml の外から足す（Spring なら context-param `globalInitializerClasses` の `ApplicationContextInitializer`。環境のプロパティは `PropertySourcesPlaceholderConfigurer` の設定ファイルより優先される）。差し替えた構成は、プロジェクトの保証の限界の文書に載せる。
- **初期状態**: シードを、固定の基準日で展開して投入する（[conformance.md](../../spec/conformance.md#比較の規則)）。実行時の時刻を書き込むシード（`localtimestamp` など）も基準日にする。ケースは決めた順に、同じ初期状態の上で実行する。
- **採取**: 応答は、状態コード・決めたヘッダ・本文（JSON はそのまま、HTML は要る部分だけ）にする。実行ごとに変わる値（セッション ID・CSRF トークン・ホストとポート）は正規化する。DB の状態の変化を観測するケースは、要求の前後の行を期待値に含める。
- **置き場所**: HTTP の層の [Source] モデルがまだ無いあいだは、採取結果を `conformance/` の外に置く（`modelDef` が実在しないため）。モデルができたら `source-model/` へ移す。

## 道具: conformance-kit

`assets/java/conformance-kit/`（Maven。`dev.spec-pivot:conformance-kit`。Java 17。[ADR 7d3a](../../decision/7d3a-java-conformance-kit-and-http-oracle-method.md)）が、上の共通の部分を持つ。プロジェクトは、操作の割当（`operation` → `Op`）と原典の組み立てを書く。

| クラス | 役割 |
| --- | --- |
| `Json` | ベクタの読み書き。書き出しは Python の `json.dumps(indent=2, ensure_ascii=False)` と同じ字面で、指定した深さ以上を 1 行にできる。比較は整数として、オブジェクトのキーの順に依らない |
| `Op`・`Runner` | `Op` はケースを受け、`expected.ok` と比べる値を返す（Lean の `ConformanceKit.Runner.Op` と同じ約束。業務上の失敗をベクタが値として書くなら、その値を返す）。`check`（照合）、`fill`（期待値の採取）、`saveOrCompare`（`--write` と `--check`） |
| `Reflect` | フィールドへの注入、引数の無いメソッドの呼び出し、インタフェースの差し替え（割り当てていないメソッドは例外） |
| `http.HttpCapture` | 要求の送信と応答の採取・正規化（Cookie はオブジェクトごと。転送は追わない） |
| `http.WebappServer` | web.xml のままの webapp を、組み込み Tomcat で 127.0.0.1 に起動する（context-param を足せる。web.xml にある名前は拒む） |

DB を使うオラクルは、`scripts/ci/with_postgres.sh` を `WITH_POSTGRES_TCP=1` で使う（JDBC は Unix ソケットに接続できないため）。

## 移植先として: 照合

- `target-model/` と `shared/` の全ベクタを、移植先の Java コードに通す（JUnit のパラメータ化テストとして実装する）。

## 道具の例

- JDK（原典の要求する版）、Maven または Gradle。原典のビルドは、作業木を汚さないよう複写してから行う。
- JSON: Jackson（ハーネス自身の設定は固定し、原典の `ObjectMapper` 設定と分ける。conformance-kit の `Json`）。
- サーブレットコンテナ: 原典の配備先と同じ系列の組み込み版（例 `tomcat-embed-core`）。配備のコンテナとの違い（コネクタ・クラスローダの構成）は保証の限界に載せる。
