
all: build run

build:
	dune build

run:
	dune exec main tests/*.r tests/**/*.r

record:
	dune exec -- main -record tests/*.r


clean:
	dune clean

deps:
	opam install . --deps-only