open Mlsem.Common
module MVariable = Mlsem.Lang.MVariable

module Position = struct
  type t = Position.t
  let pp fmt _ = Format.fprintf fmt "_"
end

type const =
| CNan
| CNa of Ast.na_kind
| CStr of string
| CFloat of string
| CInt of int
| CClx of string
| CBool of bool
| CNull
[@@deriving show]

type e' =
| Const of const
| Id of string
| Unop of string * e
| Binop of string * (e * e)
| Call of e * arg option list
| Subset of e * arg option list
| Subset2 of e * arg option list
| Dollar of e * arg_id option
| At of e * arg_id option
| Function of bool (* \x fun? *) * param list option * e
| Ite of e * e * e option
| While of e * e
| For of arg_id * e * e
| Braced of e list
| Dots | DotsN of int
| Return | Break | Next
[@@deriving show]
and arg =
| Unnamed of e
| Named of arg_id * e option
and e = Position.t * e'
[@@deriving show]
and arg_id =
| NullId
| EllipsisId
| EllipsisN of int
| ArgId of string
and param =
| NoDefault of arg_id
| Default of arg_id * e

type t = e list
[@@deriving show]

module StrSet = Set.Make(String)

let bv_param p =
  match p with
  | NoDefault (ArgId str) -> StrSet.singleton str
  | Default (ArgId str, _) -> StrSet.singleton str
  | _ -> StrSet.empty
let bv_params ps =
  List.map bv_param ps |> List.fold_left StrSet.union StrSet.empty

let rec bv_e_ ~ls (_,e) =
  let bv_e, bv_es = bv_e_ ~ls, bv_es_ ~ls in
  match e with
  | Return | Break | Next | Const _ | Id _ | Function _  | Dots | DotsN _ -> StrSet.empty
  | Unop (_,e) | Dollar (e, _) | At (e, _) -> bv_e e
  | Binop (str, (e1, e2)) ->
    let res = match str, e1, e2 with
    | ("<-" | "="), (_, Id id), _ | "->", _, (_, Id id) -> StrSet.singleton id
    | "<<-", (_, Id _), _ -> StrSet.empty
    | _, _, _ -> StrSet.empty
    in
    StrSet.union res (bv_es [e1;e2])
  (* [local(e)] gives [e] an environment of its own, so what it assigns binds
     there and not here. Only when [local] is R's own, which is what [ls] carries. *)
  | Call ((_, Id "local"), [Some (Unnamed _)]) when ls -> StrSet.empty
  | Call (e, args) | Subset (e, args) | Subset2 (e, args) ->
    let es = args |> List.concat_map (function
      | None  | Some (Named (_, None)) -> []
      | Some (Unnamed e) | Some (Named (_, Some e)) -> [e]
      )
    in
    bv_es (e::es)
  | Ite (e, e1, e2) -> bv_es (e::e1::(match e2 with None -> [] | Some e2 -> [e2]))
  | While (e, e') -> bv_es [e;e']
  | For (ArgId str, e, e') -> bv_es [e;e'] |> StrSet.add str
  | For (_, e, e') -> bv_es [e;e']
  | Braced es -> bv_es es
and bv_es_ ~ls es =
  List.map (bv_e_ ~ls) es |> List.fold_left StrSet.union StrSet.empty

(* The names [e] assigns, which are the variables local to the function whose
   body it is -- or, at top level, the definitions the statement makes.
   [local_shadowed] says whether the enclosing scope binds [local]; [e] may
   also bind it itself, in which case it is shadowed over the whole of [e],
   R scoping a body as a whole rather than sequentially. *)
let bv_e ~local_shadowed e =
  if local_shadowed then bv_e_ ~ls:false e
  else
    let bvs = bv_e_ ~ls:true e in
    if StrSet.mem "local" bvs then bv_e_ ~ls:false e else bvs

module StrMap = Map.Make(String)
(* [annots] maps the name of a variable local to the top-level definition being
   transformed to the type the user has annotated it with. *)
type env = { id: Scope.t ; annots: Mlsem.Types.GTy.t StrMap.t }

let aux_arg f arg =
  match arg with
  | Unnamed (_,Dots as e) -> MetaEnv.Ell, Some (f e)
  | Unnamed (_,DotsN _ as e) -> MetaEnv.Ell, Some (f e)
  | Unnamed e -> MetaEnv.Positional, Some (f e)
  | Named (ArgId str, eo) -> MetaEnv.Named str, Option.map f eo
  | Named (EllipsisId, _) -> assert false
  | Named (EllipsisN _, _) -> assert false
  | Named (NullId, _) -> assert false
let aux_arg f arg =
  match arg with
  | None -> MetaEnv.Positional, None
  | Some arg -> aux_arg f arg
let aux_param env f p =
  match p with
  | NoDefault (EllipsisN _) | Default (EllipsisN _, _) -> assert false
  | NoDefault EllipsisId -> Ast.Ellipsis
  | Default (EllipsisId, _) -> assert false
  | NoDefault (ArgId str) -> Ast.NoDefault (Scope.resolve str env.id)
  | Default (ArgId str, e) -> Ast.Default (Scope.resolve str env.id, f e)
  | NoDefault NullId | Default (NullId, _) -> assert false

let aux_const c =
  match c with
  | CNan -> Ast.CNan
  | CNa kind -> Ast.CNa kind
  | CStr str -> Ast.CChr str
  | CFloat str -> Ast.CDbl str
  | CInt i -> Ast.CInt i
  | CClx str -> Ast.CClx str
  | CBool b -> Ast.CLgl b
  | CNull -> Ast.CNull

let add_def env e str =
  let v = Scope.resolve str env.id in
  Eid.unique (), Ast.Declare (v, e)

let add_binding annots acc str =
  Scope.add_local_binding ?annot:(StrMap.find_opt str annots) str Scope.KAny acc

let rec expr_of_left pos r l =
  let call pos r op_prefix args =
    let args = args@[Some (Named (ArgId "v", Some r))] in
    (pos, Call ((pos, Id (op_prefix^"<-")), args))
  in
  match snd l with
  | Id id -> (id, r)
  | Dollar (l,arg) ->
    let str = match arg with Some (ArgId str) -> str | _ -> assert false in
    let arg = pos, Const (CStr str) in
    let r = call pos r "$" [Some (Unnamed l); Some (Unnamed arg)] in
    expr_of_left pos r l
  | At (l,arg) ->
    let str = match arg with Some (ArgId str) -> str | _ -> assert false in
    let arg = pos, Const (CStr str) in
    let r = call pos r "@" [Some (Unnamed l); Some (Unnamed arg)] in
    expr_of_left pos r l
  | Subset (l,args) ->
    let r = call pos r "[]" ((Some (Unnamed l))::args) in
    expr_of_left pos r l
  | Subset2 (l,args) ->
    let r = call pos r "[[]]" ((Some (Unnamed l))::args) in
    expr_of_left pos r l
  | Call ((_, Id id'), (Some (Unnamed l))::args) ->
    let r = call pos r id' ((Some (Unnamed l))::args) in
    expr_of_left pos r l
  | _ -> failwith "Invalid left value."

let rec aux_e env (pos,e) =
  let eid = Eid.unique_with_pos pos in
  let e = match e with
  | Return -> assert false
  | Break -> Ast.Break | Next -> Ast.Next
  | Const c -> Ast.Const (aux_const c)
  | Id str -> Ast.Id (Scope.resolve str env.id)
  | Unop (str, e) -> Ast.Unop (Scope.resolve str env.id, aux_e env e)
  | Binop (str, (e1,e2)) ->
    begin match str, e1, e2 with
    | ("<-" | "="), e1, e2 | "->", e2, e1 ->
      let (id, r) = expr_of_left pos e2 e1 in
      Ast.VarAssign (Scope.resolve id env.id, aux_e env r)
    | "<<-", (_, Id id), e2 -> Ast.VarAssign (Scope.resolve_parent id env.id, aux_e env e2)
    | "<<-", _, _ -> failwith "Invalid left value."
    | _, _, _ -> Ast.Binop (Scope.resolve str env.id, aux_e env e1, aux_e env e2)
    end
  | Subset (e,args) ->
    aux_e env (pos, Call ((pos, Id "[]"), (Some (Unnamed e))::args)) |> snd
  | Subset2 (e,args) ->
    aux_e env (pos, Call ((pos, Id "[[]]"), (Some (Unnamed e))::args)) |> snd
  | Dollar (e, arg) ->
    let str = match arg with Some (ArgId str) -> str | _ -> assert false in
    let arg = pos, Const (CStr str) in
    aux_e env (pos, Call ((pos, Id "$"), [Some (Unnamed e) ; Some (Unnamed arg)])) |> snd
  | At (e, arg) ->
    let str = match arg with Some (ArgId str) -> str | _ -> assert false in
    let arg = pos, Const (CStr str) in
    aux_e env (pos, Call ((pos, Id "@"), [Some (Unnamed e) ; Some (Unnamed arg)])) |> snd
  | Call ((_, Return),[]) -> Ast.Return None
  | Call ((_, Return),[Some (Unnamed e)]) -> Ast.Return (Some (aux_e env e))
  (* [local(e)] evaluates [e] in a fresh environment, so the names it assigns
     bind there instead of in the enclosing scope -- unlike a brace, which is
     not a scope in R. Only the one-argument form, since an explicit [envir]
     names an environment of the caller's choosing, and only when nothing shadows [local]. *)
  | Call ((_, Id "local"), [Some (Unnamed body)])
    when not (Scope.is_bound "local" env.id) ->
    let env = { env with id=Scope.new_scope env.id } in
    let ebvs = bv_e ~local_shadowed:false body in
    let env = { env with id=List.fold_left (add_binding env.annots) env.id
                              (StrSet.elements ebvs) } in
    List.fold_left (add_def env) (aux_e env body) (StrSet.elements ebvs) |> snd
  | Call (e,args) ->
    let e = aux_e env e in
    begin match args with
    | [None] -> Ast.Call (e, []) (* Empty parentheses should be read as 0 positional given *)
    | args ->
      let args = List.map (aux_arg (aux_e env)) args in
      Ast.Call (e, args)
    end
  | Ite (e, e1, e2) ->
    let e, e1 = aux_e env e, aux_e env e1 in
    let e2 = match e2 with None -> Eid.unique (), Ast.Const Ast.CNull | Some e2 -> aux_e env e2 in
    Ast.Ite (e, e1, e2)
  | While (e, e') -> Ast.While (aux_e env e, aux_e env e')
  | For (NullId, e, e') -> Ast.For (None, aux_e env e, aux_e env e')
  | For (EllipsisId, _, _) | For (EllipsisN _, _, _) -> failwith "Unexpected ellipsis."
  | For (ArgId str, e, e') ->
    Ast.For (Some (Scope.resolve str env.id), aux_e env e, aux_e env e')
  | Function (_,params,e) ->
    let add_binding = add_binding env.annots in
    (* Params *)
    let env = { env with id=Scope.new_scope env.id } in
    let pbvs =
      match params with
      | None -> StrSet.empty
      | Some lst -> bv_params lst
    in
    let env = { env with id=List.fold_left add_binding env.id (StrSet.elements pbvs) } in
    let params =
      match params with
      | None -> []
      | Some lst -> List.map (aux_param env (aux_e env)) lst
    in
    (* Body *)
    let ebvs = bv_e ~local_shadowed:(Scope.is_bound "local" env.id) e in
    let env = { env with id=List.fold_left add_binding env.id (StrSet.elements ebvs) } in
    let undeclared = StrSet.diff ebvs pbvs in
    let e = List.fold_left (add_def env) (aux_e env e) (StrSet.elements undeclared) in
    Ast.Function (params, e)
  | Dots -> Dots
  | DotsN n -> DotsN n
  | Braced [] -> Ast.Const Ast.CNull
  | Braced (e::es) ->
    List.fold_left (fun acc e -> Eid.unique (), Ast.Seq (acc, aux_e env e)) (aux_e env e) es |> snd
  in
  eid, e

let transform env t = aux_e env t
