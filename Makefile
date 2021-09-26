clean:
	rm -rf docs

test:
	mdbook test

build: clean test
	mdbook build
	mv book docs

.PHONY: clean build test
