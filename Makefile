# hello-depression
# Convenience targets for development and packaging.

SHELL := /bin/bash
EXT_UUID := hello-depression@rarroy2.github.io

.PHONY: all check detect install uninstall pack clean

all: check

check:
	bash -n bin/boot-to-windows
	bash -n install.sh
	bash -n uninstall.sh
	@if command -v node >/dev/null 2>&1; then \
		tmp=$$(mktemp --suffix=.mjs); \
		cp extension/extension.js "$$tmp"; \
		node --check "$$tmp"; \
		rm -f "$$tmp"; \
	else \
		echo "node not found, skipping extension syntax check"; \
	fi
	./bin/boot-to-windows --version
	./bin/boot-to-windows --help >/dev/null
	@echo "checks passed"

detect:
	./bin/boot-to-windows --detect

install:
	sudo ./install.sh

uninstall:
	sudo ./uninstall.sh

pack:
	@mkdir -p dist
	gnome-extensions pack --force --extra-source=icons --out-dir=dist extension
	@echo "packed dist/$(EXT_UUID).shell-extension.zip"

clean:
	rm -rf dist
