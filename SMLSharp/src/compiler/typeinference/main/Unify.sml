(**
 * a kinded unification for ML, an imperative version.
 * @copyright (c) 2006-2010, Tohoku University.
 * @author Atsushi Ohori 
 * @author Liu Bochao
 *)
structure Unify : UNIFY =
struct
  structure T = Types
  structure TU = TypesUtils
  structure TB = TypeinfBase

  exception Unify
  exception EqRawTy

  fun bug s = Control.Bug ("Unify:" ^ s)
  fun printType ty = print (TypeFormatter.tyToString ty ^ "\n")

  fun occurres tvarRef ty = OTSet.member (TU.EFTV ty, tvarRef)
  fun occurresTyList tvarRef nil = false
    | occurresTyList tvarRef (h::t) = 
      occurres tvarRef h orelse occurresTyList tvarRef t
  fun occurresTyEqList tvarRef nil = false
    | occurresTyEqList tvarRef ((h1,h2)::t) = 
      occurres tvarRef h1
      orelse occurres tvarRef h2
      orelse occurresTyEqList tvarRef t
                                
  exception TyConId
  fun tyConId ty = 
      case TU.derefTy ty of
        T.RAWty {tyCon = {id, ...}, args} => id
      | _ => raise TyConId

  fun checkKind ty 
                {
                 tyvarName,
                 eqKind,
                 lambdaDepth,
                 recordKind,
                 id
                }
                =
      let
        val _ = 
            case tyvarName of NONE => () | SOME _ => raise Unify
        val _ =
            (case eqKind of T.EQ => CheckEq.checkEq ty | _ => ())
            handle CheckEq.Eqcheck => raise Unify
        val _ = TU.adjustDepthInTy lambdaDepth ty
        val newTyEquations = 
            case recordKind of
              T.REC kindFields =>
              (case ty of 
                 T.RECORDty tyFields =>
                 SEnv.foldri
                   (fn (l, ty, tyEquations) =>
                       (
                        ty, 
                        case SEnv.find(tyFields, l) of
                          SOME ty' => ty'
                        | NONE => raise Unify
                       ) :: tyEquations)
                   nil
                   kindFields
               | T.TYVARty _ => raise bug "checkKind"
               | _ => raise Unify)
            | T.OCONSTkind L =>
              (case List.filter
                      (fn x => TyConID.eq(tyConId x, tyConId ty)
                               handle TyConId => raise Unify
                      )
                      L of
                 [ty1] => [(ty,ty1)]
               | _ => raise Unify)
            | T.OPRIMkind {instances, operators} => 
              (case List.filter
                      (fn x => TyConID.eq(tyConId x, tyConId ty)
                               handle TyConId => raise Unify
                      )
                      instances
                of
                 [ty1] => [(ty,ty1)]
               | _ => raise Unify)
            | T.UNIV => nil
      in
        newTyEquations
      end
        
  and lubKind 
        (
         {
          tyvarName = tyvarName1,
          eqKind = eqKind1,
          lambdaDepth = lambdaDepth1,
          recordKind = recordKind1,
          id = id1
         } : T.tvKind,
         {
          tyvarName = tyvarName2,
          eqKind = eqKind2,
          lambdaDepth = lambdaDepth2,
          recordKind = recordKind2,
          id = id2
         } : T.tvKind
        ) =
      let 
        fun lubTyList(tyList1, tyList2) = 
            let
              fun find ty nil = NONE
                | find ty (ty'::tyList) = 
                  if TyConID.eq(tyConId ty,tyConId ty')
                     handle TyConId => raise bug "non rawty in oprim kind"
                  then
                    SOME ty' 
                  else find ty tyList
              val (tyList, newEqs) =
                  foldr
                  (fn (ty, (tyList,newEqs)) =>
                      case find ty tyList2 of
                        NONE => (tyList,newEqs)
                      | SOME ty' => (ty::tyList,(ty,ty') :: newEqs)
                  )
                  (nil,nil)
                  tyList1
            in
              case tyList of nil => raise Unify
                           | _ => (tyList, newEqs)
            end
        val tyvarName =
            case (tyvarName1, tyvarName2) of
              (NONE, NONE) => NONE
             | _ =>  raise Unify
        val (eqKind, recordKind1, recordKind2) =
            (case (eqKind1, eqKind2) of
               (T.NONEQ, T.NONEQ) => (T.NONEQ, recordKind1, recordKind2)
             | (T.EQ, T.EQ) => (T.EQ, recordKind1, recordKind2)
             | (T.NONEQ, T.EQ) =>
               (T.EQ, TU.coerceReckindToEQ recordKind1, recordKind2)
             | (T.EQ, T.NONEQ) =>
               (T.EQ, recordKind1, TU.coerceReckindToEQ recordKind2)
            )
            handle TU.CoerceRecKindToEQ => raise Unify
        val lambdaDepth = 
            case Int.compare (lambdaDepth1, lambdaDepth2) of
                LESS => 
                (
                 TU.adjustDepthInRecKind lambdaDepth1 recordKind2;
                 lambdaDepth1
                )
              | GREATER =>
                (
                 TU.adjustDepthInRecKind lambdaDepth2 recordKind1;
                 lambdaDepth2
                )
              | EQUAL => lambdaDepth1
        val (newRecKind, newTyEquations) = 
            case (recordKind1, recordKind2) of
              (T.REC fl1, T.REC fl2) =>
              let 
                val newTyEquations = 
                    SEnv.listItems
                      (SEnv.intersectWith (fn x => x) (fl1, fl2))
                val newTyFields = SEnv.unionWith #1 (fl1, fl2)
              in (T.REC newTyFields, newTyEquations)
              end
            | (T.OCONSTkind L1, T.OCONSTkind L2) => 
              let
                val (tyList, newEqs) = lubTyList(L1,L2)
              in
                (T.OCONSTkind tyList, newEqs)
              end
            | (T.OCONSTkind L1,
               T.OPRIMkind {instances, operators}) => 
              let
                val (tyList, newEqs) = lubTyList(L1,instances)
              in
                (T.OCONSTkind tyList, newEqs)
              end
            | (T.OPRIMkind {instances, operators},
               T.OCONSTkind L2) => 
              let
                val (tyList, newEqs) = lubTyList(instances, L2)
              in
                (T.OCONSTkind tyList, newEqs)
              end
            | (
               T.OPRIMkind {instances = I1, operators = O1},
               T.OPRIMkind {instances = I2, operators = O2}
              ) =>
              let
                fun find (op1:T.operator) (nil:T.operator list) = NONE
                  | find  op1 (op2::opList) =
                    if OPrimID.eq(#oprimId op1, #oprimId op2) then
                      SOME op2
                    else find op1 opList
                (* we do not and should not generate equations from 
                   (O1,O2) 
                 *)
                val O2 =
                    foldr
                    (fn (op2, O2) =>
                        let
                          val op1Opt = find op2 O1
                        in
                          case op1Opt of
                            SOME _ => O2
                          | NONE => op2::O2
                        end
                    )
                    nil
                    O2
                val (I,newEqs) = lubTyList(I1,I2)
              in
                case I of 
                  nil => raise Unify
                | _ => 
                  (T.OPRIMkind
                     {
                      instances = I,
                      operators = O1@O2
                     },
                   newEqs)
              end
            | (T.UNIV, x) => (x,nil)
            | (x, T.UNIV) => (x,nil)
            | _ => raise Unify
      in 
        (
         {
          lambdaDepth = lambdaDepth,
          recordKind = newRecKind, 
          eqKind = eqKind, 
          tyvarName = tyvarName,
          id = id1
         },
         newTyEquations
        )
      end

  (**
   * The mysterious control flag "calledFromPatternUnify" should be
   * eiminated in future.
   *)
  and unifyTypeEquations calledFromPatternUnify L =
      let
        fun unifyTy nil = ()
          | unifyTy ((ty1, ty2) :: tail) = 
            case (ty1, ty2) of
           (* Special types: SUBSTITUTED, ALIASty, ERRORty, DUMMYty,
            * OPAQUEty, SPECty. These cases are all disjoint.
            *)
              (T.TYVARty (ref(T.SUBSTITUTED derefTy1)), _)
              => unifyTy ((derefTy1, ty2) :: tail)
            | (_, T.TYVARty (ref(T.SUBSTITUTED derefTy2)))
              => unifyTy ((ty1, derefTy2) :: tail)
            | (T.ALIASty(_, ty1), _) => unifyTy ((ty1, ty2) :: tail)
            | (ty1, T.ALIASty(_, ty2)) => unifyTy ((ty1, ty2) :: tail)
            | (T.ERRORty, _) => unifyTy tail
            | (_, T.ERRORty) => unifyTy tail
            | (T.DUMMYty n2, T.DUMMYty n1) =>
              if n1 = n2 then unifyTy tail else raise Unify
            | (T.DUMMYty _, _) => raise Unify
            | (_, T.DUMMYty _) => raise Unify
            | (T.OPAQUEty {spec={tyCon={id=id1, ...}, args = args1}, ...},
               T.OPAQUEty {spec={tyCon={id=id2, ...}, args = args2}, ...})
              =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
            | (T.OPAQUEty {spec={tyCon={id = id1,...}, args = args1},...},
               T.RAWty {tyCon = {id = id2,...}, args = args2})
              =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
            | (T.RAWty {tyCon = {id = id1, ...}, args = args1},
               T.OPAQUEty {spec = {tyCon={id = id2, ...}, args = args2},...})
              =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
            | (T.SPECty {tyCon = {id = id1, ...}, args = args1},
               T.SPECty {tyCon = {id = id2, ...}, args = args2}) =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
            | (T.SPECty {tyCon = {id = id1, ...}, args = args1},
               T.RAWty {tyCon = {id = id2, ...}, args = args2}) =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
            | (T.RAWty {tyCon = {id = id1, ...}, args = args1},
               T.SPECty {tyCon = {id = id2, ...}, args = args2}) =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length args1 = length args2
                then unifyTy (ListPair.zip (args1, args2) @ tail)
                else raise Unify
              end
           (* type variables *)
            | (
               T.TYVARty(tvState1 as ref(T.TVAR {tyvarName = SOME _,
                                                 eqKind = eqkind1,
                                                 recordKind= T.UNIV,
                                             ...})),
               T.TYVARty(tvState2 as ref(T.TVAR {lambdaDepth,
                                                 tyvarName = NONE,
                                                 eqKind = eqkind2,
                                                 recordKind= T.UNIV,
                                             ...}))
              ) =>
              let
                val _ =
                    case (eqkind1, eqkind2) of
                      (T.NONEQ, T.EQ) => raise Unify
                    | _ => ()
              in
                (
                 TU.adjustDepthInTy lambdaDepth ty1;
                 TU.performSubst(ty2, ty1); 
                 unifyTy  tail
                )
              end
            | (
               T.TYVARty(tvState1 as ref(T.TVAR {lambdaDepth,
                                                 tyvarName = NONE,
                                                 eqKind = eqkind1,
                                                 recordKind= T.UNIV,
                                                 ...})),
               T.TYVARty(tvState2 as ref(T.TVAR {tyvarName = SOME _,
                                                 eqKind = eqkind2,
                                                 recordKind= T.UNIV,
                                                 ...}))
              ) =>
              let
                val _ =
                    case (eqkind1, eqkind2) of
                      (T.EQ, T.NONEQ) => raise Unify
                    | _ => ()
              in
                (
                 TU.adjustDepthInTy lambdaDepth ty2;
                 TU.performSubst(ty1, ty2); 
                 unifyTy tail
                )
              end
            | (
               T.TYVARty (tvState1 as (ref(T.TVAR tvKind1))),
               T.TYVARty (tvState2 as (ref(T.TVAR tvKind2)))
              ) => 
              if FreeTypeVarID.eq(#id tvKind1, #id tvKind2) then unifyTy tail
              else if occurres tvState1 ty2 orelse occurres tvState2 ty1 
              then raise Unify
              else 
                let 
                  val (newKind, newTyEquations) = lubKind (tvKind1, tvKind2)
                  val newTy = T.newtyRaw {tyvarName = #tyvarName newKind,
                                          lambdaDepth = #lambdaDepth newKind,
                                          recordKind = #recordKind newKind,
                                          eqKind = #eqKind newKind}
                in
                  unifyTy newTyEquations;
                  TU.performSubst(ty1, newTy);
                  TU.performSubst(ty2, newTy);
                  unifyTy tail
                end
            | (
               T.TYVARty (tvState1 as ref(T.TVAR tvKind1)),
               _
              ) =>
              if occurres tvState1 ty2 
              then raise Unify
              else
                let
                  val newTyEquations = checkKind ty2 tvKind1
                  val _ = unifyTy newTyEquations
                in
                  (
                   TU.performSubst(ty1, ty2); 
                   unifyTy tail
                  )
                end

            | (
               _,
               T.TYVARty (tvState2 as ref(T.TVAR tvKind2))
              ) =>
              if occurres tvState2 ty1
              then raise Unify
              else
                let
                  val newTyEquations = checkKind ty1 tvKind2
                  val _ = unifyTy newTyEquations
                in
                  (
                   TU.performSubst(ty2, ty1); 
                   unifyTy tail
                  )
                end

           (* constructor types *)
            | (
               T.FUNMty(domainTyList1, rangeTy1),
               T.FUNMty(domainTyList2, rangeTy2)
              ) =>
              if length domainTyList1 = length domainTyList2 then
                unifyTy (ListPair.zip (domainTyList1, domainTyList2)
                         @ ((rangeTy1, rangeTy2) :: tail))
              else raise Unify
            | (
               T.RAWty {tyCon = {id = id1,...}, args = tyList1},
               T.RAWty {tyCon = {id = id2,...}, args = tyList2}
              ) =>
              let
                val omit = calledFromPatternUnify orelse TyConID.eq(id1, id2)
              in
                if omit andalso length tyList1 = length tyList2
                then unifyTy  (ListPair.zip (tyList1, tyList2) @ tail)
                else raise Unify
              end
            | (T.RECORDty tyFields1, T.RECORDty tyFields2) =>
              let
                val (newTyEquations, rest) = 
                    SEnv.foldri 
                      (fn (label, ty1, (newTyEquations, rest)) =>
                          let val (rest, ty2) = SEnv.remove(rest, label)
                          in ((ty1, ty2) :: newTyEquations, rest) end
                          handle LibBase.NotFound => raise Unify)
                      (nil, tyFields2)
                      tyFields1
              in
                if SEnv.isEmpty rest 
                then unifyTy (newTyEquations@tail)
                else raise Unify
              end
            | (T.INSTCODEty {oprimId=oprimId1,
                             oprimPolyTy=oprimPolyTy1,
                             name = name1,
                             keyTyList = KeyTyList1,
                             instTyList = instTyList1
                            },
               T.INSTCODEty {oprimId=oprimId2,
                             oprimPolyTy=oprimPolyTy2,
                             name = name2,
                             keyTyList = KeyTyList2,
                             instTyList = instTyList2
                            }
              ) =>
              (* keyTyList(i) is a subset of instTyList(i) *)
              if OPrimID.eq (oprimId1, oprimId2) then
                unifyTy (ListPair.zip (instTyList1,instTyList2)@tail)
              else raise Unify
            | (ty1, ty2) => raise Unify
      in
        unifyTy L
      end

  (**
   * Perform imperative unification. When it succeeds, the unifier had
   * already been applied. 
   * 
   * @params typeEqs
   * @return nil 
   *)
  fun unify typeEqs = unifyTypeEquations false typeEqs

  (* Note: only used in type instantiation for signature match.
   * Since signature match guaranttes the type is correct
   * we just need to do patternUnify to avoid a problem causing
   * by the following case :
   * 
   *   structure A = struct ... end :> sig ... end : sig ... end
   *
   * For opaque signature matching, we generate a type instantiation
   * environment based on the actual structure environment and the 
   * type instantiated signature environment (instead of the abstract 
   * signature environment). And then We do transparent signature
   * match, but the instantiated type in transparent signature is 
   * enriched by the opaque signature instead of the original structure
   * environment. So unification on types fails. But since signature match
   * guarrantees the type correctness, we only need to do patternUnify.
   *)
  fun patternUnify typeEqs = unifyTypeEquations true typeEqs

end