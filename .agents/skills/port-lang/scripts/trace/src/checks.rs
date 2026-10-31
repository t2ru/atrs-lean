//! 決定論的な検査の登録 `trace/checks.json`（references/docs/traceability.md#検査済みハッシュ・9cd9）。
//!
//! 各検査は `steps`（作業ディレクトリと argv）を順に実行し、すべて終了コード 0 なら合格とする。
//! 覆う定義（`covers`）は、Lean の名前の glob（`names`）と、適合テストベクタのファイルの glob
//! （`vectors`。ファイルの `modelDef` と、その参照の閉包を覆う）で書く。

use crate::lean::{closure, Dump};
use globset::{Glob, GlobSet, GlobSetBuilder};
use serde::Deserialize;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

#[derive(Deserialize, Clone, Debug)]
pub struct Step {
    #[serde(default = "dot")]
    pub cwd: String,
    pub argv: Vec<String>,
}

fn dot() -> String {
    ".".into()
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Covers {
    #[serde(default)]
    pub names: Vec<String>,
    #[serde(default)]
    pub vectors: Vec<String>,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Check {
    pub id: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub description: String,
    pub steps: Vec<Step>,
    #[serde(default)]
    pub covers: Covers,
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Registry {
    #[serde(default)]
    pub checks: Vec<Check>,
}

pub fn load(repo: &Path) -> Result<Registry, String> {
    let p = repo.join("trace/checks.json");
    match std::fs::read_to_string(&p) {
        Ok(s) => {
            let r: Registry = serde_json::from_str(&s).map_err(|e| format!("{}: {e}", p.display()))?;
            let mut ids = BTreeSet::new();
            for c in &r.checks {
                if !ids.insert(&c.id) {
                    return Err(format!("{}: duplicate check id {}", p.display(), c.id));
                }
                if c.steps.iter().any(|s| s.argv.is_empty()) {
                    return Err(format!("{}: {}: empty argv", p.display(), c.id));
                }
            }
            Ok(r)
        }
        Err(_) => Ok(Registry::default()),
    }
}

fn globs(pats: &[String]) -> Result<GlobSet, String> {
    let mut b = GlobSetBuilder::new();
    for p in pats {
        b.add(Glob::new(p).map_err(|e| format!("{p}: {e}"))?);
    }
    b.build().map_err(|e| e.to_string())
}

/// glob の先頭の、ワイルドカードを含まないディレクトリ。
fn literal_base(pat: &str) -> &str {
    let mut end = 0;
    for (i, c) in pat.char_indices() {
        if matches!(c, '*' | '?' | '[' | '{') {
            break;
        }
        if c == '/' {
            end = i;
        }
    }
    &pat[..end]
}

fn walk(dir: &Path, out: &mut Vec<std::path::PathBuf>) {
    let Ok(rd) = std::fs::read_dir(dir) else { return };
    let mut v: Vec<_> = rd.flatten().map(|e| e.path()).collect();
    v.sort();
    for p in v {
        if p.is_dir() {
            walk(&p, out);
        } else {
            out.push(p);
        }
    }
}

/// ベクタの `modelDef`。文字列か、モデルごとの名前の配列（`shared/`。references/docs/conformance.md）。
pub fn model_defs_of(v: &serde_json::Value) -> Vec<String> {
    match &v["modelDef"] {
        serde_json::Value::String(s) => vec![s.clone()],
        serde_json::Value::Array(xs) => xs.iter().filter_map(|x| x.as_str().map(String::from)).collect(),
        _ => vec![],
    }
}

/// `vectors` の glob に当たるファイルの（リポジトリからの相対パス, `modelDef`）。
fn vector_model_defs(repo: &Path, pats: &[String]) -> Result<Vec<(String, String)>, String> {
    let set = globs(pats)?;
    let mut bases: BTreeSet<&str> = pats.iter().map(|p| literal_base(p)).collect();
    if bases.contains("") {
        bases = BTreeSet::from([""]);
    }
    let mut out = vec![];
    for b in bases {
        let mut files = vec![];
        walk(&repo.join(b), &mut files);
        for f in files {
            let rel = f.strip_prefix(repo).unwrap_or(&f).to_string_lossy().replace('\\', "/");
            if !set.is_match(&rel) {
                continue;
            }
            let v: serde_json::Value =
                std::fs::read_to_string(&f).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default();
            for n in model_defs_of(&v) {
                out.push((rel.clone(), n));
            }
        }
    }
    Ok(out)
}

/// 定義ごとの、覆う検査の ID。
pub fn coverage(reg: &Registry, repo: &Path, dump: &Dump) -> Result<BTreeMap<String, BTreeSet<String>>, String> {
    let mut out: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
    for c in &reg.checks {
        let names = globs(&c.covers.names)?;
        for d in &dump.definitions {
            if names.is_match(&d.name) {
                out.entry(d.name.clone()).or_default().insert(c.id.clone());
            }
        }
        let roots: Vec<String> = vector_model_defs(repo, &c.covers.vectors)?.into_iter().map(|(_, n)| n).collect();
        for n in closure(dump, &roots) {
            out.entry(n).or_default().insert(c.id.clone());
        }
    }
    Ok(out)
}

/// 検査を実行する。すべての段が終了コード 0 なら合格。出力はそのまま標準エラーに流す。
pub fn run(repo: &Path, c: &Check) -> bool {
    for s in &c.steps {
        eprintln!("rehash: [{}] {} (in {})", c.id, s.argv.join(" "), s.cwd);
        let status = std::process::Command::new(&s.argv[0])
            .args(&s.argv[1..])
            .current_dir(repo.join(&s.cwd))
            .stdout(std::process::Stdio::from(std::io::stderr()))
            .status();
        match status {
            Ok(st) if st.success() => {}
            Ok(st) => {
                eprintln!("rehash: [{}] failed ({st})", c.id);
                return false;
            }
            Err(e) => {
                eprintln!("rehash: [{}] {}: {e}", c.id, s.argv[0]);
                return false;
            }
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn model_def_string_or_array() {
        assert_eq!(model_defs_of(&serde_json::json!({"modelDef": "Spec.Fare.fare"})), vec!["Spec.Fare.fare"]);
        assert_eq!(
            model_defs_of(&serde_json::json!({"modelDef": ["Spec.Fare.fare", "SourceModel.Fare.calculateFare"]})),
            vec!["Spec.Fare.fare", "SourceModel.Fare.calculateFare"]
        );
        assert!(model_defs_of(&serde_json::json!({"cases": []})).is_empty());
    }

    #[test]
    fn literal_base_of_globs() {
        assert_eq!(literal_base("conformance/**/*.json"), "conformance");
        assert_eq!(literal_base("conformance/source-model/fare/*.json"), "conformance/source-model/fare");
        assert_eq!(literal_base("*.json"), "");
    }
}
