//! `tools/trace`: ATRS の両端の追跡の道具（backlog 0024、ADR 0036・0040）。
//!
//! ```text
//! trace inventory source [--check]
//! trace inventory target [--check]
//! trace manifest --dump <trace-dump.json> --obligations <obligation-check.json> [--check]
//! trace check --dump <trace-dump.json> --obligations <obligation-check.json>
//! ```
//!
//! リポジトリのルートは、作業ディレクトリから上にたどって `trace/upstream.json` があるところとする
//! （`--repo <dir>` で指定もできる）。

mod check;
mod docs;
mod inventory;
mod item;
mod java;
mod lean;
mod manifest;
mod mapper;
mod normalize;
mod props;
mod rust;
mod sqlfile;
mod tmpl;
mod webxml;

use std::path::{Path, PathBuf};
use std::process::ExitCode;

/// ATRS の移植先の crate 名（rules/atrs-porting.md）。
const CRATE: &str = "atrs";

fn find_repo(args: &[String]) -> Result<PathBuf, String> {
    if let Some(i) = args.iter().position(|a| a == "--repo") {
        return args.get(i + 1).map(PathBuf::from).ok_or("--repo needs a value".into());
    }
    let mut d = std::env::current_dir().map_err(|e| e.to_string())?;
    loop {
        if d.join("trace/upstream.json").is_file() {
            return Ok(d);
        }
        if !d.pop() {
            return Err("repository root (trace/upstream.json) not found".into());
        }
    }
}

/// 生成した内容をファイルに書く。`check` なら、既存の内容と比べるだけにする。
fn write_or_check(path: &Path, content: &str, check: bool) -> Result<(), String> {
    if check {
        let old = std::fs::read_to_string(path).unwrap_or_default();
        if old != content {
            return Err(format!("{} is out of date (regenerate with tools/trace)", path.display()));
        }
        Ok(())
    } else {
        std::fs::write(path, content).map_err(|e| e.to_string())
    }
}

fn run(args: &[String]) -> Result<ExitCode, String> {
    let repo = find_repo(args)?;
    let check = args.iter().any(|a| a == "--check");
    match args.first().map(String::as_str) {
        Some("inventory") => {
            let (inv, path) = match args.get(1).map(String::as_str) {
                Some("source") => (inventory::source(&repo)?, "trace/source-inventory.json"),
                Some("target") => (inventory::target(&repo, CRATE)?, "trace/target-inventory.json"),
                _ => return Err("usage: trace inventory source|target [--check]".into()),
            };
            write_or_check(&repo.join(path), &inventory::to_json(&inv), check)?;
            let total: usize = inv.counts.values().sum();
            let detail: Vec<String> = inv.counts.iter().map(|(k, v)| format!("{k} {v}")).collect();
            println!("{path}: {total} items ({}){}", detail.join(", "), if check { ", up to date" } else { "" });
            Ok(ExitCode::SUCCESS)
        }
        Some("manifest") => {
            let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
            let target = inventory::load(&repo.join("trace/target-inventory.json"))?;
            let source = inventory::load(&repo.join("trace/source-inventory.json"))?;
            let mpath = repo.join("trace/manifest.json");
            let old = manifest::load(&mpath)?;
            let m = manifest::build(&dump, &target, &old);
            write_or_check(&mpath, &manifest::to_json(&m), check)?;
            let dpath = repo.join("docs/spec/traceability.md");
            let doc = std::fs::read_to_string(&dpath).map_err(|e| e.to_string())?;
            write_or_check(&dpath, &manifest::render_doc(&doc, &m, &source, &target)?, check)?;
            println!(
                "trace/manifest.json: {} nodes, {} links, {} check records{}",
                m.nodes.len(),
                m.links.len(),
                m.checks.len(),
                if check { ", up to date" } else { "" }
            );
            Ok(ExitCode::SUCCESS)
        }
        Some("check") => check_cmd(&repo, args),
        _ => Err("usage: trace inventory|manifest|check …".into()),
    }
}

fn arg_path(args: &[String], key: &str) -> Result<PathBuf, String> {
    args.iter()
        .position(|a| a == key)
        .and_then(|i| args.get(i + 1))
        .map(PathBuf::from)
        .ok_or(format!("{key} <file> is required"))
}

fn read_json(path: &Path) -> serde_json::Value {
    std::fs::read_to_string(path).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or(serde_json::Value::Null)
}

fn files_with_ext(dir: &Path, ext: &str, out: &mut Vec<PathBuf>) {
    let Ok(rd) = std::fs::read_dir(dir) else { return };
    let mut v: Vec<PathBuf> = rd.flatten().map(|e| e.path()).collect();
    v.sort();
    for p in v {
        if p.is_dir() {
            if p.file_name().map(|n| n != "target").unwrap_or(true) {
                files_with_ext(&p, ext, out);
            }
        } else if p.extension().map(|e| e == ext).unwrap_or(false) {
            out.push(p);
        }
    }
}

/// `check_obligations.py` を実行し、その誤り・警告を TR-G・TR-N として取り込む。
fn obligation_script(repo: &Path, obligations: &Path) -> Result<Vec<check::Finding>, String> {
    let out = std::process::Command::new("python3")
        .args(["-I", "tools/ci/check_obligations.py"])
        .arg(obligations)
        .current_dir(repo)
        .output()
        .map_err(|e| format!("check_obligations.py: {e}"))?;
    let mut list = vec![];
    let text = String::from_utf8_lossy(&out.stderr).to_string() + &String::from_utf8_lossy(&out.stdout);
    for l in text.lines() {
        let Some(rest) = l.strip_prefix("check_obligations: ") else { continue };
        let (error, rest) = if let Some(r) = rest.strip_prefix("error: ") {
            (true, r)
        } else if let Some(r) = rest.strip_prefix("warning: ") {
            (false, r)
        } else {
            continue;
        };
        let rule = if rest.starts_with("OB-N") { "TR-N" } else { "TR-G" };
        list.push(check::Finding { error, rule, feature: "(registry)".into(), msg: rest.to_string() });
    }
    if !out.status.success() && !list.iter().any(|f| f.error) {
        return Err(format!("check_obligations.py failed: {text}"));
    }
    Ok(list)
}

fn check_cmd(repo: &Path, args: &[String]) -> Result<ExitCode, String> {
    let verbose = args.iter().any(|a| a == "--verbose");
    let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
    let obl_path = arg_path(args, "--obligations")?;
    let obligations: lean::Obligations = lean::load(&obl_path)?;
    let source = inventory::load(&repo.join("trace/source-inventory.json"))?;
    let target = inventory::load(&repo.join("trace/target-inventory.json"))?;
    let features = docs::Features::load(repo)?;
    let abs = std::fs::read_to_string(repo.join("docs/spec/abstraction.md")).map_err(|e| e.to_string())?;
    let rfn = std::fs::read_to_string(repo.join("docs/spec/refinement.md")).map_err(|e| e.to_string())?;
    let mut deviations = docs::deviations(&abs, "既知差異");
    deviations.extend(docs::deviations(&rfn, "既知差異"));
    let mut entry_tasks = docs::entry_tasks(&abs);
    entry_tasks.extend(docs::entry_tasks(&rfn));
    let mut r_tasks = docs::r_tasks(&abs);
    r_tasks.extend(docs::r_tasks(&rfn));
    let mut rust_files = vec![];
    let mut rs = vec![];
    files_with_ext(&repo.join("rust"), "rs", &mut rs);
    for p in rs {
        let rel = p.strip_prefix(repo).unwrap_or(&p).to_string_lossy().to_string();
        rust_files.push((rel, std::fs::read_to_string(&p).unwrap_or_default()));
    }
    let mut model_defs = vec![];
    let mut vecs = vec![];
    files_with_ext(&repo.join("conformance"), "json", &mut vecs);
    for p in vecs {
        if let Some(n) = read_json(&p)["modelDef"].as_str() {
            let rel = p.strip_prefix(repo).unwrap_or(&p).to_string_lossy().to_string();
            model_defs.push((rel, n.to_string()));
        }
    }
    let input = check::Input {
        dump: &dump,
        obligations: &obligations,
        source: &source,
        target: &target,
        features: &features,
        deviations,
        entry_tasks,
        r_tasks,
        upstream: read_json(&repo.join("trace/upstream.json")),
        target_decl: read_json(&repo.join("trace/target.json")),
        passed: manifest::passed(&manifest::load(&repo.join("trace/manifest.json"))?),
        rust_files,
        model_defs,
    };
    let mut findings = check::run(&input);
    if !args.iter().any(|a| a == "--no-obligation-script") {
        findings.extend(obligation_script(repo, &obl_path)?);
    }
    let errors: Vec<&check::Finding> = findings.iter().filter(|f| f.error).collect();
    for f in &errors {
        let feat = if f.feature.is_empty() { String::new() } else { format!("[{}] ", f.feature) };
        eprintln!("error: {}: {feat}{}", f.rule, f.msg);
    }
    let mut groups: std::collections::BTreeMap<(&str, &str), usize> = std::collections::BTreeMap::new();
    for f in findings.iter().filter(|f| !f.error) {
        *groups.entry((f.rule, f.feature.as_str())).or_default() += 1;
        if verbose {
            eprintln!("warning: {}: [{}] {}", f.rule, f.feature, f.msg);
        }
    }
    for ((rule, feat), n) in &groups {
        println!("warning: {rule}: [{feat}] {n} finding(s) (staged: the feature's backlog is not done)");
    }
    let warnings: usize = groups.values().sum();
    if errors.is_empty() {
        println!("trace check: OK ({warnings} warning(s))");
        Ok(ExitCode::SUCCESS)
    } else {
        eprintln!("trace check: FAIL ({} error(s), {warnings} warning(s))", errors.len());
        Ok(ExitCode::from(1))
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match run(&args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("trace: {e}");
            ExitCode::from(2)
        }
    }
}
