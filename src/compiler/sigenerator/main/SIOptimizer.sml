(** symbolic code optimization
 * @copyright (c) 2006, Tohoku University.
 * @author Nguyen Huu-Duc
 * @version $Id: SIOptimizer.sml,v 1.3 2007/06/20 06:50:41 kiyoshiy Exp $
 *)
structure SIOptimizer : SIOPTIMIZER = struct

  structure CTX = SIGContext
  structure BT = BasicTypes
  open SymbolicInstructions

  structure Entry_ord:ordsig = struct 
  type ord_key = entry

  fun compare ({id = id1, displayName = displayName1},{id = id2, displayName = displayName2}) =
      ID.compare(id1,id2)
  end
  
  structure EntryMap = BinaryMapFn(Entry_ord)
  structure EntrySet = BinarySetFn(Entry_ord)

  datatype SizeListKind =
           EmptySizeList
         | SingletonSizeList of size
         | SingleSizeList 
         | LastArbitrarySizeList of size
         | FixedSizeList of BT.UInt32 list
         | VariantSizeList 

  fun allFixedSizes context [] L = SOME (rev L)
    | allFixedSizes context (sizeEntry::rest) L =
      (
       case CTX.wordOf context sizeEntry of
         SOME w => allFixedSizes context rest (w::L)
       | NONE => NONE
      )

  fun computeSizeListKind context [] = EmptySizeList
    | computeSizeListKind context [sizeEntry] = 
      (
       case CTX.wordOf context sizeEntry of
         SOME 0w1 => SingletonSizeList SINGLE
       | SOME 0w2 => SingletonSizeList DOUBLE
       | _ => SingletonSizeList (VARIANT sizeEntry)
      )
    | computeSizeListKind context sizeEntries = 
      let
        val L = rev sizeEntries
        val sizeEntries = rev (List.tl L)
        val lastSizeEntry = List.hd L
      in
        case allFixedSizes context sizeEntries [] of
          SOME sizes => 
          (
           if List.all (fn w => w = 0w1) sizes 
           then
             case CTX.wordOf context lastSizeEntry of
               SOME 0w0 => FixedSizeList (sizes @ [0w0])
             | SOME 0w1 => SingleSizeList
             | SOME 0w2 => LastArbitrarySizeList DOUBLE
             | NONE => LastArbitrarySizeList (VARIANT lastSizeEntry)
           else
             case CTX.wordOf context lastSizeEntry of
               SOME w => FixedSizeList (sizes @ [w])
             | _ => VariantSizeList
          )
        | NONE => VariantSizeList
      end

  fun optimizeCallPrim context (instruction as CallPrim {primitive, argEntries, destination}) =
      let
        val intOf = CTX.intOf context
        val wordOf = CTX.wordOf context
        fun charOf entry = 
            case CTX.charOf context entry of 
              SOME ch => SOME (Word32.fromInt (Char.ord ch))
            | NONE => NONE
        val realOf = CTX.realOf context
        val floatOf = CTX.floatOf context
            
        fun optimize converter (operator1, operator2) (argEntry1, argEntry2) =
            case (converter argEntry1, converter argEntry2) of
              (SOME v, NONE) => 
              operator1 {argValue1 = v, argEntry2 = argEntry2, destination = destination}
            | (NONE, SOME v) =>
              operator2 {argEntry1 = argEntry1, argValue2 = v, destination = destination}
            | _ => instruction

      in
        case (#bindName primitive, argEntries) of
          ("addInt", [arg1,arg2]) => optimize intOf (AddInt_Const_1, AddInt_Const_2) (arg1, arg2)
        | ("addReal", [arg1,arg2]) => optimize realOf (AddReal_Const_1, AddReal_Const_2) (arg1, arg2)
        | ("addWord", [arg1,arg2]) => optimize wordOf (AddWord_Const_1, AddWord_Const_2) (arg1, arg2)
        | ("addByte", [arg1,arg2]) => optimize wordOf (AddByte_Const_1, AddByte_Const_2) (arg1, arg2)

        | ("subInt", [arg1,arg2]) => optimize intOf (SubInt_Const_1, SubInt_Const_2) (arg1, arg2)
        | ("subReal", [arg1,arg2]) => optimize realOf (SubReal_Const_1, SubReal_Const_2) (arg1, arg2)
        | ("subWord", [arg1,arg2]) => optimize wordOf (SubWord_Const_1, SubWord_Const_2) (arg1, arg2)
        | ("subByte", [arg1,arg2]) => optimize wordOf (SubByte_Const_1, SubByte_Const_2) (arg1, arg2)

        | ("mulInt", [arg1,arg2]) => optimize intOf (MulInt_Const_1, MulInt_Const_2) (arg1, arg2)
        | ("mulReal", [arg1,arg2]) => optimize realOf (MulReal_Const_1, MulReal_Const_2) (arg1, arg2)
        | ("mulWord", [arg1,arg2]) => optimize wordOf (MulWord_Const_1, MulWord_Const_2) (arg1, arg2)
        | ("mulByte", [arg1,arg2]) => optimize wordOf (MulByte_Const_1, MulByte_Const_2) (arg1, arg2)

        | ("divInt", [arg1,arg2]) => optimize intOf (DivInt_Const_1, DivInt_Const_2) (arg1, arg2)
        | ("/", [arg1,arg2]) => optimize realOf (DivReal_Const_1, DivReal_Const_2) (arg1, arg2)
        | ("divWord", [arg1,arg2]) => optimize wordOf (DivWord_Const_1, DivWord_Const_2) (arg1, arg2)
        | ("divByte", [arg1,arg2]) => optimize wordOf (DivByte_Const_1, DivByte_Const_2) (arg1, arg2)

        | ("modInt", [arg1,arg2]) => optimize intOf (ModInt_Const_1, ModInt_Const_2) (arg1, arg2)
        | ("modWord", [arg1,arg2]) => optimize wordOf (ModWord_Const_1, ModWord_Const_2) (arg1, arg2)
        | ("modByte", [arg1,arg2]) => optimize wordOf (ModByte_Const_1, ModByte_Const_2) (arg1, arg2)

        | ("quotInt", [arg1,arg2]) => optimize intOf (QuotInt_Const_1, QuotInt_Const_2) (arg1, arg2)
        | ("remInt", [arg1,arg2]) => optimize intOf (RemInt_Const_1, RemInt_Const_2) (arg1, arg2)

        | ("ltInt", [arg1,arg2]) => optimize intOf (LtInt_Const_1, LtInt_Const_2) (arg1, arg2)
        | ("ltReal", [arg1,arg2]) => optimize realOf (LtReal_Const_1, LtReal_Const_2) (arg1, arg2)
        | ("ltWord", [arg1,arg2]) => optimize wordOf (LtWord_Const_1, LtWord_Const_2) (arg1, arg2)
        | ("ltByte", [arg1,arg2]) => optimize wordOf (LtByte_Const_1, LtByte_Const_2) (arg1, arg2)
        | ("ltChar", [arg1,arg2]) => optimize charOf (LtChar_Const_1, LtChar_Const_2) (arg1, arg2)

        | ("gtInt", [arg1,arg2]) => optimize intOf (GtInt_Const_1, GtInt_Const_2) (arg1, arg2)
        | ("gtReal", [arg1,arg2]) => optimize realOf (GtReal_Const_1, GtReal_Const_2) (arg1, arg2)
        | ("gtWord", [arg1,arg2]) => optimize wordOf (GtWord_Const_1, GtWord_Const_2) (arg1, arg2)
        | ("gtByte", [arg1,arg2]) => optimize wordOf (GtByte_Const_1, GtByte_Const_2) (arg1, arg2)
        | ("gtChar", [arg1,arg2]) => optimize charOf (GtChar_Const_1, GtChar_Const_2) (arg1, arg2)

        | ("lteqInt", [arg1,arg2]) => optimize intOf (LteqInt_Const_1, LteqInt_Const_2) (arg1, arg2)
        | ("lteqReal", [arg1,arg2]) => optimize realOf (LteqReal_Const_1, LteqReal_Const_2) (arg1, arg2)
        | ("lteqWord", [arg1,arg2]) => optimize wordOf (LteqWord_Const_1, LteqWord_Const_2) (arg1, arg2)
        | ("lteqByte", [arg1,arg2]) => optimize wordOf (LteqByte_Const_1, LteqByte_Const_2) (arg1, arg2)
        | ("lteqChar", [arg1,arg2]) => optimize charOf (LteqChar_Const_1, LteqChar_Const_2) (arg1, arg2)

        | ("gteqInt", [arg1,arg2]) => optimize intOf (GteqInt_Const_1, GteqInt_Const_2) (arg1, arg2)
        | ("gteqReal", [arg1,arg2]) => optimize realOf (GteqReal_Const_1, GteqReal_Const_2) (arg1, arg2)
        | ("gteqWord", [arg1,arg2]) => optimize wordOf (GteqWord_Const_1, GteqWord_Const_2) (arg1, arg2)
        | ("gteqByte", [arg1,arg2]) => optimize wordOf (GteqByte_Const_1, GteqByte_Const_2) (arg1, arg2)
        | ("gteqChar", [arg1,arg2]) => optimize charOf (GteqChar_Const_1, GteqChar_Const_2) (arg1, arg2)

        | ("Word_andb", [arg1,arg2]) => optimize wordOf (Word_andb_Const_1, Word_andb_Const_2) (arg1, arg2)
        | ("Word_orb", [arg1,arg2]) => optimize wordOf (Word_orb_Const_1, Word_orb_Const_2) (arg1, arg2)
        | ("Word_xorb", [arg1,arg2]) => optimize wordOf (Word_xorb_Const_1, Word_xorb_Const_2) (arg1, arg2)
        | ("Word_leftShift", [arg1,arg2]) => 
          optimize wordOf (Word_leftShift_Const_1, Word_leftShift_Const_2) (arg1, arg2)
        | ("Word_logicalRightShift", [arg1,arg2]) => 
          optimize wordOf (Word_logicalRightShift_Const_1, Word_logicalRightShift_Const_2) (arg1, arg2)
        | ("Word_arithmeticRightShift", [arg1,arg2]) => 
          optimize wordOf (Word_arithmeticRightShift_Const_1, Word_arithmeticRightShift_Const_2) (arg1, arg2)

        | _ => instruction
      end
    | optimizeCallPrim context instruction = raise Control.Bug "CallPrim is expected"


  fun optimizeInstruction context instruction = 
      case instruction of
        AccessNestedEnv{nestLevel,offset,variableSize,destination} =>
        if nestLevel = 0w0
        then
          AccessEnv 
              {
               offset = offset, 
               variableSize = variableSize,
               destination = destination
              }
        else instruction
      | GetFieldIndirect{blockEntry,fieldOffsetEntry,fieldSize,destination} =>
        (
         case CTX.wordOf context fieldOffsetEntry of
           SOME fieldOffset =>
           GetField
               {
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                destination = destination
               }
         | NONE => instruction
        )
      | GetNestedField{nestLevel,blockEntry,fieldOffset,fieldSize,destination} =>
        if nestLevel = 0w0
        then
          GetField
              {
               blockEntry = blockEntry,
               fieldOffset = fieldOffset,
               fieldSize = fieldSize,
               destination = destination
              }
        else instruction
      | GetNestedFieldIndirect{nestLevelEntry,blockEntry,fieldOffsetEntry,fieldSize,destination} =>
        (
         case (CTX.wordOf context nestLevelEntry, CTX.wordOf context fieldOffsetEntry) of
           (SOME 0w0,SOME fieldOffset) =>
           GetField
               {
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                destination = destination
               }
         | (SOME 0w0, NONE) =>
           GetFieldIndirect
               {
                blockEntry = blockEntry,
                fieldOffsetEntry = fieldOffsetEntry,
                fieldSize = fieldSize,
                destination = destination
               }
         | (SOME nestLevel, SOME fieldOffset) =>
           GetNestedField
               {
                nestLevel = nestLevel,
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                destination = destination
               }
         | _ => instruction
        )
      | SetFieldIndirect{blockEntry,fieldOffsetEntry,fieldSize,newValueEntry} =>
        (
         case CTX.wordOf context fieldOffsetEntry of
           SOME fieldOffset =>
           SetField
               {
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                newValueEntry = newValueEntry
               }
         | NONE => instruction
        )
      | SetNestedField{nestLevel,blockEntry,fieldOffset,fieldSize,newValueEntry} =>
        if nestLevel = 0w0
        then
          SetField
              {
               blockEntry = blockEntry,
               fieldOffset = fieldOffset,
               fieldSize = fieldSize,
               newValueEntry = newValueEntry
              }
        else instruction
      | SetNestedFieldIndirect{nestLevelEntry,blockEntry,fieldOffsetEntry,fieldSize,newValueEntry} =>
        (
         case (CTX.wordOf context nestLevelEntry, CTX.wordOf context fieldOffsetEntry) of
           (SOME 0w0,SOME fieldOffset) =>
           SetField
               {
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                newValueEntry = newValueEntry
               }
         | (SOME 0w0, NONE) =>
           SetFieldIndirect
               {
                blockEntry = blockEntry,
                fieldOffsetEntry = fieldOffsetEntry,
                fieldSize = fieldSize,
                newValueEntry = newValueEntry
               }
         | (SOME nestLevel, SOME fieldOffset) =>
           SetNestedField
               {
                nestLevel = nestLevel,
                blockEntry = blockEntry,
                fieldOffset = fieldOffset,
                fieldSize = fieldSize,
                newValueEntry = newValueEntry
               }
         | _ => instruction
        )
      | CallPrim {destination,...} => optimizeCallPrim context instruction
      | Apply_MV {closureEntry,argEntries,argSizeEntries,destinations} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           Apply_0
               {
                closureEntry = closureEntry,
                destinations = destinations
               }
         | SingletonSizeList argSize =>
           Apply_1
               {
                closureEntry = closureEntry,
                argEntry = List.hd argEntries,
                argSize = argSize,
                destinations = destinations
               }
         | SingleSizeList =>
           Apply_MS
               {
                closureEntry = closureEntry,
                argEntries = argEntries,
                destinations = destinations
               }
         | LastArbitrarySizeList size =>
           Apply_ML
               {
                closureEntry = closureEntry,
                argEntries = argEntries,
                lastArgSize = size,
                destinations = destinations
               }
         | FixedSizeList argSizes =>
           Apply_MF
               {
                closureEntry = closureEntry,
                argEntries = argEntries,
                argSizes = argSizes,
                destinations = destinations
               }
         | VariantSizeList => instruction
        )
      | TailApply_MV {closureEntry,argEntries,argSizeEntries} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           TailApply_0
               {
                closureEntry = closureEntry
               }
         | SingletonSizeList argSize =>
           TailApply_1
               {
                closureEntry = closureEntry,
                argEntry = List.hd argEntries,
                argSize = argSize
               }
         | SingleSizeList =>
           TailApply_MS
               {
                closureEntry = closureEntry,
                argEntries = argEntries
               }
         | LastArbitrarySizeList size =>
           TailApply_ML
               {
                closureEntry = closureEntry,
                argEntries = argEntries,
                     lastArgSize = size
               }
         | FixedSizeList argSizes =>
           TailApply_MF
               {
                closureEntry = closureEntry,
                argEntries = argEntries,
                argSizes = argSizes
               }
         | VariantSizeList => instruction
        )
      | CallStatic_MV {entryPoint,envEntry,argEntries,argSizeEntries,destinations} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           CallStatic_0
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                destinations = destinations
               }
         | SingletonSizeList argSize =>
           CallStatic_1
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntry = List.hd argEntries,
                argSize = argSize,
                destinations = destinations
               }
         | SingleSizeList =>
           CallStatic_MS
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries,
                destinations = destinations
               }
         | LastArbitrarySizeList size =>
           CallStatic_ML
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries,
                lastArgSize = size,
                destinations = destinations
               }
         | FixedSizeList argSizes =>
           CallStatic_MF
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries,
                argSizes = argSizes,
                destinations = destinations
               }
         | VariantSizeList => instruction
        )
      | TailCallStatic_MV {entryPoint,envEntry,argEntries,argSizeEntries} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           TailCallStatic_0
               {
                entryPoint = entryPoint,
                envEntry = envEntry
               }
         | SingletonSizeList argSize =>
           TailCallStatic_1
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntry = List.hd argEntries,
                argSize = argSize
               }
         | SingleSizeList =>
           TailCallStatic_MS
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries
               }
         | LastArbitrarySizeList size =>
           TailCallStatic_ML
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries,
                lastArgSize = size
               }
         | FixedSizeList argSizes =>
           TailCallStatic_MF
               {
                entryPoint = entryPoint,
                envEntry = envEntry,
                argEntries = argEntries,
                argSizes = argSizes
               }
         | VariantSizeList => instruction
        )
      | RecursiveCallStatic_MV {entryPoint,argEntries,argSizeEntries,destinations} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           RecursiveCallStatic_0
               {
                entryPoint = entryPoint,
                destinations = destinations
               }
         | SingletonSizeList argSize =>
           RecursiveCallStatic_1
               {
                entryPoint = entryPoint,
                argEntry = List.hd argEntries,
                argSize = argSize,
                destinations = destinations
               }
         | SingleSizeList =>
           RecursiveCallStatic_MS
               {
                entryPoint = entryPoint,
                argEntries = argEntries,
                destinations = destinations
               }
         | LastArbitrarySizeList size =>
           RecursiveCallStatic_ML
               {
                entryPoint = entryPoint,
                argEntries = argEntries,
                lastArgSize = size,
                destinations = destinations
               }
         | FixedSizeList argSizes =>
           RecursiveCallStatic_MF
               {
                entryPoint = entryPoint,
                argEntries = argEntries,
                argSizes = argSizes,
                destinations = destinations
               }
         | VariantSizeList => instruction
        )
      | RecursiveTailCallStatic_MV {entryPoint,argEntries,argSizeEntries} =>
        (
         case computeSizeListKind context argSizeEntries of
           EmptySizeList =>
           RecursiveTailCallStatic_0
               {
                entryPoint = entryPoint
               }
         | SingletonSizeList argSize =>
           RecursiveTailCallStatic_1
               {
                entryPoint = entryPoint,
                argEntry = List.hd argEntries,
                argSize = argSize
               }
         | SingleSizeList =>
           RecursiveTailCallStatic_MS
               {
                entryPoint = entryPoint,
                argEntries = argEntries
               }
         | LastArbitrarySizeList size =>
           RecursiveTailCallStatic_ML
               {
                entryPoint = entryPoint,
                argEntries = argEntries,
                lastArgSize = size
               }
         | FixedSizeList argSizes =>
           RecursiveTailCallStatic_MF
               {
                entryPoint = entryPoint,
                argEntries = argEntries,
                argSizes = argSizes
               }
         | VariantSizeList => instruction
        )
      | MakeBlock{bitmapEntry,sizeEntry,fieldEntries,fieldSizeEntries,destination} =>
        (
         case computeSizeListKind context fieldSizeEntries of
           EmptySizeList => LoadEmptyBlock {destination = destination}
         | SingletonSizeList (SINGLE) =>
           MakeFixedSizeBlock
               {
                bitmapEntry = bitmapEntry,
                size = 0w1,
                fieldEntries = fieldEntries,
                fieldSizes = [0w1],
                destination = destination
               }
         | SingletonSizeList (DOUBLE) =>
           MakeFixedSizeBlock
               {
                bitmapEntry = bitmapEntry,
                size = 0w2,
                fieldEntries = fieldEntries,
                fieldSizes = [0w2],
                destination = destination
               }
         | SingletonSizeList (VARIANT sizeEntry) =>
           MakeBlock
               {
                bitmapEntry = bitmapEntry,
                sizeEntry = sizeEntry,
                fieldEntries = fieldEntries,
                fieldSizeEntries = [sizeEntry],
                destination = destination
               }
         | SingleSizeList =>
           MakeBlockOfSingleValues
               {
                bitmapEntry = bitmapEntry,
                fieldEntries = fieldEntries,
                destination = destination
               }
         | LastArbitrarySizeList DOUBLE =>
           MakeFixedSizeBlock
               {
                bitmapEntry = bitmapEntry,
                size = Word32.fromInt ((List.length fieldEntries) + 1),
                fieldEntries = fieldEntries,
                fieldSizes = 
                (List.tabulate ((List.length fieldEntries) - 1, (fn _ => 0w1))) @ [0w2],
                destination = destination
               }
         | LastArbitrarySizeList _ => instruction
         | FixedSizeList fieldSizes =>
           MakeFixedSizeBlock
               {
                bitmapEntry = bitmapEntry,
                size = foldl (fn (x,y) => x + y) 0w0 fieldSizes,
                fieldEntries = fieldEntries,
                fieldSizes = fieldSizes,
                destination = destination
               }
         | VariantSizeList => instruction
        )
      | MakeFixedSizeBlock{bitmapEntry,size,fieldEntries,fieldSizes,destination} =>
        (
         if size = 0w0 
         then LoadEmptyBlock {destination = destination}
         else
           if size = BT.UInt32.fromInt (List.length fieldEntries)
           then
             MakeBlockOfSingleValues
                 {
                  bitmapEntry = bitmapEntry,
                  fieldEntries = fieldEntries,
                  destination = destination
                 }
           else instruction
        )
      | Return_MV {variableEntries, variableSizeEntries} =>
        (
         case computeSizeListKind context variableSizeEntries of
           EmptySizeList => Return_0
         | SingletonSizeList variableSize =>
           Return_1 {variableEntry = List.hd variableEntries, variableSize = variableSize}
         | SingleSizeList =>
           Return_MS {variableEntries = variableEntries}
         | LastArbitrarySizeList size =>
           Return_ML {variableEntries = variableEntries, lastVariableSize = size}
         | FixedSizeList variableSizes =>
           Return_MF {variableEntries = variableEntries, variableSizes = variableSizes}
         | VariantSizeList => instruction
        )
      | _ => instruction

  val ALWAYS_Entry = {id= ID.reserve (),displayName =""}
  val ALWAYS = [ALWAYS_Entry]

  fun entryOfSize SINGLE = []
    | entryOfSize DOUBLE = []
    | entryOfSize (VARIANT v) = [v]

  fun analyse instruction =
      case instruction of
        LoadInt {destination,...} => ([],[destination])
      | LoadWord {destination,...} => ([],[destination])
      | LoadReal {destination,...} => ([],[destination])
      | LoadFloat {destination,...} => ([],[destination])
      | LoadString {destination,...} => ([],[destination])
      | LoadChar {destination,...} => ([],[destination])
      | LoadEmptyBlock {destination} => ([],[destination])
      | Access {variableEntry,variableSize,destination} => 
        (variableEntry::(entryOfSize variableSize),[destination])
      | AccessEnv {variableSize, destination,...} => 
        (entryOfSize variableSize,[destination])
      | AccessNestedEnv {variableSize, destination,...} => 
        (entryOfSize variableSize,[destination])
      | GetField{fieldSize,blockEntry,destination,...} =>
        (blockEntry::(entryOfSize fieldSize),[destination])
      | GetFieldIndirect{fieldOffsetEntry,fieldSize,blockEntry,destination} =>
        (fieldOffsetEntry::blockEntry::(entryOfSize fieldSize),[destination])
      | GetNestedField{fieldSize,blockEntry,destination,...} =>
        (blockEntry::(entryOfSize fieldSize),[destination])
      | GetNestedFieldIndirect{nestLevelEntry,fieldOffsetEntry,fieldSize,blockEntry,destination} =>
        (nestLevelEntry::fieldOffsetEntry::blockEntry::(entryOfSize fieldSize),[destination])
      | SetField{fieldSize,blockEntry,newValueEntry,...} =>
        (blockEntry::newValueEntry::(entryOfSize fieldSize),ALWAYS)
      | SetFieldIndirect{fieldOffsetEntry,fieldSize,blockEntry,newValueEntry} =>
        (fieldOffsetEntry::blockEntry::newValueEntry::(entryOfSize fieldSize),ALWAYS)
      | SetNestedField{fieldSize,blockEntry,newValueEntry,...} =>
        (blockEntry::newValueEntry::(entryOfSize fieldSize),ALWAYS)
      | SetNestedFieldIndirect{nestLevelEntry,fieldOffsetEntry,fieldSize,blockEntry,newValueEntry} =>
        (nestLevelEntry::fieldOffsetEntry::blockEntry::newValueEntry::(entryOfSize fieldSize),ALWAYS)
      | CopyBlock{blockEntry, nestLevelEntry,destination} => 
        ([blockEntry,nestLevelEntry],[destination])
      | GetGlobal{variableSize,destination,...} => 
        (entryOfSize variableSize,[destination])
      | SetGlobal{newValueEntry,variableSize,...} =>  
        (newValueEntry::(entryOfSize variableSize),ALWAYS)
      | InitGlobalArrayUnboxed _ => ([],ALWAYS)
      | InitGlobalArrayBoxed _ => ([],ALWAYS)
      | InitGlobalArrayDouble _ => ([],ALWAYS)
      | GetEnv{destination} => ([],[destination])
      | CallPrim{argEntries,destination,...} => 
        (argEntries,destination::ALWAYS)
      | ForeignApply{closureEntry,argEntries,destination,...} => 
        (closureEntry::argEntries,destination::ALWAYS)
      | RegisterCallback{closureEntry,destination,...} => 
        ([closureEntry],destination::ALWAYS)

      | Apply_0{closureEntry,destinations} => 
        ([closureEntry], destinations @ ALWAYS)
      | Apply_1{closureEntry,argEntry,argSize,destinations} => 
        (closureEntry::argEntry::(entryOfSize argSize), destinations @ ALWAYS)
      | Apply_MS{closureEntry,argEntries,destinations}=>
        (closureEntry::argEntries, destinations @ ALWAYS)
      | Apply_ML{closureEntry,argEntries,lastArgSize,destinations,...}=>
        ((closureEntry::argEntries) @ (entryOfSize lastArgSize), destinations @ ALWAYS)
      | Apply_MF{closureEntry,argEntries,destinations,...}=>
        (closureEntry::argEntries, destinations @ ALWAYS)
      | Apply_MV{closureEntry,argEntries,argSizeEntries,destinations,...}=>
        ((closureEntry::argEntries) @ argSizeEntries, destinations @ ALWAYS)

      | TailApply_0{closureEntry} => 
        ([closureEntry], ALWAYS)
      | TailApply_1{closureEntry,argEntry,argSize} => 
        (closureEntry::argEntry::(entryOfSize argSize), ALWAYS)
      | TailApply_MS{closureEntry,argEntries}=>
        (closureEntry::argEntries, ALWAYS)
      | TailApply_ML{closureEntry,argEntries,lastArgSize,...}=>
        ((closureEntry::argEntries) @ (entryOfSize lastArgSize), ALWAYS)
      | TailApply_MF{closureEntry,argEntries,...}=>
        (closureEntry::argEntries, ALWAYS)
      | TailApply_MV{closureEntry,argEntries,argSizeEntries,...}=>
        ((closureEntry::argEntries) @ argSizeEntries, ALWAYS)

      | CallStatic_0{envEntry,destinations,...} => 
        ([envEntry], destinations @ ALWAYS)
      | CallStatic_1{envEntry,argEntry,argSize,destinations,...} => 
        (envEntry::argEntry::(entryOfSize argSize), destinations @ ALWAYS)
      | CallStatic_MS{envEntry,argEntries,destinations,...}=>
        (envEntry::argEntries, destinations @ ALWAYS)
      | CallStatic_ML{envEntry,argEntries,lastArgSize,destinations,...}=>
        ((envEntry::argEntries) @ (entryOfSize lastArgSize), destinations @ ALWAYS)
      | CallStatic_MF{envEntry,argEntries,destinations,...}=>
        (envEntry::argEntries, destinations @ ALWAYS)
      | CallStatic_MV{envEntry,argEntries,argSizeEntries,destinations,...}=>
        ((envEntry::argEntries) @ argSizeEntries, destinations @ ALWAYS)

      | TailCallStatic_0{envEntry,...} => 
        ([envEntry], ALWAYS)
      | TailCallStatic_1{envEntry,argEntry,argSize,...} => 
        (envEntry::argEntry::(entryOfSize argSize), ALWAYS)
      | TailCallStatic_MS{envEntry,argEntries,...}=>
        (envEntry::argEntries, ALWAYS)
      | TailCallStatic_ML{envEntry,argEntries,lastArgSize,...}=>
        ((envEntry::argEntries) @ (entryOfSize lastArgSize), ALWAYS)
      | TailCallStatic_MF{envEntry,argEntries,...}=>
        (envEntry::argEntries, ALWAYS)
      | TailCallStatic_MV{envEntry,argEntries,argSizeEntries,...}=>
        ((envEntry::argEntries) @ argSizeEntries, ALWAYS)

      | RecursiveCallStatic_0{destinations,...} => 
        ([], destinations @ ALWAYS)
      | RecursiveCallStatic_1{argEntry,argSize,destinations,...} => 
        (argEntry::(entryOfSize argSize), destinations @ ALWAYS)
      | RecursiveCallStatic_MS{argEntries,destinations,...}=>
        (argEntries, destinations @ ALWAYS)
      | RecursiveCallStatic_ML{argEntries,lastArgSize,destinations,...}=>
        (argEntries @ (entryOfSize lastArgSize), destinations @ ALWAYS)
      | RecursiveCallStatic_MF{argEntries,destinations,...}=>
        (argEntries, destinations @ ALWAYS)
      | RecursiveCallStatic_MV{argEntries,argSizeEntries,destinations,...}=>
        (argEntries @ argSizeEntries, destinations @ ALWAYS)

      | RecursiveTailCallStatic_0 _ => 
        ([], ALWAYS)
      | RecursiveTailCallStatic_1{argEntry,argSize,...} => 
        (argEntry::(entryOfSize argSize), ALWAYS)
      | RecursiveTailCallStatic_MS{argEntries,...}=>
        (argEntries, ALWAYS)
      | RecursiveTailCallStatic_ML{argEntries,lastArgSize,...}=>
        (argEntries @ (entryOfSize lastArgSize), ALWAYS)
      | RecursiveTailCallStatic_MF{argEntries,...}=>
        (argEntries, ALWAYS)
      | RecursiveTailCallStatic_MV{argEntries,argSizeEntries,...}=>
        (argEntries @ argSizeEntries, ALWAYS)

      | MakeBlock{bitmapEntry,sizeEntry,fieldEntries,fieldSizeEntries,destination,...} =>
        (bitmapEntry::sizeEntry::(fieldEntries @ fieldSizeEntries),[destination])
      | MakeFixedSizeBlock{bitmapEntry,fieldEntries,destination,...} => (bitmapEntry::fieldEntries,[destination])
      | MakeBlockOfSingleValues{bitmapEntry,fieldEntries,destination,...} => (bitmapEntry::fieldEntries,[destination])
      | MakeArray{bitmapEntry,sizeEntry,initialValueEntry,initialValueSize,destination} =>
        (bitmapEntry::sizeEntry::initialValueEntry::(entryOfSize initialValueSize),[destination])
      | MakeClosure{envEntry,destination,...} => ([envEntry],[destination])
      | Raise{exceptionEntry} => ([exceptionEntry],ALWAYS)
      | PushHandler{exceptionEntry, ...} => ([exceptionEntry],ALWAYS)
      | PopHandler _ => ([],ALWAYS)
      | Label _ => ([],ALWAYS)
      | Location _ => ([],ALWAYS)
      | SwitchInt {targetEntry,...} => ([targetEntry],ALWAYS)
      | SwitchWord {targetEntry,...} => ([targetEntry],ALWAYS)
      | SwitchString {targetEntry,...} => ([targetEntry],ALWAYS)
      | SwitchChar {targetEntry,...} => ([targetEntry],ALWAYS)
      | Jump _ => ([],ALWAYS)
      | Exit => ([],ALWAYS)
      | Return_0 => ([],ALWAYS)
      | Return_1 {variableEntry,variableSize} => (variableEntry::(entryOfSize variableSize),ALWAYS)
      | Return_MS {variableEntries} => (variableEntries,ALWAYS)
      | Return_ML {variableEntries,lastVariableSize} => 
        (variableEntries @ (entryOfSize lastVariableSize),ALWAYS)
      | Return_MF {variableEntries,variableSizes} => (variableEntries,ALWAYS)
      | Return_MV {variableEntries,variableSizeEntries} => (variableEntries @ variableSizeEntries,ALWAYS)
      | ConstString _ => ([],ALWAYS)

      | AddInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | AddInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | AddReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | AddReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | AddWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | AddWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | AddByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | AddByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
        
      | SubInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | SubInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | SubReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | SubReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | SubWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | SubWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | SubByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | SubByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | MulInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | MulInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | MulReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | MulReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | MulWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | MulWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | MulByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | MulByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | DivInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | DivInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | DivReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | DivReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | DivWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | DivWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | DivByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | DivByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | ModInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | ModInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | ModWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | ModWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | ModByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | ModByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | QuotInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | QuotInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | RemInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | RemInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | LtInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LtInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LtReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LtReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LtWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LtWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LtByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LtByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LtChar_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LtChar_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | GtInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GtInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GtReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GtReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GtWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GtWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GtByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GtByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GtChar_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GtChar_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | LteqInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LteqInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LteqReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LteqReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LteqWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LteqWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LteqByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LteqByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | LteqChar_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | LteqChar_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | GteqInt_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GteqInt_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GteqReal_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GteqReal_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GteqWord_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GteqWord_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GteqByte_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GteqByte_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])
      | GteqChar_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | GteqChar_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_andb_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_andb_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_orb_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_orb_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_xorb_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_xorb_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_leftShift_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_leftShift_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_logicalRightShift_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_logicalRightShift_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])

      | Word_arithmeticRightShift_Const_1{argValue1,argEntry2,destination} => ([argEntry2],[destination])
      | Word_arithmeticRightShift_Const_2{argEntry1,argValue2,destination} => ([argEntry1],[destination])


  fun deadCodeEliminateInstruction (instruction,(entrySet,instructions)) =
      let
        fun addEntry (e,S) = EntrySet.add(S,e)
        fun useful e = EntrySet.member(entrySet, e)
        val (inputEntries,outputEntries) = analyse instruction
      in
        if List.exists useful outputEntries
        then
          (
           foldl addEntry (foldl addEntry entrySet outputEntries) inputEntries,
           instruction::instructions
          )
        else
          (
           entrySet,
           instructions
          )
      end  

  fun deadCodeEliminateFunction ({name, loc, args, instructions} : functionCode) =
      let
        val entrySet = EntrySet.singleton(ALWAYS_Entry)
        val (entrySet,newInstructions) =
            foldr
                deadCodeEliminateInstruction
                (entrySet,[])
                instructions
      in
        (
         entrySet,
         {
          name = name,
          loc = loc,
          args = args,
          instructions = newInstructions
         } : functionCode
        )
      end      
        
  fun deadCodeEliminateCluster ({frameInfo, functionCodes, loc} : clusterCode) =
      let
        val (entrySet,newFunctionCodesRev) =
            foldl
                (fn (C,(S,L)) =>
                    let
                      val (entrySet,code) = deadCodeEliminateFunction C
                      val entrySet =
                          foldl
                              (fn (e,S) => EntrySet.add(S,e))
                              entrySet
                              (#args code)
                    in
                      (EntrySet.union(entrySet,S),code::L)
                    end
                )
                (EntrySet.empty,[])
                functionCodes
        fun removeUselessEntries L = 
            List.filter (fn e => EntrySet.member(entrySet,e)) L
        val newFrameInfo =
            {
             bitmapvals = #bitmapvals frameInfo,
             pointers = removeUselessEntries (#pointers frameInfo),
             atoms = removeUselessEntries (#atoms frameInfo),
             doubles = removeUselessEntries (#doubles frameInfo),
             records = map removeUselessEntries (#records frameInfo)
            }
      in
        {
         frameInfo = newFrameInfo,
         functionCodes = rev newFunctionCodesRev,
         loc = loc
        } : clusterCode
      end

  val deadCodeEliminate = deadCodeEliminateCluster

end
