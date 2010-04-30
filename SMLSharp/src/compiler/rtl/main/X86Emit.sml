(**
 * x86 RTL
 * @copyright (c) 2009, Tohoku University.
 * @author UENO Katsuhiro
 * @version $Id: $
 *)

structure X86Emit : RTLEMIT =
struct

  structure Target = X86Asm
  structure X = X86Asm
  structure I = RTL

  open X86Asm
  open RTL

  type env =
      {
        regAlloc: Target.reg LocalVarID.Map.map,  (* var id -> reg *)
        slotIndex: int LocalVarID.Map.map,        (* slot id -> offset *)
        preFrameOrigin: int,
        postFrameOrigin: int,
        frameAllocSize: int
      }

  type env' =
      {
        clusterId: RTL.clusterId option,
        totalPreFrameSize: int,
        env: env
      }

  fun regAlloc ({env={regAlloc,...},...}:env') varId =
      case LocalVarID.Map.find (regAlloc, varId) of
        NONE => raise Control.Bug ("regAlloc: " ^
                                   Control.prettyPrint (I.format_id varId))
      | SOME reg => reg

  fun slotIndex ({env={slotIndex,...},...}:env') slotId =
      case LocalVarID.Map.find (slotIndex, slotId) of
        NONE => raise Control.Bug ("slotIndex: " ^
                                   Control.prettyPrint (I.format_id slotId))
      | SOME reg => reg

  fun preFrameOrigin ({env={preFrameOrigin,...},...}:env') = preFrameOrigin
  fun postFrameOrigin ({env={postFrameOrigin,...},...}:env') = postFrameOrigin
  fun clusterId ({clusterId=SOME x,...}:env') = X.CLUSTER x
    | clusterId {clusterId=NONE,...} = raise Control.Bug "clusterId"
  fun frameAllocSize ({env={frameAllocSize,...},...}:env') = frameAllocSize
  fun totalPreFrameSize ({totalPreFrameSize,...}:env') = totalPreFrameSize

  fun formatOf ty =
      case ty of
        I.Int8 _ => {tag = UNBOXED, size = 1, align = 1}
      | I.Int16 _ => {tag = UNBOXED, size = 2, align = 2}
      | I.Int32 _ => {tag = UNBOXED, size = 4, align = 4}
      | I.NoType => {tag = UNBOXED, size = 4, align = 4}
      | I.Ptr I.Data => {tag = BOXED, size = 4, align = 4}
      | I.Ptr _ => {tag = UNBOXED, size = 4, align = 4}
      | I.Int64 _ => {tag = UNBOXED, size = 8, align = 4}
      | I.Real32 => {tag = UNBOXED, size = 4, align = 4}
      | I.Real64 => {tag = UNBOXED, size = 8, align = 8}
      | I.Real80 => {tag = UNBOXED, size = 12, align = 16}
      | I.Generic tid => {tag = GENERIC tid, size = 16, align = 16}
      | I.PtrDiff _ => {tag = UNBOXED, size = 4, align = 4}
      | I.Atom => {tag = UNBOXED, size = 4, align = 4}

  fun R32toR8 EAX = XL EAX
    | R32toR8 EBX = XL EBX
    | R32toR8 ECX = XL ECX
    | R32toR8 EDX = XL EDX
    | R32toR8 _ = raise Control.Bug "toR8"
  fun R32toR16 EAX = X EAX
    | R32toR16 EBX = X EBX
    | R32toR16 ECX = X ECX
    | R32toR16 EDX = X EDX
    | R32toR16 ESI = X ESI
    | R32toR16 EDI = X EDI
    | R32toR16 _ = raise Control.Bug "toR16"
  fun RM32toRMI32 (R r) = R_ r
    | RM32toRMI32 (M m) = M_ m
  fun RM16toRMI16 (R16 r) = R_16 r
    | RM16toRMI16 (M16 m) = M_16 m
  fun RM8toRMI8 (R8 r) = R_8 r
    | RM8toRMI8 (M8 m) = M_8 m
  fun RMI32toRM32 (R_ r) = R r
    | RMI32toRM32 (M_ m) = M m
    | RMI32toRM32 (I_ i) = raise Control.Bug "RMI32toRM32"
  fun RM32toR32 (R r) = r
    | RM32toR32 _ = raise Control.Bug "RM32toR32"
  fun RM32toRM16 (R r) = R16 (R32toR16 r)
    | RM32toRM16 (M m) = M16 m
  fun RM32toRM8 (R r) = R8 (R32toR8 r)
    | RM32toRM8 (M m) = M8 m
  fun RMI32toRMI16 (R_ r) = R_16 (R32toR16 r)
    | RMI32toRMI16 (M_ m) = M_16 m
    | RMI32toRMI16 (I_ i) = I_16 i
  fun RMI32toRMI8 (R_ r) = R_8 (R32toR8 r)
    | RMI32toRMI8 (M_ m) = M_8 m
    | RMI32toRMI8 (I_ i) = I_8 i
  fun RM32toMem (R r) = raise Control.Bug "RM32toMem"
    | RM32toMem (M m) = m
  fun R8toR32 (XL r) = r
    | R8toR32 (XH _) = raise Control.Bug "R8toR32"


  fun emitCC cc =
      case cc of
        OVERFLOW => O
      | NOTOVERFLOW => NO
      | EQUAL => E
      | NOTEQUAL => NE
      | BELOW => B
      | BELOWEQUAL => BE
      | ABOVE => A
      | ABOVEEQUAL => AE
      | SIGN => X.S
      | NOTSIGN => NS
      | LESS => L
      | LESSEQUAL => LE
      | GREATER => G
      | GREATEREQUAL => GE

  fun assert i b =
      if b then ()
      else raise Control.Bug ("assertion failed: " ^ Int.toString i)

  fun r32 env (REG {id,...}) = regAlloc env id
    | r32 env (COUPLE _) = raise Control.Bug "r32: COUPLE"
    | r32 env (MEM _) = raise Control.Bug "r32: MEM"
  fun r16 env dst = R32toR16 (r32 env dst)
  fun r8 env dst = R32toR8 (r32 env dst)

(*
  fun localLabel l = "L" ^ LocalVarID.toString l
*)

  fun emitScale 1 = 1
    | emitScale 2 = 2
    | emitScale 4 = 4
    | emitScale 8 = 8
    | emitScale _ = raise Control.Bug "emitScale"

  fun emitAbsLabel env label =
      case label of
        LABEL l => X.LOCAL (clusterId env, l)
      | SYMBOL (_,_,s) => X.SYMBOL s
      | CURRENT_POSITION => raise Control.Bug "emitLabel: CURRENT_POSITION"
      | LINK_ENTRY s => X.LINKPTR s
      | LINK_STUB s => X.LINKSTUB s
      | ELF_GOT => X.SYMBOL "_GLOBAL_OFFSET_TABLE_"
      | NULL _ => X.NULL
      | LABELCAST (_, l) => emitAbsLabel env label

  fun emitRelLabel env label =
      case label of
        LABEL l => X.LABEL (X.LOCAL (clusterId env, l))
      | SYMBOL (_,_,s) => X.LABEL (X.SYMBOL s)
      | CURRENT_POSITION => X.CURRENTPOS
      | LINK_ENTRY s => X.LABEL (X.LINKPTR s)
      | LINK_STUB s => X.LABEL (X.LINKSTUB s)
      | ELF_GOT => X.LABEL (X.SYMBOL "_GLOBAL_OFFSET_TABLE_")
      | NULL _ => X.LABEL X.NULL
      | LABELCAST (_, label) => emitRelLabel env label

  fun emitImm env const =
      case const of
        SYMOFFSET {base=CURRENT_POSITION, label=ELF_GOT} =>
        X.LABEL (X.SYMBOL "_GLOBAL_OFFSET_TABLE_")
      | SYMOFFSET {base=ELF_GOT, label=LINK_ENTRY symbol} =>
        X.LABEL (X.ELF_GOT (X.SYMBOL symbol))
      | SYMOFFSET {base=ELF_GOT, label=SYMBOL (_,_,symbol)} =>
        X.LABEL (X.ELF_GOTOFF (X.SYMBOL symbol))
      | SYMOFFSET {base=ELF_GOT, label=LABEL l} =>
        X.LABEL (X.ELF_GOTOFF (X.LOCAL (clusterId env, l)))
      | SYMOFFSET {base, label} =>
        CONSTSUB (emitRelLabel env label, emitRelLabel env base)
      | INT64 n => raise Control.Bug "emitImm: SINT64"
      | UINT64 n => raise Control.Bug "emitImm: UINT64"
      | INT32 n => INT n
      | UINT32 n => WORD n
      | INT16 n => INT (Int32.fromLarge (Int.toLarge n))  (* FIXME *)
      | UINT16 n => WORD (Word32.fromLarge (Word.toLarge n))  (* FIXME *)
      | INT8 n => INT (Int32.fromLarge (Int.toLarge n))  (* FIXME *)
      | UINT8 n => WORD (Word32.fromLarge (Word8.toLarge n))  (* FIXME *)
      | REAL32 _ => raise Control.Bug "emitImm: FIXME: Real32"
      | REAL64 _ => raise Control.Bug "emitImm: Real64"
      | REAL64HI n => raise Control.Bug "emitImm: FIXME: Real64Hi"
      | REAL64LO n => raise Control.Bug "emitImm: FIXME: Real64Lo"

  exception NotRIAddr

  fun emitRIAddr env addr =
      case addr of
        ABSADDR label => I_ (X.LABEL (emitAbsLabel env label))
      | ADDRCAST (_, addr) => emitRIAddr env addr
      | DISP (const, addr) =>
        (
          case emitRIAddr env addr of
            I_ i => I_ (X.CONSTADD (emitImm env const, i))
          | _ => raise NotRIAddr
        )
      | BASE var => R_ (r32 env (REG var))
      | BASEINDEX _ => raise NotRIAddr
      | ABSINDEX _ => raise NotRIAddr
      | POSTFRAME _ => raise NotRIAddr
      | PREFRAME _ => raise NotRIAddr
      | WORKFRAME _ => raise NotRIAddr
      | FRAMEINFO _ => raise NotRIAddr

  local
    fun Disp (X.INT 0, addr) = addr
      | Disp (disp, addr) = X.DISP (disp, addr)
  in

  fun emitAddr env addr =
      case addr of
        ADDRCAST (_, addr) => emitAddr env addr
      | ABSADDR label => X.ABSADDR (X.LABEL (emitAbsLabel env label))
      | DISP (const, addr) => Disp (emitImm env const, emitAddr env addr)
      | BASE var => X.BASE (r32 env (REG var))
      | ABSINDEX {base, scale, index} =>
        Disp (X.LABEL (emitAbsLabel env base),
              X.INDEX (r32 env (REG index), emitScale scale))
      | BASEINDEX {base, scale, index} =>
        X.BASEINDEX (r32 env (REG base), r32 env (REG index),
                     emitScale scale)
      | POSTFRAME {offset, size} =>
        Disp (X.INT (Int32.fromInt (postFrameOrigin env + offset)),
              X.BASE X.EBP)
      | PREFRAME {offset, size} =>
        Disp (X.INT (Int32.fromInt (preFrameOrigin env - offset)),
              X.BASE X.EBP)
      | WORKFRAME {id,...} =>
        Disp (X.INT (Int32.fromInt (slotIndex env id)), X.BASE X.EBP)
      | FRAMEINFO offset =>
        Disp (X.INT (Int32.fromInt offset), X.BASE X.EBP)

  fun emitMem env (SLOT {id,...}) =
      Disp (X.INT (Int32.fromInt (slotIndex env id)), X.BASE X.EBP)
    | emitMem env (ADDR x) = emitAddr env x

  end (* local *)

  fun dstToMem env (REG _) = raise Control.Bug "dstToMem: REG"
    | dstToMem env (COUPLE _) = raise Control.Bug "dstToMem: COUPLE"
    | dstToMem env (MEM (_, mem)) = emitMem env mem

  fun rm32 env (MEM (_, mem)) = M (emitMem env mem)
    | rm32 env (dst as REG _) = R (r32 env dst)
    | rm32 env (COUPLE _) = raise Control.Bug "rm32: COUPLE"
  fun rmi32 env (CONST const) = I_ (emitImm env const)
    | rmi32 env (REF (_, dst)) = RM32toRMI32 (rm32 env dst)
  fun rm8 env dst = RM32toRM8 (rm32 env dst)
  fun rm16 env dst = RM32toRM16 (rm32 env dst)

(*
  fun rmi8 env op1 = RMI32toRMI8 (rmi32 env op1)
  fun rmi16 env op1 = RMI32toRMI16 (rmi32 env op1)
*)

  fun rm_rmi env (dst, op1) =
      case (rm32 env dst, rmi32 env op1) of
        (M _, M_ _) => raise Control.Bug "rm_rmi"
      | x => x

  fun emitMOVL (rm32, rmi32) =
      if RM32toRMI32 rm32 = rmi32 then nil else [MOVL (rm32, rmi32)]
  fun emitMOVW (rm16, rmi16) =
      if RM16toRMI16 rm16 = rmi16 then nil else [MOVW (rm16, rmi16)]
  fun emitMOVB (rm8, rmi8) =
      if RM8toRMI8 rm8 = rmi8 then nil else [MOVB (rm8, rmi8)]

  fun to8 (dst, op1) = (RM32toRM8 dst, RMI32toRMI8 op1)
  fun to16 (dst, op1) = (RM32toRM16 dst, RMI32toRMI16 op1)

  fun samePlace (dst, I.REF (_, dst1)) = dst = dst1
    | samePlace (dst, I.CONST _) = false

  fun emitMove env (dst, op1) =
      if samePlace (dst, op1) then nil
      else emitMOVL (rm_rmi env (dst, op1))
  fun emitMove16 env (dst, op1) =
      if samePlace (dst, op1) then nil
      else emitMOVW (to16 (rm_rmi env (dst, op1)))
  fun emitMove8 env (dst, op1) =
      if samePlace (dst, op1) then nil
      else emitMOVB (to8 (rm_rmi env (dst, op1)))

  fun arith1 env (dst, REF (_, op1)) =
      let
        val dst = rm32 env dst
        val op1 = rm32 env op1
      in
        assert 10 (dst = op1);
        dst
      end
    | arith1 env _ = raise Control.Bug "arith1"

  fun arith2 env (dst, REF (_, op1), op2) =
      let
        val dst = rm32 env dst
        val op1 = rm32 env op1
        val op2 = rmi32 env op2
      in
        assert 20 (dst = op1);
        (dst, op2)
      end
    | arith2 env _ = raise Control.Bug "arith2"

  fun shiftInsn env shl shl_cx (dst, REF (_, op1), op2) =
      let
        val dst = rm32 env dst
        val op1 = rm32 env op1
      in
        assert 30 (dst = op1);
        case op2 of
          CONST (UINT32 x) =>
          if x < 0w32
          then shl (dst, Word32.toInt x)
          else raise Control.Bug "shiftInsn: shift count >= 32"
        | CONST _ => raise Control.Bug "shiftInsn: CONST"
        | REF (_, op2) => (assert 40 (r32 env op2 = ECX); shl_cx dst)
      end
    | shiftInsn env shl shl_cx _ = raise Control.Bug "shiftInsn"

  fun option insn (SOME x) = [insn x]
    | option insn NONE = nil

  fun emitCopy env (dst, src, size, off, nil) =
      raise Control.Bug "emitCopy: no working register"
    | emitCopy env (dst, src, 0w0, off, _) = nil
    | emitCopy env (dst, src, size, off, var::vars) =
      let
        val vars = case vars of nil => [var] | _ => vars
        val srcAddr = X.DISP (X.WORD off, src)
        val dstAddr = X.DISP (X.WORD off, dst)
      in
        if size >= 0w4 then
          let
            val reg = r32 env (I.REG var)
          in
            MOVL (R reg, M_ srcAddr) ::
            MOVL (M dstAddr, R_ reg) ::
            emitCopy env (dst, src, size - 0w4, off + 0w4, vars)
          end
        else if size >= 0w2 then
          let
            val reg = r16 env (I.REG var)
          in
            MOVW (R16 reg, M_16 srcAddr) ::
            MOVW (M16 dstAddr, R_16 reg) ::
            emitCopy env (dst, src, size - 0w2, off + 0w2, vars)
          end
        else
          let
            val reg = r8 env (I.REG var)
          in
            MOVB (R8 reg, M_8 srcAddr) ::
            MOVB (M8 dstAddr, R_8 reg) ::
            emitCopy env (dst, src, size - 0w1, off + 0w1, vars)
          end
      end

(*
  fun emitTest env insn =
      case insn of
        TEST_SUB (Int8 _, REF (Int8 _, op1), op2) =>
        [CMPB (to8 (rm_rmi env (op1, op2)))]
      | TEST_SUB (Int32 _, REF (Int32 _, op1), op2) =>
        [CMPL (rm_rmi env (op1, op2))]
      | TEST_SUB _ => raise Control.Bug "emitTest: TEST_SUB"
      | TEST_AND (Int8 _, REF (Int8 _, op1), op2) =>
        [TESTB (to8 (rm_rmi env (op1, op2)))]
      | TEST_AND (Int32 _, REF (Int32 _, op1), op2) =>
        [TESTL (rm_rmi env (op1, op2))]
      | TEST_AND _ => raise Control.Bug "emitTest: TEST_AND"
*)

  fun emitInsn env insn =
      let
        val emitMem = emitMem env
        val rm8 = rm8 env
        val rm16 = rm16 env
        val rm32 = rm32 env
        val r8 = r8 env
        val r16 = r16 env
        val r32 = r32 env
        val rmi32 = rmi32 env
        val rm_rmi = rm_rmi env
        val arith1 = arith1 env
        val arith2 = arith2 env
        val shiftInsn = shiftInsn env
      in
        case insn of
          NOP => [X.NOP]
        | STABILIZE => []
        | REQUEST_SLOT slot => []
        | REQUIRE_SLOT slot => []
        | USE ops => []
        | COMPUTE_FRAME {uses, clobs} =>
          raise Control.Bug "emitInsn: COMPUTE_FRAME must be expanded"
        | MOVE (ty as Int32 _, dst, op1) => emitMove env (dst, op1)
        | MOVE (ty as NoType, dst, op1) => emitMove env (dst, op1)
        (* due to split or spill *)
        | MOVE (ty as Atom, dst, op1) => emitMove env (dst, op1)
        | MOVE (ty as Ptr _, dst, op1) => emitMove env (dst, op1)
        | MOVE (ty as Real32, dst, op1) => emitMove env (dst, op1)
        | MOVE (ty as Int16 _, dst, op1) => emitMove16 env (dst, op1)
        | MOVE (ty as Int8 _, dst, op1) => emitMove8 env (dst, op1)
        | MOVE _ => raise Control.Bug "emitInsn: MOVE"
        | MOVEADDR (_, dst, addr) =>
          (
            emitMOVL (rm32 dst, emitRIAddr env addr)
            handle NotRIAddr => [LEAL (r32 dst, emitAddr env addr)]
          )
        | COPY {ty, dst, src=REF (_,src), clobs} =>
          emitCopy env (dstToMem env dst, dstToMem env src,
                          Word.fromInt (#size (formatOf ty)), 0w0, clobs)
        | COPY _ => raise Control.Bug "emitInsn: COPY"
        | MLOAD {ty, dst:I.slot, srcAddr=BASE src,
                 size=REF (_,REG size), defs, clobs} =>
          (assert 50 (r32 (REG src) = ESI andalso r32 (REG size) = ECX);
           [LEAL (EDI, emitMem (SLOT dst)), CLD, REP_MOVSB])
        | MLOAD _ => raise Control.Bug "emitInsn: MLOAD"
        | MSTORE {ty, dstAddr=BASE dst, src:I.slot,
                  size=REF (_,REG size), defs, clobs, global} =>
          (assert 60 (r32 (REG dst) = EDI andalso r32 (REG size) = ECX);
           [LEAL (ESI, emitMem (SLOT src)), CLD, REP_MOVSB])
        | MSTORE _ => raise Control.Bug "emitInsn: MSTORE"
(*
        | EXT8TO16 (I.U, dst, REF (Int8 _, op1)) =>
          [MOVZBW (r16 dst, rm8 op1)]
        | EXT8TO16 (I.S, dst, REF (Int8 _, op1)) =>
          if r16 dst = X EAX andalso r8 op1 = XL EAX
          then [CBW]
          else [MOVSBW (r16 dst, rm8 op1)]
        | EXT8TO16 _ => raise Control.Bug "emitInsn: EXT8TO16"
*)
        | EXT8TO32 (I.U, dst, REF (_,op1)) =>
          [MOVZBL (r32 dst, rm8 op1)]
        | EXT8TO32 (I.S, dst, REF (_,op1)) =>
          [MOVSBL (r32 dst, rm8 op1)]
        | EXT8TO32 _ => raise Control.Bug "emitInsn: EXT8TO32"
        | EXT16TO32 (I.U, dst, REF (_,op1)) =>
          [MOVZWL (r32 dst, rm16 op1)]
        | EXT16TO32 (I.S, dst, REF (_,op1)) =>
          if r32 dst = EAX andalso r16 op1 = X EAX
          then [CWDE]
          else [MOVSWL (r32 dst, rm16 op1)]
        | EXT16TO32 _ => raise Control.Bug "emitInsn: EXT16TO32"
(*
        | SIGNEXT8TO16 (_, dst, REF (Int8 _, op1)) =>
          (assert (r16 dst = X EAX andalso r8 op1 = XL EAX); [CBW])
        | SIGNEXT8TO16 _ => raise Control.Bug "emitInsn: SIGNEXT8TO16"
        | SIGNEXT8TO32 (_, dst, REF (Int8 _, op1)) =>
          (assert (r16 dst = X EAX andalso r8 op1 = XL EAX); [CBW, CWDE])
        | SIGNEXT8TO32 _ => raise Control.Bug "emitInsn: SIGNEXT8TO32"
        | SIGNEXT16TO32 (_, dst, REF (Int16 _, op1)) =>
          (assert (r32 dst = EAX andalso r16 op1 = X EAX); [CWDE])
        | SIGNEXT16TO32 _ => raise Control.Bug "emitInsn: SIGNEXT16TO32"
*)
        | EXT32TO64 (S, COUPLE (_, {hi, lo}), REF (_,op1)) =>
          (assert 70 (r32 hi = EDX andalso r32 lo = EAX
                      andalso r32 op1 = EAX);
           [CDQ])
        | EXT32TO64 (U, MEM (_, mem), op1) =>
          let
            val op1 =
                case op1 of
                  REF (_, dst) => R_ (r32 dst)
                | CONST c => I_ (emitImm env c)
            val addr = emitMem mem
          in
            [MOVL (M addr, op1),
             MOVL (M (X.DISP (X.INT 4, addr)), I_ (WORD 0w0))]
          end
        | EXT32TO64 _ => raise Control.Bug "emitInsn: EXT32TO64"
(*
        | DOWN16TO8 (_, dst, op1) => emitMOVB (to8 (rm_rmi (dst, op1)))
*)
        | DOWN32TO8 (s, dst, op1) => emitMove8 env (dst, op1)
        | DOWN32TO16 (s, dst, op1) => emitMove16 env (dst, op1)
        | ADD (Int32 _, dst, op1, op2) => [ADDL (arith2 (dst, op1, op2))]
        | ADD _ => raise Control.Bug "emitInsn: ADD"
        | SUB (Int32 _, dst, op1, op2) => [SUBL (arith2 (dst, op1, op2))]
        | SUB _ => raise Control.Bug "emitInsn: SUB"
        | AND (Int32 _, dst, op1, op2) => [ANDL (arith2 (dst, op1, op2))]
        | AND (Int16 _, dst, op1, op2) => [ANDW (to16 (arith2 (dst, op1, op2)))]
        | AND (Int8 _, dst, op1, op2) => [ANDB (to8 (arith2 (dst, op1, op2)))]
        | AND _ => raise Control.Bug "emitInsn: AND"
        | OR (Int32 _, dst, op1, op2) => [ORL (arith2 (dst, op1, op2))]
        | OR (Int16 _, dst, op1, op2) => [ORW (to16 (arith2 (dst, op1, op2)))]
        | OR (Int8 _, dst, op1, op2) => [ORB (to8 (arith2 (dst, op1, op2)))]
        | OR _ => raise Control.Bug "emitInsn: OR"
        | XOR (Int32 _, dst, op1, op2) => [XORL (arith2 (dst, op1, op2))]
        | XOR _ => raise Control.Bug "emitInsn: XOR"
        | MUL ((Int32 _, dst), (Int32 _, op1), (Int32 _, op2)) =>
          let
            (*
             * mull2 r32, rmi32        r32 <- r32 * rmi32
             * mull3 r32, rm32, imm    r32 <- rm32 * imm
             *
             * dst <- op1 * op2
             *  r      r     r      mull2
             *  r      r     r'     mull2
             *  r      r     m      mull2
             *  r      r     i      mull2 or mull3 (mull2 preferred)
             *  r      r'    r      mull2 (commutative)
             *  r      r'    r''    -
             *  r      r'    m      -
             *  r      r'    i      mull3
             *  r      m     r      mull2 (commutative)
             *  r      m     r'     -
             *  r      m     m      -
             *  r      m     i      mull3
             *  r      i     r      mull2 or mull3 (commutative)
             *  r      i     r'     mull3 (commutative)
             *  r      i     m      mull3 (commutative)
             *  r      i     i      -
             *)
            val dst = r32 dst
          in
            case (rmi32 op1, rmi32 op2) of
              (R_ op1, R_ op2) =>
              if dst = op1 then [IMULL2 (dst, R_ op2)]
              else if dst = op2 then [IMULL2 (dst, R_ op1)]
              else raise Control.Bug "emitInsn: IMULL: R, R"
            | (R_ op1, op2 as M_ _) =>
              (assert 80 (dst = op1); [IMULL2 (dst, op2)])
            | (R_ op1, op2 as I_ c2) =>
              if dst = op1
              then [IMULL2 (dst, op2)]
              else [IMULL3 (dst, R op1, c2)]
            | (op1 as M_ _, R_ op2) =>
              (assert 90 (dst = op2); [IMULL2 (dst, op1)])
            | (M_ _, M_ _) => raise Control.Bug "emitInsn: IMULL: M, M"
            | (M_ op1, I_ op2) => [IMULL3 (dst, M op1, op2)]
            | (op1 as I_ c1, R_ op2) =>
              if dst = op2
              then [IMULL2 (dst, op1)]
              else [IMULL3 (dst, R op2, c1)]
            | (I_ op1, M_ op2) => [IMULL3 (dst, M op2, op1)]
            | (I_ _, I_ _) => raise Control.Bug "emitInsn: IMULL: I, I"
          end
        | MUL ((Int64 S, COUPLE (_, {hi=hi1, lo=lo1})),
               (Int32 S, REF (_,op1)), (Int32 S, REF (_,op2))) =>
          (assert 100 (r32 hi1 = EDX andalso r32 lo1 = EAX
                       andalso r32 op1 = EAX);
           [IMULL (rm32 op2)])
        | MUL ((Int64 U, COUPLE (_, {hi=hi1, lo=lo1})),
               (Int32 U, REF (_,op1)), (Int32 U, REF (_,op2))) =>
          (assert 110 (r32 hi1 = EDX andalso r32 lo1 = EAX
                       andalso r32 op1 = EAX);
           [MULL (rm32 op2)])
        | MUL _ => raise Control.Bug "emitInsn: MUL"
        | DIVMOD ({div=(Int32 S, ddiv), mod=(Int32 S, dmod)},
                  (Int64 S, REF (_,COUPLE (_, {hi, lo}))),
                  (Int32 S, REF (_,op2))) =>
          (assert 120 (r32 ddiv = EAX andalso r32 dmod = EDX andalso
                       r32 hi = EDX andalso r32 lo = EAX);
           [IDIVL (rm32 op2)])
        | DIVMOD ({div=(Int32 U, ddiv), mod=(Int32 U, dmod)},
                  (Int64 U, REF (_,COUPLE (_, {hi, lo}))),
                  (Int32 U, REF (_,op2))) =>
          (assert 130 (r32 ddiv = EAX andalso r32 dmod = EDX andalso
                       r32 hi = EDX andalso r32 lo = EAX);
           [DIVL (rm32 op2)])
        | DIVMOD _ => raise Control.Bug "emitInsn: DIVMOD"
        | LSHIFT (Int32 _, dst, op1, op2) =>
          [shiftInsn SHLL SHLL_CL (dst, op1, op2)]
        | LSHIFT _ => raise Control.Bug "emitInsn: LSHIFT"
        | RSHIFT (Int32 _, dst, op1, op2) =>
          [shiftInsn SHRL SHRL_CL (dst, op1, op2)]
        | RSHIFT _ => raise Control.Bug "emitInsn: RSHIFT"
        | ARSHIFT (Int32 _, dst, op1, op2) =>
          [shiftInsn SARL SARL_CL (dst, op1, op2)]
        | ARSHIFT _ => raise Control.Bug "emitInsn: ARSHIFT"
        | TEST_SUB (Int8 _, REF (_,op1), op2) =>
          [CMPB (to8 (rm_rmi (op1, op2)))]
        | TEST_SUB (Int32 _, REF (_,op1), op2) =>
          [CMPL (rm_rmi (op1, op2))]
        | TEST_SUB (Ptr _, REF (_,op1), op2) =>
          [CMPL (rm_rmi (op1, op2))]
        | TEST_SUB _ => raise Control.Bug "emitInsn: TEST_SUB"
        | TEST_AND (Int8 _, REF (_,op1), op2) =>
          [TESTB (to8 (rm_rmi (op1, op2)))]
        | TEST_AND (Int32 _, REF (_,op1), op2) =>
          [TESTL (rm_rmi (op1, op2))]
        | TEST_AND _ => raise Control.Bug "emitInsn: TEST_AND"
        | TEST_LABEL (_, REF (_,op1), l) =>
          [CMPL (rm32 op1, I_ (X.LABEL (emitAbsLabel env l)))]
        | TEST_LABEL _ => raise Control.Bug "emitInsn: TEST_LABEL"
        | NOT (Int32 _, dst, op1) => [NOTL (arith1 (dst, op1))]
        | NOT _ => raise Control.Bug "emitInsn: NOT"
        | NEG (Int32 _, dst, op1) => [NEGL (arith1 (dst, op1))]
        | NEG _ => raise Control.Bug "emitInsn: NEG"
        | SET (cc, Int8 _, dst, {test}) =>
          let
            val testInsn = emitInsn env test
            val dst = r8 dst
          in
            testInsn @ [ X.SET (emitCC cc, R8 dst) ]
          end
        | SET _ => raise Control.Bug "emitInsn: SET"
        | LOAD_FP dst => [MOVL (rm32 dst, R_ EBP)]
        | LOAD_SP dst => [MOVL (rm32 dst, R_ ESP)]
        | LOAD_PREV_FP dst => [MOVL (R (r32 dst), M_ (X.BASE EBP))]
        | LOAD_RETADDR dst =>
          [MOVL (R (r32 dst), M_ (X.DISP (INT 4, X.BASE EBP)))]
(*
        | SAVE_FP op1 => [MOVL (R EBP, rmi32 op1)]
        | SAVE_SP op1 => [MOVL (R ESP, rmi32 op1)]
*)
        | LOADABSADDR {ty, dst, symbol, thunk=SOME thunk} =>
          let
            val off = emitImm env (SYMOFFSET {base=CURRENT_POSITION,
                                              label=symbol})
          in
            assert 140 (r32 dst = EBX);
            [X.CALL (I_ (X.LABEL (X.SYMBOL thunk))),
             LEAL (EBX, X.DISP (off, X.BASE EBX))]
          end
        | LOADABSADDR {ty, dst, symbol, thunk=NONE} =>
          let
            val reg = r32 dst
            val label = (clusterId env, Counters.newLocalId ())
            val off = emitImm env (SYMOFFSET {base=CURRENT_POSITION,
                                              label=symbol})
            val off2 = CONSTSUB (CURRENTPOS, X.LABEL (X.LOCAL label))
          in
            [X.CALL (I_ (X.LABEL (X.LOCAL label))),
             Label label,
             POPL (R reg),
             LEAL (reg, X.DISP (CONSTADD (off, off2), X.BASE reg))]
          end
        | X86 (X86LEAINT (ty, dst, {base, shift, offset, disp})) =>
          (
            case ty of
              Int32 _ => ()
            | _ => raise Control.Bug "X86LEAINT";
            [LEAL (r32 dst,
                   X.DISP (emitImm env disp,
                           X.BASEINDEX (r32 (REG base), r32 (REG offset),
                                        emitScale shift)))]
          )
        | X86 (X86FLD (Real32, mem)) => [FLDS (emitMem mem)]
        | X86 (X86FLD (Real64, mem)) => [FLDL (emitMem mem)]
        | X86 (X86FLD (Real80, mem)) => [FLDT (emitMem mem)]
        | X86 (X86FLD (Int16 S, mem)) => [FILDS (emitMem mem)]
        | X86 (X86FLD (Int32 S, mem)) => [FILDL (emitMem mem)]
        | X86 (X86FLD (Int64 S, mem)) => [FILDQ (emitMem mem)]
        | X86 (X86FLD _) => raise Control.Bug "emitInsn: X86FLD"
        | X86 (X86FLD_ST (X86ST n)) => [FLD (ST n)]
        | X86 (X86FST (Real32, mem)) => [FSTPS (emitMem mem)]
        | X86 (X86FST (Real64, mem)) => [FSTPL (emitMem mem)]
        | X86 (X86FST (Real80, mem)) => [FSTPT (emitMem mem)]
        | X86 (X86FST (Int16 S, mem)) => [FISTPS (emitMem mem)]
        | X86 (X86FST (Int32 S, mem)) => [FISTPL (emitMem mem)]
        | X86 (X86FST (Int64 S, mem)) => [FISTPQ (emitMem mem)]
        | X86 (X86FST _) => raise Control.Bug "emitInsn: X86FST"
        | X86 (X86FSTP (Real32, mem)) => [FSTPS (emitMem mem)]
        | X86 (X86FSTP (Real64, mem)) => [FSTPL (emitMem mem)]
        | X86 (X86FSTP (Real80, mem)) => [FSTPT (emitMem mem)]
        | X86 (X86FSTP (Int16 S, mem)) => [FISTPS (emitMem mem)]
        | X86 (X86FSTP (Int32 S, mem)) => [FISTPL (emitMem mem)]
        | X86 (X86FSTP (Int64 S, mem)) => [FISTPQ (emitMem mem)]
        | X86 (X86FSTP _) => raise Control.Bug "emitInsn: X86FSTP"
        | X86 (X86FSTP_ST (X86ST n)) => [FSTP (ST n)]
        | X86 (X86FADD (Real32, mem)) => [FADDS (emitMem mem)]
        | X86 (X86FADD (Real64, mem)) => [FADDL (emitMem mem)]
        | X86 (X86FADD _) => raise Control.Bug "emitInsn: X86FADD"
        | X86 (X86FADD_ST (X86ST 0, X86ST n)) => [FADD (ST 0, ST n)]
        | X86 (X86FADD_ST (X86ST n, X86ST 0)) => [FADD (ST n, ST n)]
        | X86 (X86FADD_ST _) => raise Control.Bug "emitInsn: X86FADD_ST"
        | X86 (X86FADDP (X86ST n)) => [FADDP (ST n)]
        | X86 (X86FSUB (Real32, mem)) => [FSUBS (emitMem mem)]
        | X86 (X86FSUB (Real64, mem)) => [FSUBL (emitMem mem)]
        | X86 (X86FSUB _) => raise Control.Bug "emitInsn: X86FSUB"
        | X86 (X86FSUB_ST (X86ST 0, X86ST n)) => [FSUB (ST 0, ST n)]
        | X86 (X86FSUB_ST (X86ST n, X86ST 0)) => [FSUB (ST n, ST n)]
        | X86 (X86FSUB_ST _) => raise Control.Bug "emitInsn: X86FSUB_ST"
        | X86 (X86FSUBP (X86ST n)) => [FSUBP (ST n)]
        | X86 (X86FSUBR (Real32, mem)) => [FSUBRS (emitMem mem)]
        | X86 (X86FSUBR (Real64, mem)) => [FSUBRL (emitMem mem)]
        | X86 (X86FSUBR _) => raise Control.Bug "emitInsn: X86FSUBR"
        | X86 (X86FSUBR_ST (X86ST 0, X86ST n)) => [FSUBR (ST 0, ST n)]
        | X86 (X86FSUBR_ST (X86ST n, X86ST 0)) => [FSUBR (ST n, ST n)]
        | X86 (X86FSUBR_ST _) => raise Control.Bug "emitInsn: X86FSUBR_ST"
        | X86 (X86FSUBRP (X86ST n)) => [FSUBRP (ST n)]
        | X86 (X86FMUL (Real32, mem)) => [FMULS (emitMem mem)]
        | X86 (X86FMUL (Real64, mem)) => [FMULL (emitMem mem)]
        | X86 (X86FMUL _) => raise Control.Bug "emitInsn: X86FMUL"
        | X86 (X86FMUL_ST (X86ST 0, X86ST n)) => [FMUL (ST 0, ST n)]
        | X86 (X86FMUL_ST (X86ST n, X86ST 0)) => [FMUL (ST n, ST n)]
        | X86 (X86FMUL_ST _) => raise Control.Bug "emitInsn: X86FMUL_ST"
        | X86 (X86FMULP (X86ST n)) => [FMULP (ST n)]
        | X86 (X86FDIV (Real32, mem)) => [FDIVS (emitMem mem)]
        | X86 (X86FDIV (Real64, mem)) => [FDIVL (emitMem mem)]
        | X86 (X86FDIV _) => raise Control.Bug "emitInsn: X86FDIV"
        | X86 (X86FDIV_ST (X86ST 0, X86ST n)) => [FDIV (ST 0, ST n)]
        | X86 (X86FDIV_ST (X86ST n, X86ST 0)) => [FDIV (ST n, ST n)]
        | X86 (X86FDIV_ST _) => raise Control.Bug "emitInsn: X86FDIV_ST"
        | X86 (X86FDIVP (X86ST n)) => [FDIVP (ST n)]
        | X86 (X86FDIVR (Real32, mem)) => [FDIVRS (emitMem mem)]
        | X86 (X86FDIVR (Real64, mem)) => [FDIVRL (emitMem mem)]
        | X86 (X86FDIVR _) => raise Control.Bug "emitInsn: X86FDIVR"
        | X86 (X86FDIVR_ST (X86ST 0, X86ST n)) => [FDIVR (ST 0, ST n)]
        | X86 (X86FDIVR_ST (X86ST n, X86ST 0)) => [FDIVR (ST n, ST n)]
        | X86 (X86FDIVR_ST _) => raise Control.Bug "emitInsn: X86FDIVR_ST"
        | X86 (X86FDIVRP (X86ST n)) => [FDIVRP (ST n)]
        | X86 (X86FABS) => [FABS]
        | X86 (X86FCHS) => [FCHS]
        | X86 (X86FFREE (X86ST st)) => [FFREE (ST st)]
        | X86 (X86FXCH (X86ST st)) => [FXCH (ST st)]
        | X86 (X86FUCOM (X86ST st)) => [FUCOM (ST st)]
        | X86 (X86FUCOMP (X86ST st)) => [FUCOMP (ST st)]
        | X86 X86FUCOMPP => [FUCOMPP]
(*
        | X86 (X86FSTSW (dst, test)) =>
          let
            val testInsns = emitInsn env test
          in
            case rm32 dst of
              M m => testInsns @ [FSTSW m]
            | R r => (assert (r16 dst = X EAX); testInsns @ [FSTSW_AX])
          end
*)
          (*            C3:14 C2:10 C0:8
           * st0 > src    0     0     0
           * st0 < src    0     0     1
           * st0 = src    1     0     0
           * unordered    1     1     1
           *)
        | X86 (X86FSW_GT {clob}) =>
          (assert 150 (r32 (REG clob) = EAX);
           (* hi & 0b01000101 == 0 *)
           [FSTSW_AX, TESTB (R8 (XH EAX), I_8 (WORD 0wx45))])
        | X86 (X86FSW_GE {clob}) =>
          (assert 160 (r32 (REG clob) = EAX);
           (* hi & 0b00000101 == 0 *)
           [FSTSW_AX, TESTB (R8 (XH EAX), I_8 (WORD 0wx5))])
        | X86 (X86FSW_EQ {clob}) =>
          (assert 170 (r32 (REG clob) = EAX);
           (* hi & 0b01000101 == 0b01000000 *)
           [FSTSW_AX,
            ANDB (R8 (XH EAX), I_8 (WORD 0wx45)),
            CMPB (R8 (XH EAX), I_8 (WORD 0wx40))])
        | X86 (X86FLDCW mem) => [FLDCW (emitMem mem)]
        | X86 (X86FNSTCW mem) => [FNSTCW (emitMem mem)]
        | X86 X86FWAIT => [FWAIT]
        | X86 X86FNCLEX => [FNCLEX]
      end
handle e =>
let open FormatByHand in puts "==ERROR=="; putf I.format_instruction insn;
raise e end

  local
    fun Int n = INT (Int32.fromInt n)
  in

  fun allocFrame env preFrameSize =
      case totalPreFrameSize env - preFrameSize of
        0 =>
        [
          PUSHL (R_ EBP),
          MOVL (R EBP, R_ ESP)
        ]
        @ (case frameAllocSize env of
             0 => nil
           | n => [SUBL (R ESP, I_ (INT (Int32.fromInt n)))])
        @ (if !Control.debugCodeGen then
             [
(*
               X.PUSHL (R_ EAX),
               X.PUSHL (R_ ECX),
               X.PUSHL (R_ EDX),
               X.PUSHL (M_ (X.BASE EBP)),
               X.CALL (I_ (X.LABEL (X.SYMBOL "_sml_check_frame_valid"))),
               X.POPL (R EDX),
               X.POPL (R EDX),
               X.POPL (R ECX),
               X.POPL (R EAX),
*)
               X.PUSHL (I_ (Int 0)),
               X.CALL (I_ (X.LABEL (X.SYMBOL "__debug__clearframe__")))
             ]
           else nil)
      | pad =>
        [
          SUBL (R ESP, I_ (Int (pad + 4 + frameAllocSize env))),
          MOVL (M (X.DISP (Int (frameAllocSize env), X.BASE ESP)), R_ EBP),
          MOVL (R EBP, M_ (X.DISP (Int (pad + 4 + frameAllocSize env),
                                   X.BASE ESP))),
          MOVL (M (X.DISP (Int (frameAllocSize env + 4), X.BASE ESP)),
                R_ EBP),
          LEAL (EBP, X.DISP (Int (frameAllocSize env), X.BASE ESP))
        ]
        @ (if !Control.debugCodeGen then
             [
(*
               X.PUSHL (R_ EAX),
               X.PUSHL (R_ ECX),
               X.PUSHL (R_ EDX),
               X.PUSHL (M_ (X.BASE EBP)),
               X.CALL (I_ (X.LABEL (X.SYMBOL "_sml_check_frame_valid"))),
               X.POPL (R EDX),
               X.POPL (R EDX),
               X.POPL (R ECX),
               X.POPL (R EAX),
*)
               X.PUSHL (I_ (Int pad)),
               X.CALL (I_ (X.LABEL (X.SYMBOL "__debug__clearframe__")))
             ]
           else nil)

  fun freeFrame env preFrameSize =
      case totalPreFrameSize env - preFrameSize of
        0 =>
        [
          MOVL (R ESP, R_ EBP),
          POPL (R EBP)
        ]
      | pad =>
        [
          MOVL (R ESP, R_ EBP),
          MOVL (R EBP, M_ (X.DISP (Int 4, X.BASE ESP))),
          MOVL (M (X.DISP (Int (pad + 4), X.BASE ESP)), R_ EBP),
          POPL (R EBP),
          ADDL (R ESP, I_ (Int pad))
        ]

  end

  fun emitLast env insn =
      case insn of
        HANDLE (insn, {nextLabel, handler}) =>
        {insn = emitInsn env insn,
         continue = SOME nextLabel,
         branches = RTLUtils.handlerLabels handler}
      | CJUMP {test, cc, thenLabel, elseLabel} =>
        {insn = emitInsn env test @ [J (emitCC cc,
                                        (clusterId env, thenLabel),
                                        (clusterId env, elseLabel))],
         continue = SOME elseLabel,
         branches = [thenLabel]}
      | JUMP {jumpTo, destinations=[label]} =>
        {insn = nil,
         continue = SOME label,
         branches = nil}
      | JUMP {jumpTo, destinations} =>
        {insn = [JMP (emitRIAddr env jumpTo
                      handle NotRIAddr => raise Control.Bug "emitLast: JUMP",
                      map (fn x => (clusterId env, x)) destinations)],
         continue = NONE,
         branches = destinations}
      | CALL {callTo, returnTo, handler, defs, uses, needStabilize,
              postFrameAdjust} =>
        {insn = [X.CALL (emitRIAddr env callTo
                         handle NotRIAddr =>
                                raise Control.Bug "emitLast: CALL")] @
                (case postFrameAdjust of
                   0 => nil
                 | n => [SUBL (R ESP, I_ (INT (Int32.fromInt n)))]),
         continue = SOME returnTo,
         branches = RTLUtils.handlerLabels handler}
      | UNWIND_JUMP {jumpTo, sp, fp, uses, handler} =>
        {insn =
(*
[
           X.PUSHL (R_ EAX),
           X.PUSHL (R_ ECX),
           X.PUSHL (R_ EDX),
           X.PUSHL (R_ EBP),
           X.CALL (I_ (X.LABEL (X.SYMBOL "_sml_check_frame_valid"))),
           X.POPL (R EDX),
           X.POPL (R EDX),
           X.POPL (R ECX),
           X.POPL (R EAX)
] @
*)
                [MOVL (R EBP, rmi32 env fp),
                 MOVL (R ESP, rmi32 env sp),
                 JMP (emitRIAddr env jumpTo
                      handle NotRIAddr =>
                             raise Control.Bug "emitLast: UNWIND_JUMP",
                      nil)],
         continue = NONE,
         branches = RTLUtils.handlerLabels handler}
      | TAILCALL_JUMP {jumpTo, preFrameSize, uses} =>
        {insn =
(*
[
           X.PUSHL (R_ EAX),
           X.PUSHL (R_ ECX),
           X.PUSHL (R_ EDX),
           X.PUSHL (R_ EBP),
           X.CALL (I_ (X.LABEL (X.SYMBOL "_sml_check_frame_valid"))),
           X.POPL (R EDX),
           X.POPL (R EDX),
           X.POPL (R ECX),
           X.POPL (R EAX)
] @
*)
                freeFrame env preFrameSize @
                [JMP (emitRIAddr env jumpTo
                      handle NotRIAddr =>
                             raise Control.Bug "emitLast: TAILCALL_JUMP",
                      nil)],
         continue = NONE,
         branches = nil}
      | RETURN {preFrameSize, preFrameAligned=true, uses} =>
        {insn =
(*
[
           X.PUSHL (R_ EAX),
           X.PUSHL (R_ ECX),
           X.PUSHL (R_ EDX),
           X.PUSHL (R_ EBP),
           X.CALL (I_ (X.LABEL (X.SYMBOL "_sml_check_frame_valid"))),
           X.POPL (R EDX),
           X.POPL (R EDX),
           X.POPL (R ECX),
           X.POPL (R EAX)
] @
*)
                freeFrame env (#totalPreFrameSize env) @
                (case #totalPreFrameSize env - preFrameSize of
                   0 => [X.RET NONE]
                 | n => [X.RET (SOME (INT (Int32.fromInt n)))]),
         continue = NONE,
         branches = nil}
      | RETURN {preFrameSize, preFrameAligned=false, uses} =>
        raise Control.Bug "FIXME: RETURN: preFrameAligned=false"
      | EXIT => raise Control.Bug "emitLast: EXIT"

  fun emitAlign 1 = nil
    | emitAlign n = [X.Align {align = n, filler = 0wx90}]

  fun emitSymbolDecl GLOBAL symbol = [X.Global symbol, X.Symbol symbol]
    | emitSymbolDecl LOCAL symbol = [X.Symbol symbol]

  fun emitFirst env insn =
      case insn of
        BEGIN {label, align, loc} =>
        emitAlign align @ [X.Label (clusterId env, label)]
      | CODEENTRY {label, symbol, scope, preFrameSize, preFrameAligned=true,
                   align, defs, loc} =>
        [Loc loc] @
        emitAlign align @ emitSymbolDecl scope symbol @
        allocFrame env preFrameSize
      | CODEENTRY {label, symbol, scope, preFrameSize, preFrameAligned=false,
                   align, defs, loc} =>
        raise Control.Bug "FIXME: CODEENTRY: preFrameAligned=false"
      | HANDLERENTRY {label, align, defs, loc} =>
        [Loc loc] @
        emitAlign align @ [X.Label (clusterId env, label)]
      | ENTER => raise Control.Bug "emitFirst: ENTER"

  fun emitBlock env ((first, middle, last):I.block) =
      let
        val first = emitFirst env first
handle e =>
let open FormatByHand in puts "==ERROR=="; putf I.format_first first; raise e
end
        val middle = map (emitInsn env) middle
        val {insn=last, continue, branches} = emitLast env last
handle e =>
let open FormatByHand in puts "==ERROR=="; putf I.format_last last; raise e end
        val insn = List.concat (first :: middle @ [last])
      in
        {insn = insn, continue = continue, branches = branches}
      end

(*
  fun emitFrameBitmap env ({source, bits}:I.frameBitmap) =
      let
        val source =
            case source of
              F.REG var => F.REG (env var)
            | F.MEM addr => F.MEM (emitAddr env addr)
      in
        {source = source, bits = bits} : X.frameBitmap
      end
*)

  fun linearize (clusterId, graph, entries) =
      let
        fun jump label =
            JMP (I_ (X.LABEL (X.LOCAL label)), [label])

        fun loop (visited, nil) = nil
          | loop (visited, label::labelStack) =
            if LabelSet.member (visited, label)
            then loop (visited, labelStack)
            else
              case LabelMap.find (graph, label) of
                NONE => raise Control.Bug "linearize"
              | SOME {insn, continue, branches} =>
                let
                  val visited = LabelSet.add (visited, label)
                  val labelStack = branches @ labelStack
                in
                  insn @
                  (case continue of
                     NONE => loop (visited, labelStack)
                   | SOME nextLabel =>
                     if LabelSet.member (visited, nextLabel)
                     then jump (X.CLUSTER clusterId, nextLabel) ::
                          loop (visited, labelStack)
                     else loop (visited, nextLabel :: labelStack))
                end
      in
        loop (LabelSet.empty, entries)
      end

  fun emitCluster env ({clusterId, frameBitmap, baseLabel, body,
                        preFrameSize, postFrameSize, loc}
                       :I.cluster) =
      let
        val env =
            case ClusterID.Map.find (env, clusterId) of
              SOME env => {clusterId = SOME clusterId,
                           totalPreFrameSize = preFrameSize,
                           env = env} : env'
            | NONE => raise Control.Bug "emit"

        val entries =
            LabelMap.foldri
              (fn (label, (CODEENTRY _, _, _), labelStack) =>
                  label :: labelStack
                | (_, _, labelStack) => labelStack)
              nil
              body

        val body = LabelMap.map (fn block => emitBlock env block) body
        val insn = linearize (clusterId, body, entries)
        val insn =
            case baseLabel of
              NONE => insn
            | SOME l => X.Label (X.CLUSTER clusterId, l) :: insn
      in
        Section TextSection ::
        Align {align=4, filler=0wx90} ::
        insn
      end
(*
        {
          frameBitmap = map (emitFrameBitmap env) frameBitmap,
          body = insn,
          preFrameAligned = preFrameAligned,
          loc = loc
        } : X.cluster
      end
*)

  val emptyEnv =
      {clusterId = NONE,
       totalPreFrameSize = 0,
       env = {regAlloc = LocalVarID.Map.empty,
              slotIndex = LocalVarID.Map.empty,
              preFrameOrigin = 0,
              postFrameOrigin = 0,
              frameAllocSize = 0}} : env'

  fun emitDatum datum =
      case datum of
        CONST_DATA (SYMOFFSET {base, label}) =>
        [ImmData (CONSTSUB (X.LABEL (emitAbsLabel emptyEnv base),
                           X.LABEL (emitAbsLabel emptyEnv label)))]
      | CONST_DATA (INT64 n) =>
        raise Control.Bug "emitData: FIXME: INT64"
      | CONST_DATA (UINT64 n) =>
        raise Control.Bug "emitData: FIXME: UINT64"
      | CONST_DATA (INT32 n) => [ImmData (INT n)]
      | CONST_DATA (UINT32 n) => [ImmData (WORD n)]
      | CONST_DATA (INT16 n) =>
        raise Control.Bug "emitData: FIXME: INT16"
      | CONST_DATA (UINT16 n) =>
        raise Control.Bug "emitData: FIXME: UINT16"
      | CONST_DATA (INT8 n) =>
        [BytesData [Word8.fromInt n]]
      | CONST_DATA (UINT8 n) =>
        [BytesData [n]]
      | CONST_DATA (REAL32 s) =>
        [ImmData (WORD (IEEE754.dump32 (valOf (Real.fromString s))))]
      | CONST_DATA (REAL64 s) =>
        let
          val (hi, lo) = IEEE754.dump64 (valOf (Real.fromString s))
        in
          [ImmData (WORD lo), ImmData (WORD hi)]
        end
      | CONST_DATA (REAL64HI s) =>
        [ImmData (WORD (#1 (IEEE754.dump64 (valOf (Real.fromString s)))))]
      | CONST_DATA (REAL64LO s) =>
        [ImmData (WORD (#2 (IEEE754.dump64 (valOf (Real.fromString s)))))]
      | LABELREF_DATA l => [ImmData (X.LABEL (emitAbsLabel emptyEnv l))]
      | BINARY_DATA w => [BytesData w]
      | ASCII_DATA s => [AsciiData s]
      | SPACE_DATA {size} => [SpaceData size]

  fun emitData ({scope, symbol, aliases, ptrTy, section, prefix, align, data,
                 prefixSize, dataSize}:I.data) =
      [case section of
         DATA_SECTION => Section DataSection
       | RODATA_SECTION => Section ConstDataSection
       | LITERAL32_SECTION => Section Literal4Section
       | LITERAL64_SECTION => Section Literal8Section
       | CSTRING_SECTION => Section CStringSection] @
      [Align {align=align, filler=0w0}] @
      (if prefixSize mod align = 0 then nil
       else [SpaceData (align - prefixSize mod align)]) @
      List.concat (map emitDatum prefix) @
      List.concat (map (emitSymbolDecl scope) (symbol::aliases)) @
      List.concat (map emitDatum data)

  fun emitTopdecl env topdecl =
      case topdecl of
        CLUSTER cluster => emitCluster env cluster
      | DATA data => emitData data
      | BSS {scope, symbol, align, size} =>
        (case scope of GLOBAL => [Global symbol] | LOCAL => nil) @
        [Comm (symbol, {size=size, align=align})]
      | X86GET_PC_THUNK_BX symbol =>
        [
          GET_PC_THUNK_Decl symbol,
          MOVL (R EBX, M_ (X.BASE ESP)),
          RET NONE
        ]
      | EXTERN {symbol, linkStub, linkEntry, ptrTy} =>
        (if linkEntry then [LinkPtrEntry symbol] else nil) @
        (if linkStub then [LinkStubEntry symbol] else nil)
      | TOPLEVEL {symbol, toplevelEntry, nextToplevel,
                  smlPushHandlerLabel, smlPopHandlerLabel} =>
        (* toplevel code takes no argument and returns unhandled exception. *)
        let
          val (returnCode, nextStubCode) =
              case nextToplevel of
                NONE => ([RET NONE], nil)
              | SOME nextSymbol =>
                let
                  val l1 = Counters.newLocalId ()
                  val l2 = Counters.newLocalId ()
                in
                  ([
                     (* if eax is not null, return immediately. *)
                     TESTL (R EAX, R_ EAX),
                     J     (NE, (X.TOPLEVEL, l2), (X.TOPLEVEL, l1)),
                     Label (X.TOPLEVEL, l1),
                     JMP   (I_ (X.LABEL (X.SYMBOL nextSymbol)), nil),
                     Label (X.TOPLEVEL, l2),
                     RET   NONE
                   ],
                   [
                     NEXT_TOPLEVEL_STUB_Decl nextSymbol,
                     RET NONE
                   ])
                end

          val enterLabel = (X.TOPLEVEL, Counters.newLocalId ())
        in
          [
            Section TextSection,
            Align {align = 4, filler = 0wx90},
            Global symbol,
            Symbol symbol,
            PUSHL (R_ EBP),      (* -8 *)

            (* save callee-save registers; they may be clobbered due to
             * exception. *)
            PUSHL (R_ EBX),      (* -12 *)
            PUSHL (R_ ESI),      (* -16 *)
            PUSHL (R_ EDI),      (* -20 *)

            (* allocate memory for exception handler. *)
            SUBL  (R ESP, I_ (INT 16)),  (* -36 *)
            MOVL  (R EAX, R_ ESP),

            (* enter toplevel code. *)
            X.CALL (I_ (X.LABEL (X.LOCAL enterLabel))),

            (* if there is an unhandled exception, eax register holds
             * the exception object. *)
            ADDL  (R ESP, I_ (INT 16)),
            POPL  (R EDI),
            POPL  (R ESI),
            POPL  (R EBX),
            POPL  (R EBP)
          ] @
          returnCode @
          [
            Label enterLabel,

            (* terminate frame stack chain. *)
            PUSHL (I_ (INT 0)),   (* -44 *)
            MOVL  (R EBP, R_ ESP),
            PUSHL (I_ (INT 0)),   (* -48 *)

            (* force align stack pointer. *)
            ANDL  (R ESP, I_ (WORD 0wxfffffff0)),

            (* setup toplevel exception handler.
             * handler_addr = return address of the last call.
             * save_esp = stack pointer before the last call.
             * save_ebp = ditto (any value is ok actually)
             *)
            MOVL (R EDX, M_ (X.DISP (X.INT ~4, X.BASE EAX))),
            MOVL (M (X.DISP (X.INT 4, X.BASE EAX)), R_ EDX),
            MOVL (M (X.DISP (X.INT 8, X.BASE EAX)), R_ EAX),
            MOVL (M (X.DISP (X.INT 12, X.BASE EAX)), R_ EAX),
            X.CALL (I_ (emitRelLabel emptyEnv smlPushHandlerLabel)),

            (* call toplevel cluster. *)
            MOVL (R EAX, (I_ (X.INT 0))),
            X.CALL (I_ (X.LABEL (X.SYMBOL toplevelEntry))),

            (* pop toplevel exception handler. *)
            X.CALL (I_ (emitRelLabel emptyEnv smlPopHandlerLabel)),

            (* return NULL *)
            MOVL (R EAX, I_ (X.INT 0)),
            LEAL (ESP, X.DISP (X.INT 4, X.BASE EBP)),
            RET NONE
          ] @
          nextStubCode
        end

  fun emit env program =
      List.concat (map (emitTopdecl env) program)
      @ (if !Control.debugCodeGen then 
           [
             Section TextSection,
             Align {align = 4, filler = 0wx90},
             Symbol ("__debug__clearframe__"),
             PUSHL (R_ EDI),
             PUSHL (R_ EDX),
             PUSHL (R_ ECX),
             PUSHL (R_ EAX),
             LEAL (EDI, X.DISP (X.INT 20, X.BASE ESP)),
             MOVL (R EDX, M_ (X.BASE EDI)),
             MOVL (R ECX, R_ EBP),
             SUBL (R ECX, R_ EDI),
             MOVL (R EAX, I_ (X.WORD 0wx55555555)),
             CLD,
             REP_STOSB,
             ADDL (R EAX, I_ (X.INT 2)),
             ADDL (R EDI, I_ (X.INT 8)),
             MOVL (R ECX, R_ EDX),
             REP_STOSB,
             POPL (R EAX),
             POPL (R ECX),
             POPL (R EDX),
             POPL (R EDI),
             RET (SOME (X.INT 4))
           ]
         else nil)

(*
  fun emitSymbolDef label symbolDef =
      case symbolDef of
        CLUTER_ENTRY {scope} => nil
      | DATA {scope, ptrTy, section, prefix, align, data, prefixSize,
              dataSize} =>


      | BSS {scope, align, size} =>
        [Comm (label, {size = size})]

      | EXTERN {ptrTy, linkEntry, linkStub} =>
        (if linkEntry then [X.LinkPtrEntry label] else nil) @
        (if linkStub then [X.LinkStubEntry label] else nil)

      | X86GET_PC_THUNK_BX =>
        [
          X.Label (X.GLOBAL "_get_pc_thunk.bx"),
          X.MOVL (X.R X.EBX, X.BASE X.EBP),
          X.RET NONE
        ]
      | NEXT_TOPLEVEL_STUB =>
      | ALIAS labelRef =>
        Equ (localLabel label, emitAbsLabel labelRef)
*)

end
