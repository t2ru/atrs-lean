import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Domain.Common.Logging.LogMessages

原典の `jp.co.ntt.atrs.domain.common.logging.LogMessages`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/logging/LogMessages.java`）の写し。

予約の登録が使う `E_AR_A0_L9002`（更新件数の不一致）と、それを伝えるシステム例外（TERASOLUNA の `SystemException`）。
-/

namespace SourceModel.Domain.Common.Logging
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int

namespace LogMessages

/-- `SystemException` のクラス名。 -/
def systemExceptionClass : LangSemantics.Java.Exception.JClassName := cls!"org.terasoluna.gfw.common.exception.SystemException"

/-- `new SystemException(LogMessages.E_AR_A0_L9002.getCode(), LogMessages.E_AR_A0_L9002.getMessage(actual, expected))`。
例外のメッセージは、コードと引数を改行でつないだもの（`AtrsBusinessException.newArgs` と同じ表し方）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.logging.LogMessages.E_AR_A0_L9002@53a1080bdf3ccc39",
  "java:jp.co.ntt.atrs.domain.common.logging.LogMessages#getCode()@da85740cb21790bb",
  "java:jp.co.ntt.atrs.domain.common.logging.LogMessages#getMessage(Object...)@a089f7300284d09d",
  "dep:org.terasoluna.gfw:terasoluna-gfw-common#SystemException@terasoluna-gfw-common-5.11.0.RELEASE"]
def E_AR_A0_L9002 (actual expected : J32) : JThrow :=
  .other systemExceptionClass (String.intercalate "\n" ["e.ar.a0.L9002", toString actual.val, toString expected.val])

end LogMessages

end SourceModel.Domain.Common.Logging
