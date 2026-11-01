//! `review`: 原典とモデルの対照表（静的な HTML）を生成する（references/docs/spec/traceability.md#道具）。
//!
//! 原典のクラス（`java:`・`sql:` のロケータのクラス）ごとに 1 ページを作る。左に原典のメンバー（インベントリの行の範囲）、
//! 右に、それを `@[source]` で指すモデルの定義（`trace-dump` の `range`）を、原典のメンバーの順に並べる。
//! 印は、検査済みハッシュ（インベントリと一致し、合格の記録があるか）・ギャップの印（`@[gap]`）・覆われていない
//! メンバーである。mirror（`source.mirror`）があれば、クラスのモジュールにある、どのメンバーも指さない定義
//! （private のメソッドの写しなど）も並べる。索引（`index.html`）は、クラスごとの被覆の数を示す。
//!
//! 出力は決定論的（名前とロケータの順）で、JavaScript を使わない。生成物であり、リポジトリには置かない。

use crate::check::Passed;
use crate::inventory::Inventory;
use crate::item::Item;
use crate::lean::{split_hash, Def, Dump};
use crate::mirror::{class_of_module, locator_class, module_of_class};
use crate::project::Mirror;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write as _;
use std::path::Path;

/// HTML のエスケープ。
fn esc(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

/// ファイルの行（1 始まり、両端を含む）。
fn lines_of(text: &str, a: usize, b: usize) -> String {
    text.lines().skip(a.saturating_sub(1)).take(b + 1 - a.max(1)).collect::<Vec<_>>().join("\n")
}

/// ページのファイル名（クラスの完全修飾名から）。
fn page_name(cls: &str) -> String {
    format!("{}.html", cls.replace(['$', '/'], "_"))
}

const STYLE: &str = r#"
:root { --bg: #ffffff; --fg: #1f2328; --muted: #59636e; --line: #d1d9e0; --code: #f6f8fa;
  --ok: #1a7f37; --warn: #9a6700; --bad: #cf222e; --tag: #ddf4ff; --tagfg: #0969da; }
@media (prefers-color-scheme: dark) { :root { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #3d444d;
  --code: #151b23; --ok: #3fb950; --warn: #d29922; --bad: #f85149; --tag: #0c2d6b; --tagfg: #79c0ff; } }
body { background: var(--bg); color: var(--fg); font: 14px/1.5 system-ui, sans-serif; margin: 0 16px 32px; }
h1 { font-size: 20px; } h2 { font-size: 15px; margin: 24px 0 8px; font-family: ui-monospace, monospace; word-break: break-all; }
a { color: var(--tagfg); } .muted { color: var(--muted); }
table { border-collapse: collapse; width: 100%; } td, th { border-bottom: 1px solid var(--line); padding: 4px 8px; text-align: left; vertical-align: top; }
.pair { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 12px; }
@media (max-width: 900px) { .pair { grid-template-columns: 1fr; } }
pre { background: var(--code); border: 1px solid var(--line); border-radius: 6px; padding: 8px; overflow-x: auto; margin: 4px 0;
  font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace; white-space: pre; }
.badge { display: inline-block; border-radius: 10px; padding: 0 8px; font-size: 12px; margin-right: 4px; background: var(--tag); color: var(--tagfg); }
.ok { color: var(--ok); } .warn { color: var(--warn); } .bad { color: var(--bad); }
.head { font-size: 12px; margin: 4px 0 0; } .member { border-top: 1px solid var(--line); padding-top: 8px; margin-top: 16px; }
"#;

fn page(title: &str, body: &str) -> String {
    format!(
        "<!doctype html>\n<html lang=\"ja\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>{}</title>\n<style>{STYLE}</style>\n</head>\n<body>\n{body}\n</body>\n</html>\n",
        esc(title)
    )
}

/// 生成の結果（クラス数、メンバー数、覆われたメンバー数）。
pub struct Summary {
    pub classes: usize,
    pub members: usize,
    pub covered: usize,
}

/// 対照表を `out` に書く。
pub fn run(
    repo: &Path,
    dump: &Dump,
    inv: &Inventory,
    passed: &BTreeSet<Passed>,
    mirror: Option<&Mirror>,
    layer: &str,
    out: &Path,
) -> Result<Summary, String> {
    // クラス -> メンバー（インベントリの項目、行の順）
    let mut members: BTreeMap<String, Vec<&Item>> = BTreeMap::new();
    for it in &inv.items {
        if it.out_of_scope {
            continue;
        }
        if let Some((cls, _)) = locator_class(&it.locator) {
            members.entry(cls).or_default().push(it);
        }
    }
    for v in members.values_mut() {
        v.sort_by(|a, b| (a.file.as_str(), a.lines[0], a.locator.as_str()).cmp(&(b.file.as_str(), b.lines[0], b.locator.as_str())));
    }
    // ロケータ -> それを指す定義
    let mut by_loc: BTreeMap<&str, Vec<(&Def, &str)>> = BTreeMap::new();
    for d in dump.definitions.iter().filter(|d| d.layer == layer) {
        for v in d.attr("source") {
            let (loc, h) = split_hash(v);
            by_loc.entry(loc).or_default().push((d, h));
        }
    }
    // 定義を 1 つでも持つクラスだけ
    let classes: Vec<&String> = members.keys().filter(|c| members[*c].iter().any(|it| by_loc.contains_key(it.locator.as_str()))).collect();
    let mut file_cache: BTreeMap<String, String> = BTreeMap::new();
    let mut read = |p: &Path| -> String {
        let k = p.to_string_lossy().to_string();
        file_cache.entry(k).or_insert_with(|| std::fs::read_to_string(p).unwrap_or_default()).clone()
    };
    std::fs::create_dir_all(out).map_err(|e| format!("{}: {e}", out.display()))?;
    let mut index_rows = String::new();
    let (mut total, mut total_cov) = (0, 0);
    // mirror のモジュール -> そのモジュールの定義（どのメンバーも指さないものを後で並べる）
    let mut module_defs: BTreeMap<&str, Vec<&Def>> = BTreeMap::new();
    for d in dump.definitions.iter().filter(|d| d.layer == layer && d.range.is_some()) {
        module_defs.entry(d.module.as_str()).or_default().push(d);
    }
    for cls in &classes {
        let ms = &members[*cls];
        let module = mirror.and_then(|m| module_of_class(m, cls));
        let mut body = String::new();
        let covered = ms.iter().filter(|it| by_loc.contains_key(it.locator.as_str())).count();
        total += ms.len();
        total_cov += covered;
        let files: BTreeSet<&str> = ms.iter().map(|it| it.file.as_str()).collect();
        let _ = writeln!(body, "<p><a href=\"index.html\">← 索引</a></p>\n<h1>{}</h1>", esc(cls));
        let _ = writeln!(body, "<p class=\"muted\">原典: {}<br>モデルのモジュール: {}<br>覆われたメンバー: {covered} / {}</p>",
            files.iter().map(|f| format!("<code>{}</code>", esc(f))).collect::<Vec<_>>().join("・"),
            module.as_deref().map(|m| format!("<code>{}</code>", esc(m))).unwrap_or_else(|| "—".into()),
            ms.len());
        let mut shown: BTreeSet<&str> = BTreeSet::new();
        for it in ms {
            let src = read(&repo.join(&it.file));
            let java = lines_of(&src, it.lines[0], it.lines[1]);
            let defs = by_loc.get(it.locator.as_str()).cloned().unwrap_or_default();
            let _ = writeln!(body, "<div class=\"member\"><h2>{}</h2>", esc(&it.locator));
            let mut right = String::new();
            if defs.is_empty() {
                right.push_str("<p class=\"warn\">どの <code>@[source]</code> にも覆われていない</p>");
            }
            for (d, h) in &defs {
                shown.insert(d.name.as_str());
                let (status, cls_) = if it.hash != *h {
                    (format!("陳腐化（注釈 {h}・原典 {}）", it.hash), "bad")
                } else if passed.contains(&Passed { definition: d.name.clone(), locator: it.locator.clone(), hash: h.to_string(), merkle: d.merkle.clone() }) {
                    ("検査済み".to_string(), "ok")
                } else {
                    ("検査の記録なし（rehash）".to_string(), "warn")
                };
                let gaps: Vec<String> = d.attr("gap").iter().map(|g| format!("<span class=\"badge\">{}</span>", esc(g))).collect();
                let _ = write!(right, "<p class=\"head\"><code>{}</code> <span class=\"{cls_}\">{}</span> {}</p>", esc(&d.name), esc(&status), gaps.join(""));
                right.push_str(&lean_snippet(repo, d, &mut read));
            }
            let _ = writeln!(body, "<div class=\"pair\"><div><p class=\"head muted\">{}:{}-{}</p><pre>{}</pre></div><div>{right}</div></div></div>",
                esc(&it.file), it.lines[0], it.lines[1], esc(&java));
        }
        // モジュールにあって、どのメンバーも指さない定義（private のメソッドの写しなど）
        if let Some(m) = &module {
            let rest: Vec<&&Def> = module_defs.get(m.as_str()).map(|v| v.iter().filter(|d| !shown.contains(d.name.as_str()) && is_top(d)).collect()).unwrap_or_default();
            if !rest.is_empty() {
                let _ = writeln!(body, "<div class=\"member\"><h2>原典のメンバーを指さない定義</h2>");
                for d in rest {
                    let gaps: Vec<String> = d.attr("gap").iter().map(|g| format!("<span class=\"badge\">{}</span>", esc(g))).collect();
                    let _ = writeln!(body, "<p class=\"head\"><code>{}</code> {}</p>{}", esc(&d.name), gaps.join(""), lean_snippet(repo, d, &mut read));
                }
                body.push_str("</div>");
            }
        }
        std::fs::write(out.join(page_name(cls)), page(cls, &body)).map_err(|e| e.to_string())?;
        let mark = if covered == ms.len() { "ok" } else { "warn" };
        let _ = writeln!(index_rows, "<tr><td><a href=\"{}\">{}</a></td><td><code>{}</code></td><td class=\"{mark}\">{covered} / {}</td></tr>",
            page_name(cls), esc(cls), esc(module.as_deref().unwrap_or("—")), ms.len());
    }
    // mirror のモジュールで、原典のクラスが無いもの
    let mut orphans = String::new();
    if let Some(m) = mirror {
        for (module, _) in &module_defs {
            if let Some(c) = class_of_module(m, module) {
                if !members.contains_key(&c) {
                    let _ = writeln!(orphans, "<li><code>{}</code>（原典に {} が無い）</li>", esc(module), esc(&c));
                }
            }
        }
    }
    let mut index = format!(
        "<h1>原典とモデルの対照表</h1>\n<p class=\"muted\">クラス {} ・メンバー {total_cov} / {total} が <code>@[source]</code> に覆われている（{layer}）。\
         <code>trace review</code> が生成する。</p>\n<table><thead><tr><th>原典のクラス</th><th>モデルのモジュール</th><th>覆われたメンバー</th></tr></thead><tbody>\n{index_rows}</tbody></table>\n",
        classes.len()
    );
    if !orphans.is_empty() {
        let _ = write!(index, "<h2>原典のクラスに当たらない mirror のモジュール</h2><ul>{orphans}</ul>");
    }
    std::fs::write(out.join("index.html"), page("原典とモデルの対照表", &index)).map_err(|e| e.to_string())?;
    Ok(Summary { classes: classes.len(), members: total, covered: total_cov })
}

/// 構築子・欄・インスタンスなど自動生成の名前でない、モジュールの直下の宣言か。
fn is_top(d: &Def) -> bool {
    let Some(rest) = d.name.strip_prefix(&format!("{}.", d.module)) else { return d.name == d.module };
    !rest.contains('.') && !["mk", "ctorIdx", "noConfusionType", "noConfusion", "rec", "recOn", "casesOn"].contains(&rest)
        && !rest.starts_with("inst") && !rest.starts_with('_')
}

fn lean_snippet(repo: &Path, d: &Def, read: &mut impl FnMut(&Path) -> String) -> String {
    let Some([a, b]) = d.range else { return "<p class=\"muted\">（行の範囲が無い）</p>".into() };
    let Some(path) = crate::rehash::module_file(repo, &d.module) else { return "<p class=\"muted\">（ファイルが無い）</p>".into() };
    let text = read(&path);
    let rel = path.strip_prefix(repo).unwrap_or(&path).to_string_lossy().to_string();
    format!("<p class=\"head muted\">{}:{a}-{b}</p><pre>{}</pre>", esc(&rel), esc(&lines_of(&text, a, b)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn helpers() {
        assert_eq!(esc("<a & \"b\">"), "&lt;a &amp; &quot;b&quot;&gt;");
        assert_eq!(lines_of("1\n2\n3\n4", 2, 3), "2\n3");
        assert_eq!(page_name("p.a.B$C"), "p.a.B_C.html");
        let d = Def { name: "M.X.f".into(), module: "M.X".into(), ..Default::default() };
        assert!(is_top(&d));
        let d2 = Def { name: "M.X.mk".into(), module: "M.X".into(), ..Default::default() };
        assert!(!is_top(&d2));
    }
}
