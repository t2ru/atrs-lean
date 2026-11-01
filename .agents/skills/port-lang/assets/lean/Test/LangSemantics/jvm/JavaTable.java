// LangSemantics.Java と JVM の突き合わせ表の生成器。
//
//   java JavaTable.java > ../JavaJvm.lean
//
// 固定の入力表について JVM で値を計算し、Lean の `#guard` 行として標準出力に書く。
// 出力（Test/LangSemantics/JavaJvm.lean）はコミットし、CI で再生成して差分が無いことを確かめる。
// 出力に JDK の版は含めない（対象の演算の結果は Java 17 以降で変わらない）。

import java.io.PrintStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class JavaTable {
    static final StringBuilder out = new StringBuilder();

    static void line(String s) { out.append(s).append('\n'); }

    /** Lean の文字列リテラル。制御文字と DEL は \x でエスケープし、それ以外はそのまま書く。 */
    static String lit(String s) {
        StringBuilder b = new StringBuilder("\"");
        s.codePoints().forEach(cp -> {
            if (cp == '"') b.append("\\\"");
            else if (cp == '\\') b.append("\\\\");
            else if (cp < 0x20 || cp == 0x7F) b.append(String.format("\\x%02x", cp));
            else b.appendCodePoint(cp);
        });
        return b.append('"').toString();
    }

    /** 不対サロゲートを含むか。 */
    static boolean loneSurrogate(String s) {
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (Character.isHighSurrogate(c) && (i + 1 >= s.length() || !Character.isLowSurrogate(s.charAt(i + 1)))) return true;
            if (Character.isLowSurrogate(c) && (i == 0 || !Character.isHighSurrogate(s.charAt(i - 1)))) return true;
            if (Character.isHighSurrogate(c)) i++;
        }
        return false;
    }

    static String lit(char c) {
        return "'" + (c == '\'' ? "\\'" : String.valueOf(c)) + "'";
    }

    static String intLit(long v) { return v < 0 ? "(" + v + ")" : String.valueOf(v); }

    static String bits(double d) {
        return String.format("0x%016X#64", Double.doubleToRawLongBits(d));
    }

    static String ymd(LocalDate d) { return "(" + d.getYear() + ", " + d.getMonthValue() + ", " + d.getDayOfMonth() + ")"; }

    static String ofYmd(LocalDate d) {
        return "(JLocalDate.ofYMD? " + intLit(d.getYear()) + " " + d.getMonthValue() + " " + d.getDayOfMonth() + ")";
    }

    static void bigDecimal() {
        line("");
        line("/-! ## BigDecimal -/");
        line("");
        int[] ns = {0, 1, 49, 50, 51, 99, 100, 101, 150, 250, 1000, 1001, 1099, 1100, 28800, 28801,
            -1, -49, -50, -51, -150, -250, -1001, -1100,
            2147483599, 2147483600, 2147483647, -2147483600, -2147483601, -2147483648};
        line("-- new BigDecimal(n).setScale(-2, RoundingMode.UP).intValue()");
        for (int n : ns) {
            int v = new BigDecimal(n).setScale(-2, RoundingMode.UP).intValue();
            line("#guard (bdCeilHundredUp (J32.ofInt " + intLit(n) + ")).val == " + intLit(v));
        }
        String[][] modes = {{"UP", ".up"}, {"DOWN", ".down"}, {"CEILING", ".ceiling"}, {"FLOOR", ".floor"},
            {"HALF_UP", ".halfUp"}, {"HALF_DOWN", ".halfDown"}, {"HALF_EVEN", ".halfEven"}};
        int[] ms = {0, 49, 50, 51, 149, 150, 151, 250, 1001, -49, -50, -51, -150, -250, -1001};
        line("-- new BigDecimal(n).setScale(-2, mode).unscaledValue()");
        for (String[] m : modes) {
            for (int n : ms) {
                long u = new BigDecimal(n).setScale(-2, RoundingMode.valueOf(m[0])).unscaledValue().longValueExact();
                line("#guard ((JBigDecimal.ofInt " + intLit(n) + ").setScale (-2) " + m[1] + ").unscaled == " + intLit(u));
            }
        }
    }

    static void string() {
        line("");
        line("/-! ## String -/");
        line("");
        String[] ss = {"", "a", "abc", "a𠮷", "𠮷𠮷", "山田", "ﾔﾏﾀﾞ", " \tab \u0000", "　ab　",
            " ab ", " ", " x ", "ab\n", "\u001Fab\u001C"};
        line("-- String.length()");
        for (String s : ss) line("#guard utf16Len " + lit(s) + " == " + s.length());
        line("-- String.trim()");
        for (String s : ss) line("#guard jTrim " + lit(s) + " == " + lit(s.trim()));
        line("-- String.strip()");
        for (String s : ss) line("#guard jStrip " + lit(s) + " == " + lit(s.strip()));
        String[][] splits = {{"03-1234-5678", "-"}, {"a--", "-"}, {"-", "-"}, {"", "-"}, {"--a", "-"}, {"-a-b-", "-"},
            {"a", "-"}, {"01/25", "/"}, {"1/", "/"}, {"/1", "/"}, {"12345", "/"}, {"a//b", "/"}};
        line("-- String.split(sep)");
        for (String[] sp : splits) {
            String[] parts = sp[0].split(sp[1]);
            List<String> ps = new ArrayList<>();
            for (String p : parts) ps.add(lit(p));
            line("#guard jSplitChar " + lit(sp[0]) + " " + lit(sp[1].charAt(0)) + " == [" + String.join(", ", ps) + "]");
        }
        String[] subs = {"0945", "2415", "abc", "ab", "", "山田太郎", "a𠮷b"};
        int[][] ranges = {{0, 2}, {2, 4}, {0, 0}, {1, 3}, {3, 1}, {0, 5}};
        line("-- String.substring(begin, end)（例外は StringIndexOutOfBoundsException）");
        for (String sub : subs) {
            for (int[] r : ranges) {
                String expect;
                try {
                    String got = sub.substring(r[0], r[1]);
                    // 切り口が補助文字の中にある（結果が不対サロゲートを含む）場合は、モデルが表さないので表に載せない
                    if (loneSurrogate(got)) continue;
                    expect = "some " + lit(got);
                }
                catch (StringIndexOutOfBoundsException e) { expect = "error"; }
                if (expect.equals("error"))
                    line("#guard (jSubstring " + lit(sub) + " " + r[0] + " " + r[1] + ") matches .error (.other \"java.lang.StringIndexOutOfBoundsException\" _)");
                else
                    line("#guard (jSubstring " + lit(sub) + " " + r[0] + " " + r[1] + ").toOption == " + expect);
            }
        }
        line("-- String.substring(begin)");
        for (String sub : subs) {
            if (sub.length() >= 2 && !loneSurrogate(sub.substring(2))) line("#guard (jSubstringFrom " + lit(sub) + " 2).toOption == some " + lit(sub.substring(2)));
        }
    }

    static void decimalFormat() {
        line("");
        line("/-! ## DecimalFormat -/");
        line("");
        DecimalFormat f = new DecimalFormat("###,###", DecimalFormatSymbols.getInstance(Locale.JAPAN));
        long[] ns = {0, 1, 12, 123, 1234, 12345, 123456, 1234567, 20600, 18600, 2147483647L, -1, -1234, -2147483648L};
        line("-- new DecimalFormat(\"###,###\").format(n)（Locale.JAPAN。区切り文字 ','）");
        for (long n : ns) line("#guard formatGrouped ',' " + intLit(n) + " == " + lit(f.format(n)));
    }

    static void localDate() {
        line("");
        line("/-! ## LocalDate -/");
        line("");
        LocalDate[] ds = {LocalDate.of(1970, 1, 1), LocalDate.of(2024, 2, 28), LocalDate.of(2024, 2, 29), LocalDate.of(2023, 2, 28),
            LocalDate.of(1900, 2, 28), LocalDate.of(2000, 2, 29), LocalDate.of(2026, 12, 31), LocalDate.of(2027, 1, 1),
            LocalDate.of(2026, 11, 1), LocalDate.of(1, 1, 1), LocalDate.of(9999, 12, 31), LocalDate.of(1969, 12, 31),
            // 負の年と 400 年の境界（床除算の扱いを確かめる）
            LocalDate.of(0, 3, 1), LocalDate.of(-1, 3, 1), LocalDate.of(-399, 3, 1), LocalDate.of(-400, 2, 28),
            LocalDate.of(-400, 2, 29), LocalDate.of(-400, 3, 1), LocalDate.of(-401, 12, 31), LocalDate.of(-800, 3, 1),
            LocalDate.of(-4713, 11, 24), LocalDate.of(10000, 1, 1), LocalDate.of(5874897, 12, 31)};
        long[] ns = {0, 1, -1, 30, 60, 90, 120, 365, 366, -366, 1461};
        line("-- toEpochDay / ofEpochDay");
        for (LocalDate d : ds) {
            line("#guard " + ofYmd(d) + ".map (·.toEpochDay) == some " + intLit(d.toEpochDay()));
            LocalDate e = LocalDate.ofEpochDay(d.toEpochDay());
            line("#guard (let r := JLocalDate.ofEpochDay " + intLit(d.toEpochDay()) + "; (r.year, r.month, r.day)) == " + ymd(e));
        }
        line("-- plusDays / minusDays");
        for (LocalDate d : ds) {
            if (d.getYear() == 1 || d.getYear() == 9999) continue;
            for (long n : ns) {
                line("#guard " + ofYmd(d) + ".map (fun d => let r := d.plusDays " + intLit(n) + "; (r.year, r.month, r.day)) == some " + ymd(d.plusDays(n)));
                line("#guard " + ofYmd(d) + ".map (fun d => let r := d.minusDays " + intLit(n) + "; (r.year, r.month, r.day)) == some " + ymd(d.minusDays(n)));
            }
        }
        line("-- LocalDate.of の検査");
        int[][] bad = {{2023, 2, 29}, {1900, 2, 29}, {2026, 4, 31}, {2026, 13, 1}, {2026, 0, 1}, {2026, 1, 0}};
        for (int[] b : bad) {
            boolean ok;
            try { LocalDate.of(b[0], b[1], b[2]); ok = true; } catch (java.time.DateTimeException ex) { ok = false; }
            line("#guard (JLocalDate.ofYMD? " + b[0] + " " + b[1] + " " + b[2] + ").isSome == " + ok);
        }
        LocalDate[][] pairs = {{LocalDate.of(2000, 2, 29), LocalDate.of(2001, 2, 28)}, {LocalDate.of(2000, 2, 29), LocalDate.of(2001, 3, 1)},
            {LocalDate.of(2000, 2, 29), LocalDate.of(2004, 2, 29)}, {LocalDate.of(1990, 10, 29), LocalDate.of(2026, 10, 29)},
            {LocalDate.of(1990, 10, 30), LocalDate.of(2026, 10, 29)}, {LocalDate.of(2026, 10, 29), LocalDate.of(2026, 10, 29)},
            {LocalDate.of(1900, 1, 1), LocalDate.of(2026, 12, 31)}, {LocalDate.of(2026, 11, 1), LocalDate.of(2027, 3, 1)},
            {LocalDate.of(2027, 3, 1), LocalDate.of(2026, 11, 1)}};
        line("-- isBefore / isAfter / ChronoUnit.DAYS.between / ChronoUnit.YEARS.between");
        for (LocalDate[] p : pairs) {
            String a = ofYmd(p[0]), b = ofYmd(p[1]);
            String pre = "#guard (do let a ← " + a + "; let b ← " + b + "; pure ";
            line(pre + "(a.isBefore b, a.isAfter b)) == some (" + p[0].isBefore(p[1]) + ", " + p[0].isAfter(p[1]) + ")");
            line(pre + "(a.daysBetween b)) == some " + intLit(ChronoUnit.DAYS.between(p[0], p[1])));
            if (!p[1].isBefore(p[0])) line(pre + "(a.yearsBetween b)) == some " + intLit(ChronoUnit.YEARS.between(p[0], p[1])));
        }
    }

    static void doubles() {
        line("");
        line("/-! ## double -/");
        line("");
        String[] lits = {"0.01", "0.1", "0.7", "0.69", "0.3", "1.4", "100.0", "0.0", "-0.0", "1430", "2.5", "-2.9", "123456789.123", "0.0000001"};
        line("-- リテラル（Double.parseDouble）");
        for (String s : lits) line("#guard (jdLit " + lit(s) + ").toBits == " + bits(Double.parseDouble(s)));
        line("-- (double) n");
        long[] ns = {0, 1, -1, 1430, 100000000, 2147483647, -2147483648L, 9007199254740993L};
        for (long n : ns) line("#guard (jd " + intLit(n) + ").toBits == " + bits((double) n));
        line("-- * と - と (int)");
        String[][] pl = {{"1430", "0.7"}, {"28800", "0.69"}, {"1.0", "0.01"}};
        for (String[] p : pl) {
            double a = Double.parseDouble(p[0]), b = Double.parseDouble(p[1]);
            line("#guard (jdmul (jdLit " + lit(p[0]) + ") (jdLit " + lit(p[1]) + ")).toBits == " + bits(a * b));
            line("#guard (jdsub (jdLit " + lit(p[0]) + ") (jdLit " + lit(p[1]) + ")).toBits == " + bits(a - b));
        }
        int[] rs = {0, 1, 5, 10, 20, 30, 50, 99, 100};
        for (int r : rs) {
            double f = 1 - r * 0.01;
            line("#guard (jdsub (jd 1) (jdmul (jd " + r + ") (jdLit \"0.01\"))).toBits == " + bits(f));
            int[] bs = {1430, 25000, 28800, 52400, 100000000};
            for (int b : bs) line("#guard (jd2i (jdmul (jd " + b + ") (jdsub (jd 1) (jdmul (jd " + r + ") (jdLit \"0.01\"))))).val == " + (int) (b * (1 - r * 0.01)));
        }
        int[] ratios = {100, 125, 140, 1000};
        for (int q : ratios) {
            int[] bs = {20100, 25000, 52400, 57400, 10000000};
            for (int b : bs) line("#guard (jd2i (jdmul (jd " + b + ") (jdmul (jd " + q + ") (jdLit \"0.01\")))).val == " + (int) (b * (q * 0.01)));
        }
        line("-- 特殊値: NaN・±∞・飽和・0 方向切捨て");
        line("#guard (jdmul (.inf false) (jd 0)).toBits == " + bits(Double.POSITIVE_INFINITY * 0.0));
        line("#guard (jdsub (.inf false) (.inf false)).toBits == " + bits(Double.POSITIVE_INFINITY - Double.POSITIVE_INFINITY));
        line("#guard (jdmul (jdLit \"-1.0\") (.inf false)).toBits == " + bits(-1.0 * Double.POSITIVE_INFINITY));
        line("#guard (jd2i .nan).val == " + (int) Double.NaN);
        line("#guard (jd2i (.inf false)).val == " + (int) Double.POSITIVE_INFINITY);
        line("#guard (jd2i (.inf true)).val == " + (int) Double.NEGATIVE_INFINITY);
        String[] ts = {"2.9", "-2.9", "0.5", "-0.5", "2147483647.5", "2147483648.0", "-2147483649.0"};
        for (String t : ts) line("#guard (jd2i (jdLit " + lit(t) + ")).val == " + intLit((int) Double.parseDouble(t)));
        line("#guard (jd2i (jdmul (jd 100000) (jd 100000))).val == " + intLit((int) (100000.0 * 100000.0)));
    }

    public static void main(String[] args) {
        line("import LangSemantics.Java");
        line("");
        line("/-!");
        line("# Test.LangSemantics.JavaJvm");
        line("");
        line("**生成物（手で編集しない）。** `Test/LangSemantics/jvm/JavaTable.java` が JVM で計算した値と、");
        line("`LangSemantics.Java` の結果を突き合わせる。再生成: `java Test/LangSemantics/jvm/JavaTable.java > Test/LangSemantics/JavaJvm.lean`");
        line("-/");
        line("");
        line("open LangSemantics.Java");
        line("open LangSemantics.Java.BigDecimal LangSemantics.Java.Int LangSemantics.Java.IntLemmas LangSemantics.Java.String");
        line("open LangSemantics.Java.DoubleOps LangSemantics.Java.DecimalFormat");
        bigDecimal();
        string();
        decimalFormat();
        localDate();
        doubles();
        PrintStream ps = new PrintStream(System.out, true, StandardCharsets.UTF_8);
        ps.print(out);
        ps.flush();
    }
}
