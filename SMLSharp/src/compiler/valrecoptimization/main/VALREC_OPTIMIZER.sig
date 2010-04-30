(**
 * @copyright (c) 2006, Tohoku University.
 * @author NGUYEN Huu-Duc
 * @version $Id: VALREC_OPTIMIZER.sig,v 1.8 2007/12/15 08:30:36 bochao Exp $
 *)
signature VALREC_OPTIMIZER =
sig
  val optimize : VALREC_Utils.globalContext -> 
                 Counters.stamp ->
                 PatternCalcFlattened.plftopdec list -> 
                 (Counters.stamp * PatternCalcFlattened.plftopdec list)
end
