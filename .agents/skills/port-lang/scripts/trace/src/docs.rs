//! 文書の読み込み: 入口の R 課題と証明課題の表、backlog の状態、`trace/features.json`。
//! 既知差異（D/T）の登録簿は Lean にある（`trace-dump` の `gaps`。references/lean/trace-attributes.md#ギャップの登録簿）。

use globset::{Glob, GlobMatcher};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;

fn ids_in(s: &str) -> Vec<String> {
    let mut out = vec![];
    let cs: Vec<char> = s.chars().collect();
    let mut i = 0;
    while i < cs.len() {
        if cs[i].is_ascii_uppercase() {
            let start = i;
            while i < cs.len() && cs[i].is_ascii_uppercase() {
                i += 1;
            }
            if i + 4 <= cs.len() && cs[i] == '-' && cs[i + 1..i + 4].iter().all(|c| c.is_ascii_digit()) {
                out.push(cs[start..i + 4].iter().collect());
                i += 4;
                continue;
            }
        }
        i += 1;
    }
    out
}

/// 見出し `heading` の節（次の同じ深さ以上の見出しまで）の表の行（セルの列）。
fn section_rows(md: &str, heading: &str) -> Vec<Vec<String>> {
    let mut out = vec![];
    let mut inside = false;
    let mut level = 0;
    for l in md.lines() {
        if l.starts_with('#') {
            let lv = l.chars().take_while(|c| *c == '#').count();
            let title = l[lv..].trim();
            if inside && lv <= level {
                break;
            }
            if title.starts_with(heading) {
                inside = true;
                level = lv;
            }
            continue;
        }
        if inside && l.starts_with('|') && !l.contains("---") {
            let cells: Vec<String> = l.trim().trim_matches('|').split('|').map(|c| c.trim().to_string()).collect();
            out.push(cells);
        }
    }
    out
}

/// 入口の R 課題の ID。
pub fn entry_tasks(md: &str) -> Vec<String> {
    section_rows(md, "入口の R 課題")
        .into_iter()
        .filter_map(|r| r.first().cloned())
        .filter(|c| ids_in(c).len() == 1 && ids_in(c)[0] == *c)
        .collect()
}

/// 証明課題の表の R 課題の ID（`| ID | R | …` の行）。
pub fn r_tasks(md: &str) -> Vec<String> {
    let mut out = vec![];
    for l in md.lines() {
        let cells: Vec<&str> = l.trim().trim_matches('|').split('|').map(str::trim).collect();
        if l.starts_with('|') && cells.len() >= 2 && cells[1] == "R" && ids_in(cells[0]).len() == 1 {
            out.push(cells[0].to_string());
        }
    }
    out
}

/// 文書の「出典:」の行にある、バッククォートで囲んだロケータ（行番号は 1 始まり）。
/// ロケータの種類（`java:`・`sql:`・`rust:`・`dep:`・`lang:` など）で始まるものだけを拾う。
pub fn citations(md: &str) -> Vec<(usize, String)> {
    let kinds: Vec<&str> = crate::project::source_kinds().into_iter().chain(crate::project::target_kinds()).chain(["dep", "lang"]).collect();
    let mut out = vec![];
    for (i, l) in md.lines().enumerate() {
        let Some(p) = l.find("出典:") else { continue };
        let rest = &l[p..];
        for (j, span) in rest.split('`').enumerate() {
            if j % 2 == 1 && kinds.contains(&crate::lean::kind_of(span)) && span.contains(':') {
                out.push((i + 1, span.to_string()));
            }
        }
    }
    out
}

/// `docs/backlog/*.md` の `state`（frontmatter の `id` ごと。scripts/README.md）。
pub fn backlog_states(repo: &Path) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Ok(rd) = std::fs::read_dir(repo.join(&crate::project::get().docs.backlog)) {
        for e in rd.flatten() {
            let name = e.file_name().to_string_lossy().to_string();
            if !name.ends_with(".md") || name == "README.md" {
                continue;
            }
            let s = std::fs::read_to_string(e.path()).unwrap_or_default();
            let field = |k: &str| s.lines().find(|l| l.starts_with(k)).map(|l| l[k.len()..].trim().trim_matches('"').to_string());
            if let (Some(id), Some(state)) = (field("id:"), field("state:")) {
                out.insert(id, state);
            }
        }
    }
    out
}

/// `trace/features.json` の 1 機能。
#[derive(Deserialize, Clone, Debug)]
pub struct Feature {
    pub name: String,
    pub backlog: Vec<String>,
    #[serde(default)]
    pub lean: Vec<String>,
    #[serde(default)]
    pub tasks: Vec<String>,
    #[serde(default)]
    pub locators: Vec<String>,
}

#[derive(Deserialize, Clone, Debug)]
pub struct FeaturesFile {
    pub features: Vec<Feature>,
}

const LAYERS: &[&str] = &["SourceModel", "Abstraction", "TargetModel", "Refinement"];

/// 機能の対応表（references/traceability.md#道具）。
pub struct Features {
    pub list: Vec<Feature>,
    globs: Vec<Vec<GlobMatcher>>,
    states: BTreeMap<String, String>,
}

impl Features {
    pub fn load(repo: &Path) -> Result<Features, String> {
        let mut f: FeaturesFile = crate::lean::load(&repo.join("trace/features.json"))?;
        // 層を書かない名前空間（例 `Fare`）は、SourceModel・Abstraction・TargetModel・Refinement の 4 層に広げる
        for ft in &mut f.features {
            ft.lean = ft
                .lean
                .iter()
                .flat_map(|n| {
                    if LAYERS.iter().any(|l| n == l || n.starts_with(&format!("{l}."))) {
                        vec![n.clone()]
                    } else {
                        LAYERS.iter().map(|l| format!("{l}.{n}")).collect()
                    }
                })
                .collect();
        }
        let mut globs = vec![];
        for ft in &f.features {
            let mut v = vec![];
            for g in &ft.locators {
                v.push(Glob::new(g).map_err(|e| format!("features.json: {g}: {e}"))?.compile_matcher());
            }
            globs.push(v);
        }
        Ok(Features { list: f.features, globs, states: backlog_states(repo) })
    }

    #[cfg(test)]
    pub fn from(list: Vec<Feature>, states: BTreeMap<String, String>) -> Features {
        let globs = list
            .iter()
            .map(|f| f.locators.iter().map(|g| Glob::new(g).unwrap().compile_matcher()).collect())
            .collect();
        Features { list, globs, states }
    }

    /// ロケータの機能（最初に当たったもの）。
    pub fn of_locator(&self, loc: &str) -> Option<&Feature> {
        self.globs.iter().position(|gs| gs.iter().any(|g| g.is_match(loc))).map(|i| &self.list[i])
    }

    /// Lean の定義の機能（名前空間の接頭辞が最も長く一致するもの）。
    pub fn of_lean(&self, name: &str) -> Option<&Feature> {
        self.list
            .iter()
            .flat_map(|f| f.lean.iter().map(move |p| (p, f)))
            .filter(|(p, _)| name == p.as_str() || name.starts_with(&format!("{p}.")))
            .max_by_key(|(p, _)| p.len())
            .map(|(_, f)| f)
    }

    pub fn of_task(&self, id: &str) -> Option<&Feature> {
        self.list.iter().find(|f| f.tasks.iter().any(|t| t == id))
    }

    /// 機能の backlog がすべて `done` か（そうなら指摘は誤り、でなければ警告）。
    pub fn done(&self, f: &Feature) -> bool {
        f.backlog.iter().all(|b| self.states.get(b).map(|s| s == "done").unwrap_or(false))
    }

    /// backlog 項目が `done` か。
    pub fn backlog_done(&self, b: &str) -> bool {
        self.states.get(b).map(|s| s == "done").unwrap_or(false)
    }

    pub fn backlog_exists(&self, b: &str) -> bool {
        self.states.contains_key(b)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_tables() {
        let md = "## 既知差異\n\n| ID | 種類 | 箇所 | 差異 | 前提 | R 課題 | W 課題 |\n| --- | --- |\n\
                  | D-001 | 前提型 | a | b | `dev_D001` | ABS-001, ABS-004 | ABS-101 |\n\
                  | D-013 | モデル外 | a | b | — | — | — |\n\n### 小節\n\n| D-001 | 中断 | x | 00000000-0000-4000-8000-000000000005 |\n\
                  ## 証明課題\n\n| ID | 種類 | 内容 | 差異 |\n| ABS-001 | R | x | D-001 |\n| ABS-101 | W | y | D-001 |\n\
                  ### 入口の R 課題\n\n| ID | 入口 | backlog |\n| --- | --- | --- |\n| ABS-031 | REST | 00000000-0000-4000-8000-000000000014 |\n";
        assert_eq!(entry_tasks(md), vec!["ABS-031"]);
        assert_eq!(r_tasks(md), vec!["ABS-001"]);
    }

    #[test]
    fn reads_citations() {
        let md = "本文 `java:a.B#x()`\n出典: `java:a.B#f(int)`（private の `g` を含む）, `sql:a.M#find`\n出典: app-domain/.../B.java `f`\n";
        assert_eq!(citations(md), vec![(2, "java:a.B#f(int)".to_string()), (2, "sql:a.M#find".to_string())]);
    }
}
