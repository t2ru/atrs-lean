package atrsoriginrun;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;

/**
 * ATRS の Java の原典実行の入口（backlog f18c）。tools/ci/java_origin_run.sh から呼ぶ。
 *
 * <pre>
 *   java … atrsoriginrun.Main &lt;repo&gt; domain [--write]   ドメイン層（運賃・空席照会）
 *   java … atrsoriginrun.Main &lt;repo&gt; http   [--write]   HTTP レベル（Spring を起動した原典）
 * </pre>
 *
 * 既定（--check）は、既存のベクタの照合と、生成するベクタの再生成との差分 0 を求める。--write は生成するベクタを書き出す。
 * JVM は Asia/Tokyo・ja_JP で動かす（D-023・D-032。java_origin_run.sh が -D で与え、ここでも確かめる）。
 */
public final class Main {
    private Main() {}

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: Main <repo> domain|http [--write]");
            System.exit(64);
        }
        if (!TimeZone.getDefault().getID().equals("Asia/Tokyo") || !Locale.getDefault(Locale.Category.FORMAT).equals(Locale.JAPAN)) {
            System.err.println("origin-run: run with -Duser.timezone=Asia/Tokyo -Duser.language=ja -Duser.country=JP (got "
                    + TimeZone.getDefault().getID() + ", " + Locale.getDefault(Locale.Category.FORMAT) + ")");
            System.exit(1);
        }
        Path repo = Path.of(args[0]).toAbsolutePath().normalize();
        boolean write = List.of(args).contains("--write");
        List<String> problems = new ArrayList<>();
        switch (args[1]) {
            case "domain" -> DomainOriginRun.run(repo, write, problems);
            case "http" -> HttpOriginRun.run(repo, write, problems);
            default -> {
                System.err.println("unknown mode " + args[1]);
                System.exit(64);
            }
        }
        if (!problems.isEmpty()) {
            for (String p : problems) System.err.println("  FAIL " + p);
            System.err.println(problems.size() + " problem(s)");
            System.exit(1);
        }
        System.out.println("origin-run " + args[1] + ": OK");
        System.exit(0);
    }
}
