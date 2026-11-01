import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import Spec.Model

/-!
# SourceModel.Domain.Model.FareTypeCd

原典の `jp.co.ntt.atrs.domain.model.FareTypeCd`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/model/FareTypeCd.java`）の写し。
-/

namespace SourceModel.Domain.Model
open LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Domain.Model
open LangSemantics.Sql.Postgresql

namespace FareTypeCd

/-- `FareTypeCd` の定数名（`Enum.name()`。MyBatis の `EnumTypeHandler` が束縛する値。出典は `bind` の `EnumTypeHandler`）。 -/
def name : Spec.Model.FareTypeCd → String
  | .OW => "OW" | .RT => "RT" | .RD1 => "RD1" | .RD7 => "RD7" | .ED => "ED"
  | .LD => "LD" | .GD => "GD" | .SOW => "SOW" | .SRT => "SRT" | .SRD => "SRD"

/-- `FareTypeCd.getCode()`（原典では `this.name()` を返す）。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()@3855e45998af62f8"]
def getCode : Spec.Model.FareTypeCd → String
  | .OW => "OW" | .RT => "RT" | .RD1 => "RD1" | .RD7 => "RD7" | .ED => "ED"
  | .LD => "LD" | .GD => "GD" | .SOW => "SOW" | .SRT => "SRT" | .SRD => "SRD"

/-- `Enum.valueOf(FareTypeCd.class, s)`。 -/
@[source "java:jp.co.ntt.atrs.domain.model.FareTypeCd#getCode()@3855e45998af62f8",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.ED@4ef203daf77cede7",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.GD@884d5bff79c10dff",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.LD@ab31ea4ae5075371",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.OW@7e4b60f4d2ee743b",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD1@1cfb19d902ca71fd",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RD7@5003a843107c47b7",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.RT@3165be96f5833ae0",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SOW@7b105823acf590f2",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRD@b111f3efc4632267",
  "java:jp.co.ntt.atrs.domain.model.FareTypeCd.SRT@8a21220051bcc7d6"]
def valueOf (s : String) : JResult Spec.Model.FareTypeCd :=
  match s with
  | "OW" => pure .OW | "RT" => pure .RT | "RD1" => pure .RD1 | "RD7" => pure .RD7 | "ED" => pure .ED
  | "LD" => pure .LD | "GD" => pure .GD | "SOW" => pure .SOW | "SRT" => pure .SRT | "SRD" => pure .SRD
  | _ => throw (.illegalArgument s!"No enum constant FareTypeCd.{s}")

end FareTypeCd

end SourceModel.Domain.Model
