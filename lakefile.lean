import Lake
open Lake DSL

/-!
リポジトリのルートの Lake ワークスペース。

Lean の言語サーバ（LSP）はリポジトリのルートで起動されるため、ルートを Lake ワークスペースにし、
リポジトリ内の Lean パッケージを `require` で取り込む。これにより、どのパッケージのファイルを開いても
`import` が解決される。

- `langSemantics`: port-lang スキルの言語意味論モデル（`.agents/skills/port-lang/assets`）
- `atrs`: ATRS の Lean プロジェクト（`lean/`）
-/
package atrsWorkspace where
  leanOptions := #[⟨`autoImplicit, false⟩]

require langSemantics from "./.agents/skills/port-lang/assets"
require atrs from "./lean"
