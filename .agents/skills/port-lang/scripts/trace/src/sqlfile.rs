//! SQL ファイルのインベントリ（`ddl:`・`seed:`）。lang/sql/locators.md と references/docs/spec/traceability.md#道具 による。
//!
//! - `CREATE … <名前>` と `ALTER TABLE … ADD CONSTRAINT <名前>` は `ddl:<ファイル名>#<名前>`。
//! - `INSERT INTO <テーブル>` を含む文（関数や `DO` ブロックの中を含む）は、テーブルごとに
//!   `seed:<ファイル名>#<テーブル>` にまとめる（references/docs/spec/traceability.md#道具 でテーブル単位とした）。
//! - 文の区切りは `;`。文字列・`$$` の引用・コメントの中の `;` は区切りにしない。

use crate::item::Item;
use crate::normalize::sql_tokens;
use std::collections::BTreeMap;

/// (文の原文, 開始行, 終了行)
pub fn split(src: &str) -> Vec<(String, usize, usize)> {
    let cs: Vec<char> = src.chars().collect();
    let n = cs.len();
    let (mut out, mut start, mut line, mut start_line) = (vec![], 0usize, 1usize, 1usize);
    let mut i = 0;
    let mut dollar: Option<String> = None;
    while i < n {
        let c = cs[i];
        if c == '\n' {
            line += 1;
        }
        if let Some(tag) = &dollar {
            let t: Vec<char> = tag.chars().collect();
            if i + t.len() <= n && cs[i..i + t.len()] == t[..] {
                i += t.len();
                dollar = None;
                continue;
            }
            i += 1;
            continue;
        }
        if c == '-' && i + 1 < n && cs[i + 1] == '-' {
            while i < n && cs[i] != '\n' {
                i += 1;
            }
            continue;
        }
        if c == '/' && i + 1 < n && cs[i + 1] == '*' {
            i += 2;
            while i + 1 < n && !(cs[i] == '*' && cs[i + 1] == '/') {
                if cs[i] == '\n' {
                    line += 1;
                }
                i += 1;
            }
            i += 2;
            continue;
        }
        if c == '\'' {
            i += 1;
            while i < n && !(cs[i] == '\'' && !(i + 1 < n && cs[i + 1] == '\'')) {
                if cs[i] == '\'' {
                    i += 1;
                }
                if cs[i] == '\n' {
                    line += 1;
                }
                i += 1;
            }
            i += 1;
            continue;
        }
        if c == '$' {
            let mut j = i + 1;
            while j < n && (cs[j].is_alphanumeric() || cs[j] == '_') {
                j += 1;
            }
            if j < n && cs[j] == '$' {
                dollar = Some(cs[i..=j].iter().collect());
                i = j + 1;
                continue;
            }
        }
        if c == ';' {
            let stmt: String = cs[start..i].iter().collect();
            if !stmt.trim().is_empty() {
                out.push((stmt, start_line, line));
            }
            start = i + 1;
            start_line = line;
        }
        if start == i && c.is_whitespace() {
            start = i + 1;
            if c == '\n' {
                start_line = line;
            }
        }
        i += 1;
    }
    let rest: String = cs[start.min(n)..].iter().collect();
    if !rest.trim().is_empty() {
        out.push((rest, start_line, line));
    }
    out
}

pub fn scan(file: &str, src: &str) -> Vec<Item> {
    let name = file.rsplit('/').next().unwrap_or(file);
    let mut out = vec![];
    let mut seeds: BTreeMap<String, (Vec<String>, usize, usize)> = BTreeMap::new();
    for (stmt, s, e) in split(src) {
        let mut toks = vec![];
        sql_tokens(&stmt, &mut toks);
        let up: Vec<String> = toks.iter().map(|t| t.to_uppercase()).collect();
        let norm = toks.join(" ");
        // DDL
        if up.first().map(|t| t == "CREATE").unwrap_or(false) {
            // CREATE [OR REPLACE] [UNIQUE] TABLE|SEQUENCE|INDEX|FUNCTION|VIEW <名前>
            let mut k = 1;
            while k < up.len() && ["OR", "REPLACE", "UNIQUE", "TEMP", "TEMPORARY"].contains(&up[k].as_str()) {
                k += 1;
            }
            if k + 1 < up.len() && ["TABLE", "SEQUENCE", "INDEX", "VIEW"].contains(&up[k].as_str()) {
                out.push(Item::new("ddl", format!("{name}#{}", up[k + 1]), file, [s, e], &norm));
                continue;
            }
        }
        if up.len() > 5 && up[0] == "ALTER" && up[1] == "TABLE" {
            if let Some(p) = up.iter().position(|t| t == "CONSTRAINT") {
                if p + 1 < up.len() {
                    out.push(Item::new("ddl", format!("{name}#{}", up[p + 1]), file, [s, e], &norm));
                    continue;
                }
            }
        }
        // 初期データ: 文に現れる INSERT INTO <テーブル> ごとに集める
        let mut tables: Vec<String> = vec![];
        for w in up.windows(3) {
            if w[0] == "INSERT" && w[1] == "INTO" && !tables.contains(&w[2]) {
                tables.push(w[2].clone());
            }
        }
        for t in tables {
            let e2 = seeds.entry(t).or_insert((vec![], s, e));
            e2.0.push(norm.clone());
            e2.1 = e2.1.min(s);
            e2.2 = e2.2.max(e);
        }
    }
    for (t, (stmts, s, e)) in seeds {
        out.push(Item::new("seed", format!("{name}#{t}"), file, [s, e], &stmts.join(" ; ")));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_with_dollar_quotes_and_comments() {
        let src = "CREATE TABLE A (x int); -- ;\nALTER TABLE A ADD CONSTRAINT PK_A PRIMARY KEY (x);\n\
                   CREATE OR REPLACE FUNCTION f() RETURNS VOID AS $$ BEGIN INSERT INTO B VALUES (1); END; $$ LANGUAGE plpgsql;\n\
                   insert into A values ('a;b');\nINSERT INTO A VALUES ('c');";
        let items = scan("x/001.sql", src);
        let locs: Vec<&str> = items.iter().map(|i| i.locator.as_str()).collect();
        assert_eq!(locs, vec!["ddl:001.sql#A", "ddl:001.sql#PK_A", "seed:001.sql#A", "seed:001.sql#B"]);
    }
}
