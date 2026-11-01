package atrsoracle;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Properties;

/**
 * PostgreSQL への接続（環境変数 PGHOST・PGPORT・PGUSER・PGPASSWORD。with_postgres.sh の WITH_POSTGRES_TCP=1 か、CI のサービス）。
 * セッションのタイムゾーンは UTC とする（spec-pivot の lang/sql/dialects/postgresql/harness.md）。
 */
final class Pg {
    private Pg() {}

    static String host() {
        String h = System.getenv().getOrDefault("PGHOST", "localhost");
        if (h.startsWith("/")) throw new IllegalStateException("PGHOST is a Unix socket (" + h + "); run with WITH_POSTGRES_TCP=1");
        return h;
    }

    static String url(String db) {
        return "jdbc:postgresql://" + host() + ":" + System.getenv().getOrDefault("PGPORT", "5432") + "/" + db;
    }

    static Properties props() {
        Properties p = new Properties();
        p.setProperty("user", System.getenv().getOrDefault("PGUSER", "postgres"));
        String pw = System.getenv("PGPASSWORD");
        if (pw != null) p.setProperty("password", pw);
        p.setProperty("options", "-c TimeZone=UTC");
        return p;
    }

    static Connection connect(String db) throws SQLException {
        return DriverManager.getConnection(url(db), props());
    }

    static void recreate(String db) throws SQLException {
        try (Connection c = connect("postgres"); Statement s = c.createStatement()) {
            s.execute("DROP DATABASE IF EXISTS " + db + " WITH (FORCE)");
            s.execute("CREATE DATABASE " + db);
        }
    }
}
