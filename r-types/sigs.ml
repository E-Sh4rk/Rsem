open Common

module FunInfo = struct
  module StrMap = Map.Make(String)
  type t =
    {
      names: int StrMap.t ;
      num: int ;
    }
  let pos_of t (i, str) =
    match StrMap.find_opt str t.names with
    | None -> i
    | Some i -> i
  let unk = { names=StrMap.empty ; num=0; }
  let pp _ _ = ()
  let unop = { names=StrMap.empty ; num=1; }
  let binop = { names=StrMap.empty ; num=2; }
end

module Sig = struct
  type t = FunInfo.t VarMap.t
  let empty = VarMap.empty
  let get_info t v =
    match VarMap.find_opt v t with
    | Some i -> i
    | None -> FunInfo.unk
  let add_info t v i =
    VarMap.add v i t
end