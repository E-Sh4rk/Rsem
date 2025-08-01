
all: build run

build:
	dune build

run:
	dune exec main

clean:
	dune clean
