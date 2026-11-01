package atrsoracle;

import jp.co.ntt.atrs.app.b0.SelectFlightForm;
import jp.co.ntt.atrs.app.b0.TicketHelper;
import jp.co.ntt.atrs.config.app.mybatis.MybatisConfig;
import jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider;
import jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider;
import jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider;
import jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider;
import jp.co.ntt.atrs.domain.common.masterdata.RouteProvider;
import jp.co.ntt.atrs.domain.model.Flight;
import jp.co.ntt.atrs.domain.model.Passenger;
import jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository;
import jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository;
import jp.co.ntt.atrs.domain.repository.flight.FlightRepository;
import jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository;
import jp.co.ntt.atrs.domain.repository.route.RouteRepository;
import jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl;
import jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl;
import jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.postgresql.ds.PGSimpleDataSource;
import specpivot.conformance.Reflect;

import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.util.List;
import java.util.Properties;

/**
 * 原典のドメイン層を、DI コンテナを起動せずに組み立てる（spec-pivot の lang/java/harness.md）。
 *
 * <ul>
 * <li>リポジトリは、原典の MyBatis の設定（{@code MybatisConfig.configuration()}）と Mapper の XML をそのまま使い、
 * PostgreSQL のシードの DB に対して実行する。</li>
 * <li>Provider（マスタのキャッシュ）は、原典のリポジトリを注入して {@code load()}（{@code @PostConstruct}）を呼ぶ。</li>
 * <li>サービスと {@code TicketHelper} は {@code new} で作り、フィールドを注入する。{@code @Value} の値は、原典の
 * {@code META-INF/spring/atrs.properties}（atrs-domain の jar の中）から読む。</li>
 * <li>{@code dateFactory} は、ケースの「今日」に止めた時計（{@link FixedClockFactory}）にする。</li>
 * </ul>
 */
final class Domain implements AutoCloseable {
    final SqlSession session;
    final Properties atrs = new Properties();
    final RouteProvider routeProvider = new RouteProvider();
    final FlightMasterProvider flightMasterProvider = new FlightMasterProvider();
    final BoardingClassProvider boardingClassProvider = new BoardingClassProvider();
    final FareTypeProvider fareTypeProvider = new FareTypeProvider();
    final PeakTimeProvider peakTimeProvider = new PeakTimeProvider();
    final TicketSharedServiceImpl shared = new TicketSharedServiceImpl();
    final TicketSearchServiceImpl search = new TicketSearchServiceImpl();
    final TicketReserveServiceImpl reserve = new TicketReserveServiceImpl();
    final TicketHelper helper = new TicketHelper();
    final FlightRepository flightRepository;

    Domain(String db) throws IOException {
        PGSimpleDataSource ds = new PGSimpleDataSource();
        ds.setURL(Pg.url(db));
        ds.setUser(Pg.props().getProperty("user"));
        if (Pg.props().getProperty("password") != null) ds.setPassword(Pg.props().getProperty("password"));
        ds.setOptions("-c TimeZone=UTC");
        Configuration conf = MybatisConfig.configuration();
        conf.setEnvironment(new Environment("oracle", new JdbcTransactionFactory(), ds));
        for (Class<?> m : List.of(RouteRepository.class, FlightRepository.class, BoardingClassRepository.class,
                FareTypeRepository.class, PeakTimeRepository.class)) {
            conf.addMapper(m);
        }
        session = new SqlSessionFactoryBuilder().build(conf).openSession(true);
        flightRepository = session.getMapper(FlightRepository.class);

        try (InputStream in = TicketSharedServiceImpl.class.getClassLoader().getResourceAsStream("META-INF/spring/atrs.properties")) {
            if (in == null) throw new IllegalStateException("atrs.properties not found on the classpath");
            atrs.load(new java.io.InputStreamReader(in, java.nio.charset.StandardCharsets.UTF_8));
        }

        Reflect.set(routeProvider, "routeRepository", session.getMapper(RouteRepository.class));
        Reflect.set(flightMasterProvider, "flightRepository", flightRepository);
        Reflect.set(boardingClassProvider, "boardingClassRepository", session.getMapper(BoardingClassRepository.class));
        Reflect.set(fareTypeProvider, "fareTypeRepository", session.getMapper(FareTypeRepository.class));
        Reflect.set(peakTimeProvider, "peakTimeRepository", session.getMapper(PeakTimeRepository.class));
        for (Object p : List.of(routeProvider, flightMasterProvider, boardingClassProvider, fareTypeProvider, peakTimeProvider)) {
            Reflect.call(p, "load");
        }

        Reflect.set(shared, "reserveIntervalTime", intProp("atrs.reserveIntervalTime"));
        Reflect.set(shared, "limitDay", intProp("atrs.limitDay"));
        Reflect.set(shared, "boardingClassProvider", boardingClassProvider);
        Reflect.set(shared, "peakTimeProvider", peakTimeProvider);
        Reflect.set(shared, "flightRepository", flightRepository);

        Reflect.set(search, "flightRepository", flightRepository);
        Reflect.set(search, "routeProvider", routeProvider);
        Reflect.set(search, "fareTypeProvider", fareTypeProvider);
        Reflect.set(search, "flightMasterProvider", flightMasterProvider);
        Reflect.set(search, "boardingClassProvider", boardingClassProvider);
        Reflect.set(search, "ticketSharedService", shared);

        Reflect.set(reserve, "representativeMinAge", intProp("atrs.representativeMinAge"));
        Reflect.set(reserve, "adultPassengerMinAge", intProp("atrs.adultPassengerMinAge"));
        Reflect.set(reserve, "childFareRate", intProp("atrs.childFareRate"));
        Reflect.set(reserve, "flightRepository", flightRepository);
        Reflect.set(reserve, "ticketSharedService", shared);

        Reflect.set(helper, "boardingClassProvider", boardingClassProvider);
        Reflect.set(helper, "flightMasterProvider", flightMasterProvider);
        Reflect.set(helper, "fareTypeProvider", fareTypeProvider);

        today(LocalDate.parse(SeedDb.LOAD_DATE));
    }

    int intProp(String k) {
        String v = atrs.getProperty(k);
        if (v == null) throw new IllegalStateException("atrs.properties: " + k + " not found");
        return Integer.parseInt(v.trim());
    }

    /** 「今日」を決める（10:00 JST に止めた時計。日付だけが観測される）。 */
    void today(LocalDate d) {
        FixedClockFactory c = new FixedClockFactory(d.atTime(10, 0));
        Reflect.set(shared, "dateFactory", c);
        Reflect.set(search, "dateFactory", c);
    }

    /** 選択フライト（便名・搭乗日・搭乗クラス・運賃種別）を、原典の {@code TicketHelper.toFlightList} で Flight にする。 */
    List<Flight> toFlightList(List<SelectFlightForm> forms) {
        return helper.toFlightList(forms);
    }

    static Passenger passenger(int age) {
        Passenger p = new Passenger();
        p.setAge(age);
        return p;
    }

    @Override
    public void close() {
        session.close();
    }
}
