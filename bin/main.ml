open Lang

(* The whole driver lives in [Lang.Driver], so that TypR can reuse it; this
   executable is only the command line around it. *)

let record = ref false
let input_files = ref []

let usage_msg = "rsem [-record] [-gradual] [-errors {types|witnesses|both}] <file1> [<file2>] ..."
let anon_fun filename = input_files := filename::!input_files
let speclist =
  [
    ("-record", Arg.Set record, "Record tallying instances into a file") ;
    ("-gradual", Arg.Set Driver.gradual, "Give the dyn type to undefined functions") ;
    ("-errors", Arg.Symbol (["types" ; "witnesses" ; "both"], fun s ->
         Error.style := match s with
           | "witnesses" -> Mlsem.Lang.Error.Witnesses
           | "both" -> Mlsem.Lang.Error.Both
           | _ -> Mlsem.Lang.Error.Types),
     " Explain typing errors with the types involved, \
      with a witness value, or both (default)")
  ]

let () =
  Printexc.record_backtrace true ;
  Driver.setup () ;
  (* System.Config.infer_overload := false ; *)

  Arg.parse speclist anon_fun usage_msg ;
  let open Mlsem.Types in
  if !record then Recording.start_recording () ;

  (* The class-overloads of every file are declared before any file is
     processed (cf. [Driver.declare_overloads]). *)
  let files = List.rev !input_files |> List.map (fun fn -> fn, Driver.parse fn) in
  let ctx = files |> List.fold_left (fun ctx (_, parsed) ->
      Option.fold ~none:ctx ~some:(Driver.declare_overloads ctx) parsed) Driver.initial_ctx in
  let ctx, penv = ref ctx, ref PEnv.empty in
  files |> List.iter (fun (fn, parsed) ->
      Format.printf "@.@{<bold>===== Processing %s =====@}@." fn ;
      Recording.clear () ;
      let process (ctx, parsed) = Option.fold ~none:ctx ~some:(Driver.process ctx) parsed in
      let ctx', penv' = PEnv.sequential_handler !penv process (!ctx, parsed) in
      ctx := ctx' ; penv := penv' ;
      if !record then Recording.save_to_file fn (Recording.tally_calls ())
  )
