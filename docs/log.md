# Directory Update Log

## 2026-11-02

* **Creation**: [ADR ab93](decision/ab93-reservation-stage3-world-alpha-and-abs041.md) で、[backlog aedf](backlog/aedf-reservation-usecase.md) の第 3 段を始めた（小段 3a〜3d）。
  * 3a: 状態の α `worldOfDb` を全表（会員・予約・シーケンス）に広げて `Abstraction.World.Alpha` に置き、具体側の不変条件 `IcW` を足した。空席照会の初期状態を、シードを投入した後の `World`・状態の表に揃え、ABS-011 を新しい貼り合わせで通した。初期状態の対応は `Abstraction.World.Init`。
  * [spec/abstraction.md](spec/abstraction.md) の α の表、[spec/assurance.md](spec/assurance.md) の暫定の行を改めた。`trace/features.json` の Reserve に `World` を足した。[index.md](index.md) に ADR を足した。
  * 3b（途中）: 予約の PRE を広げ（`Request.Valid`・`World.RefMaster`・`World.MemberRefMaster`）、予約の入出力の α・貼り合わせと、ポート・Provider・選択フライトの補題、Hoare 三つ組の枠組みを置いた。ADR ab93 と [backlog/aedf](backlog/aedf-reservation-usecase.md) に進み具合を記した。
  * 3b（途中）: 3c の前に検証の道具を整えた（プロジェクトオーナーの決定）。Hoare 三つ組と簡約のタクティク `java_estate_simp` をスキルの assets に置き（スキルの ADR cd90。スキルの版を 0.26 にした。[rules/atrs-porting.md](rules/atrs-porting.md)）、選択フライトの検証の対応 `Abstraction.Reserve.ValidateFlights` を示した。ABS-021・ABS-023 を L 課題に改め（プロジェクトオーナーの決定）、[spec/abstraction.md](spec/abstraction.md) の証明課題の表とポートの契約の段落、登録簿の D-009 の R 課題の欄を改めた。
  * 3b（途中）: 予約の差異の述語 7 つと非自明性の定理（`Abstraction.Reserve.Alpha`・`Witness`）、D-031 の証人の材料を置いた。登録簿の D-001・D-002・D-009・D-012・D-014・D-027・D-031 の前提の欄と証明の状態の説明を改めた（表は [spec/abstraction.md](spec/abstraction.md) に生成）。ADR ab93・[backlog/aedf](backlog/aedf-reservation-usecase.md) を改めた。
  * 3c（途中）: 予約内容の検証（代表者の年齢・運賃種別の利用条件・代表者と搭乗者の会員照合・トランザクション）の三つ組と [Spec] の対応、予約の合計金額の補題を置いた（`Abstraction.Reserve.Validate`・`MemberCheck`・`ValidateReservation`・`TotalFare`）。選択フライトの検証（前段）の合成と、出力の値とする例外の像の補題を置き（`Selects`・`Catch`）、具体機械の業務例外のメッセージの分解を 1 文字の区切りの `String.split` にした。予約情報の組み立ての対応と予約確認の後段の三つ組を置いた（`Draft`・`SpecFacts`・`Confirm`）。障害の例外 `IsFault` に実行環境を持たせ、業務例外の引数が改行を含まない補題（`NoNL`）を置いた。予約確認の 1 歩の対応 `confirm_run`（ABS-041 の予約確認の側）を示した（`ConfirmRun`）。予約確定の空席の確保の三つ組を置いた（`Vacancy`）。採番の文・予約番号の書式（L 課題 ABS-021）と、予約の表への追加の α を置いた（`Register`）。予約・予約フライト・搭乗者の行の挿入の文の補題を置いた（`Insert`）。取消の後の α と、1 件ずつの挿入・搭乗者の列・予約フライトの列の挿入の三つ組、[Spec] の `register` の採番の分解を置いた（`Rollback`・`RegisterRun`・`RegSpec`）。スキルに `Hoare.forIn_idx` を足した。予約番号の書式の単射性と既存の行の番号の補題を置いた（`Keys`）。予約の登録全体の三つ組を示した（`FlightFacts`・`Registration`）。ADR ab93・[backlog/aedf](backlog/aedf-reservation-usecase.md) を改めた。
* **Creation**: [ADR 1add](decision/1add-license-mit-or-apache-2-0.md) で、公開のライセンスを MIT OR Apache-2.0 のデュアルライセンスにした。ルートに `LICENSE-MIT`・`LICENSE-APACHE`・`NOTICE`（上流 ATRS の著作権・ライセンスと、上流から派生した部分の一覧）・`README.md` を置いた。`AGENTS.md`・[index.md](index.md) を改めた。
* **Creation**: [ADR ca17](decision/ca17-reservation-stage2-machines-seed-nondet-advance.md) で、[backlog aedf](backlog/aedf-reservation-usecase.md) の第 2 段を行った。
  * スキルに、同じ状態の上の並置 `Machine.alt` 一式を足した（スキルの ADR a303。版 0.25）。
  * 抽象機械 `Spec.UseCase.Reserve.reserveMachine` を置き、予約の SPEC-001・002・003・004・007・008 を証明した。N-001・N-002 の選択の型に、採番の前進 `SeqAdvance` を持たせた（確認待ち。[spec/abstraction.md](spec/abstraction.md) の表を直した）。
  * 具体機械 `SourceModel.ReserveQuery.reserveConcrete` を置いた。
  * 会員のシードの生成器 `tools/conformance/member_seed.py` を置き、初期状態 `Spec.Seed.World`・`SourceModel.Db.Seed` を作った。
  * 予約の SQL の差分実行（`tools/conformance/reservation_sql.py`・`conformance/sql/reservation.json`・`Tests.ReservationSql`・検査 `pg-reservation-sql`）を足した。制約の検査の順のずれ 4 件を、写しを直して解消した。[spec/conformance.md](spec/conformance.md)・[spec/assurance.md](spec/assurance.md) を改めた。
  * [backlog/aedf](backlog/aedf-reservation-usecase.md) に第 2 段の結果を、[index.md](index.md) に ADR を足した。

## 2026-11-01

* **Creation**: [ADR f786](decision/f786-gap-inventory-and-registry-fixes.md) で、[Spec] と [Source] の差異の登録簿（`lean/Abstraction/Gap.lean`）を、実装済みと未着手の全範囲で上流の原典と突き合わせて棚卸しした。
  * 誤りを直した: D-031 の R 課題（ABS-021 → ABS-031・ABS-041・ABS-045）、D-032 の前提の文（`formatSymbols`）、D-030 の証拠（PRE の述語）、「PRE: MD-3」の誤った注記（`Spec.Fare`・[spec/fare-calculation.md](spec/fare-calculation.md)）、欠けた `@[gap]` の印、仕様文書の D 番号の引用、[spec/assurance.md](spec/assurance.md) の被覆の例、[spec/errors-and-messages.md](spec/errors-and-messages.md) の表。
  * オーナーの判断で、D-034〜D-036（PRE の外）・D-037（モデル外）・D-038〜D-041（前提型。W 課題 ABS-138〜141）を登録し、D-006・D-009・D-020・D-030・D-033 と R 課題を広げた。REST の予約の応答の `"empty": false` は [Spec] を原典に合わせた（[spec/http-contract.md](spec/http-contract.md#post-apiv1ticket)）。[ADR 0b0c](decision/0b0c-flight-search-stage3-abs011.md) の保留 2 件を承認した。
  * [spec/abstraction.md](spec/abstraction.md) の生成表と課題表、[spec/reservation.md](spec/reservation.md)・[spec/ports.md](spec/ports.md)・[spec/input-validation.md](spec/input-validation.md)・[spec/master-data.md](spec/master-data.md)・[spec/flight-search.md](spec/flight-search.md)・[spec/configuration.md](spec/configuration.md)・[spec/reservation-history-report.md](spec/reservation-history-report.md)・[spec/domain-model.md](spec/domain-model.md) を改めた。
  * 原典実行で確かめてから判断する候補を [backlog ceb8](backlog/ceb8-origin-run-checks-for-gap-candidates.md) にした。棚卸しの手順をスキルの [guide/gap-inventory.md](../.agents/skills/spec-pivot/references/docs/guide/gap-inventory.md) に置き（[スキルの ADR cb1f](../.agents/skills/spec-pivot/references/docs/decision/cb1f-gap-inventory-procedure.md)）、spec-pivot の版を 0.26 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。
* **Creation**: [ADR 4c45](decision/4c45-reservation-stage1-shared-state-and-source-model.md) で、[backlog aedf](backlog/aedf-reservation-usecase.md)（予約）を 3 段に分け、第 1 段を行った（`doing`）。
  * [Spec]: `Spec.Ticket`（選択フライトの解決と `validateFlightList`）、`Spec.UseCase.Reserve`（予約入力、搭乗者欄を詰める処理、予約内容の組み立て、`validateReservation`、`reserveConfirm`、`reserve`、選択フライトの検証を含む操作 `confirmOp`・`reserveOp`）。`Spec.Port.World` に会員・予約・採番（`Sequences`）とポートの操作を、`Spec.Error.AtrsError` に `invalidRequest`・`system`・`conflict` を、`Spec.Model` に `PassengerRecord` を足した。
  * [Source]: 原典のソースツリーの形で、`App.B2`（フォーム・`B2Mapper`・`TicketReserveHelper`）、`TicketSharedServiceImpl.validateFlightList`、`TicketReserveServiceImpl` の `validateReservation`・`registerReservation`（`findMember` は画面の初期値だけが使うので、HTTP の backlog a89e で写す）、`MemberRepository.findOne`・`ReservationRepository` の 3 つの insert・`FlightRepository` の `exists`・`findOneForUpdate`・`update`、モデルのクラスを写した。状態の表に会員・予約の表とシーケンスを足し、状態の表に対する計算 `SourceModel.Db.Tx`（Mapper の文・`@Transactional` の取消・Clock・実行環境）と、入口の計算 `SourceModel.ReserveQuery` を置いた。
  * 共有ベクタ `conformance/shared/reservation/` の 47 件が `Spec` と `SourceModel` で通る（期待値は仕様の例と手計算）。[spec/conformance.md](spec/conformance.md) に操作を足した。
  * Java の原典実行（`tools/origin-run`）に予約の操作を足した。47 件が原典と一致し、シードの範囲から予約確認の 76 件を採取した（`conformance/source-model/reservation/origin-run-confirm.json`）。原典の `TicketReserveServiceImpl` は Spring の `TransactionInterceptor` で包む。`trace/checks.json` の `java-origin-run` の範囲を広げた。[spec/assurance.md](spec/assurance.md) の移植元側の行と、暫定の限界（空席照会の α の定義域）を改めた。
  * `trace/features.json` の Reserve・Member の `lean` を改め、`trace/upstream.json` に spring-tx・spring-jdbc・mybatis-spring・mapstruct を足した。
  * 敵対的レビューの指摘と対応は ADR 4c45 に記した。
  * 空席照会の α `worldOfDb` の定義域を、予約・会員の表とシーケンスが使われていない状態に限った（ABS-011 は通り続ける）。
  * 登録簿: D-009 の範囲を INT の上限に広げた（確認待ち）。D-031 の R 課題を ABS-031・ABS-041・ABS-045 に直した（確認待ち）。D-014 に予約確定の Clock の読み出しを足した。
  * スキルの側は [スキルの ADR a303](../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)（`Machine.alt` の方針、`LangSemantics.Sql.Transaction`、`PgTimestamp`、`JLocalTime`、`JList.get`、`StringUtils`）。スキルの版を 0.25 にした（[rules/atrs-porting.md](rules/atrs-porting.md)。main の 0.24 の後）。[backlog/README.md](backlog/README.md)、[index.md](index.md) を改めた。
* **Creation**: [ADR aaf8](decision/aaf8-drop-long-tests-tier.md) で、`lake test` の分割をやめ、長い検査の段 `long-tests`（mise の `lean:test-long`）を無くした。[ADR 9c1c](decision/9c1c-check-tiers-and-change-scoped-long-checks.md) には追記だけを足した（層・範囲・選択の決定は変わらない）。
  * シードの DB を使う SourceModel の照合が遅かった原因は、SourceModel の SQL の写し（`findAllFlightMaster`・`vacantSeatRows`・`RouteRepository.findAll`）が直積の全件（1 回で最大約 650 万組）を作ってから選び、ケースごとにそれを評価していたことだった。
  * 条件を押し下げた結合が元の定義と等しいことを定理にし、`@[csimp]` でコンパイル後のコードだけを差し替えた（スキルの ADR b187、スキルの版 0.24）。定義・証明・検査の中身は変えていない。CI で 4 つの節が合わせて約 359 s から約 0.9 s になった。
  * 残る暦日の全日と double の総当たり（CI で約 7 s）も `lake test` に戻し、`lean/Tests/Long.lean`・`LongMain.lean`、`long-tests` の実行ファイル、`lean:test-long`、その範囲（`tools/ci/check-scopes.toml`）、`trace/checks.json` の段、layout-check の組（5 組にした）を除いた。
  * 廃止の後の CI（run 41320107059）で、`lake test` 全体は約 20 s（うち約 18 s は起動と、全日・総当たりの初期化での評価）だった。
  * [rules/checks.md](rules/checks.md)・[rules/atrs-porting.md](rules/atrs-porting.md)・[spec/assurance.md](spec/assurance.md)・[spec/domain-model.md](spec/domain-model.md)・`AGENTS.md`・[index.md](index.md) を改めた。

* **Creation**: [ADR 9c1c](decision/9c1c-check-tiers-and-change-scoped-long-checks.md) と [backlog 7d08](backlog/7d08-change-scoped-checks.md) で、検査を常時の段（`ci:fast`）・変更時の段・全数（`ci`）に分け、実行の時点を規約 [rules/checks.md](rules/checks.md) にした。コミット前と PR の CI は選択実行 `mise run check`、main への push・週次・手動・backlog の完了・版上げは全数。
  * CI で 20 秒以上かかる段（`lean:test-long`・`lean:layout-check`・`assets:trace-test`・`assets:layout-check`・`trace:self-test`・`ci:pg-table`・`ci:master-sql`・`ci:java-origin-run`）の範囲を `tools/ci/check-scopes.toml` に宣言し、`tools/ci/select_checks.py` が選ぶ。整合は `static:check-scopes` が検査する。
  * `lake test` から 20 秒以上かかる節（シードの DB を使う SourceModel の適合ベクタ・空席照会の SQL の結果・暦日の全日・double の総当たり）を実行ファイル `long-tests`（`lean/Tests/Long.lean`・`LongMain.lean`）に分けた。layout-check の組は増やさない（組を足すと CI の runner のメモリが尽きた）。`lake test` の各節は経過時間を表示する（`Tests.Report`）。`trace/checks.json` で `lean:test` を実行する検査は `lean:test-long` も実行する。
  * `.github/workflows/lean.yml` の起動を `pull_request`・main への `push`・週次・手動にし、PR の二重起動をやめた。検査の段で 20 秒ごとにメモリの使用量を出す（`[mem]`）。
  * 測った結果: `lake test` は 384 s → 約 3 s、`long-tests` は約 216 s、全数は 531 s、runner のメモリの最大は 6.3 GB / 7.9 GB。
  * [rules/version-control.md](rules/version-control.md)・[rules/backlog.md](rules/backlog.md)・[rules/README.md](rules/README.md)・[rules/atrs-porting.md](rules/atrs-porting.md)、[spec/assurance.md](spec/assurance.md)・[spec/domain-model.md](spec/domain-model.md)、`AGENTS.md`、[index.md](index.md)・[backlog/README.md](backlog/README.md) を改めた。
* **Creation**: [ADR 8bb7](decision/8bb7-pr-draft-until-review-ready.md) で、PR を draft で作り、人間にレビューを求める段（作業の完了・確認と CI の通過・作成者の側で残る作業が無いこと）で作成者が ready for review に変える規則を定めた。[rules/version-control.md](rules/version-control.md)・[rules/README.md](rules/README.md)・[index.md](index.md)・`AGENTS.md` を改めた。
* **Update**: `lake exe layout-check` のモジュールの組を、組ごとに別のプロセスで判定するようにした（[スキルの ADR 89f2](../.agents/skills/spec-pivot/references/docs/decision/89f2-layout-check-one-process-per-group.md)）。組ごとの環境を解放しないために CI の runner のメモリが上限に近づいていた（5 つの組で 7.4 GB / 7.9 GB）。メモリの最大は組 1 つ分になり、組を足してもメモリは増えない。これにより、メモリのために組から外していた入口 `Tests.LongMain`（`long-tests`）を 6 つ目の組として加えた（`lean/Tools/LayoutCheck.lean`）。spec-pivot の版を 0.23 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。CI の検査の段に、20 秒ごとのメモリの使用量の行（`[mem]`）を出すようにした。
* **Creation**: [ADR 625d](decision/625d-adopt-okf-bundle-and-work-records-skills.md) と [backlog 2ba8](backlog/2ba8-split-okf-and-records-skills.md)（完了）で、スキル spec-pivot から移植に関係の無い文書の道具と規則を、汎用のスキル [okf-bundle](../.agents/skills/okf-bundle/SKILL.md)（OKF のバンドルとリンクの検査・文書の移動）と [work-records](../.agents/skills/work-records/SKILL.md)（ADR・backlog の形式と ID）に分けた。スキルの側は [スキルの ADR 22b4](../.agents/skills/spec-pivot/references/docs/decision/22b4-split-okf-and-records-skills.md)。spec-pivot の版を 0.22 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。
  * 設定を `trace/project.json` の `okf`・`ids` から、ルートの `.okf.json`・`.work-records.json` に移した。`trace/features.json` の backlog の欄は `id_fields` で宣言した。ADR・backlog の形の検査（状態・選択肢・採択の行・完了条件）は `ids.py check` に移った。
  * 旧番号からの書き換えと登録簿の旧番号の検査を、ATRS の `tools/docs/legacy_ids.py` に移した（mise の `docs:ids`）。
  * [rules/documentation.md](rules/documentation.md)・[rules/decision-records.md](rules/decision-records.md)・[rules/backlog.md](rules/backlog.md)・[rules/README.md](rules/README.md)、`AGENTS.md`・`mise.toml`、[index.md](index.md)・[backlog/README.md](backlog/README.md) を改めた。完了済みの ADR・backlog の本文の旧パス（`scripts/docs/`）は来歴として残す。

* **Update**: [ADR 18ca](decision/18ca-rename-oracle-to-origin-run.md) で、「オラクル」を「原典実行」（`origin-run`）と呼び替えた（DBMS の Oracle と紛れるため）。文書・既存の ADR と作業項目の本文・この変更履歴・ベクタの `source`（`java-origin-run`）・道具（`tools/origin-run/`・`tools/ci/java_origin_run.sh`・mise の `origin-run:*`・`trace/checks.json`）をそろえた。backlog f18c・773f のファイル名は残した。スキルの側は [スキルの ADR 288a](../.agents/skills/spec-pivot/references/docs/decision/288a-rename-oracle-to-origin-run.md)（スキルの版 0.21 に含める）。
* **Creation**: [ADR 81da](decision/81da-java-origin-run-domain-and-http.md) で、[backlog f18c](backlog/f18c-java-oracle-harness.md)（Java の原典実行）の構成を決め、f18c を完了した（`done`）。`depends_on` から a8ef を外した。
  * ドメイン層: 原典を複写してビルドし（`tools/origin-run/build-upstream.sh`）、DI を起動せずに原典の MyBatis とサービスを組み立てる（`tools/origin-run/`）。運賃計算・空席照会の既存のベクタ 35 件が原典と一致した。シードの範囲の 1,867 件を原典から採取した（`conformance/source-model/{fare,flight-search}/origin-run-*.json`）。`source-model/fare/fare.json` の期待値の出所を `java-origin-run` にした。`lean/Tests/Main.lean` に `source-model/flight-search` を足した。
  * HTTP レベル: 原典の web.xml のままの webapp を組み込み Tomcat で起動し、時計・DB・`report.dir` だけを差し替える。採取結果は `tools/origin-run/http/`。
  * [spec/http-contract.md](spec/http-contract.md#rest-apiapiv1) の TODO を解消した（`LocalDate` は `"yyyy-MM-dd"`）。[spec/authentication.md](spec/authentication.md#ログインlogin) の TODO を解消し、D-028 を観測型の既知差異にした（画面ログインは状態を更新せず、REST の Basic 認証は更新する。[spec/abstraction.md](spec/abstraction.md#既知差異) は生成。W 課題 ABS-128 を足し、ABS-043・ABS-045 の差異に D-028 を足した）。[backlog 44f8](backlog/44f8-authentication-usecases.md) の範囲と完了条件を合わせた。
  * [spec/assurance.md](spec/assurance.md) の移植元側の行と付録（原典実行の対象外と範囲）、[spec/conformance.md](spec/conformance.md) を改めた。
  * 道具: mise の `origin-run:domain`・`origin-run:http`・`origin-run:gen`・`ci:java-origin-run`、`tools/ci/java_origin_run.sh`、`trace/checks.json` の `java-origin-run`。CI は `~/.m2` をキャッシュする。
  * スキルの側は [スキルの ADR 7d3a](../.agents/skills/spec-pivot/references/docs/decision/7d3a-java-conformance-kit-and-http-origin-run-method.md)（`assets/java/conformance-kit`、HTTP レベルの原典実行の方法、`with_postgres.sh` の `WITH_POSTGRES_TCP`）。スキルの版を 0.21 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。[backlog/README.md](backlog/README.md)、[index.md](index.md)、`AGENTS.md` の「現在の状態」を改めた。

* **Creation**: [ADR 44a0](decision/44a0-mise-tasks-and-uv-for-tools.md) で、一括検査 `tools/ci/lean.sh` を廃止し、各段をルートの `mise.toml` のタスクに分けた（一括検査は `mise run ci`）。mise が管理する道具は uv だけとし、Python の道具を `uv run python -I` で実行するようにした（`.python-version`・`pyproject.toml`・`uv.lock`）。
  * `.github/workflows/lean.yml` は mise を入れて `mise run ci` を実行する。`trace/checks.json` の各段はタスクを呼ぶ。終了コード 2（飛ばした）の読み替えは `tools/ci/skippable.sh` に移した。
  * スキルの側は [スキルの ADR 8cb7](../.agents/skills/spec-pivot/references/docs/decision/8cb7-run-python-tools-with-uv.md)（uv だけ。mise は求めない）。スキルの版を 0.20 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。
  * `AGENTS.md`、[rules/atrs-porting.md](rules/atrs-porting.md)・[rules/version-control.md](rules/version-control.md)・[rules/documentation.md](rules/documentation.md)・[rules/decision-records.md](rules/decision-records.md)・[rules/backlog.md](rules/backlog.md)、[spec/traceability.md](spec/traceability.md)、[index.md](index.md) を改めた。完了済みの ADR・backlog の本文の `tools/ci/lean.sh` は来歴として残す。

* **Creation**: [ADR e41c](decision/e41c-source-model-mirrors-java-tree.md) と [backlog cb06](backlog/cb06-source-model-review-aids.md)（完了）で、`SourceModel` を原典と見比べやすくした。スキルの版を 0.19 にした（[スキルの ADR 1f75](../.agents/skills/spec-pivot/references/docs/decision/1f75-java-expression-syntax-and-spring-assert.md)・[ADR 8a3c](../.agents/skills/spec-pivot/references/docs/decision/8a3c-mirror-layout-check-and-review-view.md)）。
  * `SourceModel` のモジュールを原典の Java のソースツリーと同じ形に並べた（改名の対応表 `tools/docs/lean-renames-mirror.json`）。`trace/features.json` の `lean`・`trace/checks.json` の `covers`・`trace/project.json` の `source.mirror` を改めた。
  * 式を `java!`、検査を `Assert.*` で書いた。TR-M の指摘で、原典と名前が食い違っていた欄（`fareTypeMap`）と引数を直した。
  * 改めた文書: [rules/atrs-porting.md](rules/atrs-porting.md)、[spec/fare-calculation.md](spec/fare-calculation.md)・[spec/flight-search.md](spec/flight-search.md)・[spec/conformance.md](spec/conformance.md)・[spec/traceability.md](spec/traceability.md)・[spec/abstraction.md](spec/abstraction.md) のリンクと名前。
* **Creation**: [ADR fa26](decision/fa26-rename-skill-to-spec-pivot.md) で、スキルの名前を `port-lang` から `spec-pivot` に改めたのに合わせ、ATRS のパスと参照を張り直した。方法の名前は Spec Pivot とした（[スキルの ADR cfad](../.agents/skills/spec-pivot/references/docs/decision/cfad-name-the-method-spec-pivot.md)）。
  * 張り直した設定: `lakefile.lean`・`lake-manifest.json`（ルートと `lean/`）、`.github/workflows/lean.yml`、`tools/ci/`・`tools/conformance/`、`trace/project.json`・`trace/checks.json`・`trace/renames.json`。
  * 文書・コード・コメントの名前を改めた。この変更履歴の過去の項と、ADR f4e1 の本文は旧名のまま残す。ADR f4e1 の More Information に改名を記した。
* **Creation**: [ADR 0b0c](decision/0b0c-flight-search-stage3-abs011.md) で、[backlog 0be7](backlog/0be7-flight-search-usecase.md) の第 3 段の設計を決め、0be7 を完了した（`done`）。
  * R 課題 ABS-011（`Abstraction.FlightSearch.searchRefines`）と束 `searchPreserves`、L 課題 ABS-010、W 課題 ABS-114（`need_D014`）・ABS-132（`need_D032`）を証明した。
  * トップレベルの主定理 `Abstraction.refines`・`preserves`・`abstracts` に空席照会を加えた。
  * [spec/flight-search.md](spec/flight-search.md#事前条件) の PRE を改めた。`World.RefMaster` を外し、照会の搭乗クラスがマスタにあることと、便マスタの便名が空白でないことを課す。
  * 差異 D-033（PRE の外）を登録した。D-014・D-032 を具体側の入力の述語にし、偽を証明済みにした（[spec/abstraction.md](spec/abstraction.md#既知差異) は生成）。
  * `trace/features.json` の FlightSearch を 0be7 の範囲に絞った。
  * スキルの版を 0.17 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。[backlog/README.md](backlog/README.md)、[index.md](index.md)、`AGENTS.md` の「現在の状態」を改めた。
  * 敵対的レビューの指摘に対応した（[ADR 0b0c](decision/0b0c-flight-search-stage3-abs011.md#more-information)）。D-032 の環境を書式の記号の組にし、ABS-114 の証人を単調な Clock にし、`dev_D001S`・`dev_D002S` と `FlightNamesHaveText` を絞った。

* **Creation**: [ADR cdb6](decision/cdb6-flight-search-stage2-machines-seed-sql.md) で、[backlog 0be7](backlog/0be7-flight-search-usecase.md) の第 2 段の設計を決め、完了した。
  * シード 00250 の生成器 `tools/conformance/flight_seed.py` と、生成物 `Spec.Seed.Flight`・`SourceModel.Db.FlightSeed` を置いた。
  * [Spec] に `Spec.Seed.FlightProps`（主キーの一意性・参照整合性）、抽象機械 `Spec.FlightSearch.searchMachine` と SPEC 課題を置いた。
  * [Source] に具体機械 `SourceModel.FlightSearchQuery.searchConcrete`（業務例外は出力の値）と、条件の押し下げ `vacantSeatRows_eq_on` を置いた。
  * `findByVacantSeatSearchCriteria` を PostgreSQL で差分実行するようにした（`tools/conformance/master_sql.py`、`conformance/sql/flight-search.json`、`Tests.FlightSql`、`trace/checks.json` の `pg-flight-sql`）。
  * D-027 の範囲を状態の表 FLIGHT に広げ、α `Abstraction.FlightSearch.Alpha` を置いた。
  * スキルの版を 0.16 にした（[rules/atrs-porting.md](rules/atrs-porting.md)）。[spec/conformance.md](spec/conformance.md)、[spec/flight-search.md](spec/flight-search.md)、[backlog/README.md](backlog/README.md)、[index.md](index.md) を改めた。
  * 敵対的レビューの指摘に対応した（[ADR cdb6](decision/cdb6-flight-search-stage2-machines-seed-sql.md#more-information)）。PRE の空港コードを「空白でない」に改め、D-027 の箇所と範囲の説明を補い、差分実行が `bind` と `flight-map` の値も確かめるようにし、シードの解析を厳密にし、照合の条件を 15 にした。

* **Creation**: [ADR ce36](decision/ce36-flight-search-stage1-world-and-arrival-time.md) で、[backlog 0be7](backlog/0be7-flight-search-usecase.md)（空席照会）を 3 段に分け、第 1 段の設計を決めた。0be7 に着手した（`doing`）。
  * Java の原典実行との一致の完了条件を [backlog f18c](backlog/f18c-java-oracle-harness.md) に移し、0be7 の `depends_on` から f18c を外した。
  * 便マスタの到着時刻を `Spec.Prim.Time.ArrivalTime`（出発日 0:00 からの時分。24 時以降を許す）にした。fixture の `outsideSpec` を外し、`Spec.Seed` に NTT523・NTT528 を含めた。[ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md) に補足を書いた。`flightMasterOf` の 2415 の例を `shared/master-data` に移した。
  * `DateTimeParseException` は空席照会でなく予約の往復便の検査で起きることを確かめ、既知差異 D-031（W 課題 ABS-131）を登録した。[spec/master-data.md](spec/master-data.md) の誤りを直した。
  * [spec/domain-model.md](spec/domain-model.md#arrivaltime)、[spec/master-data.md](spec/master-data.md)、[spec/abstraction.md](spec/abstraction.md#証明課題)（ABS-011・ABS-127・ABS-131、D-027 の範囲）、[spec/conformance.md](spec/conformance.md)、[spec/assurance.md](spec/assurance.md)、[backlog/README.md](backlog/README.md)、[index.md](index.md)
  * Lean: `Spec.Error`（`Business`・`NotFound`）、`Spec.Port`（`World` とその不変条件）、`Spec.FlightSearch`（照会可能期間・運賃種別の予約可能判定・`searchFlight`）。`SourceModel.FlightSearch`（`searchFlight` と、起動時の読み込みと合わせて実行する `runSearchFlight`）、`SourceModel.Repository.Flight`（`findByVacantSeatSearchCriteria` の `Bag` 式と許される並べ方）、FLIGHT の行 `FlightRow`・状態の表 `FlightDb`、`flight-map`。
  * 適合テストベクタ `conformance/shared/flight-search/`（`flightSearch.searchFlight`・`validateDepartureDate`・`isAvailableFareType`）を足し、`Spec` と `SourceModel` の両方で通した。[spec/flight-search.md](spec/flight-search.md) に Lean への参照を書き、[spec/conformance.md](spec/conformance.md#操作名) にエラーの表し方を書いた。
  * スキル port-lang の `LangSemantics.Java` に `String.substring` と `DecimalFormat` の 3 桁区切りを足した（スキルの版 0.15。[rules/atrs-porting.md](rules/atrs-porting.md)）。
  * `trace/features.json`（空席照会の名前空間・ABS-010・`validateDepatureDate` のロケータ）を改め、`trace rehash` で合格の記録を取った。
  * 敵対的レビューの指摘に対応した（[ADR ce36](decision/ce36-flight-search-stage1-world-and-arrival-time.md#more-information)）。`Spec.Port.World.RefMaster` を足し、D-014 に ABS-011 を加え、D-031 の説明を直し、既知差異 D-032（運賃の書式の既定ロケール。W 課題 ABS-132）を登録した。

## 2026-10-31

* **Creation**: [ADR 91be](decision/91be-top-level-preserves-refines-abstracts.md) で、義務の束 `Machine.Adequate` の語を廃止し、トップレベルの主定理を `Abstraction.refines`（B refines A。B メソッドのリファインメント）・`Abstraction.preserves`（A preserves B。空虚化を防ぐ意味的な義務のすべて。`Refines` を含まない）・`Abstraction.abstracts`（A abstracts B）にした。[ADR a41d](decision/a41d-top-level-refines-adequate-and-source-side-gate.md) を置き換えた（段階導入とゲートは引き継ぐ）。[backlog cb23](backlog/cb23-adequate-to-preserves-abstracts.md) を作り、完了した（`done`）。スキル側の決定は [スキルの ADR 6b4b](../.agents/skills/spec-pivot/references/docs/decision/6b4b-preserves-refines-abstracts.md)（スキルの版 0.14）。
  * R 課題ごとの束を `queryPreserves`・`basicFarePreserves`・`farePreserves`・`totalFarePreserves`（旧 `*Adequate`）に、部品のモジュールを `Abstraction.{MasterData,Fare}.Preserves`（旧 `…Adequacy`）にした。`preserves` と `refines` は R 課題の並置から独立に示す。
  * スキルの道具 `rename.py` と対応表 `tools/docs/lean-renames-preserves.json` で名前を書き換えた。来歴の文書（置き換えた ADR・完了した backlog・この変更履歴の過去の行）は書き換えていない。`trace manifest` で `trace/manifest.json` を作り直した（`trace rehash` の対象は 0 件）。
  * [spec/abstraction.md](spec/abstraction.md#トップレベルの主定理)、[spec/refinement.md](spec/refinement.md)、[rules/backlog.md](rules/backlog.md#完了の定義definition-of-done)、[rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.14）、[backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md)、`trace/features.json` を改めた。

* **Update**: [スキルの ADR 1a30](../.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md) の規則（宣言をモジュール名の下に置く NS-1、証明課題を機能のモジュールに置く TR-L）を ATRS の `lean/` に適用した（[backlog 9ed8](backlog/9ed8-atrs-module-namespace-layout.md)。スキルの側は [スキルの backlog ce23](../.agents/skills/spec-pivot/references/docs/backlog/ce23-lean-module-namespace-layout.md)）。スキルの版は 0.13。
  * `lake exe layout-check`（`lean/Tools/LayoutCheck.lean`）を足し、`tools/ci/lean.sh` から実行する。
  * 名前を改めた。例: `Spec.FlightType` → `Spec.Model.FlightType`、`Spec.Airport` → `Spec.MasterData.Airport`、`Spec.MasterData.queryMachine` → `Spec.MasterQuery.queryMachine`、`Spec.Prim.floorDiv` → `Spec.Prim.Int.floorDiv`。R・W・C 課題と義務の束を `lean/Abstraction/Fare.lean`・`lean/Abstraction/MasterData.lean` に集め（`Abstraction.Adequacy` を分けた。可換式は `*Refines_commutes`）、補題のモジュールを `*Run` にした（旧 `*Refines`）。
  * スキルの道具 `rename.py` で、`docs/`（ADR はリンクの修正として）・`conformance/` のベクタ・`trace/` を書き換えた。この変更履歴の旧い名前は記録として残した。改名の対応表は `tools/docs/lean-renames.json` にある。`trace rehash` で合格の記録を取り直した。
  * [rules/atrs-porting.md](rules/atrs-porting.md)（機能の名前空間、スキルの版 0.13）、[AGENTS.md](../AGENTS.md)、[backlog/README.md](backlog/README.md)、[index.md](index.md)

* **Creation**: [ADR a41d](decision/a41d-top-level-refines-adequate-and-source-side-gate.md) で、実装済みの範囲（マスタ・設定・コードリストの読み込みと運賃計算）のトップレベルの主定理と、移植元側の段階導入を決めた。[backlog 76a6](backlog/76a6-source-side-adequacy-gate.md) を作り、完了した（`done`）。スキル側の決定は [スキルの ADR ab9e](../.agents/skills/spec-pivot/references/docs/decision/ab9e-adequate-bundle-sum-and-side-staging.md)（スキルの版 0.12）。
  * `lean/Abstraction.lean` のトップレベルに `Abstraction.refines`・`Abstraction.adequate`、R 課題ごとの束と 1 歩の可換式を `Abstraction.Adequacy` に置いた。`Spec.machine`・`SourceModel.machine` を足した。`lean/Refinement.lean` に同じ形を書いた（`TargetModel` ができるまで主定理は置かない）。
  * `trace/features.json` を側ごとの作業項目にし、他の機能の移植元の項目を移した。運賃計算・マスタの残りの項目に `@[source]` を付け、`trace/checks.json` に `seed-lean` を、`trace/out-of-scope.json` に `commons-logging.properties` を足した。
  * [spec/abstraction.md](spec/abstraction.md#トップレベルの主定理)、[spec/refinement.md](spec/refinement.md)、[rules/backlog.md](rules/backlog.md#完了の定義definition-of-done)、[backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md) を改めた。
* **Update**: スキル port-lang の文書を、性格ごとのディレクトリ `spec/`・`rules/`・`guide/`・`lang/<lang>/` に分けた（[スキルの ADR 748c](../.agents/skills/spec-pivot/references/docs/decision/748c-skill-docs-category-directories.md)、[スキルの backlog 97a7](../.agents/skills/spec-pivot/references/docs/backlog/97a7-skill-docs-category-directories.md)）。スキルの版は 0.11。
  * スキルの道具 `docmv.py` で、ATRS の文書・`lean/`・`trace/project.json`・`.github/workflows/` のリンクとパスの言及を張り直した。ADR とこのファイルの本文に書いたリンクでないパスは記録として残し、リンクだけ直した。
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.11）、[AGENTS.md](../AGENTS.md)（言語パックの置き場所）。`tools/ci/lean.sh` に `docmv.py --self-test` を足した。

* **Update**: [スキルの ADR c08b](../.agents/skills/spec-pivot/references/docs/decision/c08b-test-namespace-for-skill-asset-tests.md) で、スキルの assets の検査の名前空間を `XxxTest` から `Test.Xxx`（`Test.LangSemantics`・`Test.Machine`・`Test.ConformanceKit`・`Test.Trace`）に改めたのにあわせ、[spec/assurance.md](spec/assurance.md) のパス、`trace/checks.json` の検査の手順（`lake build +Test.LangSemantics`）、`tools/ci/lean.sh` の表示を改めた。ATRS の `Tests` は変えていない。スキルの版は 0.10。
* **Creation**: [ADR 920d](decision/920d-docs-bundle-check-in-ci.md) で、`docs/` とスキルのバンドルを、スキルの道具 `okf_check.py`（[スキルの ADR 330e](../.agents/skills/spec-pivot/references/docs/decision/330e-okf-bundle-check-tool.md)、[スキルの backlog a49c](../.agents/skills/spec-pivot/references/docs/backlog/a49c-okf-bundle-check-tool.md)）で検査し、`tools/ci/lean.sh` から実行するようにした。[backlog ddbd](backlog/ddbd-okf-bundle-lint.md) を完了した（`done`）。
  * ATRS の規則を `trace/project.json` の `okf` に置いた。スキルの版は 0.9。
  * 導入で見つかった違反を直した: [rules/README.md](rules/README.md) の `type` を `Overview` に、[index.md](index.md) の ADR f4e1・c108 の説明を frontmatter に合わせた。[backlog 0d1a](backlog/0d1a-mutation-testing-of-named-components.md)・[backlog c27d](backlog/c27d-gap-evidence-states.md) に `対象外` の節を補った。
* **Update**: 次の文書を改めた。
  * [rules/documentation.md](rules/documentation.md#検査)（YAML の部分集合、検査）、[rules/decision-records.md](rules/decision-records.md)（採択を示す行）、[rules/backlog.md](rules/backlog.md)（節の検査）、[rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.9）
  * [backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md)

* **Creation**: [ADR 50f9](decision/50f9-move-skill-records-to-skill-bundle.md) で、スキル port-lang の記録をスキルのバンドルへ移した。スキル側の決定は [スキルの ADR 87b9](../.agents/skills/spec-pivot/references/docs/decision/87b9-skill-docs-as-okf-bundle.md)、作業は [スキルの backlog de90](../.agents/skills/spec-pivot/references/docs/backlog/de90-skill-docs-okf-bundle-and-records.md)。
  * スキルの `references/` を `references/docs/`（OKF v0.2 のバンドル。[索引](../.agents/skills/spec-pivot/references/docs/index.md)）に移し、スキルの版を 0.8 にした。ATRS の文書・`lean/`・`trace/project.json` のリンクとパスを張り直した。ADR とこのファイルの本文に書いたパスは記録として残し、リンクだけ直した。
  * ADR edc8・7fe4・6edf・0b83・0eea・9cd9 と backlog 1ae4・a936 を、ID とファイル名を変えずにスキルの `references/docs/decision`・`backlog` へ移した。[index.md](index.md) と [backlog/README.md](backlog/README.md) からは外した。backlog の依存の列と着手順の図からは、スキルの項目をリンクで指す。
  * `trace/project.json` の `ids` に、スキルの置き場所と `isolated`（スキルが ATRS を指していないことの検査）を足した。
* **Update**: 次の文書を改めた。
  * [rules/decision-records.md](rules/decision-records.md)（スキルの ADR）、[rules/backlog.md](rules/backlog.md)・[rules/documentation.md](rules/documentation.md)（スキルのバンドル）
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.8）
  * [ADR f4e1](decision/f4e1-extract-porting-method-as-agent-skill.md)（More Information の補足）
  * [index.md](index.md)、[AGENTS.md](../AGENTS.md)

* **Creation**: [backlog c27d](backlog/c27d-gap-evidence-states.md) を作り、完了した（`done`）。
* **Creation**: [ADR 6ab4](decision/6ab4-gap-evidence-states-without-axioms.md) で、ギャップの証明の状態を Lean の型 `Trace.Evidence` で表し、公理・`sorry` を使わずに裏付けの宣言で示すことにした。
  * `lean/Abstraction/Gap.lean` の 30 件に状態を与えた（偽を証明済み 4 件・未証明 13 件・形式化していない 6 件・PRE の外 7 件）。否定の定理 `need_D001`・`need_D002`・`need_D012`・`need_D027` と、`opaque` の主張に `@[gap]` を付けた。`Spec.MasterData.MD5` に `@[gap "D-005"]` を足した。
  * obligation-check（GK）が状態ごとに裏付けを照合し、`trace manifest` が表に「証明の状態」の列を足す。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（証明の状態。表は生成）・[spec/refinement.md](spec/refinement.md)（表は生成）・[spec/assurance.md](spec/assurance.md)
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.7）、[backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md)
  * スキル port-lang の SKILL.md（版 0.7）・[lean/trace-attributes.md](../.agents/skills/spec-pivot/references/docs/lang/lean/trace-attributes.md)（証明の状態）・[architecture.md](../.agents/skills/spec-pivot/references/docs/spec/architecture.md)（差異）

* **Add**: [ADR cd33](decision/cd33-spec-nondet-types-and-env-pre.md)（[Spec] の非決定性の選択の型と、入口の環境の前提・シードの検査を決める）。
* **Update**: [backlog 0fdf](backlog/0fdf-spec-nondet-and-entry-env.md) を完了した（`done`）。`Spec.Nondet`（N-001〜N-005 の `@[nondet]`）、`Spec.EnvPre`（`masterConfigOk` の `@[env_pre]`・検査関数 `validB`）、生成した `Spec.Seed` とシードの妥当性 `seed_env` を置いた。入力の値域の前提は [backlog a89e](backlog/a89e-http-contract-adapter.md)・[ac71](backlog/ac71-reservation-history-report.md) の範囲に移した。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（Spec の非決定性の表の Lean 名）
  * [spec/master-data.md](spec/master-data.md)（シードの妥当性）、[spec/assurance.md](spec/assurance.md)（シードの検査の限界）
  * [backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md)

* **Creation**: [backlog 38fb](backlog/38fb-move-generic-elements-to-skill.md) を作り、完了した（`done`）。
* **Creation**: [ADR edc8](../.agents/skills/spec-pivot/references/docs/decision/edc8-skill-scripts-and-generic-lean-libraries.md) で、アプリに依存しない要素をスキル port-lang へ移した。
  * 道具（`tools/trace`・`check_lean.py`・`check_obligations.py`・`check_upstream.py`・`with_postgres.sh`・`jvm_table.sh`・`pg_table.sh`・`ids.py`）をスキルの `scripts/` へ移した。ATRS 固有の値は `trace/project.json` に集めた。
  * 汎用の Lean コードを、スキルの assets（`Machine.Kernel`、`LangSemantics.Core`（新設）、`LangSemantics.Sql.QueryLemmas`、`LangSemantics.Java` の `ResultLemmas`・`DoubleCompare`・`IntLemmas`、`ConformanceKit`（新設））へ移した。main の backlog bbcc 第 3 段を取り込んだとき、そこで足された汎用の補題（`for` 文・`int` の演算・`mapM`）も移した。
* **Update**: [ADR e9bc](decision/e9bc-fare-double-analysis.md) の More Information に、比較の定理の汎用部を移したことを補足した。
* **Update**: 次の文書を改めた。
  * [spec/traceability.md](spec/traceability.md)・[spec/abstraction.md](spec/abstraction.md)・[spec/refinement.md](spec/refinement.md)・[spec/assurance.md](spec/assurance.md)（道具の置き場所、`trace/project.json`、`Machine.undefOrEq`）
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.6、配置、取り込むライブラリ）・[rules/backlog.md](rules/backlog.md)・[rules/documentation.md](rules/documentation.md)・[rules/decision-records.md](rules/decision-records.md)・[rules/version-control.md](rules/version-control.md)（道具のパス）
  * [backlog/README.md](backlog/README.md)、[AGENTS.md](../AGENTS.md)
  * スキル port-lang の SKILL.md（版 0.6）・`scripts/README.md`（新規）・`traceability.md`（道具・プロジェクトの設定・手書きのファイルの形）・`spec-documents.md`（道具が読む見出しと値・式の書き方）・`architecture.md`（依存の向き・SPEC 課題の一覧・汎用の核）・`verification.md`（保証の限界の必須項目）・`conformance.md`（比較の規則・実行器・架空の例）・`upgrade.md`（版上げの例）・`workflow.md`・`lean/rules.md`・`lean/trace-attributes.md`（架空の例）・`java/semantics.md`・`sql/semantics.md`・`sql/harness.md`（差分実行の結果）・`rust/semantics.md`・`rust/verification.md`（確認の課題の一覧）
* **Update**: [backlog bbcc](backlog/bbcc-fare-abstraction-proofs.md) を完了した（`done`）。第 3 段で、R 課題 ABS-004（`Abstraction.Fare.totalFareRefines`）・L 課題 ABS-005（`runTotalFare_eq`）・W 課題 ABS-112（`need_D012`。D-012 の必要性）を証明した。`Spec.Fare.totalFare` をフライトのキーと搭乗者の年齢の関数 `totalFareOfKeys` で書き直し、合計金額の抽象機械と SPEC 課題を置いた。`SourceModel.Ticket`（`TicketHelper.toFlightList`）を足し、`Tests.TicketChecks` の検査を `trace/checks.json` の `lake-test` に登録した。
* **Update**: [ADR e9bc](decision/e9bc-fare-double-analysis.md) に、第 3 段の決定（合計金額の [Spec] と具体側の入力、D-001・D-002・D-012 の前提、証人の文字列）を加えた。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（ABS-004・005・112 の定理名、α の表）、`lean/Abstraction/Gap.lean`（D-001・D-002・D-012・D-027 の前提と R 課題。表は生成）
  * [spec/fare-calculation.md](spec/fare-calculation.md)（合計金額の抽象機械）
  * [backlog/README.md](backlog/README.md)、[index.md](index.md)、[AGENTS.md](../AGENTS.md)
  * スキル port-lang の [java/semantics.md](../.agents/skills/spec-pivot/references/docs/lang/java/semantics.md)（`int` の補題）

* **Update**: [backlog bbcc](backlog/bbcc-fare-abstraction-proofs.md) の第 2 段を終えた（`doing`）。R 課題 ABS-001（`Abstraction.Fare.basicFareRefines`）・ABS-002（`fareRefines`）、C 課題 ABS-003、L 課題 ABS-007、W 課題 ABS-101・102（D-001・D-002 の必要性）を証明した。基本運賃・運賃の抽象機械と SPEC 課題を `Spec.Fare` に置いた。
* **Update**: [ADR e9bc](decision/e9bc-fare-double-analysis.md) に、第 2 段の決定（抽象機械の置き場所、具体側の入力、D-027 の定数、差異の前提の形）を加えた。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（ABS-001・002・003・007・101・102 の定理名、α の表）
  * `lean/Abstraction/Gap.lean`（D-001・D-002・D-027 の前提と R 課題。表は生成）
  * [spec/fare-calculation.md](spec/fare-calculation.md)（抽象機械）
  * [index.md](index.md)、[AGENTS.md](../AGENTS.md)
* **Creation**: [backlog 114a](backlog/114a-gap-attributes-and-trace-in-skill.md) を作り、完了した（`done`）。
* **Creation**: [ADR 7fe4](../.agents/skills/spec-pivot/references/docs/decision/7fe4-move-trace-attributes-to-skill.md) で、`lean/Trace`（追跡属性・trace-dump・obligation-check の本体）をスキル port-lang の `assets/lean/Trace` に移した。テストは `assets/lean/TraceTest` と `lake exe trace-test` に移した。
* **Creation**: [ADR cc24](decision/cc24-gap-registry-as-lean-attributes.md) で、ギャップの登録簿を Lean の `@[gap_entry]`（型 `Trace.Gap`）に置き、箇所の印 `@[gap]` を足した。`lean/Abstraction/Gap.lean` に D-001〜D-030 を移し、未確定の差異に D-028、PRE の外の ID の無かった 2 行に D-029・D-030 を割り当てた。検査 TR-K・GK を足した。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)・[spec/refinement.md](spec/refinement.md)（差異の表を生成区画にした）
  * [spec/assurance.md](spec/assurance.md)（検査器の置き場所、ギャップの登録簿の行）
  * [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの版 0.5、`Trace` の置き場所）
  * [backlog/README.md](backlog/README.md)
  * スキル port-lang の SKILL.md（版 0.5）・`architecture.md`・`traceability.md`（TR-K）・`lean/trace-attributes.md`（ギャップの登録簿）・`spec-documents.md`・`lean/rules.md`・`workflow.md`
  * [AGENTS.md](../AGENTS.md)
* **Add**: [ADR e9bc](decision/e9bc-fare-double-analysis.md)（運賃計算の double の誤差を定理で確定し、D-001・D-002 の前提を正確な条件で書く）。
* **Update**: [backlog bbcc](backlog/bbcc-fare-abstraction-proofs.md) の第 1 段を終えた（`doing`）。3 段に分け、Java の原典実行との一致の完了条件を [backlog f18c](backlog/f18c-java-oracle-harness.md) に移し、`depends_on` から f18c を外した。double・BigDecimal の補題（スキルの `LangSemantics.Java.DoubleLemmas`・`bdCeilHundredUp_val`）と、基本運賃・運賃の差異の条件（`Abstraction.Fare`）を証明した。
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（D-001・D-002 の内容と前提、ABS-006 の取り消し、ABS-007・ABS-101）
  * [spec/fare-calculation.md](spec/fare-calculation.md)（基本運賃・運賃の差異の条件）
  * [spec/assurance.md](spec/assurance.md)（前提が十分条件であること）
  * [backlog/README.md](backlog/README.md)、[AGENTS.md](../AGENTS.md)
  * スキル port-lang の [java/semantics.md](../.agents/skills/spec-pivot/references/docs/lang/java/semantics.md)（補題と、double の式の差の示し方）

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) を完了した（`done`）。R 課題 ABS-026（`Abstraction.MasterData.queryRefines`）と、W 課題 ABS-127（`need_D027`）を証明した。fare-calculation.md の例を、意図から書く例として `Tests.SpecChecks` に置いた。
* **Update**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) に、次の 2 点の決定を加えた。
  * `LocalDate` の写し `dateOfJ` を、通算日数で写す定義に改めた
  * obligation-check の G4 で、帰納型の補助の定数を許すようにした
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（ABS-026・ABS-127 の定理名）
  * [backlog/README.md](backlog/README.md)
  * [AGENTS.md](../AGENTS.md)

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 b-2a を終えた（`doing`）。ABS-026 の標準の抽象化 α（葉 19 個と核の定理、ABS-048）と `dev_D027`（D-027）を `Abstraction.MasterData` に置いた。
* **Update**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) に、次の 4 点の決定を加えた。
  * 参照の答えの射影（表示順を除く）
  * 空白の便名（`Query.Valid` に `hasText`）
  * α の葉と合成の分け方
  * 部分写像の汎用の核 `undefOrEq`（obligation-check の G7 を広げた）
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（α の表に 3 行、D-027 の成分の名前）
  * [spec/master-data.md](spec/master-data.md)（参照関数）
  * [spec/domain-model.md](spec/domain-model.md)（便名）
  * [spec/input-validation.md](spec/input-validation.md)（文字クラス `Blank`）
  * スキル port-lang の `architecture.md`（部分写像の汎用の核）
  * [AGENTS.md](../AGENTS.md)

* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 b-1 を終えた（`doing`）。R 課題 ABS-026 の補題を、`Abstraction.Prim`・`Abstraction.MasterData` と、スキル port-lang の `LangSemantics` に置いた（暦、`HashMap`、一意な検索、整列、結合、キャッシュのキー、`load()`、コードリスト）。
* **Creation**: [ADR f353](decision/f353-abs-026-proof-structure-nop-and-d027-scope.md) で、次の 4 点を決めた。作成時は旧番号 0046 だったが、main の [ADR f57e](decision/f57e-uuid-ids-for-decisions-and-backlog.md) に合わせて UUID の ID を振った。
  * 空港コード `NOP` を MD-8 で禁じる
  * D-027 の対象を具体側の入力全体に広げる（[ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) を補う）
  * `LangSemantics.Java` の `LocalDate` の通算日数を床除算で書き直す（負の年で JVM と食い違っていた）
  * 補題の置き場所と、`decide +kernel` の使い方
* **Update**: 次の文書を改めた。
  * [spec/abstraction.md](spec/abstraction.md)（D-027 の範囲、[Spec] の前提の外の `NOP`）
  * [spec/master-data.md](spec/master-data.md)（MD-8）
  * [spec/domain-model.md](spec/domain-model.md)（値域）
  * [spec/assurance.md](spec/assurance.md)（JVM の突き合わせ表の件数と `LocalDate` の範囲）
  * [ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) の More Information（補足の追記）
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR f57e](decision/f57e-uuid-ids-for-decisions-and-backlog.md) で、ADR と backlog の ID を 4 桁の連番から UUID v4 に改め、ファイル名を `<ID の先頭 4 文字>-<slug>.md` とした。
  * 既存の ADR 45 件と backlog 33 件を採番し直し、全文書・コード・JSON の参照を新 ID に書き換えた（旧番号との対応は ADR f57e と `tools/docs/legacy-ids.json`）。過去の記録の参照も書き換えた。採番の経緯を述べた箇所の番号は「旧番号」と明記した。
  * 道具が読む箇所（`id`・`depends_on`・`superseded_by`、`trace/features.json`、登録簿の backlog の列）は ID 全体、本文の参照は先頭 4 文字とした。
  * `tools/docs/ids.py`（`new`・`check`・`migrate`）を作り、`check` を `tools/ci/lean.sh` に加えた。`tools/trace` と `tools/ci/check_obligations.py` は、backlog を frontmatter の `id` で引くようにした。
* **Update**: [rules/decision-records.md](rules/decision-records.md)・[rules/backlog.md](rules/backlog.md)・[rules/documentation.md](rules/documentation.md)・[AGENTS.md](../AGENTS.md) の命名と参照の規則を改めた。[ADR d845](decision/d845-record-architecture-decisions-with-madr.md) に補足を加えた。
* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 2 段 a を終えた（`doing`）。
  * マスタ・設定・コードリストの読み込みの `SourceModel` を作った（Mapper の文、MyBatis の対応、Provider、コードリスト、設定、具体機械 `queryConcrete`）。
  * Mapper の SQL を PostgreSQL で差分実行して照合した（`conformance/sql/master-data.json`）。
  * マスタのベクタを両モデルで実行した。
  * `@[source]` 45 件を rehash で記録した。
* **Creation**: [ADR c108](decision/c108-master-data-source-model-and-spec-fixes.md) で、次の 5 点を決めた。
  * 読み込みの `SourceModel` の写し方。列の型は、処理系の範囲で写す。
  * `Spec.Route.flightTime` の削除
  * MD-8 の空港コード
  * 問い合わせの機械の拡張
  * 差分実行
* **Update**: [spec/abstraction.md](spec/abstraction.md) に、既知差異 D-027（前提型・具体側の入力）、影響（中断）、W 課題 ABS-127 を登録した。ABS-026 の行も改めた。
* **Update**: 次の文書を改めた。
  * [spec/master-data.md](spec/master-data.md)
  * [spec/domain-model.md](spec/domain-model.md)（値域）
  * [spec/assurance.md](spec/assurance.md)（SQL の差分実行の付録）
  * [spec/conformance.md](spec/conformance.md)（`master.*`）
  * スキル port-lang の `sql/semantics.md`・`java/semantics.md`
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) で、空虚化を防ぐ義務（ADR 70eb）を既存の研究と対応づけた。作成時は旧番号 0042 だったが、main に [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md) が先に入ったため旧番号 0043 に採番し直した。対応づけた研究は、Event-B の証明義務・vacuity detection・IronSpec・mCoq・Dafny の proof dependencies・CompCert である。
  * 採用 A: 成分の必要性（成分を外すと R 課題の命題が偽になること。検査 G9）
  * 採用 B: 仕様の変異テスト（[backlog 0d1a](backlog/0d1a-mutation-testing-of-named-components.md)）
  * 採用 C: 意図から書く例（Spec-Testing Proofs）
* **Creation**: [backlog ae04](backlog/ae04-component-necessity-witness.md) を作った。スキル port-lang の `Machine.Adequacy` に必要性の補題を、`MachineTest/Adequacy.lean` に反例 12・13 と正例を加えた。`obligation-check` に G9 を加えた。
* **Creation**: [backlog 0d1a](backlog/0d1a-mutation-testing-of-named-components.md) を作った（`todo`）。
* **Update**: 「強すぎる前提になっていないか」を主眼に敵対的レビューを行い、G9 を改めた（差異 ID ごとの集計、被覆 `Covers`、観測型の和 `anyOf`、ID は定数に 1 つ、`¬ Refines`・`→ False` の受理、PRE が全域な基底の `TotalUnder A always`、R 課題の基底に限った環境の前提）。指摘と対応は [ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) に記した。backlog ae04 を完了した。
* **Update**: ADR 9ac6 を次の文書に反映した。
  * [spec/abstraction.md](spec/abstraction.md)・[spec/refinement.md](spec/refinement.md)（W 課題・SPEC-006・空虚化を防ぐ義務）
  * [spec/assurance.md](spec/assurance.md)（W 課題を人が読む限界を削り、必要性の範囲の限界を加えた）
  * [ADR 70eb](decision/70eb-refinement-non-vacuity-obligations.md) の More Information（補足の追記）
  * [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の完了条件
  * スキル port-lang の SKILL・architecture・traceability・verification・conformance・spec-documents・lean/rules
  * [AGENTS.md](../AGENTS.md)
* **Update**: [backlog 25f7](backlog/25f7-fare-calculation-both-models.md) の第 1 段を終えた（`doing`）。
  * Lean `Spec.Fare` と `SourceModel.Fare`（`SourceModel.Model`・`SourceModel.MasterData`）を作った。
  * 運賃計算の全例をベクタにし、両モデルで実行するようにした（`conformance/{spec,source-model,shared}/fare/`）。
  * 共有入力 `conformance/fixtures/master-data.json`・`config.json` を、上流のシードから生成するようにした。生成器は `tools/conformance/master_fixture.py`。
  * `@[source]` 9 件を `tools/trace rehash` で記録した。
* **Creation**: [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md) で、次のことを決めた。
  * マスタの表し方（Provider のキャッシュ）
  * 列挙型
  * `HashMap`
  * 共有ベクタの `modelDef` の配列
  * 共有入力の生成
  * `source-model/` の暫定の期待値
  * 翌日着の便の暫定の扱い
* **Update**: 次の文書に、ADR 8f18 による変更を反映した。
  * [spec/fare-calculation.md](spec/fare-calculation.md): 要約（informative）に改め、Lean へのリンクを付けた
  * [spec/conformance.md](spec/conformance.md)
  * [spec/assurance.md](spec/assurance.md)
  * [spec/master-data.md](spec/master-data.md): 到着時刻 `2415` の TODO
  * [backlog 0be7](backlog/0be7-flight-search-usecase.md): 翌日着の便
  * [ADR dc3a](decision/dc3a-conformance-test-vectors.md)
  * スキル port-lang の conformance・lean/trace-attributes
  * [AGENTS.md](../AGENTS.md)

* **Creation**: [ADR 0b83](../.agents/skills/spec-pivot/references/docs/decision/0b83-porting-conditions-and-workflow.md) で、スキル port-lang に移植が成り立つ条件を明示し、進め方の既定を補うことを決めた。
  * スキルの [SKILL.md](../.agents/skills/spec-pivot/SKILL.md) に「移植が成り立つ条件」（適用の前提・成立の条件・言えること・言えないこと）を加え、版を 0.4 にした。
  * 進め方の既定として [workflow.md](../.agents/skills/spec-pivot/references/docs/guide/workflow.md) を新設した（評価・判断を記録する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録）。プロジェクトは置き換えてよい。
  * スキルの process.md・verification.md から workflow.md を参照した。
  * 独立したエージェントによる敵対的レビュー（2 観点、2 巡）を行い、指摘と対応を ADR 0b83 に記した。作成時は旧番号 0042 だったが、main に [ADR 8f18](decision/8f18-fare-source-model-and-shared-vectors.md)・[ADR 9ac6](decision/9ac6-vacuity-literature-necessity-and-mutation.md) が先に入ったため、旧番号 0044 に採番し直した。
  * main の ADR 9ac6（成分の必要性・仕様の変異テスト・意図から書く例）に合わせて、成立の条件 S2 と workflow.md の判断を記録する事項・検査ゲートを整えた。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に「進め方の適用（ATRS）」を加えた。
* **Update**: [backlog ffdc](backlog/ffdc-trace-tooling.md) を完了した（第 2 段）。
  * 追跡の道具 `tools/trace` に、`rehash`・`diff`・`impact` を加えた。
  * `rehash` は、検査の登録 `trace/checks.json` を使う。
  * `check` の TR-R に、`trace/renames.json` と「出典:」のロケータの参照切れを加えた。
  * `trace-dump` が定義の `module` を出力するようにした。
  * JVM・PostgreSQL との突き合わせを `tools/ci/jvm_table.sh`・`pg_table.sh` に切り出した。
* **Creation**: [ADR 9cd9](../.agents/skills/spec-pivot/references/docs/decision/9cd9-rehash-diff-impact-details.md) で、次の細部を決めた。ADR 0eea を補う。
  * 検査の登録
  * `rehash` の対象と手順
  * 注釈の書き換え方
  * 改名の扱い
  * `diff` の分類と `impact` の伝播
  * 「出典:」の検査
* **Update**: [spec/fare-calculation.md](spec/fare-calculation.md)・[spec/flight-search.md](spec/flight-search.md)・[spec/reservation.md](spec/reservation.md) の「出典:」をロケータ表記に書き換えた。
* **Update**: [spec/traceability.md](spec/traceability.md) を改めた。
  * 初期の予定対応の表を削除し、`trace/features.json` を参照するようにした。
  * 運賃の例から、private の `getMultiplicationRatio` を外した。
  * `checks.json`・`renames.json` と、`rehash`・`diff`・`impact` の使い方を加えた。
* **Update**: 次の文書に、ADR 9cd9 による追加を反映した。
  * [rules/documentation.md](rules/documentation.md)（出典の記法）
  * [rules/atrs-porting.md](rules/atrs-porting.md)
  * [ADR e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md) の道具の節
  * スキル port-lang の traceability・upgrade・lean/trace-attributes
  * [AGENTS.md](../AGENTS.md)

## 2026-10-30

* **Update**: [backlog ffdc](backlog/ffdc-trace-tooling.md) の第 1 段を終えた（`doing`）。追跡の道具 `tools/trace`（Rust）で、インベントリ・`check`・`manifest` を作った。最初の `trace/source-inventory.json`（1963 件）を生成し、[spec/traceability.md](spec/traceability.md) の生成区画を埋め、CI に加えた。機能と backlog の対応表 `trace/features.json` を置いた。
* **Creation**: [ADR 0eea](../.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md) で、追跡の道具の未確定事項を決めた。決めたのは、本文ハッシュ・正規化・ロケータの細部・版の文字列・機能と backlog の対応である。あわせて ADR e2a4 の `seed:` の単位をテーブルに改めた。
* **Update**: [backlog c7e8](backlog/c7e8-lang-semantics-sql.md) を完了した。`LangSemantics.Sql` に `ORDER BY` の許される順列の一意性の証明を加えた。PostgreSQL 16.15 で生成した突き合わせ表（373 件）を CI に加えた（この表で `VARCHAR(n)` の空白の切詰めの不一致を見つけて直した）。版を `trace/upstream.json` と [rules/atrs-porting.md](rules/atrs-porting.md) に、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Creation**: [ADR 70eb](decision/70eb-refinement-non-vacuity-obligations.md) で、リファインメントが空虚・自明に成り立つことを防ぐ付帯の義務と検査を定めた（作成時は旧番号 0038 だったが、main に [ADR 6edf](../.agents/skills/spec-pivot/references/docs/decision/6edf-lean-package-under-skill-assets-lean.md) が先に入ったため旧番号 0039 に採番し直した）。
  * 義務: 選択の像としての `Spec`（`Machine.ofChoice`・`FreeFrame`）、`Sound` と 1 点の初期状態（`InitIs`）、環境の固定（`Refines.Pinned`・`NoFaultReachable`）、標準の貼り合わせ（`Glue.ofStd`。部分写像）、入口の全域性（`TotalUnder`・`EnvWitness`）、`InitSurj`、`StateSafe`、両向きの W 課題（`Nontrivial`）、核の明示（`KernelIs`）
  * 検査: TR-G・TR-N を実装し、TR-V・TR-PE を定めた（ADR 01d4・e2a4・e56e の決定は変えない）
  * 設計段階と実装後に、独立したエージェントによる敵対的レビューを行い、指摘と対応を ADR 70eb に記した
* **Creation**: [backlog f7b7](backlog/f7b7-refinement-non-vacuity.md) を作り、完了した。スキル port-lang の `assets/lean/Machine/Adequacy.lean` と反例 `assets/lean/MachineTest/Adequacy.lean`（11 件）、`lean/Trace/Obligation.lean`（`lake exe obligation-check`）、`tools/ci/check_obligations.py` を作り、`tools/ci/lean.sh` に組み込んだ。追跡属性 `@[nondet]`・`@[std_abs]`・`@[kernel]`・`@[env_pre]` を加えた。
* **Update**: [spec/abstraction.md](spec/abstraction.md) を改めた。
  * 空虚化を防ぐ義務の節を加えた。
  * α の表に、核の列と、環境・HTTP の応答の行を加えた。
  * 前提型の差異の影響（出力のみ／中断）、入口の R 課題、SPEC-005〜008、ABS-048、Spec の非決定性 N-001〜N-005 を加えた（各登録簿に backlog の列）。
* **Update**: [spec/refinement.md](spec/refinement.md) に、同じ項目と REF-011・REF-012 を加えた。
* **Update**: [spec/assurance.md](spec/assurance.md) に、モデル間の保証の限界と、環境・マスタを入力とする写しの限界を加えた。[spec/domain-model.md](spec/domain-model.md) には、入口の値域を環境の前提とすることを加えた。
* **Update**: ADR [01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md)・[e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md)・[e56e](decision/e56e-conflict-as-spec-nondeterminism.md) の More Information に、ADR 70eb による追加を記した。
* **Update**: backlog [a8ef](backlog/a8ef-conformance-vector-format-and-generator.md)・[ffdc](backlog/ffdc-trace-tooling.md) と [rules/backlog.md](rules/backlog.md) の完了の定義を改めた。main で完了した [backlog 591d](backlog/591d-abstract-domain-types-and-master-data.md) に足すはずだった作業（非決定性の選択の型・入口の環境の前提）は、[backlog 0fdf](backlog/0fdf-spec-nondet-and-entry-env.md) として新設した。
* **Update**: スキル port-lang を 0.3 に改めた（architecture・traceability・conformance・verification・spec-documents・lean/trace-attributes・SKILL.md）。

* **Update**: [ADR 6edf](../.agents/skills/spec-pivot/references/docs/decision/6edf-lean-package-under-skill-assets-lean.md) で、スキル port-lang の Lake パッケージ `langSemantics` を `assets/` 直下から `assets/lean/` に移した。ルートと `lean/` の `require`・manifest、CI（`tools/ci/lean.sh`・`check_lean.py`・`.github/workflows/lean.yml`）、スキルの文書、[rules/atrs-porting.md](rules/atrs-porting.md)、[AGENTS.md](../AGENTS.md)、関係する backlog と ADR のパスを改めた。
* **Update**: [backlog a8be](backlog/a8be-lang-semantics-java.md) を完了した。`LangSemantics.Java` に、`jdLit "0.01"` のビット表現と 1430 円・30% の例の定理、`minusDays` を足した。JVM で生成した突き合わせ表（581 件）と、運賃計算の double 式のネイティブ `Float` との突き合わせ（4,006,212 件）を CI に加え、範囲を [spec/assurance.md](spec/assurance.md) に記載した。
* **Update**: [rules/version-control.md](rules/version-control.md) の push の禁止を改め、自分で作ったブランチへの push と、そこからの PR の作成を認めた（既定ブランチと他人のブランチへの push は引き続き禁止、マージはオーナーが行う）。あわせて [AGENTS.md](../AGENTS.md)・[rules/README.md](rules/README.md)・[rules/backlog.md](rules/backlog.md) の要約を改めた。
* **Update**: [backlog 591d](backlog/591d-abstract-domain-types-and-master-data.md) を完了した。`lean/Spec/` に、基本演算・暦日・時刻・書式・文字クラス（`Spec.Prim`）、列挙・コード値・エンティティ・値域（`Spec.Model`）、設定（`Spec.Config`）、マスタデータと MD-1〜MD-8・参照関数（`Spec.MasterData`）、コードリスト（`Spec.CodeList`）を実装し、SPEC-001〜003 を証明した。`conformance/shared/format/` にベクタを作り、`lake test` で `Spec` に対して実行するようにした。あわせて [spec/domain-model.md](spec/domain-model.md)・[spec/master-data.md](spec/master-data.md)・[spec/configuration.md](spec/configuration.md) の形式化した節を要約（informative）に改め、[spec/conformance.md](spec/conformance.md) の操作名を足した。
* **Update**: [backlog 1ae4](../.agents/skills/spec-pivot/references/docs/backlog/1ae4-machine-refinement-framework.md) を完了した。スキル port-lang の `assets/Machine/` に、抽象機械・具体機械・貼り合わせ・`Machine.Refines`（INIT・入力の全域性・適用可能性・正しさ）・差異による制限・推移性を実装し、`assets/MachineTest/` で例と反例を証明した。CI（`tools/ci/lean.sh`）で `assets/` をビルドし、`axiom-check`・`trace-dump` の対象に `Machine` を加えた。あわせて [ADR 01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md)（制限の関数の名前）と [spec/refinement.md](spec/refinement.md)（証明義務を 4 つに揃えた）を直した。
* **Update**: [backlog be49](backlog/be49-lean-project-scaffold.md) を完了した。`lean/`（Lake パッケージ `atrs`、Lean v4.35.0、Batteries v4.35.0）に全名前空間の骨格・追跡属性（`Trace.Attr`）・`trace-dump`・`axiom-check`・テストを置き、CI（`tools/ci/lean.sh`、`.github/workflows/lean.yml`）を整えた。あわせて [ADR 659f](decision/659f-lean-toolchain-and-dependencies.md)（採った版）、[rules/atrs-porting.md](rules/atrs-porting.md)（配置）、[rules/version-control.md](rules/version-control.md)（コミット前の確認）を改めた。
* **Update**: [backlog 455f](backlog/455f-upstream-submodule-and-inventory.md) を完了した。上流 ATRS を `upstream/atrs` に submodule として commit 固定で取り込み、`trace/upstream.json`（版の宣言）と `trace/out-of-scope.json`（追跡の対象外）を作った。あわせて [rules/atrs-porting.md](rules/atrs-porting.md)（版の正、Windows の `core.longpaths`、TODO(spec) の解消）と [spec/traceability.md](spec/traceability.md#対象外) を改めた。
* **Creation**: [ADR c336](decision/c336-foundational-principles.md) で、基本原則 3 項を、全 ADR・規約・スキルに優先する原則として定めた。3 項は次のとおり。
  * 両端の一致を決定論的な検証または変換で確認する。
  * 抽象モデルと移植元/先モデルの間に B メソッドのリファインメントを証明する。
  * 差異を証明と文書の両方ですべて明示する。
* **Creation**: 原則と矛盾する既存の決定を置き換える ADR を作った。
  * [01d4](decision/01d4-b-method-refinement-and-explicit-deviations.md): B メソッドのリファインメントと、名前付きの差異（前提型・観測型・モデル外、D/T 登録簿、R/W/C/L 課題）
  * [0bd3](decision/0bd3-generate-verus-mirror-from-target-model.md): Verus の写しを TargetModel から生成し、`Machine` を名前空間の例外に加える
  * [e2a4](decision/e2a4-traceability-hash-as-deterministic-check-record.md): 検査済みハッシュ、TR-D、`tmpl:`、TR 検査の例外の廃止
  * [e56e](decision/e56e-conflict-as-spec-nondeterminism.md): `Conflict` を Spec の非決定的な結果とする
* **Deprecation**: ADR [a43d](decision/a43d-two-layer-model-java-faithful-and-abstract.md)・[796c](decision/796c-models-in-lean-and-sources-traced-at-both-ends.md)・[81ab](decision/81ab-cross-language-traceability.md)・[41f7](decision/41f7-concurrency-failure-as-conflict-error.md) を superseded にした。
* **Update**: ADR 935b・97f9（FOR UPDATE の記述の訂正）・5fcb（`Postgresql` の表記、SQL の差分実行）・3f36・e24e・e10f に補足を加えた。置換済み ADR へのリンクを、後継の ADR へ張り替えた。
* **Creation**: [spec/assurance.md](spec/assurance.md)（保証の限界）を作った。
* **Update**: [spec/abstraction.md](spec/abstraction.md) を改めた。
  * リファインメントの形と、既知差異の種類・R/W 課題を加えた。
  * D-022〜D-025 を登録した。
  * D-003/004/005/010/015 を、前提の外の参考表に移した。
  * ABS-040 を ABS-041〜046 に分割し、W 課題 ABS-1NN を加えた。
* **Update**: [spec/refinement.md](spec/refinement.md) を改めた（T-NNN 登録簿、REF-007/008、SRC を決定論的な手段に改めた。設計レビューは廃した）。
* **Update**: 次の仕様文書を、原則に合わせて改めた。
  * [ports.md](spec/ports.md): `Conflict`、パスワードの契約、分離レベル、キューの上限
  * [domain-model.md](spec/domain-model.md): 値域を PRE とする
  * [master-data.md](spec/master-data.md)、[fare-calculation.md](spec/fare-calculation.md)、[http-contract.md](spec/http-contract.md)、[authentication.md](spec/authentication.md)、[member.md](spec/member.md)、[errors-and-messages.md](spec/errors-and-messages.md)、[traceability.md](spec/traceability.md)、[spec/README.md](spec/README.md)
* **Update**: スキル port-lang（0.2）を改めた。
  * SKILL.md: 3 原則を最上位に置いた。
  * architecture.md: B メソッドのリファインメント。
  * verification.md: 決定論的な手段、保証の限界、`native_decide` の禁止。
  * traceability.md: 検査済みハッシュ、TR-D。
  * process.md、spec-documents.md、upgrade.md、adding-a-language.md、言語パックの `verification.md`・`layout.md`・`locators.md`（`tmpl:`）・`semantics.md`、lean/rules.md、lean/trace-attributes.md も改めた。
* **Update**: [AGENTS.md](../AGENTS.md)、[rules/README.md](rules/README.md)（優先順位の軸を明確にした）、[rules/backlog.md](rules/backlog.md)（完了の定義）、[rules/atrs-porting.md](rules/atrs-porting.md) を改めた。
* **Creation**: backlog [1ae4](../.agents/skills/spec-pivot/references/docs/backlog/1ae4-machine-refinement-framework.md)（`Machine`）と [d77c](backlog/d77c-verus-mirror-generator.md)（写しの生成器）を作った。backlog a8be・bbcc・0be7・aedf・4e0e・44f8・ac71・4b0e・f18c・a89e・c7e8・ddb4・9c1b・a936・eff6・26c5・ffdc の範囲・完了条件を、R/W 課題と決定論的な手段に合わせて改めた。
* **Update**: 敵対的レビューの 2 回目の指摘を解消した。
  * [spec/abstraction.md](spec/abstraction.md): 複合的な R 課題に、差異の仮定を引き継いだ。D-009・D-014 を前提の外に、D-013 をモデル外に改めた。D-001・D-020 の前提を定めた。ABS-007・ABS-023〜025・ABS-047 と SPEC-001〜004 を加え、ABS-109/113/114 を廃止した。
  * [spec/refinement.md](spec/refinement.md): REF-009・SRC-010 を加え、Verus の禁止構文を広げた。
  * [spec/assurance.md](spec/assurance.md): `#[verifier::external]` の一覧、規範節ごとの行、活性の限界、追跡の道具、付録を加えた。
  * ADR c336・01d4・0bd3・e2a4・e56e: モデル外の差異の位置づけ、前提の 2 つの形、`bv_decide` の禁止、`model_prelude.rs`、TR-T1 の生成物の扱い、`xml:`・`seed:`、改名の検査、実行環境の失敗と活性の限界を加えた。
  * ADR 659f・578b・e10f に補足（訂正）を加えた。ADR e10f では、差分の原典実行で入力を除外しないことにした。
  * スキル: 原典の事後条件を仮定にする抜け道、方言の差を無名の前提にする記述をなくした。
* **Creation**: backlog [9c04](backlog/9c04-rust-external-adapters.md)（DB・ファイル・時計のアダプタ）を作った。backlog の依存（f18c への依存、ac71 → 4e0e）と担当（REF-008、SRC-005/007/008）を整え、ffdc と 455f の循環を解いた。
* **Update**: 敵対的レビューの 3 回目の指摘を解消した。
  * リファインメントの義務に「入力の全域性」を加えた。
  * ポートの契約を主定理の仮定から外し、ポート実装の R 課題（ABS-021・023〜026、REF-008〜010）で証明することにした。
  * マスタ・設定を不変の入力とし、MD-1〜MD-8 を PRE に移した。
  * D-009・D-014 を前提型（具体側）に戻し、W 課題 ABS-109・ABS-114 を戻した。
  * D-026（JSON の不対サロゲート）・ABS-126 を加えた。
  * TR-S2・TR-T2 で、モデル側の変更でも再検査を求めることにした。
  * `pre_*` と `gen-verus --check-contracts` で、Verus の `requires`・`ensures` を検査することにした。
  * `model_prelude.rs` をスキルの assets に移した。`LangSemantics.Sql` は両側から使えることにした。
  * I/O 失敗の対象とコードを限定し、ports.md の規範節を絞った。
  * backlog の依存（bbcc・ffdc・aedf への依存）と担当を整えた。

## 2026-10-29

* **Creation**: 未決だった仕様を確定する ADR 7 件を作成した。[ac33](decision/ac33-email-validation-rule.md)（Email 規則）、[e24e](decision/e24e-validation-error-ordering.md)（検証エラーの並び）、[9ee4](decision/9ee4-clock-timezone-and-fixture-base-date.md)（Clock の Asia/Tokyo と fixture の投入日 2026-11-01）、[41f7](decision/41f7-concurrency-failure-as-conflict-error.md)（`Conflict` 分類）、[578b](decision/578b-member-update-in-single-transaction.md)（会員情報変更の 1 トランザクション化）、[90f5](decision/90f5-report-queue-at-least-once-delivery.md)（レポートキューの配信保証）、[e10f](decision/e10f-spec-corrects-unsafe-source-behavior.md)（原典の安全でない振る舞いを Spec で正す）。ADR a4fa・6eb2・97f9・ff4d の More Information に後続へのリンクを足した。
* **Update**: 上流 `f4bfbf06` と依存ライブラリ（Spring Framework 7.0.3、Spring Security 7.0.x、Hibernate Validator 9.1.0.Final、ActiveMQ Artemis）のソースを読んで、仕様の未決事項と文書間の矛盾を解消した。[spec/input-validation.md](spec/input-validation.md)（Email、エラーの並び、日付の解析、項目名の対応、REST の搭乗者数）、[spec/http-contract.md](spec/http-contract.md)（セッションの規範節、ログインの遷移先、日付の JSON、ApiError のコード、Basic 認証の失敗）、[spec/errors-and-messages.md](spec/errors-and-messages.md)、[spec/ports.md](spec/ports.md)（規範節の範囲、Clock、採番、キュー、トランザクション）、[spec/abstraction.md](spec/abstraction.md)（既知差異 D-011〜D-021、課題 ABS-032〜034）など。
* **Update**: [rules/atrs-porting.md](rules/atrs-porting.md) に上流の依存の版を記録した。backlog [4e0e](backlog/4e0e-member-usecases-and-input-validation.md)・[f18c](backlog/f18c-java-oracle-harness.md) の範囲を改めた。

* **Update**: リポジトリのルートを Lake ワークスペースにした（`lakefile.lean` が `.agents/skills/spec-pivot/assets` を `require`）。ルートで起動した Lean LSP から `LangSemantics` の import が解決されないのを直した。手順は [atrs-porting.md](rules/atrs-porting.md) とスキルの [lean/rules.md](../.agents/skills/spec-pivot/references/docs/lang/lean/rules.md)。

* **Creation**: スキル port-lang に `assets/LangSemantics/<Lang>/`（Java・Sql・Sql.Postgresql・Rust の Lean モデル。core のみ、`#guard` 検査付き）を追加した。backlog [a8be](backlog/a8be-lang-semantics-java.md)・[c7e8](backlog/c7e8-lang-semantics-sql.md)・[a936](../.agents/skills/spec-pivot/references/docs/backlog/a936-lang-semantics-rust.md) はこれを起点とする。

* **Creation**: [ADR f4e1](decision/f4e1-extract-porting-method-as-agent-skill.md)。言語間移植の方法を、アプリ非依存のスキル `.agents/skills/spec-pivot`（Agent Skills 形式）に切り出した。言語パック（java・sql・rust）は、移植元・移植先のどちらにもなれる 6 ファイル構成とした。
* **Deprecation**: `docs/rules/` から porting・spec-writing・portability・testing・upstream-upgrade・lean・rust をスキルへ移した（git mv）。
* **Creation**: [rules/atrs-porting.md](rules/atrs-porting.md)（スキルの ATRS への適用）を追加した。
* **Update**: [spec/conformance.md](spec/conformance.md)・[spec/traceability.md](spec/traceability.md)・[spec/refinement.md](spec/refinement.md) を ATRS 固有の内容に絞った。ADR・backlog・spec の、移動した規約へのリンクを張り替えた。

* **Creation**: [ADR 796c](decision/796c-models-in-lean-and-sources-traced-at-both-ends.md)（モデルと証明をすべて Lean に置き、`TargetModel` を Lean のモデル、Rust を移植先ソースとする）、[ADR 81ab](decision/81ab-cross-language-traceability.md)（両端の追跡: ロケータ・モデル側注釈・確認済みハッシュ・TR 検査）、[ADR 3f36](decision/3f36-following-upstream-releases.md)（上流の版上げ追従・差分の原典実行）を作成した。
* **Deprecation**: [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md) と [ADR dd0f](decision/dd0f-rust-as-target-language.md) を ADR 796c で置き換えた。
* **Creation**: 規約 [port-lang/upgrade.md](../.agents/skills/spec-pivot/references/docs/guide/upgrade.md)（版上げ手順、draft）を追加した。
* **Update**: [port-lang/lean/rules.md](../.agents/skills/spec-pivot/references/docs/lang/lean/rules.md)・[port-lang/rust/layout.md](../.agents/skills/spec-pivot/references/docs/lang/rust/layout.md)・porting・testing・version-control・spec-writing・documentation を新構成と追跡注釈に合わせて改訂した。
* **Update**: [spec/traceability.md](spec/traceability.md) をロケータ文法・注釈・検査・運賃の追跡例を含む形に書き直した。[spec/refinement.md](spec/refinement.md) を REF（Lean で証明）と SRC（TargetModel ⇔ Rust の確認）に分けた。[spec/conformance.md](spec/conformance.md) に `target-model/`・`modelDef`・`upstream` を追加した。
* **Update**: バックログ be49・aedf・4b0e・a89e・fb50・ddb4・9c1b を改訂し、a936・eff6・26c5・ffdc・455f・773f を追加した。

* **Creation**: [ADR dd0f](decision/dd0f-rust-as-target-language.md)（移植先を Rust とし、Refinement を Verus・Kani・適合テストで充足）と [ADR 61bc](decision/61bc-lean-spec-as-normative-source.md)（Lean `Spec` を正規とし、`Spec` で表現できない仕様だけを docs/spec で定義）を作成した。
* **Deprecation**: [ADR 3b0a](decision/3b0a-spec-as-normative-source.md) を ADR 61bc で置き換えた。
* **Update**: [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md) の配置の記述を ADR dd0f に合わせた（Lean は `TargetModel`・`Refinement` を持たない）。ADR 84bf・97f9・dc3a・659f の関連箇所を更新した。
* **Creation**: 規約 [port-lang/rust/layout.md](../.agents/skills/spec-pivot/references/docs/lang/rust/layout.md)（draft）と [rules/version-control.md](rules/version-control.md)（作業の区切りで commit、push しない）を追加した。
* **Update**: docs/spec の全文書に区分 `spec_role`（normative / meta / draft）を付け、[spec/refinement.md](spec/refinement.md) を Rust 向けに書き直した。
* **Update**: バックログ be49・4b0e・a8ef・a89e を Rust 方針に合わせて改訂し、31da を取りやめ、fb50・ddb4・9c1b を追加した。

* **Creation**: OKF v0.2 バンドルとして [docs/index.md](index.md) と本ログを作成した（[ADR a0f1](decision/a0f1-documentation-format-okf-v0-2.md)）。
* **Creation**: 作業規約 [rules/](rules/README.md) 9 件を作成した。
* **Creation**: ADR d845・84bf・3b0a・a43d・935b・e41d・f0e4・a4fa・6eb2・10a5・97f9・1b00・dc3a・659f・2d1f・ff4d・a0f1・3e1d・5fcb を作成した。層の名前とトップレベル名前空間（`LangSemantics.<lang>` / `SourceModel` / `Spec` / `Abstraction` / `TargetModel` / `Refinement`）は [ADR 3e1d](decision/3e1d-language-neutral-top-level-namespaces.md)、SQL 意味論は [ADR 5fcb](decision/5fcb-sql-semantics-for-source-repositories.md)。
* **Creation**: 正規仕様 [spec/](spec/README.md) 初版（draft、未レビュー）を作成した。上流 commit `f4bfbf0615eb91805546c9c780d4761be92ce17e` を調査対象とした。
* **Creation**: バックログ [backlog/](backlog/README.md) be49・a8be・591d・25f7・bbcc・0be7・aedf・4e0e・44f8・ac71・4b0e・a8ef・f18c・a89e・31da・c7e8・ddbd を作成した。
