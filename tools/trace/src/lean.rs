//! Lean の出力の読み込み（`lake exe trace-dump`・`lake exe obligation-check`）。

use serde::Deserialize;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::path::Path;

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Def {
    pub name: String,
    pub layer: String,
    #[serde(default)]
    pub attributes: BTreeMap<String, Vec<String>>,
    #[serde(default)]
    pub merkle: String,
    #[serde(default)]
    pub references: Vec<String>,
    /// 定義のあるモジュール（`rehash` が注釈を書き換えるファイルを引く）
    #[serde(default)]
    pub module: String,
}

impl Def {
    pub fn attr(&self, k: &str) -> &[String] {
        self.attributes.get(k).map(|v| v.as_slice()).unwrap_or(&[])
    }
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Dump {
    #[serde(default)]
    #[allow(dead_code)]
    pub lean_version: String,
    pub definitions: Vec<Def>,
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Refinement {
    pub name: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub ids: Vec<String>,
    #[serde(default)]
    pub deviations: Vec<String>,
    #[serde(default)]
    pub observations: Vec<String>,
    #[serde(default)]
    pub errors: Vec<String>,
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Obligation {
    pub name: String,
    #[serde(default)]
    pub ids: Vec<String>,
    #[serde(default)]
    pub refines: bool,
}

#[derive(Deserialize, Clone, Debug, Default)]
pub struct Obligations {
    #[serde(default)]
    pub refinements: Vec<Refinement>,
    #[serde(default)]
    pub obligations: Vec<Obligation>,
    #[serde(default)]
    pub errors: Vec<String>,
}

pub fn load<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<T, String> {
    let s = std::fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
    serde_json::from_str(&s).map_err(|e| format!("{}: {e}", path.display()))
}

/// `"<locator>@<hash>"` を最後の `@` で分ける（ADR 0040）。
pub fn split_hash(s: &str) -> (&str, &str) {
    match s.rfind('@') {
        Some(i) => (&s[..i], &s[i + 1..]),
        None => (s, ""),
    }
}

/// ロケータの種類（`java@source:` などの `@…` は除く）。
pub fn kind_of(locator: &str) -> &str {
    let k = locator.split(':').next().unwrap_or("");
    k.split('@').next().unwrap_or(k)
}

/// 定義から、参照をたどって届く定義の集合（ダンプにある定義だけ）。
pub fn closure(dump: &Dump, roots: &[String]) -> BTreeSet<String> {
    let idx: HashMap<&str, &Def> = dump.definitions.iter().map(|d| (d.name.as_str(), d)).collect();
    let mut seen = BTreeSet::new();
    let mut stack: Vec<String> = roots.to_vec();
    while let Some(n) = stack.pop() {
        if !seen.insert(n.clone()) {
            continue;
        }
        if let Some(d) = idx.get(n.as_str()) {
            for r in &d.references {
                if idx.contains_key(r.as_str()) && !seen.contains(r) {
                    stack.push(r.clone());
                }
            }
        }
    }
    seen
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_at_last_at() {
        assert_eq!(split_hash("java:a.B#f(int)@0123"), ("java:a.B#f(int)", "0123"));
        assert_eq!(split_hash("tmpl:x.html#span[@th:text='a']@ff"), ("tmpl:x.html#span[@th:text='a']", "ff"));
        assert_eq!(kind_of("java@source:a.B#f()"), "java");
    }
}
