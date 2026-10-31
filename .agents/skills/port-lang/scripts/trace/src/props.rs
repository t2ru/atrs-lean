//! `.properties` のインベントリ（`prop:`・`msg:`）。ハッシュは値の前後の空白を除いた値（references/docs/traceability.md#道具）。

use crate::item::Item;

/// `.properties` を読み、(キー, 値, 開始行, 終了行) を返す。継続行・`\uXXXX`・コメントに対応する。
pub fn parse(src: &str) -> Vec<(String, String, usize, usize)> {
    let mut out = vec![];
    let lines: Vec<&str> = src.lines().collect();
    let mut i = 0;
    while i < lines.len() {
        let start = i + 1;
        let mut logical = String::new();
        loop {
            let l = if logical.is_empty() { lines[i].trim_start() } else { lines[i].trim_start() };
            let backslashes = l.chars().rev().take_while(|c| *c == '\\').count();
            if backslashes % 2 == 1 {
                logical.push_str(&l[..l.len() - 1]);
                i += 1;
                if i >= lines.len() {
                    break;
                }
            } else {
                logical.push_str(l);
                i += 1;
                break;
            }
        }
        let t = logical.trim_start();
        if t.is_empty() || t.starts_with('#') || t.starts_with('!') {
            continue;
        }
        // キーは最初のエスケープされていない `=`・`:`・空白まで
        let cs: Vec<char> = t.chars().collect();
        let mut k = 0;
        while k < cs.len() {
            if cs[k] == '\\' {
                k += 2;
                continue;
            }
            if cs[k] == '=' || cs[k] == ':' || cs[k].is_whitespace() {
                break;
            }
            k += 1;
        }
        let key = unescape(&cs[..k.min(cs.len())].iter().collect::<String>());
        let mut rest: &str = &t[t.char_indices().nth(k).map(|(b, _)| b).unwrap_or(t.len())..];
        rest = rest.trim_start();
        if rest.starts_with('=') || rest.starts_with(':') {
            rest = &rest[1..];
        }
        out.push((key, unescape(rest).trim().to_string(), start, i));
    }
    out
}

fn unescape(s: &str) -> String {
    let cs: Vec<char> = s.chars().collect();
    let mut out = String::new();
    let mut i = 0;
    while i < cs.len() {
        if cs[i] == '\\' && i + 1 < cs.len() {
            match cs[i + 1] {
                'u' if i + 5 < cs.len() => {
                    let hex: String = cs[i + 2..i + 6].iter().collect();
                    if let Some(c) = u32::from_str_radix(&hex, 16).ok().and_then(char::from_u32) {
                        out.push(c);
                        i += 6;
                        continue;
                    }
                    out.push('u');
                }
                't' => out.push('\t'),
                'n' => out.push('\n'),
                'r' => out.push('\r'),
                'f' => out.push('\x0c'),
                c => out.push(c),
            }
            i += 2;
        } else {
            out.push(cs[i]);
            i += 1;
        }
    }
    out
}

/// ファイルの種類: `i18n/` 配下と `*Messages*.properties` は `msg`、それ以外は `prop`。
pub fn kind_of(path: &str) -> &'static str {
    let name = path.rsplit('/').next().unwrap_or(path);
    if path.contains("/i18n/") || name.contains("Messages") { "msg" } else { "prop" }
}

pub fn scan(file: &str, src: &str) -> Vec<Item> {
    let kind = kind_of(file);
    let name = file.rsplit('/').next().unwrap_or(file);
    parse(src)
        .into_iter()
        .map(|(k, v, s, e)| Item::new(kind, format!("{name}#{k}"), file, [s, e], &v))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_properties() {
        let src = "# c\nNotNull.gender={0}\\u3092 \nmulti = a \\\n   b\n! x\nk:v\n";
        let p = parse(src);
        assert_eq!(p[0].0, "NotNull.gender");
        assert_eq!(p[0].1, "{0}を");
        assert_eq!(p[1], ("multi".into(), "a b".into(), 3, 4));
        assert_eq!(p[2].0, "k");
        assert_eq!(kind_of("a/i18n/app-messages_ja.properties"), "msg");
        assert_eq!(kind_of("a/ValidationMessages.properties"), "msg");
        assert_eq!(kind_of("a/META-INF/spring/app.properties"), "prop");
    }
}
