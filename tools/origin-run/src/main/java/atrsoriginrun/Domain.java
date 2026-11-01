package atrsoriginrun;

import jp.co.ntt.atrs.app.b0.SelectFlightForm;
import jp.co.ntt.atrs.app.b0.TicketHelper;
import jp.co.ntt.atrs.app.b2.B2MapperImpl;
import jp.co.ntt.atrs.app.b2.TicketReserveForm;
import jp.co.ntt.atrs.app.b2.TicketReserveHelper;
import jp.co.ntt.atrs.config.app.mybatis.MybatisConfig;
import jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider;
import jp.co.ntt.atrs.domain.common.masterdata.FareTypeProvider;
import jp.co.ntt.atrs.domain.common.masterdata.FlightMasterProvider;
import jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider;
import jp.co.ntt.atrs.domain.common.masterdata.RouteProvider;
import jp.co.ntt.atrs.domain.model.Flight;
import jp.co.ntt.atrs.domain.model.Passenger;
import jp.co.ntt.atrs.domain.model.Reservation;
import jp.co.ntt.atrs.domain.repository.boardingclass.BoardingClassRepository;
import jp.co.ntt.atrs.domain.repository.faretype.FareTypeRepository;
import jp.co.ntt.atrs.domain.repository.flight.FlightRepository;
import jp.co.ntt.atrs.domain.repository.member.MemberRepository;
import jp.co.ntt.atrs.domain.repository.peaktime.PeakTimeRepository;
import jp.co.ntt.atrs.domain.repository.reservation.ReservationRepository;
import jp.co.ntt.atrs.domain.repository.route.RouteRepository;
import jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl;
import jp.co.ntt.atrs.domain.service.b1.TicketSearchServiceImpl;
import jp.co.ntt.atrs.domain.service.b2.TicketReserveService;
import jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.mybatis.spring.SqlSessionTemplate;
import org.mybatis.spring.transaction.SpringManagedTransactionFactory;
import org.postgresql.ds.PGSimpleDataSource;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.TransactionManager;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import specpivot.conformance.Reflect;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
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
 * <li>トランザクションは原典の構成（AtrsInfraConfig・AtrsEnvConfig・AtrsDomainConfig）と同じ部品で張る: Mapper は
 * MyBatis-Spring の {@code SqlSessionTemplate}（{@code SpringManagedTransactionFactory}）から取り、
 * {@code DataSourceTransactionManager} の下で、{@code @Transactional} の付いたサービス（{@code TicketReserveServiceImpl}）を
 * {@code TransactionInterceptor}（{@code AnnotationTransactionAttributeSource}）の代理で包む。ヘルパーには代理を注入する
 * （原典で {@code @Inject} されるのも代理）。これで {@code registerReservation} の途中の業務例外は取り消しになる。</li>
 * </ul>
 */
final class Domain implements AutoCloseable {
    final SqlSessionTemplate session;
    final DataSourceTransactionManager txManager;
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
    final TicketReserveHelper reserveHelper = new TicketReserveHelper();
    /** {@code @Transactional} の代理（原典の DI コンテナが注入するもの）。 */
    final TicketReserveService reserveTx;
    final FlightRepository flightRepository;
    private final Method createReservation;

    Domain(String db) throws IOException {
        PGSimpleDataSource ds = new PGSimpleDataSource();
        ds.setURL(Pg.url(db));
        ds.setUser(Pg.props().getProperty("user"));
        if (Pg.props().getProperty("password") != null) ds.setPassword(Pg.props().getProperty("password"));
        ds.setOptions("-c TimeZone=UTC");
        Configuration conf = MybatisConfig.configuration();
        conf.setEnvironment(new Environment("origin-run", new SpringManagedTransactionFactory(), ds));
        for (Class<?> m : List.of(RouteRepository.class, FlightRepository.class, BoardingClassRepository.class,
                FareTypeRepository.class, PeakTimeRepository.class, MemberRepository.class, ReservationRepository.class)) {
            conf.addMapper(m);
        }
        session = new SqlSessionTemplate(new SqlSessionFactoryBuilder().build(conf));
        txManager = new DataSourceTransactionManager(ds);
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
        Reflect.set(reserve, "memberRepository", session.getMapper(MemberRepository.class));
        Reflect.set(reserve, "reservationRepository", session.getMapper(ReservationRepository.class));
        Reflect.set(reserve, "ticketSharedService", shared);
        reserveTx = transactional(reserve, TicketReserveService.class, txManager);

        Reflect.set(helper, "boardingClassProvider", boardingClassProvider);
        Reflect.set(helper, "flightMasterProvider", flightMasterProvider);
        Reflect.set(helper, "fareTypeProvider", fareTypeProvider);

        Reflect.set(reserveHelper, "beanMapper", new B2MapperImpl());
        Reflect.set(reserveHelper, "ticketReserveService", reserveTx);
        Reflect.set(reserveHelper, "ticketSharedService", shared); // @Transactional は付いていない
        Reflect.set(reserveHelper, "flightMasterProvider", flightMasterProvider);
        try {
            createReservation = TicketReserveHelper.class.getDeclaredMethod("createReservation", TicketReserveForm.class, List.class);
            createReservation.setAccessible(true);
        } catch (NoSuchMethodException e) {
            throw new IllegalStateException(e);
        }

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
        Reflect.set(reserveHelper, "dateFactory", c);
    }

    /** 原典の {@code @Transactional} の解釈（{@code @EnableTransactionManagement} の既定: 例外の種類は実行時例外で取り消し）で包む。 */
    static <T> T transactional(T target, Class<T> type, TransactionManager tm) {
        ProxyFactory pf = new ProxyFactory(target);
        pf.setInterfaces(type);
        pf.addAdvice(new TransactionInterceptor(tm, new AnnotationTransactionAttributeSource()));
        return type.cast(pf.getProxy());
    }

    /** 原典の private な {@code TicketReserveHelper.createReservation}（予約情報の組み立て）を呼ぶ。 */
    Reservation createReservation(TicketReserveForm form, List<Flight> flights) {
        try {
            return (Reservation) createReservation.invoke(reserveHelper, form, flights);
        } catch (InvocationTargetException e) {
            if (e.getCause() instanceof RuntimeException r) throw r;
            throw new IllegalStateException(e.getCause());
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
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
        // SqlSessionTemplate は Spring が閉じる（close は使えない）。接続はトランザクション・呼び出しごとに閉じている
    }
}
