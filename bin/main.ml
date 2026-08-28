open Lang

(* The whole driver lives in [Lang.Driver], so that TypR can reuse it; this
   executable is only the command line around it. *)

let record = ref false
let input_files = ref []

let usage_msg = "rsem [-record] [-gradual] <file1> [<file2>] ..."
let anon_fun filename = input_files := filename::!input_files
let speclist =
  [
    ("-record", Arg.Set record, "Record tallying instances into a file") ;
    ("-gradual", Arg.Set Driver.gradual, "Give the dyn type to undefined functions")
  ]

let () =
  Printexc.record_backtrace true ;
  Driver.setup () ;
  (* System.Config.infer_overload := false ; *)

  Arg.parse speclist anon_fun usage_msg ;
  let open Mlsem.Types in
  if !record then Recording.start_recording () ;

  let ctx, penv = ref Driver.initial_ctx, ref PEnv.empty in
  List.rev !input_files |> List.iter (fun fn ->
      Format.printf "@.@{<bold>===== Processing %s =====@}@." fn ;
      Recording.clear () ;
      let ctx', penv' = PEnv.sequential_handler !penv Driver.main (!ctx, fn) in
      ctx := ctx' ; penv := penv' ;
      if !record then Recording.save_to_file fn (Recording.tally_calls ())
  )
