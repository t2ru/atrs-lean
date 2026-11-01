//! `trace`: 両端の追跡の道具（spec-pivot の `references/docs/spec/traceability.md#道具`）。
//!
//! ```text
//! trace inventory source [--check]
//! trace inventory target [--check]
//! trace manifest --dump <trace-dump.json> --obligations <obligation-check.json> [--check]
//! trace check --dump <trace-dump.json> --obligations <obligation-check.json> [--verbose [--feature <機能>] [--rule <TR-…>]]
//! trace rehash --dump <trace-dump.json> [--dry-run]
//! trace diff --old <file|git:REV> [--side source|target] [--json]
//! trace impact --dump <trace-dump.json> --obligations <obligation-check.json> [--diff <file|git:REV>] [--json] [<起点>…]
//! ```
//!
//! リポジトリのルートは、作業ディレクトリから上にたどって `trace/project.json` があるところとする
//! （`--repo <dir>` で指定もできる）。アプリ固有の値は `trace/project.json` から読む（`project.rs`）。

mod check;
mod checks;
mod diff;
mod docs;
mod gaps;
mod impact;
mod inventory;
mod item;
mod java;
mod lean;
mod manifest;
mod mapper;
mod mirror;
mod normalize;
mod project;
mod props;
mod rehash;
mod review;
mod rust;
mod sqlfile;
mod tmpl;
mod webxml;

use std::path::{Path, PathBuf};
use std::process::ExitCode;

fn find_repo(args: &[String]) -> Result<PathBuf, String> {
    if let Some(i) = args.iter().position(|a| a == "--repo") {
        return args.get(i + 1).map(PathBuf::from).ok_or("--repo needs a value".into());
    }
    let mut d = std::env::current_dir().map_err(|e| e.to_string())?;
    loop {
        if d.join(project::FILE).is_file() {
            return Ok(d);
        }
        if !d.pop() {
            return Err(format!("repository root ({}) not found", project::FILE));
        }
    }
}

/// 生成した内容をファイルに書く。`check` なら、既存の内容と比べるだけにする。
fn write_or_check(path: &Path, content: &str, check: bool) -> Result<(), String> {
    if check {
        let old = std::fs::read_to_string(path).unwrap_or_default();
        if old != content {
            return Err(format!("{} is out of date (regenerate with trace)", path.display()));
        }
        Ok(())
    } else {
        std::fs::write(path, content).map_err(|e| e.to_string())
    }
}

fn run(args: &[String]) -> Result<ExitCode, String> {
    let repo = find_repo(args)?;
    let cfg = project::load(&repo)?;
    let check = args.iter().any(|a| a == "--check");
    match args.first().map(String::as_str) {
        Some("inventory") => {
            let (inv, path) = match args.get(1).map(String::as_str) {
                Some("source") => (inventory::source(&repo)?, "trace/source-inventory.json"),
                Some("target") => (inventory::target(&repo)?, "trace/target-inventory.json"),
                _ => return Err("usage: trace inventory source|target [--check]".into()),
            };
            write_or_check(&repo.join(path), &inventory::to_json(&inv), check)?;
            let total: usize = inv.counts.values().sum();
            let detail: Vec<String> = inv.counts.iter().map(|(k, v)| format!("{k} {v}")).collect();
            println!("{path}: {total} items ({}){}", detail.join(", "), if check { ", up to date" } else { "" });
            Ok(ExitCode::SUCCESS)
        }
        Some("review") => {
            // 原典とモデルの対照表（静的な HTML。生成物）
            let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
            let source = inventory::load(&repo.join("trace/source-inventory.json"))?;
            let passed = manifest::passed(&manifest::load(&repo.join("trace/manifest.json"))?);
            let out = match args.iter().position(|a| a == "--out").and_then(|i| args.get(i + 1)) {
                Some(o) => PathBuf::from(o),
                None => repo.join("build/review"),
            };
            let s = review::run(&repo, &dump, &source, &passed, cfg.source.mirror.as_ref(), "SourceModel", &out)?;
            println!("trace review: {} classes, {} / {} members covered -> {}", s.classes, s.covered, s.members, out.display());
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
            let dpath = repo.join(&cfg.docs.traceability);
            let doc = std::fs::read_to_string(&dpath).map_err(|e| e.to_string())?;
            write_or_check(&dpath, &manifest::render_doc(&doc, &m, &source, &target)?, check)?;
            for (path, prefix, side, regions) in gaps::docs() {
                let gpath = repo.join(&path);
                let doc = std::fs::read_to_string(&gpath).map_err(|e| e.to_string())?;
                write_or_check(&gpath, &gaps::render_doc(&doc, &path, &dump.gaps, prefix, side, regions)?, check)?;
            }
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
        Some("rehash") => rehash_cmd(&repo, args),
        Some("diff") => {
            let d = diff_of(&repo, args, &arg_path(args, "--old")?.to_string_lossy())?;
            if args.iter().any(|a| a == "--json") {
                println!("{}", serde_json::to_string_pretty(&d).unwrap());
            } else {
                print!("{}", diff::render(&d));
            }
            Ok(ExitCode::SUCCESS)
        }
        Some("impact") => impact_cmd(&repo, args),
        _ => Err("usage: trace inventory|manifest|check|rehash|diff|impact|review …".into()),
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

/// 仕様文書（設定の `docs.spec`）の「出典:」のロケータ。
fn citations(repo: &Path) -> Vec<(String, String)> {
    let mut mds = vec![];
    files_with_ext(&repo.join(&project::get().docs.spec), "md", &mut mds);
    let mut out = vec![];
    for p in mds {
        let rel = p.strip_prefix(repo).unwrap_or(&p).to_string_lossy().to_string();
        for (line, loc) in docs::citations(&std::fs::read_to_string(&p).unwrap_or_default()) {
            out.push((format!("{rel}:{line}"), loc));
        }
    }
    out
}

/// スキルの `scripts/ci/check_obligations.py` を実行し、その誤り・警告を TR-G・TR-N として取り込む。
fn obligation_script(repo: &Path, obligations: &Path) -> Result<Vec<check::Finding>, String> {
    let script = Path::new(&project::get().skill).join("scripts/ci/check_obligations.py");
    let out = std::process::Command::new("python3")
        .arg("-I")
        .arg(&script)
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

/// 引数の値（`--key <value>`）を除いた、位置引数（サブコマンドの後）。
fn positional(args: &[String]) -> Vec<String> {
    const WITH_VALUE: &[&str] = &["--dump", "--obligations", "--diff", "--old", "--side", "--repo"];
    let mut out = vec![];
    let mut skip = true; // サブコマンド名
    for a in args {
        if skip {
            skip = false;
            continue;
        }
        if WITH_VALUE.contains(&a.as_str()) {
            skip = true;
        } else if !a.starts_with("--") {
            out.push(a.clone());
        }
    }
    out
}

/// `--side` の値（既定は source）と、そのインベントリ・宣言のパス。
fn side_files(args: &[String]) -> Result<(&'static str, &'static str), String> {
    match args.iter().position(|a| a == "--side").and_then(|i| args.get(i + 1)).map(String::as_str) {
        None | Some("source") => Ok(("trace/source-inventory.json", "trace/upstream.json")),
        Some("target") => Ok(("trace/target-inventory.json", "trace/target.json")),
        Some(x) => Err(format!("--side source|target (got {x})")),
    }
}

/// `git show <rev>:<path>`（無ければ None）。
fn git_show(repo: &Path, rev: &str, path: &str) -> Result<Option<String>, String> {
    let out = std::process::Command::new("git")
        .args(["show", &format!("{rev}:{path}")])
        .current_dir(repo)
        .output()
        .map_err(|e| format!("git: {e}"))?;
    Ok(out.status.success().then(|| String::from_utf8_lossy(&out.stdout).to_string()))
}

/// 新旧のインベントリの差分。`old` はファイルか `git:<rev>`（宣言の新旧も比べる）。
fn diff_of(repo: &Path, args: &[String], old: &str) -> Result<diff::Diff, String> {
    let (inv_path, decl_path) = side_files(args)?;
    let new = inventory::load(&repo.join(inv_path))?;
    let renames = rehash::load_renames(repo)?;
    let parse = |s: &str, what: &str| -> Result<inventory::Inventory, String> {
        serde_json::from_str(s).map_err(|e| format!("{what}: {e}"))
    };
    if let Some(rev) = old.strip_prefix("git:") {
        let o = git_show(repo, rev, inv_path)?.map(|s| parse(&s, &format!("{rev}:{inv_path}"))).transpose()?.unwrap_or_default();
        let od: serde_json::Value = git_show(repo, rev, decl_path)?.and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default();
        let nd = read_json(&repo.join(decl_path));
        Ok(diff::diff(&o, &new, &renames, Some((&od, &nd))))
    } else {
        let o = parse(&std::fs::read_to_string(old).map_err(|e| format!("{old}: {e}"))?, old)?;
        Ok(diff::diff(&o, &new, &renames, None))
    }
}

fn impact_cmd(repo: &Path, args: &[String]) -> Result<ExitCode, String> {
    let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
    let obligations: lean::Obligations = lean::load(&arg_path(args, "--obligations")?)?;
    let mut seeds = positional(args);
    if let Ok(old) = arg_path(args, "--diff") {
        seeds.extend(diff_of(repo, args, &old.to_string_lossy())?.changed_locators());
    }
    if seeds.is_empty() {
        return Err("impact: give locators or Lean names, or --diff <file|git:REV>".into());
    }
    let i = impact::impact(&dump, &obligations, &seeds);
    if args.iter().any(|a| a == "--json") {
        println!("{}", serde_json::to_string_pretty(&i).unwrap());
    } else {
        print!("{}", impact::render(&i));
    }
    Ok(ExitCode::SUCCESS)
}

fn rehash_cmd(repo: &Path, args: &[String]) -> Result<ExitCode, String> {
    let dry = args.iter().any(|a| a == "--dry-run");
    let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
    let source = inventory::load(&repo.join("trace/source-inventory.json"))?;
    let target = inventory::load(&repo.join("trace/target-inventory.json"))?;
    let upstream = read_json(&repo.join("trace/upstream.json"));
    let target_decl = read_json(&repo.join("trace/target.json"));
    let mpath = repo.join("trace/manifest.json");
    let mut m = manifest::load(&mpath)?;
    let passed = manifest::passed(&m);
    let renames = rehash::load_renames(repo)?;
    let reg = checks::load(repo)?;
    let cover = checks::coverage(&reg, repo, &dump)?;
    let cx = rehash::Context {
        dump: &dump,
        source: &source,
        target: &target,
        upstream: &upstream,
        target_decl: &target_decl,
        passed: &passed,
        renames: &renames,
    };
    if dry {
        let p = rehash::plan(&cx);
        for c in &p.candidates {
            let ids: Vec<String> = cover.get(&c.definition).map(|s| s.iter().cloned().collect()).unwrap_or_default();
            println!("{}: {} -> {} ({}); checks: {}", c.definition, c.old, c.new_value(), c.reason,
                if ids.is_empty() { "(none: not updatable)".into() } else { ids.join(", ") });
        }
        for u in &p.unresolved {
            println!("unresolved: {u}");
        }
        println!("trace rehash --dry-run: {} candidate(s), {} unresolved", p.candidates.len(), p.unresolved.len());
        return Ok(ExitCode::SUCCESS);
    }
    let out = rehash::execute(repo, &cx, &reg, &cover, &mut m, &checks::run)?;
    // 書き換えた注釈を反映した manifest と生成区画
    let mut dump2 = dump.clone();
    for (name, new) in &out.updated {
        let loc = lean::split_hash(new).0;
        let Some(d) = dump2.definitions.iter_mut().find(|d| d.name == *name) else { continue };
        for (_, vs) in d.attributes.iter_mut().filter(|(a, _)| *a == "source" || *a == "target") {
            for v in vs.iter_mut() {
                let old_loc = lean::split_hash(v).0;
                if old_loc == loc || renames.iter().any(|(o, n)| o == old_loc && n == loc) {
                    *v = new.clone();
                }
            }
        }
    }
    let m2 = manifest::build(&dump2, &target, &m);
    std::fs::write(&mpath, manifest::to_json(&m2)).map_err(|e| e.to_string())?;
    let dpath = repo.join(&project::get().docs.traceability);
    let doc = std::fs::read_to_string(&dpath).map_err(|e| e.to_string())?;
    std::fs::write(&dpath, manifest::render_doc(&doc, &m2, &source, &target)?).map_err(|e| e.to_string())?;
    for (id, ok) in &out.results {
        println!("check {id}: {}", if *ok { "passed" } else { "FAILED" });
    }
    for (d, v) in &out.updated {
        println!("updated: {d}: {v}");
    }
    for s in &out.skipped {
        println!("not updated: {s}");
    }
    println!(
        "trace rehash: {} updated, {} not updated{}",
        out.updated.len(),
        out.skipped.len(),
        if out.updated.is_empty() { "" } else { " (rebuild Lean and rerun trace-dump before trace check)" }
    );
    Ok(if out.skipped.is_empty() { ExitCode::SUCCESS } else { ExitCode::from(1) })
}

fn check_cmd(repo: &Path, args: &[String]) -> Result<ExitCode, String> {
    let verbose = args.iter().any(|a| a == "--verbose");
    let dump: lean::Dump = lean::load(&arg_path(args, "--dump")?)?;
    let obl_path = arg_path(args, "--obligations")?;
    let obligations: lean::Obligations = lean::load(&obl_path)?;
    let source = inventory::load(&repo.join("trace/source-inventory.json"))?;
    let target = inventory::load(&repo.join("trace/target-inventory.json"))?;
    let features = docs::Features::load(repo)?;
    let cfg = project::get();
    let abs = std::fs::read_to_string(repo.join(&cfg.docs.abstraction)).map_err(|e| e.to_string())?;
    let rfn = std::fs::read_to_string(repo.join(&cfg.docs.refinement)).map_err(|e| e.to_string())?;
    let mut entry_tasks = docs::entry_tasks(&abs);
    entry_tasks.extend(docs::entry_tasks(&rfn));
    let mut r_tasks = docs::r_tasks(&abs);
    r_tasks.extend(docs::r_tasks(&rfn));
    let mut rust_files = vec![];
    let mut rs = vec![];
    files_with_ext(&repo.join(&cfg.target.root), "rs", &mut rs);
    for p in rs {
        let rel = p.strip_prefix(repo).unwrap_or(&p).to_string_lossy().to_string();
        rust_files.push((rel, std::fs::read_to_string(&p).unwrap_or_default()));
    }
    let mut model_defs = vec![];
    let mut vecs = vec![];
    files_with_ext(&repo.join(&cfg.conformance), "json", &mut vecs);
    for p in vecs {
        let rel = p.strip_prefix(repo).unwrap_or(&p).to_string_lossy().to_string();
        for n in checks::model_defs_of(&read_json(&p)) {
            model_defs.push((rel.clone(), n));
        }
    }
    let input = check::Input {
        dump: &dump,
        obligations: &obligations,
        source: &source,
        target: &target,
        features: &features,
        entry_tasks,
        r_tasks,
        upstream: read_json(&repo.join("trace/upstream.json")),
        target_decl: read_json(&repo.join("trace/target.json")),
        passed: manifest::passed(&manifest::load(&repo.join("trace/manifest.json"))?),
        rust_files,
        model_defs,
        renames: rehash::load_renames(repo)?,
        citations: citations(repo),
    };
    let mut findings = check::run(&input);
    // TR-M: モデルのモジュールが原典のソースツリーの形に並んでいること（source.mirror があるときだけ）
    if let Some(m) = &cfg.source.mirror {
        let classes = mirror::load_classes(repo, &source);
        findings.extend(mirror::check(&dump, m, &classes, &features));
    }
    if !args.iter().any(|a| a == "--no-obligation-script") {
        findings.extend(obligation_script(repo, &obl_path)?);
    }
    // --verbose の絞り込み（機能・規則。機能の取り込みで、未対応の一覧を機能ごとに見る）
    let opt = |k: &str| args.iter().position(|a| a == k).and_then(|i| args.get(i + 1)).cloned();
    let (only_feature, only_rule) = (opt("--feature"), opt("--rule"));
    let shown = |f: &check::Finding| {
        only_feature.as_ref().is_none_or(|x| &f.feature == x) && only_rule.as_ref().is_none_or(|x| f.rule == x)
    };
    let errors: Vec<&check::Finding> = findings.iter().filter(|f| f.error).collect();
    for f in &errors {
        let feat = if f.feature.is_empty() { String::new() } else { format!("[{}] ", f.feature) };
        eprintln!("error: {}: {feat}{}", f.rule, f.msg);
    }
    let mut groups: std::collections::BTreeMap<(&str, &str), usize> = std::collections::BTreeMap::new();
    for f in findings.iter().filter(|f| !f.error) {
        *groups.entry((f.rule, f.feature.as_str())).or_default() += 1;
        if verbose && shown(f) {
            eprintln!("warning: {}: [{}] {}", f.rule, f.feature, f.msg);
        }
    }
    for ((rule, feat), n) in &groups {
        // TR-M2・TR-M4 は常に警告（人が確かめる。src/mirror.rs）
        let why = if ["TR-M2", "TR-M4"].contains(rule) { "advisory: review the names" } else { "staged: the feature's backlog is not done" };
        println!("warning: {rule}: [{feat}] {n} finding(s) ({why})");
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
