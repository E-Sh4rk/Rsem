#!/bin/sh


usage () {
    echo "Usage: ${0} <cmd>
where <cmd> is:
  perf      run perf record on main.exe (see the report with perf report)
  ref       execute a reference run of main.exe
  diff      compare the output of main.exe with the reference run
  clean     clean-up generated files (_bench directory and perf.data)
"
}
N=4   #number of runs for benchmark

TMP_DIR="_bench"
REF_FILE="types.ref"
mkdir -p "$TMP_DIR"

compare_output () {
    cat "$1" > "$TMP_DIR"/t1.tmp
    cat "$2" > "$TMP_DIR"/t2.tmp
    diff -q "$TMP_DIR"/t1.tmp "$TMP_DIR"/t2.tmp >/dev/null 2>&1
    R=$?
    if [ "$R" -ne 0 ]
    then
        diff --color -U 0 "$TMP_DIR"/t1.tmp "$TMP_DIR"/t2.tmp
    fi
    return $R
}


if [ "$1" = "perf" ]
then
    opam exec -- dune build main
    perf record --call-graph=dwarf -- main tests/*.r tests/**/*.r >/dev/null 2>&1
elif [ "$1" = "report" ]
then
    perf report
elif [ "$1" = "ref" ]
then
    opam exec -- dune exec -- main tests/*.r tests/**/*.r  > "$REF_FILE"
    exit 0
elif [ "$1" = "diff" ]
then
     opam exec -- dune exec --display=quiet -- main tests/*.r tests/**/*.r > "$TMP_DIR"/types.tmp
     compare_output "$REF_FILE" "$TMP_DIR"/types.tmp || exit 1
     exit 0
elif [ "$1" = "clean" ]
then
    rm -rf "$TMP_DIR" perf.data
else
    usage
fi
