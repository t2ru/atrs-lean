//! ギャップの表: `docs/spec/abstraction.md`・`refinement.md` の生成区画（references/docs/lean/trace-attributes.md#ギャップの登録簿）。
//!
//! 登録簿の正は Lean の `@[gap_entry]`（`trace-dump` の `gaps`）である。表は `trace manifest` が書き、
//! `--check` で最新であることを確かめる。
//!
//! | 区画 | 行 |
//! | --- | --- |
//! | `gaps-known` | 前提型・観測型・モデル外 |
//! | `gaps-impact` | 前提型の影響 |
//! | `gaps-outside-pre` | PRE の外の振る舞い |
//! | `gaps-undetermined` | 未確定 |

use crate::lean::{Gap, Site};
use std::path::{Component, Path, PathBuf};

/// `from_dir`（リポジトリからの相対ディレクトリ）から `target`（リポジトリからの相対パス）への相対パス。
fn relative(from_dir: &Path, target: &Path) -> String {
    let norm = |p: &Path| -> Vec<String> {
        let mut v: Vec<String> = vec![];
        for c in p.components() {
            match c {
                Component::Normal(s) => v.push(s.to_string_lossy().into_owned()),
                Component::ParentDir => {
                    v.pop();
                }
                _ => {}
            }
        }
        v
    };
    let (a, b) = (norm(from_dir), norm(target));
    let common = a.iter().zip(b.iter()).take_while(|(x, y)| x == y).count();
    let mut out = PathBuf::new();
    for _ in common..a.len() {
        out.push("..");
    }
    for s in &b[common..] {
        out.push(s);
    }
    out.to_string_lossy().into_owned()
}

/// 箇所のリンク（文書のディレクトリからの相対パス）。
fn site_link(doc_dir: &Path, s: &Site) -> String {
    let (path, anchor) = match s.path.split_once('#') {
        Some((p, a)) => (p, Some(a)),
        None => (s.path.as_str(), None),
    };
    let mut href = relative(doc_dir, Path::new(path));
    if let Some(a) = anchor {
        href.push('#');
        href.push_str(a);
    }
    format!("[{}]({href}){}", s.label, s.note)
}

fn cell(s: &str) -> String {
    s.replace('|', "\\|").replace('\n', " ")
}

fn sites(doc_dir: &Path, g: &Gap) -> String {
    cell(&g.sites.iter().map(|s| site_link(doc_dir, s)).collect::<Vec<_>>().join("・"))
}

/// Lean 名の最後の成分。
fn short(n: &str) -> String {
    format!("`{}`", n.rsplit('.').next().unwrap_or(n))
}

/// 証明の状態の欄: 名前と、裏付けの宣言（`covered` は覆う差異と定理、`pending` は理由）。
fn evidence(g: &Gap) -> String {
    let e = &g.evidence;
    if e.state.is_empty() {
        return "—".into();
    }
    let ws: Vec<String> = e.witnesses.iter().map(|w| short(w)).collect();
    let detail = match e.state.as_str() {
        "covered" => {
            let by = e.coverer.as_deref().map(short).unwrap_or_default();
            format!("{by} が覆う。{}", ws.join("・"))
        }
        "pending" => e.reason.clone(),
        _ => ws.join("・"),
    };
    if detail.is_empty() { e.label.clone() } else { cell(&format!("{}（{detail}）", e.label)) }
}

fn dash_or(v: &[String]) -> String {
    if v.is_empty() {
        "—".into()
    } else {
        v.join(", ")
    }
}

fn table(header: &[&str], rows: Vec<Vec<String>>) -> String {
    let mut s = format!("| {} |\n|{}\n", header.join(" | "), " --- |".repeat(header.len()));
    if rows.is_empty() {
        s.push_str("\n（現在なし）\n");
    }
    for r in rows {
        s.push_str(&format!("| {} |\n", r.join(" | ")));
    }
    s
}

/// 区画の中身。`side` は具体側の名前（`[Source]`・`[Target]`）。
pub fn region(name: &str, doc_dir: &Path, gaps: &[&Gap], side: &str) -> Result<String, String> {
    let note = "`trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。\n\n";
    let body = match name {
        "gaps-known" => table(
            &["ID", "種類", "箇所", "差異", "前提（前提型）／成分（観測型）", "R 課題", "W 課題", "証明の状態"],
            gaps.iter()
                .filter(|g| g.is_typed() || g.kind == "out_of_model")
                .map(|g| {
                    vec![
                        g.id.clone(),
                        g.kind_label.clone(),
                        sites(doc_dir, g),
                        cell(&g.doc),
                        cell(&g.premise),
                        dash_or(&g.r_tasks),
                        g.w_task.clone().unwrap_or_else(|| "—".into()),
                        evidence(g),
                    ]
                })
                .collect(),
        ),
        "gaps-impact" => table(
            &["ID", "影響", "理由", "backlog"],
            gaps.iter()
                .filter_map(|g| g.impact.as_ref().map(|i| (g, i)))
                .map(|(g, i)| vec![g.id.clone(), i.label.clone(), cell(&i.reason), g.backlog.join(", ")])
                .collect(),
        ),
        "gaps-outside-pre" => table(
            &["ID", "箇所", &format!("{side} の振る舞い"), "[Spec] の前提"],
            gaps.iter()
                .filter(|g| g.kind == "outside_pre")
                .map(|g| vec![g.id.clone(), sites(doc_dir, g), cell(&g.doc), cell(&g.premise)])
                .collect(),
        ),
        "gaps-undetermined" => table(
            &["ID", "対象", "状況", "確定させる作業", "証明の状態"],
            gaps.iter()
                .filter(|g| g.kind == "undetermined")
                .map(|g| vec![g.id.clone(), sites(doc_dir, g), cell(&g.doc), cell(&g.resolution), evidence(g)])
                .collect(),
        ),
        _ => return Err(format!("unknown generated region {name:?}")),
    };
    Ok(format!("{note}{body}"))
}

/// 文書の生成区画（`regions`）を書き換えた全文。`prefix` の ID（`D-`・`T-`）の登録だけを使う。
pub fn render_doc(
    doc: &str,
    doc_path: &str,
    gaps: &[Gap],
    prefix: &str,
    side: &str,
    regions: &[&str],
) -> Result<String, String> {
    let doc_dir = Path::new(doc_path).parent().unwrap_or(Path::new(""));
    let mut mine: Vec<&Gap> = gaps.iter().filter(|g| g.id.starts_with(prefix)).collect();
    mine.sort_by(|a, b| a.id.cmp(&b.id));
    let mut out = doc.to_string();
    for name in regions {
        let begin = format!("<!-- BEGIN GENERATED: {name} -->\n");
        let end = format!("<!-- END GENERATED: {name} -->");
        let b = out.find(&begin).ok_or(format!("{doc_path}: marker {begin:?} not found"))? + begin.len();
        let e = out[b..].find(&end).ok_or(format!("{doc_path}: marker {end:?} not found"))? + b;
        out.replace_range(b..e, &region(name, doc_dir, &mine, side)?);
    }
    Ok(out)
}

/// 生成する文書（パス, ID の接頭辞, 具体側の名前, 区画）。パスは設定の `docs.abstraction`・`docs.refinement`。
pub fn docs() -> Vec<(String, &'static str, &'static str, &'static [&'static str])> {
    let d = &crate::project::get().docs;
    vec![
        (d.abstraction.clone(), "D-", "[Source]", &["gaps-known", "gaps-impact", "gaps-outside-pre", "gaps-undetermined"]),
        (d.refinement.clone(), "T-", "[Target]", &["gaps-known", "gaps-impact"]),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lean::Impact;

    fn gap(id: &str, kind: &str, label: &str) -> Gap {
        Gap {
            name: format!("Abstraction.Gap.{}", id.replace('-', "")),
            id: id.into(),
            kind: kind.into(),
            kind_label: label.into(),
            sites: vec![
                Site { label: "価格".into(), path: "docs/spec/pricing.md#価格".into(), note: String::new() },
                Site { label: "ADR x".into(), path: "docs/decision/x.md".into(), note: "（規範節）".into() },
            ],
            doc: "差 | 異".into(),
            premise: "`dev_D001`: p".into(),
            ..Default::default()
        }
    }

    #[test]
    fn relative_paths() {
        assert_eq!(relative(Path::new("docs/spec"), Path::new("docs/spec/a.md")), "a.md");
        assert_eq!(relative(Path::new("docs/spec"), Path::new("docs/decision/b.md")), "../decision/b.md");
        assert_eq!(relative(Path::new("docs/spec"), Path::new(".agents/skills/x.md")), "../../.agents/skills/x.md");
    }

    #[test]
    fn renders_regions() {
        let mut d1 = gap("D-001", "pre", "前提型");
        d1.r_tasks = vec!["ABS-001".into(), "ABS-004".into()];
        d1.w_task = Some("ABS-101".into());
        d1.evidence = crate::lean::Evidence { state: "refuted".into(), label: "偽を証明済み".into(),
            witnesses: vec!["Abstraction.Fare.need_D001".into()], ..Default::default() };
        d1.impact = Some(Impact { kind: "abort".into(), label: "中断".into(), reason: "理由".into() });
        d1.backlog = vec!["b1".into()];
        let mut d2 = gap("D-013", "out_of_model", "モデル外");
        d2.evidence = crate::lean::Evidence { state: "unformalized".into(), label: "形式化していない".into(),
            witnesses: vec!["Abstraction.Gap.claim_D013".into()], ..Default::default() };
        let mut d3 = gap("D-003", "outside_pre", "PRE の外");
        d3.premise = "PRE MD-7".into();
        let t1 = gap("T-001", "observational", "観測型");
        let doc = "# x\n<!-- BEGIN GENERATED: gaps-known -->\nold\n<!-- END GENERATED: gaps-known -->\n\
                   <!-- BEGIN GENERATED: gaps-impact -->\n<!-- END GENERATED: gaps-impact -->\n\
                   <!-- BEGIN GENERATED: gaps-outside-pre -->\n<!-- END GENERATED: gaps-outside-pre -->\n";
        let gaps = vec![d2, d1, d3, t1];
        let out = render_doc(doc, "docs/spec/abstraction.md", &gaps, "D-", "[Source]",
            &["gaps-known", "gaps-impact", "gaps-outside-pre"]).unwrap();
        assert!(out.contains("| D-001 | 前提型 | [価格](pricing.md#価格)・[ADR x](../decision/x.md)（規範節） | 差 \\| 異 | `dev_D001`: p | ABS-001, ABS-004 | ABS-101 | 偽を証明済み（`need_D001`） |\n| D-013 | モデル外 |"), "{out}");
        assert!(out.contains("| D-013 | モデル外 | [価格](pricing.md#価格)・[ADR x](../decision/x.md)（規範節） | 差 \\| 異 | `dev_D001`: p | — | — | 形式化していない（`claim_D013`） |"));
        assert!(out.contains("| D-001 | 中断 | 理由 | b1 |"));
        assert!(out.contains("| ID | 箇所 | [Source] の振る舞い | [Spec] の前提 |"));
        assert!(out.contains("| D-003 | [価格](pricing.md#価格)・[ADR x](../decision/x.md)（規範節） | 差 \\| 異 | PRE MD-7 |"));
        assert!(!out.contains("T-001") && !out.contains("old"));
        // 区画が無い
        assert!(render_doc("# x\n", "docs/spec/a.md", &gaps, "D-", "[Source]", &["gaps-known"]).is_err());
        // 行が無い
        let out = render_doc("<!-- BEGIN GENERATED: gaps-known -->\n<!-- END GENERATED: gaps-known -->", "docs/spec/r.md",
            &[], "T-", "[Target]", &["gaps-known"]).unwrap();
        assert!(out.contains("（現在なし）"));
    }
}
