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
        g.confirm();
        g.reserve();
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

        /** 搭乗者の型: 名前・年齢・性別（予約代表者は 1 人目。{@code rep17} は代表者の年齢 17）。空の欄 {@code null} を挟むものもある。 */
        record Mix(String id, String label, int repAge, Object[][] passengers) {}

        static final List<Mix> MIXES = List.of(
                new Mix("F30", "大人の女性 1 名", 30, new Object[][] {{"ハナコ", 30, "F"}}),
                new Mix("M40-F8", "大人の男性 1 名と小児の女性 1 名", 40, new Object[][] {{"タロウ", 40, "M"}, {"ハナコ", 8, "F"}}),
                new Mix("F30-F29", "大人の女性 2 名", 30, new Object[][] {{"ハナコ", 30, "F"}, {"サクラ", 29, "F"}}),
                new Mix("F30-M31-F12", "大人 3 名（12 歳を含む）", 30, new Object[][] {{"ハナコ", 30, "F"}, {"タロウ", 31, "M"}, {"サクラ", 12, "F"}}),
                new Mix("gap-F30-M5", "空の欄を挟む大人の女性 1 名と小児の男性 1 名", 30,
                        new Object[][] {null, {"ハナコ", 30, "F"}, null, {"ジロウ", 5, "M"}}),
                new Mix("six", "6 名（大人 2 名・小児 4 名、11 歳と 2 歳を含む）", 30, new Object[][] {{"ハナコ", 30, "F"}, {"タロウ", 30, "M"},
                        {"ジロウ", 5, "M"}, {"サクラ", 8, "F"}, {"サブロウ", 11, "M"}, {"モモ", 2, "F"}}),
                new Mix("rep17", "代表者 17 歳（大人の女性 1 名）", 17, new Object[][] {{"ハナコ", 17, "F"}}));

        static ObjectNode reserveForm(Mix m) {
            ObjectNode f = Json.obj();
            f.put("repFamilyName", "デンデン");
            Object[] rep = m.passengers()[0] != null ? m.passengers()[0] : m.passengers()[1];
            f.put("repGivenName", (String) rep[0]);
            f.put("repAge", m.repAge());
            f.put("repGender", (String) rep[2]);
            f.put("repTel1", "03");
            f.put("repTel2", "1234");
            f.put("repTel3", "5678");
            f.put("repMail", "hanako@example.com");
            f.putNull("repMembershipNumber");
            ArrayNode ps = f.putArray("passengers");
            for (int k = 0; k < 6; k++) {
                ObjectNode p = ps.addObject();
                Object[] x = k < m.passengers().length ? m.passengers()[k] : null;
                if (x == null) continue;
                p.put("familyName", "デンデン");
                p.put("givenName", (String) x[0]);
                p.put("age", (Integer) x[1]);
                p.put("gender", (String) x[2]);
            }
            return f;
        }

        /** 選択フライトの FLIGHT の行（シードの値）。シードに無ければ null。 */
        ObjectNode seedRow(ObjectNode sel) throws Exception {
            LocalDate d = LocalDate.parse(sel.get("departureDate").asText());
            for (JsonNode r : seedFlights(d, routeOf(sel.get("flightName").asText()))) {
                if (r.get("flightName").asText().equals(sel.get("flightName").asText())
                        && r.get("boardingClassCd").asText().equals(sel.get("boardingClassCd").asText())
                        && r.get("fareTypeCd").asText().equals(sel.get("fareTypeCd").asText())) return (ObjectNode) r;
            }
            return null;
        }

        int routeOf(String flightName) {
            for (JsonNode f : master.get("flightMasters")) if (f.get("flightName").asText().equals(flightName)) return f.get("routeNo").intValue();
            throw new IllegalArgumentException(flightName);
        }

        /** 搭乗日・区間のシードの便のうち、便名の順で最初のもの（シードの FLIGHT はすべての便を持たない）。無ければ null。 */
        String seededRepresentative(LocalDate d, int routeNo) throws Exception {
            ArrayNode rows = seedFlights(d, routeNo);
            return rows.isEmpty() ? null : rows.get(0).get("flightName").asText();
        }

        /** 片道・往復の選択フライト（往復の復路は逆区間の代表便の 2 日後）。シードに便が無い・逆区間の無い往復は null。 */
        List<ObjectNode> trip(JsonNode route, LocalDate d, String cls, String ft, boolean roundTrip) throws Exception {
            String out = seededRepresentative(d, route.get("routeNo").intValue());
            if (out == null) return null;
            List<ObjectNode> fs = new ArrayList<>();
            fs.add(flight(out, d, cls, ft));
            if (roundTrip) {
                Integer rev = reverseRoute(route);
                String back = rev == null ? null : seededRepresentative(d.plusDays(2), rev);
                if (back == null) return null;
                fs.add(flight(back, d.plusDays(2), cls, ft));
            }
            return fs;
        }

        ObjectNode confirmCase(List<ObjectNode> trip, Mix m, String id, String description) throws Exception {
            ObjectNode in = Json.obj();
            in.put("today", TODAY.toString());
            ArrayNode rows = in.putArray("flights");
            ArrayNode sels = in.putArray("selectFlights");
            for (ObjectNode f : trip) {
                ObjectNode row = seedRow(f);
                if (row == null) return null;
                rows.add(row);
                ObjectNode s = sels.addObject();
                s.put("depDate", f.get("departureDate").asText());
                s.put("flightName", f.get("flightName").asText());
                s.put("boardingClassCd", f.get("boardingClassCd").asText());
                s.put("fareTypeCd", f.get("fareTypeCd").asText());
            }
            in.set("form", reserveForm(m));
            return testCase(id, description, in);
        }

        static String tripLabel(List<ObjectNode> trip) {
            StringBuilder b = new StringBuilder();
            for (ObjectNode f : trip) {
                if (b.length() > 0) b.append('-');
                b.append(f.get("flightName").asText()).append('-').append(f.get("departureDate").asText());
            }
            return b + "-" + trip.get(0).get("boardingClassCd").asText() + "-" + trip.get(0).get("fareTypeCd").asText();
        }

        void confirm() throws Exception {
            ObjectNode doc = header("reservation/confirm.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力の flights は、選択フライトのシードの FLIGHT の行（00250 を投入日 2026-11-01 で展開）。今日は投入日。"
                    + "区間 1 の代表便（シードにある便のうち便名の順で最初のもの。搭乗日 2026-11-11）の搭乗クラス × 運賃種別（片道は片道系、往復は往復系と逆区間の代表便の 2 日後）"
                    + "× 搭乗者の型のすべてと、ほかの区間（シードに便のあるもの）の代表便（搭乗日 2026-12-26）の搭乗クラス・運賃種別・搭乗者の型の巡回",
                    List.of("D-001", "D-002", "D-012"));
            reservationCases(doc, "confirm");
            emit("reservation/origin-run-confirm.json", doc);
        }

        /** 予約確定: 予約確認と同じ入力（会員・予約の表は空、採番は初期値）。結果と実行後の状態を採取する。 */
        void reserve() throws Exception {
            ObjectNode doc = header("reservation/reserve.json", "Java の原典実行で採取した期待値（tools/origin-run の Generate。手で編集しない）。"
                    + "入力は origin-run-confirm.json と同じ（選択フライトのシードの FLIGHT の行、今日は投入日、会員・予約の表は空、採番は初期値）。"
                    + "期待値は予約確定の結果と実行後の状態（FLIGHT・予約の表・採番）",
                    List.of("D-001", "D-002", "D-012"));
            reservationCases(doc, "reserve");
            emit("reservation/origin-run-reserve.json", doc);
        }

        /** 区間 1 の代表便の搭乗クラス × 運賃種別 × 搭乗者の型のすべてと、ほかの区間の代表便の巡回（予約確認・予約確定で共通）。 */
        void reservationCases(ObjectNode doc, String prefix) throws Exception {
            ArrayNode cases = doc.withArray("cases");
            List<String[]> kinds = List.of(new String[] {"N", "OW"}, new String[] {"N", "RD1"}, new String[] {"N", "RD7"},
                    new String[] {"N", "ED"}, new String[] {"N", "LD"}, new String[] {"N", "GD"}, new String[] {"S", "SOW"},
                    new String[] {"S", "SRD"}, new String[] {"N", "RT"}, new String[] {"S", "SRT"});
            JsonNode routes = master.get("routes");
            JsonNode r1 = routes.get(0);
            LocalDate d1 = TODAY.plusDays(10);
            for (String[] k : kinds) {
                List<ObjectNode> trip = trip(r1, d1, k[0], k[1], k[1].endsWith("RT"));
                if (trip == null) continue;
                for (Mix m : MIXES) {
                    ObjectNode c = confirmCase(trip, m, prefix + "-" + tripLabel(trip) + "-" + m.id(),
                            String.join("・", k) + "・" + tripLabel(trip) + "・" + m.label());
                    if (c != null) cases.add(c);
                }
            }
            LocalDate peak = LocalDate.parse("2026-12-26");
            int n = 0;
            for (int r = 1; r < routes.size(); r++) {
                String[] k = kinds.get(n % kinds.size());
                Mix m = MIXES.get(n % MIXES.size());
                List<ObjectNode> trip = trip(routes.get(r), peak, k[0], k[1], k[1].endsWith("RT"));
                if (trip == null) continue;
                ObjectNode c = confirmCase(trip, m, prefix + "-" + tripLabel(trip) + "-" + m.id(),
                        String.join("・", k) + "・" + tripLabel(trip) + "・" + m.label());
                if (c == null) continue;
                cases.add(c);
                n++;
            }
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
