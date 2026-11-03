import Lake
open Lake DSL

/-!
mdgen（Lean のファイルを Markdown にする道具。<https://github.com/Seasawher/mdgen>）を取り込むだけのパッケージ。
`scripts/book/build.py` が `lake -d <skill>/assets/mdgen exe mdgen <入力> <出力>` で呼ぶ。

mdgen は入力の Lean のファイルを文字列として読むだけで、コンパイルしない。そのため、モデル（`assets/lean` や
適用先の Lean プロジェクト）の依存に加えず、別のパッケージにする。mdgen の版は、適用先の Lean の版に合わせる。
-/
package specBook where

require mdgen from git "https://github.com/Seasawher/mdgen" @ "v4.35.0-rc4"
