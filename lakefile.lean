import Lake
open Lake DSL

/-!
リポジトリのルートの Lake ワークスペース。

Lean の言語サーバ（LSP）はリポジトリのルートで起動されるため、ルートを Lake ワークスペースにし、
リポジトリ内の Lean パッケージを `require` で取り込む。これにより、どのパッケージのファイルを開いても
`import` が解決される。

- `langSemantics`: spec-pivot スキルの言語意味論モデルと `Machine`（`.agents/skills/spec-pivot/assets/lean`）
- `atrs`: ATRS の Lean プロジェクト（`lean/`）
-/
package atrsWorkspace where
  leanOptions := #[⟨`autoImplicit, false⟩]

require langSemantics from "./.agents/skills/spec-pivot/assets/lean"
require atrs from "./lean"
