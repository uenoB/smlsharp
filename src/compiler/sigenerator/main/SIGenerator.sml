(** symbolic code generator
 * @copyright (c) 2006, Tohoku University.
 * @author Nguyen Huu-Duc
 * @version $Id: SIGenerator.sml,v 1.4 2007/06/20 06:50:41 kiyoshiy Exp $
 *)
structure SIGenerator : SIGENERATOR = struct

  structure BT = BasicTypes
  structure CT = ConstantTerm
  structure AN = ANormal
  structure IL = IntermediateLanguage
  structure SI = SymbolicInstructions
  structure ILU = ILUtils
  structure CTX = SIGContext
  structure SIO = SIOptimizer

  (***************************************************************************)

  fun sizeToCaseTag SI.SINGLE = 0w1 : BT.UInt32
    | sizeToCaseTag SI.DOUBLE = 0w2
    | sizeToCaseTag (SI.VARIANT _) = raise Control.Bug "sizeToCaseTag"
                                           
  fun funTypeToCaseTag (argTys, resultTy) =
      let
        fun tag (h::t) = sizeToCaseTag h + 0w2 * tag t
          | tag nil = 0w0 : BT.UInt32
      in
        tag (rev (resultTy::argTys))
      end

  (***************************************************************************)

  (** get an instruction which implements the specified primitive.
   * @params name
   * @param the name of primitive
   *)
  fun findPrimitive name =
      case
        List.find (fn {bindName, ...} => bindName = name) Primitives.primitives
       of
        NONE => raise Control.Bug ("primitive " ^ name ^ " is not found.")
      | SOME primitive => primitive

  fun varInfoToEntry ({id, displayName, ty, varKind} : IL.varInfo) =
      {id = id, displayName = displayName} : SI.entry

  fun constToSize (CT.WORD 0w1) = SI.SINGLE
    | constToSize (CT.WORD 0w2) = SI.DOUBLE
    | constToSize _ = raise Control.Bug "invalid size"

  fun expToSize context exp =
      case exp of 
        IL.Constant c => constToSize c
      | IL.Variable varInfo =>
        let
          val entry = varInfoToEntry varInfo
        in
          case CTX.rootOf context entry of
            SOME (CTX.CONST constant) => constToSize constant
          | SOME (CTX.VAR e) => SI.VARIANT e
          | _ => SI.VARIANT entry
        end
      | _ => raise Control.Bug "invalid size"


  fun generateConstantInstruction (context : CTX.context) (constant, destination) =
      case constant of
        CT.INT value => SI.LoadInt{value = value, destination = destination}
      | CT.WORD value => SI.LoadWord{value = value, destination = destination}
      | CT.STRING value =>
        let 
          val label = CTX.addStringConstant context value
        in
          SI.LoadString{string = label, destination = destination}
        end
      | CT.REAL value => SI.LoadReal{value = value, destination = destination}
      | CT.FLOAT value => SI.LoadFloat{value = value, destination = destination}
      | CT.CHAR value => SI.LoadChar{value = BT.IntToUInt32(Char.ord value), destination = destination}
      | CT.UNIT => SI.LoadInt{value = 0, destination = destination}

  fun generateLocInstruction context instructions =
      if !Control.generateExnHistory orelse !Control.generateDebugInfo
      then
        let
          val loc = CTX.getLocation context
        in
          if loc = Loc.noloc
          then instructions
          else (SI.Location loc) :: instructions
        end
      else instructions


  fun transformConstantArg context const =
      case CTX.findFirstConstantBind context const of 
        SOME entry => (context, [], entry)
      | NONE  =>
        let
          val boundVarInfo = ILU.newVar IL.LOCAL (ILU.defaultConstantType const) 
          val entry = CTX.addLocalVariable context boundVarInfo
          val instruction = generateConstantInstruction context (const, entry)
          val newContext = CTX.addConstantBind context (const, entry)
        in
          (newContext, generateLocInstruction context [instruction], entry)
        end

  (* we only allow constant and local variable at argument position*)
  fun transformArg context exp =
      case exp of
        IL.Constant const => transformConstantArg context const
      | IL.ExceptionTag tagValue => transformConstantArg context (CT.WORD tagValue)
      | IL.Label label => raise Control.Bug "not implemented"
      | IL.Variable (varInfo as {varKind = IL.GLOBAL _,...}) => raise Control.Bug "not implemented"
      | IL.Variable varInfo => (context, [], CTX.rootEntry context (varInfoToEntry varInfo))
      | _ => raise Control.Bug "not implemented"

  fun transformArgList context [] = (context, [], [])
    | transformArgList context (arg::rest) =
      let
        val (context, code1, entry) = transformArg context arg
        val (context, code2, entryList) = transformArgList context rest
      in
        (context, code1 @ code2, entry::entryList)
      end

  fun transformCallExp context (exp, destinations) =
      case exp of
        IL.Apply {funExp, argExpList, argTyList, argSizeExpList} =>
        let
          val (context,code1,funEntry) = transformArg context funExp
          val (context,code2,argSizeEntries) = transformArgList context argSizeExpList
          val (context,code3,argEntries) = transformArgList context argExpList
          val instruction =
              case CTX.closureOf context funEntry of
                SOME (entryPoint, envEntry) =>
                SI.CallStatic_MV 
                    {
                     entryPoint = entryPoint,
                     envEntry = envEntry,
                     argEntries = argEntries,
                     argSizeEntries = argSizeEntries,
                     destinations = destinations
                    }
              | NONE =>
                SI.Apply_MV 
                    {
                     closureEntry = funEntry,
                     argEntries = argEntries,
                     argSizeEntries = argSizeEntries,
                     destinations = destinations
                    }
          val code4 = generateLocInstruction context [SIO.optimizeInstruction context instruction]
        in
          (context, code1 @ code2 @ code3 @ code4)
        end
      | IL.RecursiveCall {funLabelExp as IL.Label label, argExpList, argTyList, argSizeExpList} =>
        let
          val (context,code1,argSizeEntries) = transformArgList context argSizeExpList
          val (context,code2,argEntries) = transformArgList context argExpList
          val instruction =
              SI.RecursiveCallStatic_MV 
                  {
                   entryPoint = label,
                   argEntries = argEntries,
                   argSizeEntries = argSizeEntries,
                   destinations = destinations
                  }
          val code3 = generateLocInstruction context [SIO.optimizeInstruction context instruction]
        in
          (context, code1 @ code2 @ code3)
        end
      | _ => raise Control.Bug "invalid call expression"

  fun transformConstantExp context (constant, destination) =
      let
        val instruction = generateConstantInstruction context (constant, destination)
        val newContext = CTX.addConstantBind context (constant, destination)
      in
        (newContext, generateLocInstruction newContext [instruction])
      end

  fun transformExp context (exp, expSizes, destinations) =
      case exp of
        IL.Constant constant => transformConstantExp context (constant, List.hd destinations)
      | IL.ExceptionTag tagValue => transformConstantExp context (CT.WORD tagValue, List.hd destinations)
      | IL.Label label => raise Control.Bug "not implemented"
      | IL.Variable {varKind = IL.GLOBAL {globalArrayIndex, offset},...} =>
        (
         context,
         [
          SI.GetGlobal
              {
               globalArrayIndex = globalArrayIndex,
               offset = offset,
               variableSize = List.hd expSizes,
               destination = List.hd destinations
              }
         ]
        )
      | IL.Variable valueVarInfo =>
        let
          val valueEntry = varInfoToEntry valueVarInfo
          val destination = List.hd destinations
        in
          case CTX.rootOf context valueEntry of
            SOME (CTX.CONST constant) => transformConstantExp context (constant, destination)
          | SOME (CTX.VAR entry) =>
            let
              val instruction =
                  SI.Access 
                      {
                       variableEntry = entry,
                       variableSize = List.hd expSizes,
                       destination = destination
                      }
              val newContext = CTX.addVariableBind context (entry,destination) 
            in
              (newContext, generateLocInstruction newContext [instruction])
            end
          | SOME (CTX.CLOSURE (entryPoint, envEntry)) =>
            let
              val instruction =
                  SI.Access 
                      {
                       variableEntry = valueEntry,
                       variableSize = List.hd expSizes,
                       destination = destination
                      }
              val newContext = CTX.addClosureBind context (entryPoint, envEntry, destination) 
            in
              (newContext, generateLocInstruction newContext [instruction])
            end
          | NONE =>
            let
              val instruction =
                  SI.Access 
                      {
                       variableEntry = valueEntry,
                       variableSize = List.hd expSizes,
                       destination = destination
                      }
              val newContext = CTX.addVariableBind context (valueEntry,destination) 
            in
              (newContext, generateLocInstruction newContext [instruction])
            end
        end
      | IL.AccessEnv {nestLevelExp, offsetExp} =>
        let
          val (context, code1, nestLevelEntry) = transformArg context nestLevelExp
          val (context, code2, offsetEntry) = transformArg context offsetExp
          (* nestLevel and offset should be constant*)
          val nestLevel = valOf(CTX.wordOf context nestLevelEntry)
          val offset = valOf(CTX.wordOf context offsetEntry)
          val instruction =
              SI.AccessNestedEnv
                  {
                   nestLevel = nestLevel,
                   offset = offset,
                   variableSize = List.hd expSizes,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ (generateLocInstruction context [instruction]))
        end
      | IL.ArraySub {arrayExp, offsetExp} =>
        let
          val (context,code1,blockEntry) = transformArg context arrayExp
          val (context,code2,fieldOffsetEntry) = transformArg context offsetExp
          val instruction =
              SI.GetFieldIndirect
                  {
                   fieldOffsetEntry = fieldOffsetEntry,
                   fieldSize = List.hd expSizes,
                   blockEntry = blockEntry,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ (generateLocInstruction context [instruction]))
        end
      | IL.RecordSelect {recordExp, nestLevelExp, fieldOffsetExp} =>
        let
          val (context,code1,blockEntry) = transformArg context recordExp
          val (context,code2,nestLevelEntry) = transformArg context nestLevelExp
          val (context,code3,fieldOffsetEntry) = transformArg context fieldOffsetExp
          val instruction =
              SI.GetNestedFieldIndirect
                  {
                   nestLevelEntry = nestLevelEntry,
                   fieldOffsetEntry = fieldOffsetEntry,
                   fieldSize = List.hd expSizes,
                   blockEntry = blockEntry,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ (generateLocInstruction context [instruction]))
        end
      | IL.CallPrim {primName, argExpList, argTyList, argSizeExpList} =>
        let
          val (context,code,argEntries) = transformArgList context argExpList
          val instruction =
              SI.CallPrim
                  {
                   primitive = findPrimitive primName,
                   argEntries = argEntries,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code @ (generateLocInstruction context [instruction]))
        end
      | IL.ForeignApply {funExp, argExpList, argTyList, argSizeExpList, convention} =>
        let
          val argSizeList = map (expToSize context) argSizeExpList
          val (context,code1,closureEntry) = transformArg context funExp
          val (context,code2,argEntries) = transformArgList context argExpList
          val switchTag = 
              if !Control.LARGEFFISWITCH 
              then funTypeToCaseTag (argSizeList, List.hd expSizes)
              else Word32.fromInt (List.length argSizeList)
          val instruction =
              SI.ForeignApply
                  {
                   switchTag = switchTag,
                   convention = convention,
                   closureEntry = closureEntry,
                   argEntries = argEntries,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ (generateLocInstruction context [instruction]))
        end
      | IL.ExportCallback {funExp, argSizeExpList, resultSizeExpList} =>
        let
          val argSizeList = map (expToSize context) argSizeExpList
          val resultSizeList = map (expToSize context) resultSizeExpList
          val (context,code,closureEntry) = transformArg context funExp
          val instruction =
              SI.RegisterCallback
                  {
                   sizeTag = funTypeToCaseTag (argSizeList, List.hd resultSizeList),
                   closureEntry = closureEntry,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code @ (generateLocInstruction context [instruction]))
        end
      | IL.Apply _ => transformCallExp context (exp, destinations)
      | IL.RecursiveCall _ => transformCallExp context (exp, destinations)
      | IL.InnerCall _ => transformCallExp context (exp, destinations)
      | IL.MakeBlock {bitmapExp, sizeExp, fieldExpList, fieldTyList, fieldSizeExpList} =>
        let
          val (context,code1,bitmapEntry) = transformArg context bitmapExp
          val (context,code2,sizeEntry) = transformArg context sizeExp
          val (context,code3,fieldEntries) = transformArgList context fieldExpList
          val (context,code4,fieldSizeEntries) = transformArgList context fieldSizeExpList
          val instruction =
              SI.MakeBlock
                  {
                   bitmapEntry = bitmapEntry,
                   sizeEntry = sizeEntry,
                   fieldEntries = fieldEntries,
                   fieldSizeEntries = fieldSizeEntries,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ code4 @ (generateLocInstruction context [instruction]))
        end
      | IL.MakeFixedSizeBlock {bitmapExp, sizeExp, fieldExpList, fieldTyList, fieldSizeExpList, fixedSizeExpList} =>
        let
          val (context,code1,bitmapEntry) = transformArg context bitmapExp
          val (context,code2,sizeEntry) = transformArg context sizeExp
          val (context,code3,fieldEntries) = transformArgList context fieldExpList
          val (context,code4,fixedSizeEntries) = transformArgList context fixedSizeExpList
          val size = valOf(CTX.wordOf context sizeEntry)
          val fieldSizes = map (valOf o (CTX.wordOf context)) fixedSizeEntries
          val instruction =
              SI.MakeFixedSizeBlock
                  {
                   bitmapEntry = bitmapEntry,
                   size = size,
                   fieldEntries = fieldEntries,
                   fieldSizes = fieldSizes,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ code4 @ (generateLocInstruction context [instruction]))
        end
      | IL.MakeArray {bitmapExp, sizeExp, initialValueExp, elementTy, elementSizeExp} =>
        let
          val (context,code1,bitmapEntry) = transformArg context bitmapExp
          val (context,code2,sizeEntry) = transformArg context sizeExp
          val (context,code3,initialValueEntry) = transformArg context initialValueExp
          val initialValueSize = expToSize context elementSizeExp
          val instruction =
              SI.MakeArray
                  {
                   bitmapEntry = bitmapEntry,
                   sizeEntry = sizeEntry,
                   initialValueEntry = initialValueEntry,
                   initialValueSize = initialValueSize,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ (generateLocInstruction context [instruction]))
        end
      | IL.MakeClosure {funLabelExp = IL.Label label, envExp} =>
        let
          val (context,code,envEntry) = transformArg context envExp
          val instruction =
              SI.MakeClosure
                  {
                   entryPoint = label,
                   envEntry = envEntry,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code @ (generateLocInstruction context [instruction]))
        end
      | IL.CopyBlock {recordExp, nestLevelExp} =>
        let
          val (context,code1,blockEntry) = transformArg context recordExp
          val (context,code2,nestLevelEntry) = transformArg context nestLevelExp
          val instruction =
              SI.CopyBlock
                  {
                   blockEntry = blockEntry,
                   nestLevelEntry = nestLevelEntry,
                   destination = List.hd destinations
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ (generateLocInstruction context [instruction]))
        end
      | IL.GetEnv =>
        let
          val instruction = SI.GetEnv {destination = List.hd destinations}
        in
          (context, generateLocInstruction context [instruction])
        end
      | _ => raise Control.Bug "invalid expression"
        
  fun transformStatementList context [] = (context, [])
    | transformStatementList context [statement] = transformStatement context statement
    | transformStatementList context (statement::statementList) =
      let
        val tailPosition = CTX.getPosition context
        val context = CTX.setPosition context CTX.NonTail
        val (context, code1) = transformStatement context statement
        val context = CTX.setPosition context tailPosition
        val (context, code2) = transformStatementList context statementList
      in
        (context, code1 @ code2)
      end

  and transformStatement context statement =
      case statement of
        IL.Sequence {statements, loc} => transformStatementList context statements
                                         
      | IL.Assign 
            {
             variableList as [{ty, varKind = IL.GLOBAL _,...}], 
             variableSizeExpList as [sizeExp], 
             valueExp as IL.Variable {varKind = IL.GLOBAL _,...}, 
             loc
            } => 
        let
          val intermediateVarInfo = ILU.newVar IL.LOCAL ty
          val statement1 =
              IL.Assign
                  {
                   variableList = [intermediateVarInfo],
                   variableSizeExpList = variableSizeExpList,
                   valueExp = valueExp,
                   loc = loc
                  }
          val statement2 =
              IL.Assign
                  {
                   variableList = variableList,
                   variableSizeExpList = variableSizeExpList,
                   valueExp = IL.Variable intermediateVarInfo,
                   loc = loc
                  }
        in
          transformStatement context (IL.Sequence {statements = [statement1,statement2], loc = loc})
        end

      | IL.Assign 
            {
             variableList as [{varKind = IL.GLOBAL {globalArrayIndex, offset},...}], 
             variableSizeExpList as [sizeExp], 
             valueExp as IL.Variable valueVarInfo, 
             loc
            } => 
        let
          val context = CTX.setLocation context loc 
          val instruction =
              SI.SetGlobal
                  {
                   globalArrayIndex = globalArrayIndex,
                   offset = offset,
                   newValueEntry = CTX.rootEntry context (varInfoToEntry valueVarInfo),
                   variableSize = expToSize context sizeExp
                  }
        in
          (context, generateLocInstruction context [instruction])
        end

      | IL.Assign 
            {
             variableList as [{ty, varKind = IL.GLOBAL _,...}], 
             variableSizeExpList as [sizeExp], 
             valueExp, 
             loc
            } => 
        let
          val intermediateVarInfo = ILU.newVar IL.LOCAL ty
          val statement1 =
              IL.Assign
                  {
                   variableList = [intermediateVarInfo],
                   variableSizeExpList = variableSizeExpList,
                   valueExp = valueExp,
                   loc = loc
                  }
          val statement2 =
              IL.Assign
                  {
                   variableList = variableList,
                   variableSizeExpList = variableSizeExpList,
                   valueExp = IL.Variable intermediateVarInfo,
                   loc = loc
                  }
        in
          transformStatement context (IL.Sequence {statements = [statement1,statement2], loc = loc})
        end

      | IL.Assign {variableList, variableSizeExpList, valueExp, loc} => 
        let
          val context = CTX.setLocation context loc 
          val destinations = map (CTX.addLocalVariable context) variableList
          val expSizes = map (expToSize context) variableSizeExpList
        in
          transformExp context (valueExp, expSizes, destinations)
        end

      | IL.Switch {switchExp, expTy, branches, defaultBranch, loc} =>
        let
          val context = CTX.setLocation context loc 
          val (context, switchCode, targetEntry) = transformArg context switchExp
          val defaultLabel = ID.generate()
          val (_, defaultCode) = transformStatement context defaultBranch

          fun transformCase ({constant, statement}, (cases, codes)) =
              let
                val label = ID.generate ()
                val (_, code) = transformStatement context statement
                val cases' = {const = constant, destination = label} :: cases
                val codes' = (SI.Label label :: code) :: codes
              in (cases', codes') end

          (* NOTE: To arrange cases, constants in them are treated as unsigned
           *      integer. For instance, 1 < ~1.
           *)
          fun compareCase ({constant = const1, statement = statement1}, {constant = const2, statement = statement2}) =
              case (const1, const2) of
                (CT.INT int1, CT.INT int2) =>
                BT.UInt32.compare (BT.SInt32ToUInt32 int1, BT.SInt32ToUInt32 int2)
              | (CT.WORD word1, CT.WORD word2) => BT.UInt32.compare (word1, word2)
              | (CT.CHAR char1, CT.CHAR char2) => Char.compare (char1, char2)
              | (CT.STRING string1, CT.STRING string2) => String.compare (string1, string2)
              | _ => raise Control.Bug "compare different type constant. "

          val sortedCases = ListSorter.sort compareCase branches
          val (cases, caseCodes) = foldl transformCase ([], []) sortedCases
          val cases = List.rev cases
          val caseCodes = List.rev caseCodes

          val instruction =
              case hd branches 
               of {constant = CT.INT _, ...} =>
                  SI.SwitchInt
                      {
                       targetEntry = targetEntry,
                       cases =
                       map
                           (fn {const = CT.INT const, destination} =>
                               {const = const, destination = destination})
                           cases,
                       default = defaultLabel
                      }
                | {constant = CT.WORD _, ...} =>
                  SI.SwitchWord
                      {
                       targetEntry = targetEntry,
                       cases =
                       map
                           (fn {const = CT.WORD const, destination} =>
                               {const = const, destination = destination})
                           cases,
                       default = defaultLabel
                      }
                | {constant = CT.CHAR _, ...} =>
                  SI.SwitchChar
                      {
                       targetEntry = targetEntry,
                       cases =
                       map
                           (fn {const = CT.CHAR const, destination} =>
                               {
                                const = BT.IntToUInt32 (Char.ord const),
                                destination = destination
                           })
                           cases,
                       default = defaultLabel
                      }
                | {constant = CT.STRING _, ...} =>
                  SI.SwitchString
                      {
                       targetEntry = targetEntry,
                       cases =
                       map
                           (fn {const = CT.STRING const, destination} =>
                               let val label = CTX.addStringConstant context const
                               in {const = label, destination = destination} end)
                           cases,
                       default = defaultLabel
                      }
                | _ =>
                  raise
                    Control.Bug
                        "linearizeCase expects INT,WORD,CHAR as the pattern of \
                        \ branches."
          val (caseCodes, tailCode) =
              case CTX.getPosition context of
                CTX.NonTail =>
                (* insert jumps to the instruction sequence which follows this
                 * Switch instruction. *)
                let
                  val tailLabel = ID.generate ()
                  fun appendJump code = code @ [SI.Jump{destination = tailLabel}]
                in
                  (map appendJump caseCodes, [SI.Label tailLabel])
                end
              | CTX.Tail =>
                (* No instruction sequence follows. *)
                (caseCodes, [])
        in
          (
           context, 
           switchCode
           @ (instruction :: (List.concat caseCodes))
           @ [SI.Label defaultLabel]
           @ defaultCode
           @ tailCode
          )
        end

      | IL.ArrayUpdate {arrayExp, offsetExp, newValueExp, newValueTy, newValueSizeExp, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context, code1, blockEntry) = transformArg context arrayExp
          val (context, code2, fieldOffsetEntry) = transformArg context offsetExp
          val (context, code3, newValueEntry) = transformArg context newValueExp
          val fieldSize = expToSize context newValueSizeExp
          val instruction =
              SI.SetFieldIndirect
                  {
                   blockEntry = blockEntry,
                   fieldOffsetEntry = fieldOffsetEntry,
                   fieldSize = fieldSize,
                   newValueEntry = newValueEntry
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ (generateLocInstruction context [instruction]))
        end

      | IL.RecordUpdate {recordExp, nestLevelExp, fieldOffsetExp, newValueExp, fieldTy, fieldSizeExp, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context, code1, blockEntry) = transformArg context recordExp
          val (context, code2, fieldOffsetEntry) = transformArg context fieldOffsetExp
          val (context, code3, newValueEntry) = transformArg context newValueExp
          val (context, code4, nestLevelEntry) = transformArg context nestLevelExp
          val fieldSize = expToSize context fieldSizeExp
          val instruction =
              SI.SetNestedFieldIndirect
                  {
                   blockEntry = blockEntry,
                   nestLevelEntry = nestLevelEntry,
                   fieldOffsetEntry = fieldOffsetEntry,
                   fieldSize = fieldSize,
                   newValueEntry = newValueEntry
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ code4 @ (generateLocInstruction context [instruction]))
        end

      | IL.SetTail {consExp, offsetExp, newTailExp, nestLevelExp, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context, code1, blockEntry) = transformArg context consExp
          val (context, code2, offsetEntry) = transformArg context offsetExp
          val (context, code3, nestLevelEntry) = transformArg context nestLevelExp
          val (context, code4, newTailEntry) = transformArg context newTailExp
          val instruction =
           SI.SetNestedFieldIndirect
           {
             fieldOffsetEntry = offsetEntry,
             nestLevelEntry = nestLevelEntry,
             fieldSize = SI.SINGLE,
             blockEntry = blockEntry,
             newValueEntry = newTailEntry
           }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, code1 @ code2 @ code3 @ code4 @ (generateLocInstruction context [instruction]))
        end

      | IL.Raise {exnExp, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context, code, exceptionEntry) = transformArg context exnExp
          val instruction = SI.Raise{exceptionEntry = exceptionEntry}
        in
          (context, code @ (generateLocInstruction context [instruction]))
        end

      | IL.Handle {mainCode, exnVar, handlerCode, loc} =>
        let
          val context = CTX.setLocation context loc
          val exnEntry = CTX.addLocalVariable context exnVar
          val startLabel = ID.generate ()
          val handlerLabel = ID.generate ()
          val tailLabel = ID.generate ()
          val (_, mainCode) = transformStatement (CTX.enterGuardedCode context startLabel) mainCode
          val (_,handlerCode) = transformStatement context handlerCode
        in
          (
           context,
           SI.Label startLabel
           :: (SI.PushHandler
                   {
                    handlerStart = handlerLabel,
                    handlerEnd = tailLabel,
                    exceptionEntry = exnEntry
              })
           :: mainCode
           @ [
           SI.PopHandler {guardedStart = startLabel},
           SI.Jump{destination = tailLabel},
           SI.Label handlerLabel
           ]
           @ handlerCode
           @ [SI.Label tailLabel]
          )
        end

      | IL.Return {valueExpList, valueTyList, valueSizeExpList, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context, code1, variableEntries) = transformArgList context valueExpList
          val (context, code2, variableSizeEntries) = transformArgList context valueSizeExpList
          val popHandlers =
              List.map
                  (fn label => SI.PopHandler {guardedStart = label})
                  (CTX.getEnclosingHandlers context)
          val instruction = 
              SI.Return_MV
                  {
                   variableEntries = variableEntries,
                   variableSizeEntries = variableSizeEntries
                  }
          val instruction = SIO.optimizeInstruction context instruction
        in
          (context, popHandlers @ code1 @ code2 @ (generateLocInstruction context [instruction]))
        end

      | IL.Exit loc => (context, [SI.Exit])

      | IL.TailApply {funExp, argExpList, argTyList, argSizeExpList, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context,code1,funEntry) = transformArg context funExp
          val (context,code2,argSizeEntries) = transformArgList context argSizeExpList
          val (context,code3,argEntries) = transformArgList context argExpList
          val instruction =
              case CTX.closureOf context funEntry of
                SOME (entryPoint, envEntry) =>
                SI.TailCallStatic_MV 
                    {
                     entryPoint = entryPoint,
                     envEntry = envEntry,
                     argEntries = argEntries,
                     argSizeEntries = argSizeEntries
                    }
              | NONE =>
                SI.TailApply_MV 
                    {
                     closureEntry = funEntry,
                     argEntries = argEntries,
                     argSizeEntries = argSizeEntries
                    }
          val code4 = generateLocInstruction context [SIO.optimizeInstruction context instruction]
        in
          (context, code1 @ code2 @ code3 @ code4)
        end

      | IL.RecursiveTailCall {funLabelExp as IL.Label label, argExpList, argTyList, argSizeExpList, loc} =>
        let
          val context = CTX.setLocation context loc
          val (context,code1,argSizeEntries) = transformArgList context argSizeExpList
          val (context,code2,argEntries) = transformArgList context argExpList
          val instruction =
              SI.RecursiveTailCallStatic_MV 
                  {
                   entryPoint = label,
                   argEntries = argEntries,
                   argSizeEntries = argSizeEntries
                  }
          val code3 = generateLocInstruction context [SIO.optimizeInstruction context instruction]
        in
          (context, code1 @ code2 @ code3)
        end

      | IL.InnerTailCall _ => raise Control.Bug "not implemented"

      | IL.InitGlobalArray 
            {
             arrayIndexExp = IL.Constant (CT.WORD globalArrayIndex), 
             arraySizeExp = IL.Constant (CT.WORD arraySize),
             elementTy = AN.BOXED, 
             loc = loc
            } =>
        let
          val instruction = 
              SI.InitGlobalArrayBoxed 
                  {
                   globalArrayIndex = globalArrayIndex, 
                   arraySize = arraySize
                  } 
        in
          (context, generateLocInstruction context [instruction])
        end

      | IL.InitGlobalArray 
            {
             arrayIndexExp = IL.Constant (CT.WORD globalArrayIndex), 
             arraySizeExp = IL.Constant (CT.WORD arraySize),
             elementTy = AN.ATOM, 
             loc = loc
            } =>
        let
          val instruction = 
              SI.InitGlobalArrayUnboxed 
                  {
                   globalArrayIndex = globalArrayIndex, 
                   arraySize = arraySize
                  } 
        in
          (context, generateLocInstruction context [instruction])
        end

      | IL.InitGlobalArray 
            {
             arrayIndexExp = IL.Constant (CT.WORD globalArrayIndex), 
             arraySizeExp = IL.Constant (CT.WORD arraySize),
             elementTy = AN.DOUBLE, 
             loc = loc
            } =>
        let
          val instruction = 
              SI.InitGlobalArrayDouble 
                  {
                   globalArrayIndex = globalArrayIndex, 
                   arraySize = arraySize
                  } 
        in
          (context, generateLocInstruction context [instruction])
        end

      | _ => raise Control.Bug "invalid statement"


  fun transformFunction enclosingContext (functionCode : IL.functionCode) =
      let
        val context = CTX.createContext enclosingContext functionCode
        val ( _, bodyCode) = transformStatement context (#bodyCode functionCode)
        val constantCode = CTX.getConstantInstructions context
        val funId = #functionLabel functionCode
      in
        {
         name = {id = funId, displayName = "L" ^ ID.toString funId},
         loc = #loc functionCode,
         args = map varInfoToEntry (#argVarList functionCode),
         instructions = bodyCode @ constantCode
        }
      end 

  fun transformCluster ({clusterLabel, frameInfo, entryFunctions, innerFunctions, isRecursive, loc} : IL.clusterCode) =
      let
        val initialContext = CTX.createInitialContext loc
        val functionCodes = map (transformFunction initialContext) (entryFunctions @ innerFunctions)
        val tyvars = #tyvars frameInfo
        
        fun groupByType (varInfo,(atoms, pointers, doubles, records, unboxedRecords)) =
            let 
              val entry = varInfoToEntry varInfo
              fun insertRecord tyvarid records=
                  let
                    val entriesOfTyVar =
                        case IEnv.find (records, tyvarid) of
                          NONE => [entry]
                        | SOME entries => entry :: entries
                  in IEnv.insert (records, tyvarid, entriesOfTyVar) end
            in
              case #ty varInfo of
                AN.BOXED => (atoms, entry :: pointers, doubles, records, unboxedRecords)
              | AN.ATOM => (entry :: atoms, pointers, doubles, records, unboxedRecords)
              | AN.DOUBLE => (atoms, pointers, entry :: doubles, records, unboxedRecords)
              | AN.GENERIC tyvarid => (atoms, pointers, doubles, insertRecord tyvarid records, unboxedRecords)
              | AN.SINGLE tyvarid => (atoms, pointers, doubles, insertRecord tyvarid records, unboxedRecords)
              | AN.UNBOXED tyvarid => (atoms, pointers, doubles, records, insertRecord tyvarid unboxedRecords)
            end
        val localVars = CTX.getLocalVariables initialContext
        val (atomVarIDs, pointerVarIDs, doubleVarIDs, recordVarIDsMap, unboxedRecordVarIDsMap) = 
            foldl groupByType ([], [], [], IEnv.empty, IEnv.empty) localVars

        (* A frame bitmap is composed from tags information of free type variables and bound type variables
         * so that least bits coresspond to bound type variables and most bits correspond to free type variables.
         * The list of arbitrary type local variables should be sorted in this order.
         * Only GENERIC type variables and SINGLE type variables can be considered as arbitrary type variable whose
         * slots require to be garbage collected.
         * UNBOXED slots are allocated similar to arbitrary type slots, but they are places at tails of record group,
         * thus does not required garbage collections.
         * Futher optimization could be done here for considering UNBOXED slots as double.
         *)
        val recordVarIDLists =
            map
            (fn tyvarid =>
                case IEnv.find (recordVarIDsMap, tyvarid) of
                  SOME entries => entries
                | NONE => [])
            tyvars

        val unboxedRecordVarIDLists = IEnv.listItems unboxedRecordVarIDsMap

        val tagArgs = map varInfoToEntry (#tagArgs frameInfo)
        val bitmapFree =
            case #bitmapFree frameInfo of
              SOME w => [w]
            | NONE => []

        val frameInfo = 
            {
              bitmapvals = {args = tagArgs, frees = bitmapFree},
              atoms = atomVarIDs,
              pointers = pointerVarIDs,
              doubles = doubleVarIDs,
              records = recordVarIDLists @ unboxedRecordVarIDLists
            }
        val SIClusterCode =
            {
             frameInfo = frameInfo,
             functionCodes = functionCodes,
             loc = loc
            } : SI.clusterCode
      in
        SIO.deadCodeEliminate SIClusterCode
      end

  fun generate ({clusterCodes, initFunctionLabel} : IL.moduleCode) =
      map transformCluster (rev clusterCodes)

end
