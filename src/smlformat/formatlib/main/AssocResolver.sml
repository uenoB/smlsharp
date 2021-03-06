(**
 *  This module eliminates assoc indicators or replaces them with parentheses
 * if necessary.
 * @author YAMATODANI Kiyoshi
 * @copyright 2010, Tohoku University.
 * @version $Id: PreProcessor.sml,v 1.7 2010/02/09 07:53:18 katsu Exp $
 *)
structure AssocResolver =
struct

  (***************************************************************************)

  structure FE = FormatExpression

  (***************************************************************************)

  (**
   * remove assoc indicators from symbol.
   * Parentheses are inserted instead if necessary.
   *)
  fun resolve (parameter : PrinterParameter.parameterRecord) symbol =
      let
        (**
         * compare two assocs.
         * <p>
         * The weakThan relation('<') on assocs is defined as follows:
         * <ul>
         *   <li>An < Bm if n < m (A,B is L,R or N)</li>
         *   <li>Ln < Nn</li>
         *   <li>Rn < Nn</li>
         *   <li>p < q, if p < r and r < q</li>
         * </ul>
         * </p>
         * @params (left, right)
         * @param left a assoc to be compared.
         * @param right another assoc to be compared.
         * @return true if left < right
         *)
        fun weakThan (left : FE.assoc, right : FE.assoc) =
            if #strength left < #strength right
            then true
            else
              if #strength left = #strength right 
              then
                case (#direction left, #direction right) of
                  (FE.Left, FE.Neutral) => true
                | (FE.Right, FE.Neutral) => true
                | _ => false
              else false

        (**
         * equivalence of two assocs
         * @params (left, right)
         * @param left a assoc to be compared.
         * @param right another assoc to be compared.
         * @return true if left = right regardless of cut.
         *)
        fun equal (left : FE.assoc, right : FE.assoc) =
            #strength left = #strength right
            andalso #direction left = #direction right

        (**
         * enclose symbols in a pair of parentheses.
         * @params symbols
         * @param symbols a list of format expressions
         * @return the symbols enclosed in a pair of parentheses.
         *)
        fun encloseSymbols symbols =
            [
              FE.Term (1, #guardLeft parameter),
              FE.StartOfIndent 1,
(*
              FE.Indicator
              {
                space = false,
                newline =
                SOME {priority = FE.Preferred 1}
              }
*)
              FE.Sequence symbols,
(*
              FE.EndOfIndent,
              FE.Indicator
              {
                space = false,
                newline =
                SOME {priority = FE.Preferred 1}
              },
*)
              FE.Term (1, #guardRight parameter),
              FE.EndOfIndent
            ]

        (**
         *  visit format expressions to remove assoc indicators and insert
         * parentheses if needed.
         * @params enclosingAssoc symbol
         * @param  enclosingAssoc the assoc of the assoc indicator
         *       which enclose this symbol.
         * @param symbol the format expression to be visited.
         * @return a symbol which contains no assoc indicator.
         *)
        fun visit
            enclosingAssoc
            (FE.Guard (enclosedAssocOpt, symbols)) =
            let
              (* the assoc to inherit to the (first) children *)
              val inheritToFirstAssoc as {cut, strength, direction} =
                  case enclosedAssocOpt of
                    NONE => enclosingAssoc
                  | SOME(enclosedAssoc) => enclosedAssoc
              (* the assoc to inherit to the other children *)
              val inheritToOtherAssoc = 
                  {cut = cut, strength = strength, direction = FE.Neutral}

              fun revFE nil nil r = r
                | revFE nil (h :: t) r = revFE h t r
                | revFE (FE.Sequence x :: t) k r = revFE x (t :: k) r
                | revFE (h :: t) k r = revFE t k (h :: r)
              val revFE = fn l => revFE l nil nil

              fun mapRevFE f nil nil r = r
                | mapRevFE f nil (h :: t) r = mapRevFE f h t r
                | mapRevFE f (FE.Sequence x :: t) k r = mapRevFE f x (t :: k) r
                | mapRevFE f (h :: t) k r = mapRevFE f t k (f h :: r)
              val mapRevFE = fn f => fn l => mapRevFE f l nil nil

              (**
               *  Visit the children with specified assoc to inherit.
               *
               *  To the first Term of Guard, <code>toFirstChild</code> is
               * passed.
               *  The <code>toFirstChild</code> is passed also to the
               * FormatIndicator/EndOfIndent children between the head of list
               * and the first Term/Guard, although the passed assocs are 
               * ignored in these visit.
               *  To children after the first Term/Guard child,
               * <code>toOther</code> is passed.
               *)
              fun visitList (toFirstChild, toOther) children =
                  let
                    fun scan _ nil nil visited = visited
                      | scan i nil (h :: t) visited =
                        scan i h t visited
                      | scan i (FE.Sequence x :: t) k visited =
                        scan i x (t :: k) visited
                      | scan toInherit (head :: others) k visited =
                        let
                          val visited' = (visit toInherit head) :: visited
                        in
                          case head of
                            (* switch the assoc to pass to children. *)
                            FE.Guard _ => scan toOther others k visited'
                          | FE.Term _ => scan toOther others k visited'
                          | _ => scan toInherit others k visited'
                        end
                  in
                    scan toFirstChild children nil []
                  end

              val newSymbols =
                  case direction of 
                    FE.Left =>
                    (* pass Ln to the left-most child Term/Guard,
                     * Nn to the other following it. *)
                    revFE
                      (visitList
                         (inheritToFirstAssoc, inheritToOtherAssoc)
                         symbols)

                  | FE.Right =>
                    (* pass Rn to the right-most child Term/Guard,
                     * Nn to the other following it. *)
                    visitList
                      (inheritToFirstAssoc, inheritToOtherAssoc)
                      (revFE symbols)

                  | _ =>
                    revFE (mapRevFE (visit inheritToFirstAssoc) symbols)
            in
              case enclosedAssocOpt of
                NONE => FE.Guard (NONE, newSymbols)
              | SOME {cut = true, ...} => FE.Guard (NONE, newSymbols)
              | SOME enclosedAssoc =>
                if weakThan (enclosingAssoc, enclosedAssoc) orelse
                   equal (enclosingAssoc, enclosedAssoc)
                then FE.Guard (NONE, newSymbols)
                else FE.Guard (NONE, encloseSymbols newSymbols)
            end

          | visit enclosing symbol = symbol
      in
        visit {cut = true, strength = ~1, direction = FE.Neutral} symbol
      end
                 
  (***************************************************************************)

end
