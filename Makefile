clean:
	rm -rf docs

build: clean
	mdbook build
	mv book docs

.PHONY: clean build
