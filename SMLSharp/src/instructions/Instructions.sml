(* -*- sml -*- *)

(**
 * IML instruction set.
 * @author YAMATODANI Kiyoshi
 * @author Huu-Duc Nguyen
 * @version $Id: Instructions.sml.in,v 1.50 2007/12/19 02:00:56 kiyoshiy Exp $
 *)
structure Instructions =
struct

  datatype instruction =
           (* store an integer into a frame slot. *)
           LoadInt of
           {
             (* an integer value *)
             value : SInt32,
             (* the index of a frame slot into which the integer is stored. *)
             destination : UInt32
           }
         | LoadLargeInt of
           {
             (* the offset of a ConstString instruction which holds a
              * string representation of largeInt in its operand. *)
             value : UInt32,
             destination : UInt32
           }
         | LoadWord of {value : UInt32, destination : UInt32}
         | LoadString of
           {
             (* the offset of a ConstString instruction which holds a
              * string constant in its operand. *)
             string : UInt32,
             destination : UInt32
           }
         | LoadFloat of {value : Real32, destination : UInt32}
         | LoadReal of {value : Real64, destination : UInt32}
         | (* this instruction is now not used. *)
           LoadBoxedReal of {value : Real64, destination : UInt32}
         | LoadChar of {value : UInt32, destination : UInt32}
         | LoadEmptyBlock of {destination : UInt32}
         | LoadAddress of {address : UInt32, destination : UInt32}
         | (* copy a value from a frame slot to another slot. *)
           Access_S of {variableIndex : UInt32, destination : UInt32}
         | Access_D of {variableIndex : UInt32, destination : UInt32}
         | (* copy a value from frame slot(s) to other frame slot(s).
            * The number of slots to be copied is determined in runtime.
            *)
           Access_V of
           {
             (* the index of the first slot which holds a value to be copied.
              *)
             variableIndex : UInt32,
             (* the index of a slot which holds the size of value. *)
             variableSizeIndex : UInt32,
             (* the index of the second slot into which the value is
              * copied. *)
             destination : UInt32
           }
         | (* copy a value from a field in the ENV block to a frame slot. *)
           AccessEnv_S of {offset : UInt32, destination : UInt32}
         | AccessEnv_D of {offset : UInt32, destination : UInt32}
         | AccessEnv_V of
           {
             offset : UInt32,
             variableSizeIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a block which is linked from the ENV block to
            * a frame slot.
            *)
           AccessNestedEnv_S of
           {
             (* the number of indirection from the ENV block to the target
              * block which contains the value to be copied.
              * A pointer to a child block is in the last field of the block.
              *)
             nestLevel : UInt32,
             (* the offset of a field in the target block which holds the
              * value to be copied. *)
             offset : UInt32,
             destination : UInt32
           }
         | AccessNestedEnv_D of
           {
             nestLevel : UInt32,
             offset : UInt32,
             destination : UInt32
           }
         | AccessNestedEnv_V of
           {
	     nestLevel : UInt32,
             offset : UInt32,
             variableSizeIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a block field to a frame slot.
           *)
           GetField_S of
           {
             (* the offset of a field in a block which holds the value to be
              * copied. *)
             fieldOffset : UInt32,
             (* the index of a frame slot which holds a pointer to a block. *)
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetField_D of
           {
             fieldOffset : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetField_V of
           {
             fieldOffset : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a block field to a frame slot.
            * The offset of the block field is determined in runtime.
            *)
           GetFieldIndirect_S of
           {
             (* the index of a frame slot which holds the offset of the
              * block field. *)
             fieldOffsetIndex : UInt32,
             (* the index of a frame slot which holds a pointer to a block. *)
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetFieldIndirect_D of
           {
             fieldOffsetIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetFieldIndirect_V of
           {
             fieldOffsetIndex : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a block field to a frame slot.
            * The block which contains the value is obtained by traversing
            * indirect link.
            * The offset of the block field is determined in compile time.
            *)
           GetNestedField_S of
           {
             (* the number of indirect links between the start block and the
              * target block. *)
             nestLevel : UInt32,
             (* the offset of a frame slot *)
             fieldOffset : UInt32,
             (* the index of a frame slot which holds a pointer to a block
              * which is the start point of indirect link to reach the target
              * block. *)
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetNestedField_D of
           {
             nestLevel : UInt32,
             fieldOffset : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetNestedField_V of
           {
             nestLevel : UInt32,
             fieldOffset : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a block field to a frame slot.
            * The block which contains the value is obtained by traversing
            * indirect link.
            * The offset of the block field is determined in runtime.
            *)
           GetNestedFieldIndirect_S of
           {
             (* The index of a frame slot which hold 
              * the number of indirect links between the start block and the
              * target block. *)
             nestLevelIndex : UInt32,
             (* the index of a frame slot which holds the offset of a field
              * in the target block which holds the value to be copied. *)
             fieldOffsetIndex : UInt32,
             (* the index of a frame slot which holds a pointer to a block
              * which is the start point of indirect link to reach the target
              * block. *)
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetNestedFieldIndirect_D of
           {
             nestLevelIndex : UInt32,
             fieldOffsetIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | GetNestedFieldIndirect_V of
           {
             nestLevelIndex : UInt32,
             fieldOffsetIndex : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             destination : UInt32
           }
         | (* copy a value from a frame slot to a block field.
            *)
           SetField_S of
           {
             (* the offset of a field in the block into which the value is
              * copied. *)
             fieldOffset : UInt32,
             (* the index of a frame slot which holds a pointer to a block.
              *)
             blockIndex : UInt32,
             (* the index of a frame slot which holds the value to be copied.
              *)
             newValueIndex : UInt32
           }
         | SetField_D of
           {
             fieldOffset : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | SetField_V of
           {
             fieldOffset : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | (* copy a value from a frame slot to a block field.
            * The offset of the block field is determined in runtime.
            *)
           SetFieldIndirect_S of
           {
             (* the index of a frame slot which holds the offset of the
              * block fielld. *)
             fieldOffsetIndex : UInt32,
             (* the index of a frame slot which holds a pointer to a block.
              *)
             blockIndex : UInt32,
             (* the index of a frame slot which holds the value to be copied.
              *)
             newValueIndex : UInt32
           }
         | SetFieldIndirect_D of
           {
             fieldOffsetIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | SetFieldIndirect_V of
           {
             fieldOffsetIndex : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | (* copy a value from a frame slot to a block field.
            * The block into which the value is copied is obtained by
            * traversing indirect link.
            * The offset of the block field is determined in compile time.
            *)
           SetNestedField_S of
           {
             (* the number of indirect links between the start block and the
              * target block. *)
             nestLevel : UInt32,
             (* the offset of the field in the target block into which the value is copied. *)
             fieldOffset : UInt32,
             (* the index of a frame slot which holds a pointer to a block
              * which is the start point of indirect link to reach the target
              * block. *)
             blockIndex : UInt32,
             (* the index of a frame slot which holds the value to be copied.
              *)
             newValueIndex : UInt32
           }
         | SetNestedField_D of
           {
             nestLevel : UInt32,
             fieldOffset : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | SetNestedField_V of
           {
             nestLevel : UInt32,
             fieldOffset : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | (* copy a value from a frame slot to a block field.
            * The block into which the value is copied is obtained by
            * traversing indirect link.
            * The offset of the block field is determined in runtime.
            *)
           SetNestedFieldIndirect_S of
           {
             (* The index of a frame slot which hold
              * the number of indirect links between the start block and the
              * target block. *)
             nestLevelIndex : UInt32,
             (* the index of a frame slot which holds the offset of a field
              * in the target block into which the value is copied. *)
             fieldOffsetIndex : UInt32,
             (* the index of a frame slot which holds a pointer to a block
              * which is the start point of indirect link to reach the target
              * block. *)
             blockIndex : UInt32,
             (* the index of a frame slot which holds the value to be copied.
              *)
             newValueIndex : UInt32
           }
         | SetNestedFieldIndirect_D of
           {
             nestLevelIndex : UInt32,
             fieldOffsetIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | SetNestedFieldIndirect_V of
           {
             nestLevelIndex : UInt32,
             fieldOffsetIndex : UInt32,
             fieldSizeIndex : UInt32,
             blockIndex : UInt32,
             newValueIndex : UInt32
           }
         | (* allocate a new block which holds a copy of contents of another
            * block. *)
           CopyBlock of
           {
             (* the index of a frame slot which holds a pointer to a block
              * whose contents are copied into a new block. *)
             blockIndex : UInt32,
             nestLevelIndex : UInt32,
             destination : UInt32
           }
         | CopyArray_S of
           {
             srcIndex : UInt32,
             srcOffsetIndex : UInt32,
             dstIndex : UInt32,
             dstOffsetIndex : UInt32,
             lengthIndex : UInt32
           }
         | CopyArray_D of
           {
             srcIndex : UInt32,
             srcOffsetIndex : UInt32,
             dstIndex : UInt32,
             dstOffsetIndex : UInt32,
             lengthIndex : UInt32
           }
         | CopyArray_V of
           {
             srcIndex : UInt32,
             srcOffsetIndex : UInt32,
             dstIndex : UInt32,
             dstOffsetIndex : UInt32,
             lengthIndex : UInt32,
             elementSizeIndex : UInt32
           }
         | GetGlobal_S of
           {
             globalArrayIndex : UInt32,
             offset : UInt32, 
             destination : UInt32
           }
         | GetGlobal_D of
           {
             globalArrayIndex : UInt32,
             offset : UInt32, 
             destination : UInt32
           }
         | SetGlobal_S of
           {
             globalArrayIndex : UInt32,
             offset : UInt32, 
             variableIndex : UInt32
           }
         | SetGlobal_D of
           {
             globalArrayIndex : UInt32,
             offset : UInt32, 
             variableIndex : UInt32
           }
         | InitGlobalArrayUnboxed of
           {
             globalArrayIndex : UInt32,
             arraySize : UInt32 
           }
         | InitGlobalArrayBoxed of
           {
             globalArrayIndex : UInt32,
             arraySize : UInt32 
           }
         | InitGlobalArrayDouble of
           {
             globalArrayIndex : UInt32,
             arraySize : UInt32 
           }
         | (* store a pointer to the ENV block into a frame slot. *)
           GetEnv of {destination : UInt32}
         | CallPrim of
           {
             primSymbolIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | (** <p>
            * Hierarchy of call instructions.
            * <pre>
            *   XXX_X
            *     +-- XXX_0
            *     +-- XXX_S
            *     +-- XXX_D
            *     +-- XXX_V
            *     +-- XXX_MS
            *     +-- XXX_MLD
            *     +-- XXX_MLV
            *     +-- XXX_MF
            *     +-- XXX_MV
            * </pre>
            * </p>
            * <p>
            * XXX_A is the call instruction for XXX where A indicates the arguments kind
            * </p>
            * <p>
            * Arguments kind "0" indicates an empty argument list 
            * </p>
            * <p>
            * Arguments kind {"S","D","V"} indicates a single argument whose size is single size, 
            * double size, and arbitrary size, respectively.
            * </p>
            * <p>
            * Arguments kind "MS" indicates a single size argument list
            * </p>
            * <p>
            * Arguments kind "MF" indicates a fixed size argument list
            * </p>
            * <p>
            * Arguments kind "MV" indicates a generic argument list, arguments' sizes are
            * decided at runtime
            * </p>
            * <p>
            * Tail call instructions does not require to specify the return values'
            * destinations.
            * Suffix {0,1,M} is omitted.
            * </p>
            *)
           Apply_0_0 of
           {
             closureIndex : UInt32
           }
         | Apply_S_0 of
           {
             closureIndex : UInt32,
             argIndex : UInt32
           }
         | Apply_D_0 of
           {
             closureIndex : UInt32,
             argIndex : UInt32
           }
         | Apply_V_0 of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | Apply_MS_0 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | Apply_MLD_0 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | Apply_MLV_0 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }
         | Apply_MF_0 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | Apply_MV_0 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | CallStatic_0_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32
           }
         | CallStatic_S_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32
           }
         | CallStatic_D_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32
           }
         | CallStatic_V_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | CallStatic_MS_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | CallStatic_MLD_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | CallStatic_MLV_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }
         | CallStatic_MF_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | CallStatic_MV_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | RecursiveCallStatic_0_0 of
           {
             entryPoint : UInt32
           }
         | RecursiveCallStatic_S_0 of
           {
             entryPoint : UInt32,
             argIndex : UInt32
           }
         | RecursiveCallStatic_D_0 of
           {
             entryPoint : UInt32,
             argIndex : UInt32
           }
         | RecursiveCallStatic_V_0 of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | RecursiveCallStatic_MS_0 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | RecursiveCallStatic_MLD_0 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | RecursiveCallStatic_MLV_0 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }
         | RecursiveCallStatic_MF_0 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | RecursiveCallStatic_MV_0 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | Apply_0_1 of
           {
             closureIndex : UInt32,
             destination : UInt32
           }
         | Apply_S_1 of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | Apply_D_1 of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | Apply_V_1 of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destination : UInt32
           }
         | Apply_MS_1 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | Apply_MLD_1 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | Apply_MLV_1 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destination : UInt32
           }
         | Apply_MF_1 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destination : UInt32
           }
         | Apply_MV_1 of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destination : UInt32
           }
         | CallStatic_0_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             destination : UInt32
           }
         | CallStatic_S_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | CallStatic_D_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | CallStatic_V_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destination : UInt32
           }
         | CallStatic_MS_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | CallStatic_MLD_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | CallStatic_MLV_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destination : UInt32
           }
         | CallStatic_MF_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destination : UInt32
           }
         | CallStatic_MV_1 of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destination : UInt32
           }
         | RecursiveCallStatic_0_1 of
           {
             entryPoint : UInt32,
             destination : UInt32
           }
         | RecursiveCallStatic_S_1 of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | RecursiveCallStatic_D_1 of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             destination : UInt32
           }
         | RecursiveCallStatic_V_1 of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destination : UInt32
           }
         | RecursiveCallStatic_MS_1 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | RecursiveCallStatic_MLD_1 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | RecursiveCallStatic_MLV_1 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destination : UInt32
           }
         | RecursiveCallStatic_MF_1 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destination : UInt32
           }
         | RecursiveCallStatic_MV_1 of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destination : UInt32
           }
         | Apply_0_M of
           {
             closureIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_S_M of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_D_M of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_V_M of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_MS_M of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_MLD_M of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_MLV_M of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_MF_M of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | Apply_MV_M of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | TailApply_0 of
           {
             closureIndex : UInt32
           }
         | TailApply_S of
           {
             closureIndex : UInt32,
             argIndex : UInt32
           }
         | TailApply_D of
           {
             closureIndex : UInt32,
             argIndex : UInt32
           }
         | TailApply_V of
           {
             closureIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | TailApply_MS of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | TailApply_MLD of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | TailApply_MLV of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }
         | TailApply_MF of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | TailApply_MV of
           {
             closureIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | CallStatic_0_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_S_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_D_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_V_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_MS_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_MLD_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_MLV_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_MF_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | CallStatic_MV_M of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | TailCallStatic_0 of
           {
             entryPoint : UInt32,
             envIndex : UInt32
           }
         | TailCallStatic_S of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32
           }
         | TailCallStatic_D of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32
           }
         | TailCallStatic_V of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | TailCallStatic_MS of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | TailCallStatic_MLD of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | TailCallStatic_MLV of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }
         | TailCallStatic_MF of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | TailCallStatic_MV of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | RecursiveCallStatic_0_M of
           {
             entryPoint : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_S_M of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_D_M of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_V_M of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_MS_M of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_MLD_M of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_MLV_M of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_MF_M of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveCallStatic_MV_M of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list,
             destsCount : UInt32,
             destinations : UInt32 list
           }
         | RecursiveTailCallStatic_0 of
           {
             entryPoint : UInt32
           }
         | RecursiveTailCallStatic_S of
           {
             entryPoint : UInt32,
             argIndex : UInt32
           }
         | RecursiveTailCallStatic_D of
           {
             entryPoint : UInt32,
             argIndex : UInt32
           }
         | RecursiveTailCallStatic_V of
           {
             entryPoint : UInt32,
             argIndex : UInt32,
             argSizeIndex : UInt32
           }
         | RecursiveTailCallStatic_MS of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | RecursiveTailCallStatic_MLD of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list
           }
         | RecursiveTailCallStatic_MLV of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             lastArgSizeIndex : UInt32
           }

         | RecursiveTailCallStatic_MF of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizes : UInt32 list
           }
         | RecursiveTailCallStatic_MV of
           {
             entryPoint : UInt32,
             argsCount : UInt32,
             argIndexes : UInt32 list,
             argSizeIndexes : UInt32 list
           }
         | (* allocate a new block.
            * Payload of the block is partitioned into logical fields.
            * Each logical field occupies variable number of physical fields.
            * The number of physical fields each logical field occupies is
            * determined in runtime.
            *)
           MakeBlock of
           {
             (* the offset of a frame slot which holds a bitmap for the new
              * block. *)
             bitmapIndex : UInt32,
             (* the offset of a frame slot which holds the size of the new
              * block. *)
	     sizeIndex : UInt32,
             (* the number of logical fields. *)
             fieldsCount : UInt32,
             (* a list of offsets of frame slots which hold initial values of
              * each logical field. *)
             fieldIndexes : UInt32 list,
             (* a list of offsets of frame slots which hold the size of 
              * each logical field. *)
             fieldSizeIndexes : UInt32 list,
             destination : UInt32
           }
         | (* allocate a new block.
            * Payload of the block is partitioned into logical fields.
            * Each logical field occupies variable number of physical fields.
            * The number of physical fields each logical field occupies is
            * determined in runtime.
            *)
           MakeFixedSizeBlock of
           {
             (* the offset of a frame slot which holds a bitmap for the new
              * block. *)
             bitmapIndex : UInt32,
             (* the offset of a frame slot which holds the size of the new
              * block. *)
	     size : UInt32,
             (* the number of logical fields. *)
             fieldsCount : UInt32,
             (* a list of offsets of frame slots which hold initial values of
              * each logical field. *)
             fieldIndexes : UInt32 list,
             (* a list of offsets of frame slots which hold the size of 
              * each logical field. *)
             fieldSizes : UInt32 list,
             destination : UInt32
           }
         | (* This is a derived version of the MakeBlock instruction
            * specialized to allocate a block in which every logical field
            * occupies one physical field.
            *)
           MakeBlockOfSingleValues of
           {
             bitmapIndex : UInt32,
             fieldsCount : UInt32,
             fieldIndexes : UInt32 list,
             destination : UInt32
           }
         | (* allocate a new mutable array block.
            *)
           MakeArray_S of
           {
             bitmapIndex : UInt32,
             sizeIndex : UInt32,
             (* the offset of a frame slot which holds a value which is
              * copied to every field of the new array. *)
             initialValueIndex : UInt32,
             isMutable : UInt32,
             destination : UInt32
           }
         | MakeArray_D of
           {
             bitmapIndex : UInt32,
             sizeIndex : UInt32,
             initialValueIndex : UInt32,
             isMutable : UInt32,
             destination : UInt32
           }
         | MakeArray_V of
           {
             bitmapIndex : UInt32,
             sizeIndex : UInt32,
             initialValueIndex : UInt32,
	     initialValueSize : UInt32,
             isMutable : UInt32,
             destination : UInt32
           }
         | MakeClosure of
           {
             entryPoint : UInt32,
             envIndex : UInt32,
             destination : UInt32
           }
         | Raise of {exceptionIndex : UInt32}
         | PushHandler of {handler : UInt32, exceptionIndex : UInt32}
         | PopHandler
         | SwitchInt of
           {
             targetIndex : UInt32,
             casesCount : UInt32,
             cases : SInt32 list,
             default : UInt32
           }
         | SwitchLargeInt of
           {
             targetIndex : UInt32,
             casesCount : UInt32,
             cases : UInt32 list,
             default : UInt32
           }
         | SwitchWord of
           {
             targetIndex : UInt32,
             casesCount : UInt32,
             cases : UInt32 list,
             default : UInt32
           }
         | SwitchChar of
           {
             targetIndex : UInt32,
             casesCount : UInt32,
             cases : UInt32 list,
             default : UInt32
           }
         | SwitchString of
           {
             targetIndex : UInt32,
             casesCount : UInt32,
             cases : UInt32 list,
             default : UInt32
           }
         | Jump of {destination : UInt32}
         | IndirectJump of {destination : UInt32}
         | Exit
         | Return_0
         | Return_S of {variableIndex : UInt32}
         | Return_D of {variableIndex : UInt32}
         | Return_V of {variableIndex : UInt32, variableSizeIndex : UInt32}
         | Return_MS of 
           {
             variablesCount: UInt32, 
             variableIndexes : UInt32 list
           }
         | Return_MLD of 
           {
             variablesCount: UInt32, 
             variableIndexes : UInt32 list
           }
         | Return_MLV of 
           {
             variablesCount: UInt32, 
             variableIndexes : UInt32 list,
             lastVariableSizeIndex : UInt32
           }
         | Return_MF of 
           {
             variablesCount: UInt32, 
             variableIndexes : UInt32 list, 
             variableSizes : UInt32 list
           }
         | Return_MV of 
           {
             variablesCount: UInt32, 
             variableIndexes : UInt32 list, 
             variableSizeIndexes : UInt32 list
           }
         | (* entry point of a function.
            * Informations required to allocate new stack frame for an
            * invocation of the function are obtained from its operands.
            *)
           FunEntry of
           {
             (* the number of words of the stack frame. *)
             frameSize : UInt32,
             (* the offset of the first instruction of the function body. *)
             startOffset : UInt32,
             (* the number of arguments this function requires. *)
             arity : UInt32,
             (* a list of offset of slots of a new stack frame into which
              * passed arguments are copied.
              *)
             argsdest : UInt32 list,
             (* informations necessary to compose a frame bitmap. *)
             bitmapvalsFreesCount : UInt32,
             bitmapvalsFrees : UInt32 list,
             bitmapvalsArgsCount : UInt32,
             bitmapvalsArgs : UInt32 list,
             (* the number of slots used by pointer variables. *)
             pointers : UInt32,
             (* the number of slots used by non-pointer variables. *)
             atoms : UInt32,
             (* the number of elements of recordGroups. *)
             recordGroupsCount : UInt32,
             (* a list of the number of slots used by polytype variables
              * whose instantiated type is indicated by a bit in the frame
              * bitmap. *)
             recordGroups : UInt32 list
           }
         | (* This instruction is referred to by LoadString and SwitchString
            * instructions. This instruction itself is never executed.*)
           ConstString of
           {
             (* The number of bytes of the string, excluding trailing zeros. *)
             length : UInt32,
             (* This byte list includes trailing zeros.
              * The number of zeros is from 1 to 4.
              *)
             string : UInt8 list
           }
         | Nop
         | (* invoke an external function which is imported by the FFIVal
            * instruction.
            *)
           ForeignApply of
           {
             (* the index of a frame slot which holds a pointer to a block
              * containing a pointer to the external function. *)
             closureIndex : UInt32,
             argsCount : UInt32,
             (* largeSwitchTag is used to dispatch C FFI function in VirtualMachine.cc
              * if Control.LARGEFFISWITCH = ref true. *)
             switchTag : UInt32,
             convention : UInt32,
             argIndexes : UInt32 list,
             destination : UInt32
           }
         | RegisterCallback of
           {
             closureIndex : UInt32,
             sizeTag : UInt32,
             destination : UInt32
           }
         | DebuggerBreak

         | AddInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | AddLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | AddReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | AddFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | AddWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | AddByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | AddByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | SubInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | SubLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | SubReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | SubFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | SubWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | SubByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | SubByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | MulInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | MulLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | MulReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | MulFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | MulWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | MulByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | MulByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | DivInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | DivLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | DivReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | DivFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | DivWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | DivByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | DivByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | ModInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | ModInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | ModLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | ModLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | ModWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | ModWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | ModByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | ModByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | QuotInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | QuotInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | QuotLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | QuotLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | RemInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | RemInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | RemLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | RemLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | LtInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | LtLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LtReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | LtFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | LtWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LtByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LtChar_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LtChar_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | GtInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | GtLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GtReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | GtFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | GtWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GtByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GtChar_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GtChar_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | LteqInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | LteqLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LteqReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | LteqFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | LteqWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LteqByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | LteqChar_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | LteqChar_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | GteqInt_Const_1 of
           {
            argValue1 : SInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : SInt32,
            destination : UInt32
           }
         | GteqLargeInt_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqLargeInt_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GteqReal_Const_1 of
           {
            argValue1 : Real64,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqReal_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real64,
            destination : UInt32
           }
         | GteqFloat_Const_1 of
           {
            argValue1 : Real32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqFloat_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : Real32,
            destination : UInt32
           }
         | GteqWord_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqWord_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GteqByte_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqByte_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | GteqChar_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | GteqChar_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }

         | Word_andb_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_andb_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | Word_orb_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_orb_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | Word_xorb_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_xorb_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | Word_leftShift_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_leftShift_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | Word_logicalRightShift_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_logicalRightShift_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }
         | Word_arithmeticRightShift_Const_1 of
           {
            argValue1 : UInt32,
            argIndex2 : UInt32,
            destination : UInt32
           }
         | Word_arithmeticRightShift_Const_2 of
           {
            argIndex1 : UInt32,
            argValue2 : UInt32,
            destination : UInt32
           }


        | Equal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | AddByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | SubByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | MulByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | DivFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | ModInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | ModLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | ModWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | ModByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | QuotInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | QuotLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | RemInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | RemLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | NegInt of {argIndex : UInt32, destination : UInt32}
        | NegLargeInt of {argIndex : UInt32, destination : UInt32}
        | NegReal of {argIndex : UInt32, destination : UInt32}
        | NegFloat of {argIndex : UInt32, destination : UInt32}
        | AbsInt of {argIndex : UInt32, destination : UInt32}
        | AbsLargeInt of {argIndex : UInt32, destination : UInt32}
        | AbsReal of {argIndex : UInt32, destination : UInt32}
        | AbsFloat of {argIndex : UInt32, destination : UInt32}
        | LtInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtChar of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LtString of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtChar of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GtString of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqChar of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | LteqString of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqLargeInt of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqReal of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqFloat of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqWord of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqByte of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqChar of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | GteqString of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Byte_toIntX of {argIndex : UInt32, destination : UInt32}
        | Byte_fromInt of {argIndex : UInt32, destination : UInt32}
        | Word_toIntX of {argIndex : UInt32, destination : UInt32}
        | Word_fromInt of {argIndex : UInt32, destination : UInt32}
        | Word_andb of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Word_orb of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Word_xorb of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Word_notb of {argIndex : UInt32, destination : UInt32}
        | Word_leftShift of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Word_logicalRightShift of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Word_arithmeticRightShift of {argIndex1 : UInt32, argIndex2 : UInt32, destination : UInt32}
        | Array_length of {argIndex : UInt32, destination : UInt32}
        | CurrentIP of {argIndex : UInt32, destination : UInt32}
        | StackTrace of {argIndex : UInt32, destination : UInt32}

end