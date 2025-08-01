
all: build run

build:
	dune build

run:
	dune exec parse-r

clean:
	dune clean
