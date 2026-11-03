---
type: Architecture Decision Record
title: "Lean のモジュール文書のリンクと、.lean の見出しアンカーを検査する"
description: "okf_check.py が、設定 links.lean_roots の Lean のファイルについて、mdgen が Markdown の地の文にする部分（列 0 から始まる /-! -/ と /- -/）を文書として読み、その中のリンクを L1・L2 で検査する。.lean を指すリンクの見出しアンカーも、同じ地の文の見出しから作って検査する。"
tags: [adr, okf, links, lean]
id: "75c9a882-3c37-409f-9b8c-1412bfcd67fe"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: 適用先 ATRS のオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# Lean のモジュール文書のリンクと、.lean の見出しアンカーを検査する

## Context and Problem Statement

適用先 ATRS は、業務仕様の散文を Markdown の文書から Lean のモジュール文書（`/-! … -/`）へ移し、mdgen と mdbook で HTML の本にすることにした（来歴: ATRS の ADR 68a6）。
`okf_check.py` は Markdown のリンクだけを検査し、`.lean` を指すリンクはファイルの存在だけを確かめていた。散文を Lean へ移すと、その中のリンクと、散文の見出しを指すアンカーが検査から外れる。

## Decision Drivers

* 文書を Lean へ移しても、リンクと見出しアンカーの検査が届く範囲を減らさないこと
* 本（mdgen と mdbook）で辿るリンクと、エディタや GitHub で辿るリンクを同じにすること
* Lean を処理系として動かさず、標準ライブラリの Python だけで検査すること

## Considered Options

* 設定した Lean のファイルの、mdgen が地の文にする部分を文書として読む
* Lean のファイルの `/-! -/` だけを読む（`/- -/` は読まない）
* 本の Markdown（mdgen の出力）を検査する

## Decision Outcome

Chosen option: "設定した Lean のファイルの、mdgen が地の文にする部分を文書として読む", because 本に現れる文と検査する文が一致し、mdgen も Lean も動かさずに検査できるため。本の Markdown を検査すると、mdgen と Lean の道具が要り、誤りの行も Lean のファイルの行と対応しない。

* 設定 `links.lean_roots`（ファイルかディレクトリ）の `.lean` を、`links.roots` の Markdown と同じく L1・L3 で検査する。
* 地の文は mdgen（版 v4.35.0-rc4）の規則に合わせる: 列 0 から始まる `/-`（`/--` を除く）でブロックコメントに入り、行末の `-/` で出る（入れ子を数える）。`/--` の文書コメントは地の文にしない。行末の `--#` の行と、`--#--` で囲んだ行は無視する。区切りの `/-!`・`/-`・`-/` は除く。行番号は元のファイルのままにする。
* `.lean` を指すリンクの見出しアンカー（L2）は、そのファイルの地の文の見出しから、Markdown と同じ規則（GitHub）で作る。

### Consequences

* Good, because Lean へ移した散文の中のリンクと、散文の見出しを指すリンクが検査される。
* Bad, because mdgen の規則が変われば、この読み方も合わせる必要がある（違反例 `scripts/fixtures/lean-docs` で確かめる）。

## More Information

* 規則と設定: [rules/bundle.md](../rules/bundle.md#設定)。
