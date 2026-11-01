//! プロジェクトの設定 `trace/project.json`（spec-pivot の `references/docs/spec/traceability.md#プロジェクトの設定`）。
//!
//! 道具はアプリに依存しない。アプリ固有の値（移植元・移植先の配置、crate 名、文書のパス、言語の組、
//! Lean のルート）は、すべてこのファイルから読む。言語ごとのロケータの種類と `LangSemantics` の層は、
//! 言語パックの既定（[`lang_kinds`]・[`lang_layer`]）から引く。

use serde::Deserialize;
use std::path::Path;
use std::sync::OnceLock;

#[derive(Deserialize, Clone, Debug)]
pub struct Lean {
    /// Lean のモジュールを探すルート（`rehash` が注釈を書き換えるファイルを引く）
    pub roots: Vec<String>,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Languages {
    /// 移植元の言語（言語パックの名前。例 `java`・`sql`）
    pub source: Vec<String>,
    /// 移植先の言語（例 `rust`）
    pub target: Vec<String>,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Source {
    /// 移植元ソースの走査のルート（リポジトリからの相対。`out-of-scope.json` の glob もここからの相対）
    pub root: String,
    /// SQL のファイル（DDL・シード）を走査するディレクトリ（`root` からの相対）
    #[serde(default)]
    pub sql_dirs: Vec<String>,
    /// モデルのモジュールを原典のソースツリーの形に並べる規則（TR-M。無ければ検査しない）
    #[serde(default)]
    pub mirror: Option<Mirror>,
}

/// 原典のソースツリーとモデルのモジュールの対応（references/docs/spec/traceability.md#プロジェクトの設定）。
#[derive(Deserialize, Clone, Debug, Default)]
pub struct Mirror {
    /// モデルの層（例 `SourceModel`）
    pub lean_root: String,
    /// 原典のパッケージの共通の接頭辞（例 `jp.co.ntt.atrs`）。モジュールの名前からは除く
    pub package_prefix: String,
    /// 原典のソースツリーを写すモジュールの、層の直下の成分（例 `Domain`）。これ以外は原典のクラスに当たらないもの
    pub roots: Vec<String>,
    /// パッケージの成分の写し方。`upper-camel`（先頭だけ大文字）か `same`（そのまま）
    #[serde(default = "default_case")]
    pub case: String,
    /// どの定義から引いてもよい、横断的な設定のクラス（TR-M1 で、そのロケータは配置の根拠にしない）
    #[serde(default)]
    pub shared: Vec<String>,
}

fn default_case() -> String {
    "upper-camel".into()
}

#[derive(Deserialize, Clone, Debug)]
pub struct Target {
    /// 移植先のプロジェクトのルート（移植元のロケータが紛れ込んでいないかを調べる範囲。TR-X）
    pub root: String,
    /// 移植先ソースの走査のルート
    pub src: String,
    /// crate 名（Rust のパスの先頭）
    #[serde(rename = "crate")]
    pub crate_name: String,
    /// 生成した写しのディレクトリ（`src` からの相対）
    pub generated: String,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Docs {
    /// 仕様文書のディレクトリ（「出典:」を走査する範囲）
    pub spec: String,
    /// 抽象化の課題一覧（`D-NNN` の表・入口の R 課題・証明課題）
    pub abstraction: String,
    /// 具体化の課題一覧（`T-NNN` の表・入口の R 課題・REF 課題）
    pub refinement: String,
    /// 追跡の文書（`source-trace`・`target-trace` の生成区画）
    pub traceability: String,
    /// 意思決定記録のディレクトリ（記録の検査はスキル work-records の `scripts/ids.py`。この道具は読まない）
    #[allow(dead_code)]
    pub decision: String,
    /// 作業項目のディレクトリ（frontmatter の `id`・`state`）
    pub backlog: String,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Project {
    /// スキル spec-pivot の置き場所（`scripts/`・`assets/` の親）
    pub skill: String,
    pub lean: Lean,
    pub languages: Languages,
    pub source: Source,
    pub target: Target,
    pub docs: Docs,
    /// 適合テストベクタのディレクトリ
    pub conformance: String,
}

/// 設定ファイルのリポジトリからの相対パス。リポジトリのルートの目印でもある。
pub const FILE: &str = "trace/project.json";

static PROJECT: OnceLock<Project> = OnceLock::new();

/// `trace/project.json` を読み込む。
pub fn load(repo: &Path) -> Result<&'static Project, String> {
    let path = repo.join(FILE);
    let s = std::fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?;
    let p: Project = serde_json::from_str(&s).map_err(|e| format!("{}: {e}", path.display()))?;
    for l in p.languages.source.iter().chain(&p.languages.target) {
        if lang_kinds(l).is_empty() {
            return Err(format!("{}: unknown language {l:?} (no language pack)", path.display()));
        }
    }
    Ok(PROJECT.get_or_init(|| p))
}

/// 読み込んだ設定。テストでは、Java・SQL → Rust の既定を使う。
pub fn get() -> &'static Project {
    PROJECT.get_or_init(|| {
        if cfg!(test) {
            serde_json::from_str(TEST_DEFAULT).unwrap()
        } else {
            panic!("{FILE} is not loaded")
        }
    })
}

const TEST_DEFAULT: &str = r#"{
  "skill": ".agents/skills/spec-pivot",
  "lean": { "roots": ["lean", ".agents/skills/spec-pivot/assets/lean"] },
  "languages": { "source": ["java", "sql"], "target": ["rust"] },
  "source": { "root": "upstream/app/src", "sql_dirs": ["db"] },
  "target": { "root": "rust", "src": "rust/src", "crate": "app", "generated": "model" },
  "docs": { "spec": "docs/spec", "abstraction": "docs/spec/abstraction.md", "refinement": "docs/spec/refinement.md",
            "traceability": "docs/spec/traceability.md", "decision": "docs/decision", "backlog": "docs/backlog" },
  "conformance": "conformance"
}"#;

/// 言語パックのロケータの種類（言語パックの `locators.md`）。未知の言語は空。
pub fn lang_kinds(lang: &str) -> &'static [&'static str] {
    match lang {
        "java" => &["java", "prop", "msg", "http", "xml", "tmpl"],
        "sql" => &["sql", "ddl", "seed"],
        "rust" => &["rust"],
        _ => &[],
    }
}

/// 言語パックの `LangSemantics` の層の名前（例 `java` → `LangSemantics.Java`）。
pub fn lang_layer(lang: &str) -> String {
    let mut cs = lang.chars();
    let cap: String = cs.next().map(|c| c.to_uppercase().chain(cs).collect()).unwrap_or_default();
    format!("LangSemantics.{cap}")
}

/// 移植元のロケータの種類（設定の言語の順）。
pub fn source_kinds() -> Vec<&'static str> {
    get().languages.source.iter().flat_map(|l| lang_kinds(l).iter().copied()).collect()
}

/// 移植先のロケータの種類。
pub fn target_kinds() -> Vec<&'static str> {
    get().languages.target.iter().flat_map(|l| lang_kinds(l).iter().copied()).collect()
}

/// 移植元側の `LangSemantics` の層。
pub fn source_langs() -> Vec<String> {
    get().languages.source.iter().map(|l| lang_layer(l)).collect()
}

/// 移植先側の `LangSemantics` の層。
pub fn target_langs() -> Vec<String> {
    get().languages.target.iter().map(|l| lang_layer(l)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn language_table() {
        assert_eq!(lang_layer("sql"), "LangSemantics.Sql");
        assert_eq!(source_kinds(), vec!["java", "prop", "msg", "http", "xml", "tmpl", "sql", "ddl", "seed"]);
        assert_eq!(target_kinds(), vec!["rust"]);
        assert_eq!(source_langs(), vec!["LangSemantics.Java", "LangSemantics.Sql"]);
    }
}
