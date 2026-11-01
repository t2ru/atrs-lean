package atrsoriginrun;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import specpivot.conformance.Json;
import specpivot.conformance.Op;
import specpivot.conformance.Runner;

import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * 原典実行が期待値を採取するベクタ（{@code conformance/source-model/<feature>/origin-run-*.json}）。入力はシードの値から機械的に作る
 * （範囲は docs/spec/assurance.md の付録）。{@code --check} では再生成し、書いてあるものとの差分 0 を求める。
 */
final class Generate {
    private Generate() {}

    /** ケースの中身（input・expected）を 1 行に書く深さ（文書 0 → cases 1 → ケース 2 → 値 3）。 */
    static final int FLAT = 3;
    static final String SOURCE = "java-origin-run";
    static final LocalDate TODAY = LocalDate.parse(SeedDb.LOAD_DATE);

    static void all(Path repo, Map<String, Op> ops, boolean write, List<String> problems) throws Exception {
        JsonNode master = Json.read(repo.resolve("conformance/fixtures/master-data.json"));
        Gen g = new Gen(repo, ops, write, problems, master);
        g.basicFareAndFare();
        g.totalFare();
        g.searchFlight();
    }

    static final class Gen {
        final Path repo;
        final Map<String, Op> ops;
        final boolean write;
        final List<String> problems;
        final JsonNode master;

        Gen(Path repo, Map<String, Op> ops, boolean write, List<String> problems, JsonNode master) {
            this.repo = repo;
            this.ops = ops;
            this.write = write;
            this.problems = problems;
            this.master = master;
        }

        /** 共有のベクタ（shared/）の頭を写し、SourceModel の modelDef だけを残す。 */
        ObjectNode header(String sharedFile, String note, List<String> differences) {
            JsonNode s = Json.read(repo.resolve("conformance/shared").resolve(sharedFile));
            String src = null;
            for (JsonNode m : s.get("modelDef")) if (m.asText().startsWith("SourceModel.")) src = m.asText();
            ObjectNode d = Runner.header(s.get("operation").asText(), Json.F.textNode(src), s.get("specRef").asText(),
                    Upstream.version(repo), s.get("fixtures"), note);
            if (!differences.isEmpty()) {
                ArrayNode a = d.putArray("differences");
                differences.forEach(a::add);
                d.set("cases", d.remove("cases"));
            }
            return d;
        }

        void emit(String rel, ObjectNode doc) throws Exception {
            Runner.fill(doc, ops.get(doc.get("operation").asText()), SOURCE);
            String p = Runner.saveOrCompare(repo.resolve("conformance/source-model").resolve(rel), doc, FLAT, write);
            if (p != null) problems.add(p);
            System.out.println("  " + (write ? "wrote" : (p == null ? "ok   " : "FAIL ")) + " conformance/source-model/" + rel + " ("
                    + doc.get("cases").size() + " cases)");
        }

        static ObjectNode testCase(String id, String description, ObjectNode input) {
            ObjectNode c = Json.obj();
            c.put("id", id);
            c.put("description", description);
            c.set("input", input);
            return c;
        }

        /** 搭乗日: 通常日（投入日）と、各ピーク時期の前日・初日・末日・翌日。 */
        Set<LocalDate> fareDates() {
            TreeSet<LocalDate> ds = new TreeSet<>();
            ds.add(TODAY);
            for (JsonNode p : master.get("peakTimes")) {
                LocalDate s = LocalDate.parse(p.get("peakStartDate").asText());
                LocalDate e = LocalDate.parse(p.get("peakEndDate").asText());
                ds.add(s.minusDays(1));
                ds.add(s);
                ds.add(e);
                ds.add(e.plusDays(1));
            }
            return ds;
        }

        void basicFareAndFare() throws Exception {
            Set<Integer> routeFares = new TreeSet<>();
            for (JsonNode r : master.get("routes")) routeFares.add(r.get("basicFare").intValue());
            List<String> classes = new ArrayList<>();
            for (JsonNode b : master.get("boardingClasses")) classes.add(b.get("boardingClassCd").asText());

            ObjectNode bf = header("fare/basicFare.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力はシードの区間の運賃 × 搭乗クラス × 搭乗日（投入日と、各ピーク時期の前日・初日・末日・翌日）の全組", List.of("D-001"));
            ArrayNode cases = bf.withArray("cases");
            for (int x : routeFares) {
                for (String cls : classes) {
                    for (LocalDate d : fareDates()) {
                        ObjectNode in = Json.obj();
                        in.put("routeBasicFare", x);
                        in.put("boardingClassCd", cls);
                        in.put("depDate", d.toString());
                        cases.add(testCase("basicFare-" + x + "-" + cls + "-" + d, "区間の運賃 " + x + "・搭乗クラス " + cls + "・搭乗日 " + d, in));
                    }
                }
            }
            emit("fare/origin-run-basicFare.json", bf);

            Set<Integer> basicFares = new TreeSet<>();
            for (JsonNode c : bf.get("cases")) basicFares.add(c.get("expected").get("ok").intValue());
            Set<Integer> rates = new TreeSet<>();
            for (JsonNode f : master.get("fareTypes")) rates.add(f.get("discountRate").intValue());
            ObjectNode fa = header("fare/fare.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力は origin-run-basicFare.json の基本運賃のすべて × シードの運賃種別の割引率のすべて", List.of("D-002"));
            ArrayNode fc = fa.withArray("cases");
            for (int b : basicFares) {
                for (int r : rates) {
                    ObjectNode in = Json.obj();
                    in.put("basicFare", b);
                    in.put("discountRate", r);
                    fc.add(testCase("fare-" + b + "-" + r, "基本運賃 " + b + "・割引率 " + r + "%", in));
                }
            }
            emit("fare/origin-run-fare.json", fa);
        }

        /** 区間ごとの代表便（シードの順で最初の便マスタ）。 */
        String representative(int routeNo) {
            for (JsonNode f : master.get("flightMasters")) if (f.get("routeNo").intValue() == routeNo) return f.get("flightName").asText();
            return null;
        }

        Integer reverseRoute(JsonNode r) {
            for (JsonNode q : master.get("routes")) {
                if (q.get("depAirportCd").asText().equals(r.get("arrAirportCd").asText())
                        && q.get("arrAirportCd").asText().equals(r.get("depAirportCd").asText())) return q.get("routeNo").intValue();
            }
            return null;
        }

        static ObjectNode flight(String name, LocalDate d, String cls, String ft) {
            ObjectNode f = Json.obj();
            f.put("flightName", name);
            f.put("departureDate", d.toString());
            f.put("boardingClassCd", cls);
            f.put("fareTypeCd", ft);
            return f;
        }

        void totalFare() throws Exception {
            // 片道は片道系、往復は往復系（搭乗クラスごと。FareTypeUtil・seed の運賃種別）
            Map<String, List<String>> oneWay = Map.of("N", List.of("OW", "RD1", "RD7", "ED", "LD", "GD"), "S", List.of("SOW", "SRD"));
            Map<String, String> roundTrip = Map.of("N", "RT", "S", "SRT");
            List<int[]> passengerTypes = List.of(new int[] {30}, new int[] {30, 11}, new int[] {11, 12}, new int[] {30, 30, 5, 8, 11, 2});
            LocalDate peak = LocalDate.parse("2026-12-26");
            ObjectNode doc = header("fare/totalFare.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力は区間ごとの代表便 × 搭乗クラス × 運賃種別（片道は片道系、往復は往復系と逆区間の代表便）× 搭乗者の型 × 搭乗日"
                    + "（投入日 2026-11-01 とピーク日 2026-12-26）の抽出", List.of("D-001", "D-002", "D-012"));
            ArrayNode cases = doc.withArray("cases");
            for (JsonNode r : master.get("routes")) {
                int routeNo = r.get("routeNo").intValue();
                String out = representative(routeNo);
                if (out == null) continue; // 便マスタの無い区間（シードにある）
                Integer rev = reverseRoute(r);
                String back = rev == null ? null : representative(rev);
                for (LocalDate d : List.of(TODAY, peak)) {
                    for (String cls : List.of("N", "S")) {
                        List<ArrayNode> trips = new ArrayList<>();
                        List<String> labels = new ArrayList<>();
                        for (String ft : oneWay.get(cls)) {
                            ArrayNode fs = Json.arr();
                            fs.add(flight(out, d, cls, ft));
                            trips.add(fs);
                            labels.add(out + " " + cls + " " + ft);
                        }
                        if (back != null) {
                            ArrayNode fs = Json.arr();
                            fs.add(flight(out, d, cls, roundTrip.get(cls)));
                            fs.add(flight(back, d.plusDays(2), cls, roundTrip.get(cls)));
                            trips.add(fs);
                            labels.add(out + "・" + back + " " + cls + " " + roundTrip.get(cls));
                        }
                        for (int t = 0; t < trips.size(); t++) {
                            for (int[] ages : passengerTypes) {
                                ObjectNode in = Json.obj();
                                in.set("flights", trips.get(t));
                                ArrayNode ps = in.putArray("passengers");
                                StringBuilder a = new StringBuilder();
                                for (int age : ages) {
                                    ps.addObject().put("age", age);
                                    if (a.length() > 0) a.append('_');
                                    a.append(age);
                                }
                                String label = labels.get(t);
                                cases.add(testCase("totalFare-" + label.replace(' ', '-').replace("・", "-") + "-" + d + "-" + a,
                                        label + "・搭乗日 " + d + "・年齢 " + a.toString().replace('_', ','), in));
                            }
                        }
                    }
                }
            }
            emit("fare/origin-run-totalFare.json", doc);
        }

        /** シードの FLIGHT（投入日で展開）から、搭乗日・区間の便の行（両搭乗クラス）を読む。 */
        ArrayNode seedFlights(LocalDate d, int routeNo) throws Exception {
            ArrayNode rows = Json.arr();
            try (Connection c = Pg.connect(DomainOriginRun.SEED_DB);
                    PreparedStatement p = c.prepareStatement("SELECT f.departure_date, f.flight_name, f.boarding_class_cd, f.fare_type_cd, "
                            + "f.vacant_num FROM flight f JOIN flight_master fm ON f.flight_name = fm.flight_name "
                            + "WHERE f.departure_date = ? AND fm.route_no = ? "
                            + "ORDER BY f.flight_name, f.boarding_class_cd, f.fare_type_cd COLLATE \"C\"")) {
                p.setObject(1, d);
                p.setInt(2, routeNo);
                try (ResultSet rs = p.executeQuery()) {
                    while (rs.next()) {
                        ObjectNode f = rows.addObject();
                        f.put("departureDate", rs.getObject(1, LocalDate.class).toString());
                        f.put("flightName", rs.getString(2));
                        f.put("boardingClassCd", rs.getString(3));
                        f.put("fareTypeCd", rs.getString(4));
                        f.put("vacantNum", rs.getInt(5));
                    }
                }
            }
            return rows;
        }

        void searchFlight() throws Exception {
            ObjectNode doc = header("flight-search/searchFlight.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力の flights は、シードの FLIGHT（00250 を投入日 2026-11-01 で展開）のうち、搭乗日・区間の便の行（両搭乗クラス）。"
                    + "区間 × 搭乗クラス × 片道・往復（搭乗日 2026-11-11）と、照会可能期間の境界（区間 1）",
                    List.of("D-001", "D-002"));
            ArrayNode cases = doc.withArray("cases");
            LocalDate dep = TODAY.plusDays(10);
            for (JsonNode r : master.get("routes")) {
                int routeNo = r.get("routeNo").intValue();
                ArrayNode rows = seedFlights(dep, routeNo);
                for (String cls : List.of("N", "S")) {
                    for (String type : List.of("OW", "RT")) {
                        cases.add(searchCase("searchFlight-route" + routeNo + "-" + cls + "-" + type, r, dep, cls, type, rows,
                                "区間 " + routeNo + "（" + r.get("depAirportCd").asText() + "→" + r.get("arrAirportCd").asText() + "）・"
                                        + cls + "・" + type + "・搭乗日 " + dep));
                    }
                }
            }
            JsonNode r1 = master.get("routes").get(0);
            int limitDay = Json.read(repo.resolve("conformance/fixtures/config.json")).get("limitDay").intValue();
            for (int k : new int[] {0, limitDay, limitDay + 1}) {
                LocalDate d = TODAY.plusDays(k);
                cases.add(searchCase("searchFlight-route1-N-OW-d" + k, r1, d, "N", "OW", seedFlights(d, r1.get("routeNo").intValue()),
                        "照会可能期間の境界: 今日から " + k + " 日後（照会可能期間は " + limitDay + " 日後まで）"));
            }
            emit("flight-search/origin-run-searchFlight.json", doc);
        }

        static ObjectNode searchCase(String id, JsonNode route, LocalDate dep, String cls, String type, ArrayNode rows, String description) {
            ObjectNode in = Json.obj();
            in.put("today", TODAY.toString());
            in.set("flights", rows);
            ObjectNode q = in.putObject("criteria");
            q.put("flightType", type);
            q.put("depDate", dep.toString());
            q.put("depAirportCd", route.get("depAirportCd").asText());
            q.put("arrAirportCd", route.get("arrAirportCd").asText());
            q.put("boardingClassCd", cls);
            return testCase(id, description, in);
        }
    }
}
