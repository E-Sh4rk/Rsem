open Rstt

type sig_def = string * (string,string,string) Builder.t
type alias_def = string * (string,string,string) Builder.t
(* Declaration of a new class-overload (S3 dispatch): the name of the method,
   for instance [print.myclass]. *)
type class_def = string

type t =
| Sig of sig_def
| Alias of alias_def
| NewClass of class_def
