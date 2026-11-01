package specpivot.conformance.http;

import org.apache.catalina.Context;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.startup.Tomcat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

/**
 * web.xml を持つ webapp を、組み込み Tomcat で起動する（HTTP レベルのオラクル。references/docs/lang/java/harness.md）。
 *
 * <ul>
 * <li>web.xml は原典のまま読む（ContextConfig）。クラスは webapp の WEB-INF でなく、ハーネスのクラスパスから読む
 * （WebappClassLoader の親）。</li>
 * <li>Tomcat の既定の web.xml（JSP・DefaultServlet）は足さない。原典の web.xml に無いサーブレットを増やさないためである。</li>
 * <li>構成の差し替えは、web.xml に手を入れず、context-param を足して行う（例 Spring の {@code globalInitializerClasses}）。
 * web.xml に同じ名前の context-param があれば、原典を優先して起動を止める。</li>
 * <li>待ち受けは 127.0.0.1 の空いているポート。</li>
 * </ul>
 */
public final class WebappServer implements AutoCloseable {
    private final Tomcat tomcat;
    private final String contextPath;

    private WebappServer(Tomcat tomcat, String contextPath) {
        this.tomcat = tomcat;
        this.contextPath = contextPath;
    }

    public static WebappServer start(Path docBase, String contextPath, Map<String, String> extraContextParams) {
        try {
            String webXml = Files.readString(docBase.resolve("WEB-INF/web.xml"));
            for (String k : extraContextParams.keySet()) {
                if (webXml.contains("<param-name>" + k + "</param-name>")) {
                    throw new IllegalStateException("web.xml already defines context-param " + k);
                }
            }
            Path base = Files.createTempDirectory("webapp-server");
            Tomcat t = new Tomcat();
            t.setBaseDir(base.toString());
            t.setHostname("127.0.0.1");
            t.setPort(0);
            t.getConnector().setProperty("address", "127.0.0.1");
            t.setAddDefaultWebXmlToWebapp(false);
            t.getHost().setAutoDeploy(false);
            Context ctx = t.addWebapp(contextPath, docBase.toAbsolutePath().toString());
            ctx.setParentClassLoader(Thread.currentThread().getContextClassLoader());
            ctx.getJarScanner().setJarScanFilter((type, name) -> false);
            extraContextParams.forEach(ctx::addParameter);
            t.start();
            if (!ctx.getState().isAvailable()) {
                t.stop();
                throw new IllegalStateException("webapp failed to start: " + ctx.getState());
            }
            return new WebappServer(t, contextPath);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        } catch (LifecycleException e) {
            throw new IllegalStateException(e);
        }
    }

    public int port() { return tomcat.getConnector().getLocalPort(); }

    /** {@code http://127.0.0.1:<port><contextPath>} */
    public String baseUrl() { return "http://127.0.0.1:" + port() + contextPath; }

    @Override
    public void close() {
        try {
            tomcat.stop();
            tomcat.destroy();
        } catch (LifecycleException e) {
            throw new IllegalStateException(e);
        }
    }
}
