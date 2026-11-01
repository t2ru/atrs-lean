package atrsoriginrun;

import specpivot.conformance.Op;
import specpivot.conformance.Runner;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;

/**
 * ドメイン層の原典実行（運賃計算・空席照会）。
 *
 * <ol>
 * <li>照合: {@code conformance/{shared,source-model}/{fare,flight-search}/} の全ケースを原典で実行し、期待値と比べる。</li>
 * <li>生成: シードの範囲を全探索（運賃）・抽出（合計金額・空席照会）したケースの期待値を原典から採取し、
 * {@code conformance/source-model/<feature>/origin-run-*.json} に書く（{@link Generate}）。--check では再生成との差分 0 を求める。</li>
 * </ol>
 */
final class DomainOriginRun {
    private DomainOriginRun() {}

    static final String MASTER_DB = "atrs_origin_run_master";
    static final String SEED_DB = "atrs_origin_run_seed";

    static final List<String> DIRS = List.of("shared/fare", "source-model/fare", "shared/flight-search", "source-model/flight-search");

    static void run(Path repo, boolean write, List<String> problems) throws Exception {
        SeedDb.load(repo, MASTER_DB, SeedDb.MASTER);
        SeedDb.load(repo, SEED_DB, SeedDb.FULL);
        try (Domain d = new Domain(MASTER_DB)) {
            Map<String, Op> ops = new DomainOps(d, MASTER_DB).ops();
            if (write) Generate.all(repo, ops, true, problems);
            for (String dir : DIRS) {
                for (Path f : Runner.jsonFiles(repo.resolve("conformance").resolve(dir))) {
                    Runner.FileResult r = Runner.check(f, ops);
                    String rel = repo.relativize(f).toString();
                    for (String x : r.failures()) problems.add(rel + ": " + x);
                    System.out.println((r.ok() ? "  ok   " : "  FAIL ") + rel + " (" + r.passed() + " cases)");
                }
            }
            if (!write) Generate.all(repo, ops, false, problems);
        }
    }
}
