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
    /// ギャップの登録簿（`@[gap_entry]`。references/docs/lang/lean/trace-attributes.md#ギャップの登録簿）
    #[serde(default)]
    pub gaps: Vec<Gap>,
}

/// 文書の節への参照（`Trace.Gap.DocRef`）。
#[derive(Deserialize, Clone, Debug, Default, PartialEq)]
pub struct Site {
    pub label: String,
    /// リポジトリのルートからのパスと、任意のアンカー
    pub path: String,
    #[serde(default)]
    pub note: String,
}

/// 前提型の差異の影響。
#[derive(Deserialize, Clone, Debug, Default, PartialEq)]
pub struct Impact {
    /// `output_only` / `abort`
    pub kind: String,
    /// 「出力のみ」/「中断」
    pub label: String,
    pub reason: String,
}

/// ギャップの証明の状態（`Trace.Gap.Evidence`）。
#[derive(Deserialize, Clone, Debug, Default)]
pub struct Evidence {
    /// `refuted` / `covered` / `pending` / `unformalized` / `excluded_by`
    #[serde(default)]
    pub state: String,
    /// 文書の表に出す名前
    #[serde(default)]
    pub label: String,
    /// 裏付けの宣言（否定の定理・被覆の定理・`opaque` の主張・前提の述語）
    #[serde(default)]
    pub witnesses: Vec<String>,
    /// `pending` の理由
    #[serde(default)]
    pub reason: String,
    /// `covered` の、覆う差異の述語
    #[serde(default)]
    pub coverer: Option<String>,
}

/// ギャップの登録（`Trace.Gap` と、その宣言・印）。
#[derive(Deserialize, Clone, Debug, Default)]
pub struct Gap {
    /// 宣言の Lean 名
    pub name: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub module: String,
    pub id: String,
    /// `pre` / `pre_concrete_*` / `observational` / `out_of_model` / `outside_pre` / `undetermined`
    pub kind: String,
    /// 文書の表に出す種類の名前
    pub kind_label: String,
    #[serde(default)]
    pub sites: Vec<Site>,
    /// 説明（docstring）
    #[serde(default)]
    pub doc: String,
    #[serde(default)]
    pub premise: String,
    #[serde(default)]
    pub r_tasks: Vec<String>,
    /// 証明の状態
    #[serde(default)]
    pub evidence: Evidence,
    /// W 課題（`refuted`・`covered` は裏付けの定理の `@[obligation]`、`pending` は予定）
    #[serde(default)]
    pub w_task: Option<String>,
    #[serde(default)]
    pub impact: Option<Impact>,
    #[serde(default)]
    pub resolution: String,
    #[serde(default)]
    pub backlog: Vec<String>,
    /// `@[gap]` の印を付けた定義（裏付けの宣言を含む）
    #[serde(default)]
    pub markers: Vec<String>,
    /// `@[deviation]` を付けた定義（同じ ID）
    #[serde(default)]
    pub deviations: Vec<String>,
}

impl Gap {
    /// 前提型（抽象側・具体側）か。
    pub fn is_pre(&self) -> bool {
        self.kind == "pre" || self.kind.starts_with("pre_concrete")
    }
    /// 名前付きの仮定・成分としてリファインメント定理に現れる種類（前提型・観測型）か。
    pub fn is_typed(&self) -> bool {
        self.is_pre() || self.kind == "observational"
    }
    /// 箇所の印（証明の層に置く裏付けの宣言を除く `@[gap]`。PRE の外の前提の述語は `Spec` の箇所の印でもある）。
    pub fn site_markers(&self) -> impl Iterator<Item = &String> {
        let proof = self.evidence.state != "excluded_by";
        self.markers.iter().filter(move |m| !(proof && self.evidence.witnesses.contains(m)))
    }
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
    /// 結論が束 `Machine.Preserves`（A preserves B）
    #[serde(default)]
    pub preserves: bool,
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

/// `"<locator>@<hash>"` を最後の `@` で分ける（references/docs/spec/traceability.md#道具）。
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
