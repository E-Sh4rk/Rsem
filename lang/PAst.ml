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
| Ns of string * string (* [ns::name], or [ns:::name] *)
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
| Repeat of e
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
module StrMap = Map.Make(String)

(* ===== Binders and their kinds ===== *)

(* The kind a name gets from the expression it is bound to, before typing and
   from its syntax only (cf. [Scope.resolve_call]): a function definition is a
   function, a mere name (e.g. [f <- stats::median]) may be anything, and
   anything else is assumed not to be a function. It is an approximation: e.g.
   [f <- match.fun(f)] binds a function. The value of an assignment is the one
   it assigns. *)
let rec kind_of_value (_,e) =
  match e with
  | Function _ -> Scope.KFun
  | Id _ | Ns _ -> Scope.KAny
  | Binop (("<-" | "=" | "<<-"), (_, e)) | Binop ("->", (e, _)) -> kind_of_value e
  | _ -> Scope.KVal

(* The binders of a scope, each with its kind. A name bound several times gets
   the kind of all its bindings if they agree, and [KAny] otherwise. *)
let union_kinds =
  StrMap.union (fun _ k1 k2 -> Some (if k1 = k2 then k1 else Scope.KAny))
let unions_kinds = List.fold_left union_kinds StrMap.empty

(* A parameter with no default value may be given anything, and one with a
   default value is assumed to be of the kind of its default value. *)
let bv_param p =
  match p with
  | NoDefault (ArgId str) -> StrMap.singleton str Scope.KAny
  | Default (ArgId str, e) -> StrMap.singleton str (kind_of_value e)
  | _ -> StrMap.empty
let bv_params ps = List.map bv_param ps |> unions_kinds

let rec bv_e_ ~ls (_,e) =
  let bv_e, bv_es = bv_e_ ~ls, bv_es_ ~ls in
  match e with
  | Return | Break | Next | Const _ | Id _ | Ns _ | Function _  | Dots | DotsN _ -> StrMap.empty
  | Unop (_,e) | Dollar (e, _) | At (e, _) | Repeat e -> bv_e e
  | Binop (str, (e1, e2)) ->
    let res = match str, e1, e2 with
    | ("<-" | "="), (_, Id id), e | "->", e, (_, Id id) -> StrMap.singleton id (kind_of_value e)
    | "<<-", (_, Id _), _ -> StrMap.empty
    | _, _, _ -> StrMap.empty
    in
    union_kinds res (bv_es [e1;e2])
  (* [local(e)] gives [e] an environment of its own, so what it assigns binds
     there and not here. Only when [local] is R's own, which is what [ls] carries. *)
  | Call ((_, Id "local"), [Some (Unnamed _)]) when ls -> StrMap.empty
  | Call (e, args) | Subset (e, args) | Subset2 (e, args) ->
    let es = args |> List.concat_map (function
      | None  | Some (Named (_, None)) -> []
      | Some (Unnamed e) | Some (Named (_, Some e)) -> [e]
      )
    in
    bv_es (e::es)
  | Ite (e, e1, e2) -> bv_es (e::e1::(match e2 with None -> [] | Some e2 -> [e2]))
  | While (e, e') -> bv_es [e;e']
  | For (ArgId str, e, e') -> union_kinds (StrMap.singleton str Scope.KVal) (bv_es [e;e'])
  | For (_, e, e') -> bv_es [e;e']
  | Braced es -> bv_es es
and bv_es_ ~ls es = List.map (bv_e_ ~ls) es |> unions_kinds

(* The names [e] assigns, which are the variables local to the function whose
   body it is -- or, at top level, the definitions the statement makes --, each
   with its kind.
   [local_shadowed] says whether the enclosing scope binds [local]; [e] may
   also bind it itself, in which case it is shadowed over the whole of [e],
   R scoping a body as a whole rather than sequentially. *)
let bv_kinds ~local_shadowed e =
  if local_shadowed then bv_e_ ~ls:false e
  else
    let bvs = bv_e_ ~ls:true e in
    if StrMap.mem "local" bvs then bv_e_ ~ls:false e else bvs
let domain m = StrMap.fold (fun str _ acc -> StrSet.add str acc) m StrSet.empty
let bv_e ~local_shadowed e = bv_kinds ~local_shadowed e |> domain

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

let add_bindings annots kinds acc =
  StrMap.fold (fun str kind acc ->
    Scope.add_local_binding ?annot:(StrMap.find_opt str annots) str kind acc)
    kinds acc

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
  | Ns (ns, name) -> Ast.Id (Scope.resolve_ns ns name env.id)
  | Unop (str, e) -> Ast.Unop (Scope.resolve_call str env.id, aux_e env e)
  | Binop (str, (e1,e2)) ->
    begin match str, e1, e2 with
    | ("<-" | "="), e1, e2 | "->", e2, e1 ->
      let (id, r) = expr_of_left pos e2 e1 in
      Ast.VarAssign (Scope.resolve_assigned id env.id, aux_e env r)
    | "<<-", (_, Id id), e2 -> Ast.VarAssign (Scope.resolve_parent id env.id, aux_e env e2)
    | "<<-", _, _ -> failwith "Invalid left value."
    | _, _, _ -> Ast.Binop (Scope.resolve_call str env.id, aux_e env e1, aux_e env e2)
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
    let ebvs = bv_kinds ~local_shadowed:false body in
    let env = { env with id=add_bindings env.annots ebvs env.id } in
    Ast.Local (List.fold_left (add_def env) (aux_e env body) (domain ebvs |> StrSet.elements))
  | Call (e,args) ->
    let e = match e with
      | pos, Id str -> Eid.unique_with_pos pos, Ast.Id (Scope.resolve_call str env.id)
      | e -> aux_e env e
    in
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
    Ast.For (Some (Scope.resolve_assigned str env.id), aux_e env e, aux_e env e')
  | Repeat e -> Ast.Repeat (aux_e env e)
  | Function (_,params,e) ->
    let add_bindings = add_bindings env.annots in
    let env = { env with id=Scope.new_scope env.id } in
    let pbvs =
      match params with
      | None -> StrMap.empty
      | Some lst -> bv_params lst
    in
    (* The parameters and the local variables share the scope of the body: a
       name that is both gets the kind of all its bindings (cf. [union_kinds]),
       already for the default values of the parameters. *)
    let local_shadowed = StrMap.mem "local" pbvs || Scope.is_bound "local" env.id in
    let ebvs = bv_kinds ~local_shadowed e in
    let kinds = union_kinds pbvs ebvs in
    let kinds_of bvs = StrMap.mapi (fun str _ -> StrMap.find str kinds) bvs in
    (* Params *)
    let env = { env with id=add_bindings (kinds_of pbvs) env.id } in
    let params =
      match params with
      | None -> []
      | Some lst -> List.map (aux_param env (aux_e env)) lst
    in
    (* Body *)
    let env = { env with id=add_bindings (kinds_of ebvs) env.id } in
    let undeclared = StrSet.diff (domain ebvs) (domain pbvs) in
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
