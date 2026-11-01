package atrsoracle;

import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.support.BeanDefinitionRegistry;
import org.springframework.beans.factory.support.RootBeanDefinition;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.MapPropertySource;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * HTTP レベルのオラクルで、原典の構成を差し替える初期化子（web.xml には手を入れず、context-param
 * {@code globalInitializerClasses} で、ルートと 2 つの DispatcherServlet の文脈すべてに掛ける）。差し替えるのは次だけで、
 * docs/spec/assurance.md の「オラクルのハーネスの対象外」に載せる。
 *
 * <ul>
 * <li>{@code database.url}・{@code database.username}・{@code database.password}: シードを投入した DB（{@link HttpOracle}）。
 * 原典の {@code atrs-infra.properties} より環境の値が優先される（PropertySourcesPlaceholderConfigurer の既定）。</li>
 * <li>{@code report.dir}: 一時ディレクトリ（予約履歴レポートの出力先）。</li>
 * <li>{@code dateFactory}: 決めた時刻に止めた時計（{@link FixedClockFactory}。システムプロパティ {@code oracle.now}）。</li>
 * </ul>
 */
public final class OracleContextInitializer implements ApplicationContextInitializer<ConfigurableApplicationContext> {
    static final String PREFIX = "oracle.override.";

    @Override
    public void initialize(ConfigurableApplicationContext ctx) {
        Map<String, Object> props = new LinkedHashMap<>();
        System.getProperties().forEach((k, v) -> {
            if (k.toString().startsWith(PREFIX)) props.put(k.toString().substring(PREFIX.length()), v);
        });
        ctx.getEnvironment().getPropertySources().addFirst(new MapPropertySource("oracle-overrides", props));
        LocalDateTime now = LocalDateTime.parse(System.getProperty("oracle.now", SeedDb.LOAD_DATE + "T10:00:00"));
        ctx.addBeanFactoryPostProcessor((BeanFactoryPostProcessor) bf -> {
            if (bf instanceof BeanDefinitionRegistry reg && reg.containsBeanDefinition("dateFactory")) {
                reg.removeBeanDefinition("dateFactory");
                RootBeanDefinition def = new RootBeanDefinition(FixedClockFactory.class, () -> new FixedClockFactory(now));
                reg.registerBeanDefinition("dateFactory", def);
            }
        });
    }
}
