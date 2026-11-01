---
type: Architecture Decision Record
title: "layout-check のモジュールの組を、組ごとに別のプロセスで判定する"
description: "layout-check（Trace.Layout.run）は、モジュールの組ごとに環境を読み込んで解放しないため、メモリが組の数に比例して増えていた。組ごとに同じ実行ファイルを子プロセスとして起動して判定し、親は結果の JSON を合わせるだけにする。Environment.freeRegions による解放は採らない。"
tags: [adr, skill, tooling, lean, memory]
id: "89f209dc-b8f4-495f-aa1e-a30c26ee4749"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:00:00+09:00
---

# layout-check のモジュールの組を、組ごとに別のプロセスで判定する

## Context and Problem Statement

`lake exe layout-check` の本体 `Trace.Layout.run` は、モジュールの組（実行ファイルの入口は、どれも `main` を持ち同時には読み込めないので組を分ける）ごとに、`Trace.Dump.loadEnv`（`importModules`）で環境を読み込む。読み込んだ .olean の領域（compacted region）は解放されないため、メモリは組の数に比例して増える。
適用先 ATRS の CI では、5 つの組の判定のあいだに使用量が 1.2 GB から 6.2 GB、7.4 GB（runner の 7.9 GB のうち）に達し、6 つ目の組を足すと runner が止まった。メモリの最大を、組 1 つ分にする方法を決める。

## Decision Drivers

* メモリの最大が、組の数によらず組 1 つ分であること
* 解放の誤りが、未定義の動作（解放後の参照）にならないこと。型では防げず、Lean の版上げで現れうる
* 道具の入口（適用先の `main`）の呼び出しと、出力（文と `--json`）・終了コードを変えないこと

## Considered Options

* 組ごとに別のプロセスで判定する（同じ実行ファイルを子プロセスとして起動する）
* 判定のあと `Environment.freeRegions` で領域を解放する
* 組をやめ、1 つの環境に読み込む

## Decision Outcome

Chosen option: "組ごとに別のプロセスで判定する（同じ実行ファイルを子プロセスとして起動する）", because 子プロセスの終了で、組の環境のメモリがすべて OS に返り、解放後の参照が起こりえないため。

* `Trace.Layout.run` は、引数 `--layout-group <i>`（内部用）が無ければ親として動き、組ごとに `IO.appPath` の実行ファイルを `--layout-group <i>` で順に起動する。親は環境を読み込まない。
* 子は組 `i` の環境を読み込み、`check`（静的な除外だけを与える）と、同じモジュールの祖先への集約（`Result.collapse`）を行い、結果（範囲のモジュールとその検査数、違反、例外。名前は文字列）を JSON で標準出力に出す。
* 親は `mergeGroups` で組の順に合わせる。前の組に現れたモジュールは数えず、その件も採らない。これは、従来の「検査済みのモジュールを次の組で除く」と同じ結果になる（定数のモジュールは一意で、集約は同じモジュールの中だけで行うため）。
* 子が失敗するか、結果が読めなければ、終了コード 2 を返す。

### Consequences

* Good, because 組を足しても、メモリの最大は組 1 つ分のままである。
* Good, because 解放の安全性を考えなくてよい（unsafe な解放を使わない）。
* Bad, because 組ごとにプロセスの起動と Lean の初期化がかかる。環境の読み込みに比べて小さい。
* Bad, because 結果を JSON で渡すので、件の名前は文字列になる（出力は従来も文字列なので変わらない）。

### Confirmation

* `assets/lean` の `lake exe trace-test` が、`mergeGroups`（同じモジュールを 2 度数えない、最初の組の件だけを採る、順を保つ）と、結果の JSON の往復と、`check` の範囲のモジュールの数を確かめる。
* `assets/lean` と適用先の `lake exe layout-check` が通り、検査数が変わらない。
* 適用先 ATRS の CI で、layout-check を単独で 1 秒ごとの `free -m` とともに動かして確かめた（一時的な計測の段。確かめたあと外した）。
  * 変更前（6 組）: 使用量が 1.2 GB から 6.2 GB、7.4 GB（7.9 GB のうち）に達し、runner が止まった。
  * 変更後（5 組）: 使用量は 1,015 MB から最大 1,309 MB。最大のプロセス（組 1 つの子プロセス）の最大 RSS は 1,647 MB。検査数 2,781 は変更前と同じ。
  * 変更後（6 組。`Tests.LongMain` を加えた）: 使用量は 869 MB から最大 1,156 MB。最大のプロセスの最大 RSS は 1,650 MB。実行は 6 秒程度（変更前の 5 組では 42 秒）。
  * `free -m` の used には、ファイルを写した .olean のページが入らないため、最大 RSS も挙げる。どちらも組の数によらない。

## Pros and Cons of the Options

### 判定のあと `Environment.freeRegions` で領域を解放する

* Good, because プロセスを起動しない。
* Bad, because 判定の結果（`Name`）や、読み込みで実行した初期化子が大域の `IO.Ref` に残した値が、領域の中を指しうる。解放後にそれを読むと、型では防げない未定義の動作（多くは segfault）になり、後の組や Lean の版上げで初めて現れうる。

### 組をやめ、1 つの環境に読み込む

* Good, because 読み込みが 1 度で済む。
* Bad, because 実行ファイルの入口のモジュールは、どれも `main` を持ち、同時には読み込めない。

## More Information

* 本体: `assets/lean/Trace/Layout.lean`（`run`・`runGroup`・`runAll`・`mergeGroups`）。検査: `assets/lean/Test/Trace/Main.lean`
* 検査の規則: [lang/lean/rules.md](../lang/lean/rules.md#モジュールと名前空間)、[ADR 1a30](1a30-lean-module-namespace-layout.md)
* 来歴: 適用先 ATRS の CI（layout-check のメモリで runner が止まった）
