(**
 * @copyright (c) 2011, Tohoku University.
 * @author UENO Katsuhiro
 * @author Atsushi Ohori
 *)
structure RecordKind : KIND_INSTANCE =
struct
  structure RC = RecordCalc
  structure D = DynamicKind
  structure T = Types

  type singleton_ty_body = RecordLabel.label * Types.ty
  type kind = DynamicKind.record * Types.ty RecordLabel.Map.map
  type instance = RecordCalc.rcexp
  val singletonTy = T.INDEXty

  fun compare ((l1, t1), (l2, t2)) =
      case RecordLabel.compare (l1, l2) of
        EQUAL => (case (TypesBasics.derefTy t1, TypesBasics.derefTy t2) of
                    (T.BOUNDVARty t1, T.BOUNDVARty t2) =>
                    BoundTypeVarID.compare (t1, t2)
                  | _ => raise Bug.Bug "compareIndex")
      | x => x

  fun generateArgs btvEnvrecordKind (btv, (indices, fields)) =
      RecordLabel.Map.listItems
        (RecordLabel.Map.mergeWithi
           (fn (l, _, NONE) => NONE
             | (l, NONE, SOME _) => SOME (T.INDEXty (l, T.BOUNDVARty btv))
             | (l, SOME _, SOME _) => NONE)
           (indices, fields))

  fun generateInstance {btvEnv, lookup} (arg as (label, ty)) loc =
      case TypesBasics.derefTy ty of
        ty as T.BOUNDVARty tid =>
        (case BoundTypeVarID.Map.find (btvEnv, tid) of
           SOME (kind as T.KIND {dynamicKind,...}) =>
           (case (case dynamicKind of
                    SOME x => SOME x
                  | NONE => DynamicKindUtils.kindOfStaticKind kind) of
              NONE => raise Bug.Bug "RecordKind.generateInstance"
            | SOME {record, ...} =>
              case RecordLabel.Map.find (record, label) of
                SOME n => SOME (RC.RCCONSTANT
                                  {const = RC.INDEX (n, label, ty),
                                   ty = T.SINGLETONty (singletonTy arg),
                                   loc = loc})
              | NONE => NONE)
         | NONE => raise Bug.Bug "generateInstance")
      | ty as T.RECORDty _ =>
        SOME (RC.RCINDEXOF (label, ty, loc))
      | ty as T.DUMMYty (id, T.KIND {tvarKind = T.REC _, ...}) =>
        SOME (RC.RCINDEXOF (label, ty, loc))
      | _ => NONE

end