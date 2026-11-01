package specpivot.conformance;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.Map;
import java.util.function.Function;

/**
 * DI コンテナを起動せずに原典のクラスを組み立てる補助（references/docs/lang/java/harness.md）。
 * フィールド注入（{@code @Inject}・{@code @Value} のフィールド。private・package-private を問わない）と、
 * {@code @PostConstruct} などのメソッドの呼び出し、インタフェースの差し替え（{@link Proxy}）を行う。
 */
public final class Reflect {
    private Reflect() {}

    /** {@code target} のクラス階層から {@code name} のフィールドを探して値を入れる。 */
    public static <T> T set(T target, String name, Object value) {
        Field f = field(target.getClass(), name);
        try {
            f.setAccessible(true);
            f.set(target, value);
            return target;
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
    }

    public static Object get(Object target, String name) {
        Field f = field(target.getClass(), name);
        try {
            f.setAccessible(true);
            return f.get(target);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
    }

    private static Field field(Class<?> c, String name) {
        for (Class<?> k = c; k != null; k = k.getSuperclass()) {
            try {
                return k.getDeclaredField(name);
            } catch (NoSuchFieldException e) {
                // 親へ
            }
        }
        throw new IllegalArgumentException(c.getName() + " has no field " + name);
    }

    /** 引数の無いメソッド（{@code @PostConstruct} の {@code load()} など）を呼ぶ。 */
    public static Object call(Object target, String method) {
        try {
            Method m = target.getClass().getMethod(method);
            return m.invoke(target);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException(target.getClass().getName() + "#" + method, e);
        }
    }

    /**
     * インタフェース {@code type} の実装を、メソッド名ごとの関数（引数の配列 → 戻り値）で作る。割り当てていない
     * メソッドを呼ぶと {@link UnsupportedOperationException}（ハーネスの想定の外を黙って通さない）。
     */
    public static <T> T stub(Class<T> type, Map<String, Function<Object[], Object>> methods) {
        Object p = Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type}, (proxy, m, args) -> {
            if (m.getDeclaringClass() == Object.class) {
                return switch (m.getName()) {
                    case "toString" -> "stub " + type.getName();
                    case "hashCode" -> System.identityHashCode(proxy);
                    case "equals" -> proxy == args[0];
                    default -> throw new UnsupportedOperationException(m.getName());
                };
            }
            Function<Object[], Object> f = methods.get(m.getName());
            if (f == null) throw new UnsupportedOperationException(type.getName() + "#" + m.getName());
            return f.apply(args == null ? new Object[0] : args);
        });
        return type.cast(p);
    }
}
