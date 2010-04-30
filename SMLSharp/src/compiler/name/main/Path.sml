(**
 * Path represents a long identifier.
 * @copyright (c) 2006, Tohoku University.
 * @author YAMATODANI Kiyoshi
 * @version $Id: Path.sml,v 1.15 2008/08/06 17:23:40 ohori Exp $
 *)
structure Path : PATH = 
struct

  (***************************************************************************)

  datatype path =        
           PUsrStructure of (* id * *) string * path
         | PSysStructure of (* id * *) string * path
         | NilPath

  (***************************************************************************)
  (*  val topStrName = "$TOP"
  (* NOTE: It should be careful to avoid the conflict between this ID and
   * structure IDs which are generated by StaticEnv.
   * (Due to interdependency of modules, Path can not refer to the StaticEnv.)
   *)
  val topStrID = ID.reserve ()
  val topStrPath = PStructure (topStrID, topStrName, NilPath)
  *)

  val externStrName = "$EXTERN"
  (* val externStrID = ID.reserve() *)
  val externPath = PSysStructure ((* externStrID, *) externStrName, NilPath)

  fun isExternPath path =
      case path of
          PSysStructure(name, tail) =>
          if (* ID.eq(id, externStrID) andalso*) name = externStrName then true
          else false
        | _ => false

  fun usrPathToString p = 
      let
          fun pathcvt p s =
              case p of
                  NilPath => s
                | PUsrStructure((* id, *)name, NilPath) => (s ^ name)
                | PSysStructure((* id, *)name, NilPath) => s
                | PUsrStructure((* id, *)name, path) => pathcvt path (s ^ name ^ ".")
                | PSysStructure((* id, *)name, path) => pathcvt path s
      in
          pathcvt p ""
      end

  fun pathToString p =
      let
        fun pathcvt p s =
            case p of
              NilPath => s
            | PUsrStructure(name, NilPath) => (s ^ name)
            | PSysStructure(name, NilPath) => (s ^ name)
            | PUsrStructure(name, path) => pathcvt path (s ^ name ^ ".")
            | PSysStructure(name, path) => pathcvt path (s ^ name ^ ".")
      in pathcvt p "" end

  fun pathToList p =
      let
          fun pathcvt p s =
              case p of
                  NilPath => s
                | PUsrStructure(name, NilPath) => (s @ [name])
                | PSysStructure(name, NilPath) => (s @ [name])
                | PUsrStructure(name, path) => pathcvt path (s @ [name])
                | PSysStructure(name, path) => pathcvt path (s @ [name])
      in pathcvt p nil end

  fun appendUsrPath (NilPath, name) = PUsrStructure(name, NilPath)
    | appendUsrPath (PUsrStructure(strName, tl), name) =
      PUsrStructure(strName, appendUsrPath(tl, name))
    | appendUsrPath (PSysStructure(strName, tl), name) =
      PSysStructure(strName, appendUsrPath(tl, name))
      
  fun appendSysPath (NilPath, name) = PSysStructure(name, NilPath)
    | appendSysPath (PUsrStructure(strName, tl), name) =
      PUsrStructure(strName, appendSysPath(tl, name))
    | appendSysPath (PSysStructure(strName, tl), name) =
      PSysStructure(strName, appendSysPath(tl, name))

  fun joinPath (path1, path2) =
      case path2 of
          NilPath => path1
        | PUsrStructure(strName, tl) => 
          joinPath ((appendUsrPath (path1, strName)), tl)
        | PSysStructure(strName, tl) => 
          joinPath ((appendSysPath (path1, strName)), tl)

  fun getLastElementOfPath (PUsrStructure(name, NilPath)) =
      name
    | getLastElementOfPath (PSysStructure(name, NilPath)) =
      name
    | getLastElementOfPath (PUsrStructure(name, tail)) =
      getLastElementOfPath tail
    | getLastElementOfPath (PSysStructure(name, tail)) =
      getLastElementOfPath tail
    | getLastElementOfPath NilPath = 
      raise Control.Bug "NilPath to getLastElementOfPath (name/main/Path.sml)"

  fun getParentPath NilPath = NilPath
    | getParentPath (PUsrStructure(name, NilPath)) = NilPath
    | getParentPath (PSysStructure(name, NilPath)) = NilPath
    | getParentPath (PUsrStructure(name, tail)) =
      PUsrStructure(name, getParentPath tail)
    | getParentPath (PSysStructure(name, tail)) =
      PSysStructure(name, getParentPath tail)

  fun comparePathByName (path1, path2) =
      case (path1, path2) of
          (PUsrStructure(name1,p1),PUsrStructure(name2,p2)) =>
          if name1 = name2 then comparePathByName (p1,p2) else false
        | (PUsrStructure _, PSysStructure _) => false
        | (PUsrStructure _, NilPath) => false
        | (PSysStructure(name1,p1),PSysStructure(name2,p2)) =>
          if name1 = name2 then comparePathByName (p1,p2) else false
        | (PSysStructure _, PUsrStructure _) => false
        | (PSysStructure _, NilPath) => false
        | (NilPath,NilPath) => true
        | (NilPath,PUsrStructure _ ) => false
        | (NilPath,PSysStructure _ ) => false

(*
  fun comparePathById (path1, path2) =
      case (path1, path2) of
          (PUsrStructure(id1,name1,p1),PUsrStructure(id2,name2,p2)) =>
          if ID.eq(id1,id2) then comparePathByName (p1,p2) else false
        | (PUsrStructure _, PSysStructure _) => false
        | (PUsrStructure _, NilPath) => false
        | (PSysStructure(id1,name1,p1),PSysStructure(id2,name2,p2)) =>
          if ID.eq(id1,id2) then comparePathByName (p1,p2) else false
        | (PSysStructure _, PUsrStructure _) => false
        | (PSysStructure _, NilPath) => false
        | (NilPath,NilPath) => true
        | (NilPath,PUsrStructure _ ) => false
        | (NilPath,PSysStructure _ ) => false
*)

  fun removeCommonPrefix (leftPath, rightPath) =
      case (leftPath, rightPath) of
        (
          PUsrStructure(leftName, leftTail),
          PUsrStructure(rightName, rightTail)
        ) =>
        if leftName = rightName
        then removeCommonPrefix (leftTail, rightTail)
        else (leftPath, rightPath)
      | (
         PSysStructure(leftName, leftTail),
         PSysStructure(rightName, rightTail)
        ) =>
        if leftName = rightName
        then removeCommonPrefix (leftTail, rightTail)
        else (leftPath, rightPath)
      | _ => (leftPath, rightPath)

  fun getTailPath path =
      case path of
          PSysStructure(_,  tail) => tail
        | PUsrStructure(_,  tail) => tail
        | NilPath => NilPath

  fun pathToUsrPath path =
      case path of
          PSysStructure(_, tail) => pathToUsrPath tail
        | PUsrStructure(name, tail) => 
          PUsrStructure(name, pathToUsrPath tail) 
        | NilPath => NilPath

  fun isPrefix {path, prefix} =
      case (path, prefix) of
          (PUsrStructure(leftName, leftTail),
           PUsrStructure(rightName, rightTail)) =>
          if leftName = rightName then
              isPrefix {path = leftTail, prefix = rightTail}
          else false
        | (PSysStructure(leftName, leftTail),
           PSysStructure(rightName, rightTail)) =>
          if leftName = rightName then 
              isPrefix {path = leftTail, prefix = rightTail}
          else false 
        | (_, NilPath) => true
        | _ => false

(*  fun hideTopStructure (path as PUsrStructure(strID, strName, tail)) =
      if ID.eq (strID, topStrID) then tail else path
    | hideTopStructure path = path
*)

  fun format_pathWithoutDotend  x = 
      let
          fun format_name_path (name, path) =
              List.concat
                  [
                   SMLFormat.BasicFormatters.format_string(name),
                   [SMLFormat.FormatExpression.Term(1, ".")],
                   format_pathWithoutDotend(path)
                   ]
          fun format_id_name_path (name, path)  = 
              case  path of
                  NilPath => SMLFormat.BasicFormatters.format_string(name)
                | PUsrStructure _  => format_name_path (name, path)
                | PSysStructure _  => format_name_path (name, path)
      in
          case x of 
              NilPath => [SMLFormat.FormatExpression.Term(0, "")]
            | PUsrStructure x => format_id_name_path x
            | PSysStructure x => format_id_name_path x
      end
              
  fun format_pathWithDotend x = 
      case x of 
          NilPath => [SMLFormat.FormatExpression.Term(0, "")]
        | PUsrStructure (name, path) => 
          List.concat [SMLFormat.BasicFormatters.format_string(name),
                       [SMLFormat.FormatExpression.Term(1, ".")],
                       format_pathWithDotend(path)
                       ]
        | PSysStructure (name, path) => 
          List.concat [SMLFormat.BasicFormatters.format_string(name),
                       [SMLFormat.FormatExpression.Term(1, ".")],
                       format_pathWithDotend(path)
                       ]
end
