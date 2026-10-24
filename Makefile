
all: build run

build:
	dune build

run:
	dune exec main sigs/*.R tests/*.r tests/**/*.r

record:
	dune exec -- main -record sigs/*.R tests/*.r

test:
	./bench.sh diff

promote:
	./bench.sh ref

clean:
	dune clean

deps:
	opam install . --deps-only

perf:
	sudo perf record --call-graph=dwarf -- ./_build/default/bin/main.exe sigs/*.R tests/*.r tests/**/*.r
	sudo perf report
