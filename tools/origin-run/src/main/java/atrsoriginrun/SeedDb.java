package atrsoriginrun;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;

/**
 * 原典のシードの SQL（atrs-initdb/src/sqls/integration-test-postgres）を、新しいデータベースに投入する。
 * 投入日に依存する値は、投入日 2026-11-01 で展開する（ADR 9ee4。tools/conformance/master_sql.py と同じ置き換え）:
 * 00230 の {@code localtimestamp}（会員の最終ログイン日時）と 00240 の {@code current_timestamp} を
 * {@code TIMESTAMP '2026-11-01 00:00:00'}、00250 の {@code current_date} を {@code DATE '2026-11-01'} にする。
 * 原典のファイルは書き換えない（読んだ文字列を置き換える）。
 */
final class SeedDb {
    private SeedDb() {}

    static final String LOAD_DATE = "2026-11-01";

    /** マスタだけ（FLIGHT・MEMBER は空）。ドメイン層の原典実行がケースごとに FLIGHT を入れる。 */
    static final List<String> MASTER = List.of("00100_create_all_tables.sql", "00200_insert_fixed_value.sql",
            "00210_insert_route.sql", "00220_insert_flight_master.sql", "00240_insert_peak_time.sql");

    /** シードのすべて（会員・フライトを含む）。HTTP レベルの原典実行と、空席照会の入力の採取に使う。 */
    static final List<String> FULL = List.of("00100_create_all_tables.sql", "00200_insert_fixed_value.sql",
            "00210_insert_route.sql", "00220_insert_flight_master.sql", "00230_insert_member.sql",
            "00240_insert_peak_time.sql", "00250_insert_flight.sql");

    static void load(Path repo, String db, List<String> files) throws IOException, SQLException {
        Path dir = Upstream.atrs(repo).resolve("atrs-initdb/src/sqls/integration-test-postgres");
        Pg.recreate(db);
        try (Connection c = Pg.connect(db)) {
            c.setAutoCommit(true);
            for (String f : files) {
                String sql = Files.readString(dir.resolve(f), StandardCharsets.UTF_8);
                if (f.startsWith("00230")) sql = replaceOnce(sql, f, "localtimestamp", "TIMESTAMP '" + LOAD_DATE + " 00:00:00'");
                if (f.startsWith("00240")) sql = replaceOnce(sql, f, "current_timestamp", "TIMESTAMP '" + LOAD_DATE + " 00:00:00'");
                if (f.startsWith("00250")) sql = replaceOnce(sql, f, "current_date", "DATE '" + LOAD_DATE + "'");
                try (Statement s = c.createStatement()) {
                    s.execute(sql);
                }
            }
        }
    }

    private static String replaceOnce(String sql, String file, String from, String to) {
        if (!sql.contains(from)) throw new IllegalStateException(file + " does not use " + from);
        return sql.replace(from, to);
    }
}
