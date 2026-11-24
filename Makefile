# hello-depression
# Convenience targets for development and packaging.

SHELL := /bin/bash
EXT_UUID := hello-depression@rarroy2.github.io

.PHONY: all check detect install install-icon uninstall pack clean

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

install-icon:
	@test -d "$(HOME)/.local/share/gnome-shell/extensions/$(EXT_UUID)" || { \
		echo "extension is not installed for this user"; exit 1; \
	}
	install -Dm0644 extension/icons/hello-depression-symbolic.svg \
		"$(HOME)/.local/share/gnome-shell/extensions/$(EXT_UUID)/icons/hello-depression-symbolic.svg"
	install -Dm0644 extension/icons/hello-depression-symbolic.svg \
		"$(HOME)/.local/share/icons/hicolor/scalable/actions/hello-depression-symbolic.svg"
	@if command -v gtk-update-icon-cache >/dev/null 2>&1; then \
		gtk-update-icon-cache -f -t "$(HOME)/.local/share/icons/hicolor" >/dev/null 2>&1 || true; \
	fi
	@if gnome-extensions list 2>/dev/null | grep -qx '$(EXT_UUID)'; then \
		gnome-extensions disable '$(EXT_UUID)' 2>/dev/null || true; \
		gnome-extensions enable '$(EXT_UUID)' 2>/dev/null || true; \
	fi
	@echo "Icon updated. Log out and back in if it does not refresh."

uninstall:
	sudo ./uninstall.sh

pack:
	@mkdir -p dist
	gnome-extensions pack --force --extra-source=icons --out-dir=dist extension
	@echo "packed dist/$(EXT_UUID).shell-extension.zip"

clean:
	rm -rf dist
