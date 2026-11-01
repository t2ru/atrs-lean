package specpivot.conformance;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * ベクタの操作 1 つの割当。ケース（{@code cases[]} の要素。{@code input} などを含む）を受け取り、{@code expected.ok} と比べる値を返す
 * （Lean の {@code ConformanceKit.Runner.Op} と同じ約束）。業務上の失敗をベクタが値として書く場合（例 {@code {"error": {kind, code}}}）は、
 * その値を返す。期待値の形にできない結果（想定外の例外など）は、例外を投げてケースの失敗にする。
 */
@FunctionalInterface
public interface Op {
    JsonNode run(JsonNode testCase) throws Exception;
}
