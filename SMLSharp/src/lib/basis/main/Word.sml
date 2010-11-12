(**
 * Word structure.
 * @author YAMATODANI Kiyoshi
 * @copyright 2010, Tohoku University.
 * @version $Id: Word.sml,v 1.6.14.1 2010/05/05 05:39:17 kiyoshiy Exp $
 *)
structure Word =
struct
  open Word

  (***************************************************************************)

  structure SC = StringCvt

  (***************************************************************************)

  type word = word

  (***************************************************************************)

  val wordSize = 32
  val MAX_WORD = 0xFFFFFFFF : IntInf.int

  fun toLarge word = word

  fun toLargeX word = word

  fun fromLarge largeWord = largeWord

  val toLargeWord = toLarge

  val toLargeWordX = toLargeX

  val fromLargeWord = fromLarge

  fun toLargeInt word = SMLSharp.Runtime.LargeInt_fromWord word

  (**
   * interprets a 32bit word as a 2's complement signed integer.
   * <ul>
   *   <li>toLargeIntX 0wxFFFFFFFF => ~1
   *   <li>toLargeIntX 0wx80000000 => ~0x80000000 (= 2147483648)
   * </ul>
   *)
  fun toLargeIntX word =
      (* FIXME: This should be implemented in native code as a primitive ? *)
      let
        val largeInt = SMLSharp.Runtime.LargeInt_fromWord word
      in
        if 0w0 = andb (0wx80000000, word)
        then largeInt
        else largeInt - 0xFFFFFFFF - 1
      end;

  fun fromLargeInt largeInt = SMLSharp.Runtime.LargeInt_toWord largeInt

  fun toInt word = 
      let val int = Word.toIntX word
      in if int < 0 then raise Overflow else int end

(*
  fun toIntX word = Word_toIntX word

  fun fromInt int = Word_fromInt int

  val orb = fn (left, right) => Word_orb (left, right)

  val xorb = fn (left, right) => Word_xorb (left, right)

  val andb = fn (left, right) => Word_andb (left, right)

  val notb = fn word => Word_notb word

  val op << = fn (left, right) => Word_leftShift (left, right)

  val op >> = fn (left, right) => Word_logicalRightShift (left, right)

  val op ~>> = fn (left, right) => Word_arithmeticRightShift (left, right)
*)

  (** returns the 2's complement. *)
  val ~ = fn word => notb word + 0w1

  fun compare (left : word, right) =
      if left < right
      then General.LESS
      else if left = right then General.EQUAL else General.GREATER

  fun min (left : word, right) = if left < right then left else right

  fun max (left : word, right) = if left > right then left else right

  local
    (*
     * Following functions can be defined by using the Char structure.
     * But because the Char structure refers to this Int structure,
     * we cannot rely on it to avoid a cyclic reference.
     *)
    fun charOfNum num = 
        case num of
          0w0 => #"0"
        | 0w1 => #"1"
        | 0w2 => #"2"
        | 0w3 => #"3"
        | 0w4 => #"4"
        | 0w5 => #"5"
        | 0w6 => #"6"
        | 0w7 => #"7"
        | 0w8 => #"8"
        | 0w9 => #"9"
        | 0w10 => #"A"
        | 0w11 => #"B"
        | 0w12 => #"C"
        | 0w13 => #"D"
        | 0w14 => #"E"
        | 0w15 => #"F"
        | _ => raise Fail "bug: Word.charOfNum"
    fun numOfChar char = 
        case char of
          #"0" => 0 : IntInf.int
        | #"1" => 1
        | #"2" => 2
        | #"3" => 3
        | #"4" => 4
        | #"5" => 5
        | #"6" => 6
        | #"7" => 7
        | #"8" => 8
        | #"9" => 9
        | #"A" => 10
        | #"a" => 10
        | #"B" => 11
        | #"b" => 11
        | #"C" => 12
        | #"c" => 12
        | #"D" => 13
        | #"d" => 13
        | #"E" => 14
        | #"e" => 14
        | #"F" => 15              
        | #"f" => 15
        | _ => raise Fail "bug: Int.numOfChar"
    fun numOfRadix radix =
        case radix of
          SC.BIN => 2 | SC.OCT => 8 | SC.DEC => 10 | SC.HEX => 16
    fun isNumChar radix =
        case radix of
          SC.BIN => (fn char => char = #"0" orelse char = #"1")
        | SC.OCT => (fn char => #"0" <= char andalso char <= #"7")
        | SC.DEC => (fn char => #"0" <= char andalso char <= #"9")
        | SC.HEX =>
          (fn char =>
              (#"0" <= char andalso char <= #"9")
              orelse (#"a" <= char andalso char <= #"f")
              orelse (#"A" <= char andalso char <= #"F"))
  in
  fun fmt radix (num : word) =
      let
        val radixNum = fromInt (numOfRadix radix)
        fun loop 0w0 chars = implode chars
          | loop n chars =
            loop (n div radixNum) ((charOfNum (n mod radixNum)) :: chars)
      in
        if 0w0 = num
        then "0"
        else loop num []
      end

  fun toString num = fmt SC.HEX num

  local
    structure PC = ParserComb
    (*  Basis spec requires that Word.scan raises an Overflow exception
     * when the scanned number is too large to fit in a word.
     * On the other hand, Basis spec requires that arithmetic operations of
     * Word do NOT raise Overflow.
     * So, we have to check any occurrence of overflow here.
     *)
    fun accumIntList base ints =
        foldl
            (fn (int, accum) =>
                let val value = accum * base + int
                in if IntInf.< (MAX_WORD, value) then raise Overflow else value
                end)
            0
            ints
    fun scanNumbers radix reader stream =
        let
          val (isNumberChar, charToNumber, base) =
              (isNumChar radix, numOfChar, numOfRadix radix)
        in
          PC.wrap
              (
                PC.oneOrMore(PC.wrap(PC.eatChar isNumberChar, charToNumber)),
                fromLargeInt o accumIntList (IntInf.fromInt base)
              )
              reader
              stream
        end
    fun scanZeroW reader stream = PC.string "0w" reader stream
    fun scanZeroX reader stream =
        PC.or'
         [PC.string "0wx", PC.string "0wX", PC.string "0x", PC.string "0X"]
        reader
        stream
  in
  fun scan radix reader stream =
      let
        val scanNumbers = scanNumbers radix
        fun scanBody reader stream =
            (case radix of
               StringCvt.HEX =>
               PC.or(PC.seqWith #2 (scanZeroX, scanNumbers), scanNumbers)
             | _ => PC.or(PC.seqWith #2 (scanZeroW, scanNumbers), scanNumbers))
            reader
            stream
      in
        scanBody reader (StringCvt.skipWS reader stream)
      end
  end
  end
  fun fromString string = (SC.scanString (scan SC.HEX)) string

  val op + = fn (left : word, right) => left + right

  val op - = fn (left : word, right) => left - right

  val op * = fn (left : word, right) => left * right

  val op div = op div : word * word -> word

  val op mod = op mod : word * word -> word

  fun op < (left : word, right : word) =
      case compare (left, right) of General.LESS => true | _ => false
  fun op <= (left : word, right : word) =
      case compare (left, right) of General.GREATER => false | _ => true
  val op > = not o (op <=)
  val op >= = not o (op <)

  (***************************************************************************)

end;