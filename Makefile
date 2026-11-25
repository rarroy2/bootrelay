# bootrelay
# Convenience targets for development and packaging.

SHELL := /bin/bash
EXT_UUID := bootrelay@rarroy2.github.io
VERSION := 0.3.0
RPMTOP := $(CURDIR)/dist/rpmbuild
RPMDEF := --define "_topdir $(RPMTOP)"

.PHONY: all check detect install install-icon uninstall pack prepare-rpm srpm rpm rpmlint clean

all: check

check:
	bash -n bin/bootrelay
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
	@if command -v rpmspec >/dev/null 2>&1; then \
		rpmspec -P packaging/bootrelay.spec >/dev/null; \
	fi
	./bin/bootrelay --version
	./bin/bootrelay --help >/dev/null
	@echo "checks passed"

detect:
	./bin/bootrelay --detect

install:
	sudo ./install.sh

install-icon:
	@test -d "$(HOME)/.local/share/gnome-shell/extensions/$(EXT_UUID)" || { \
		echo "extension is not installed for this user"; exit 1; \
	}
	install -Dm0644 extension/icons/bootrelay-symbolic.svg \
		"$(HOME)/.local/share/gnome-shell/extensions/$(EXT_UUID)/icons/bootrelay-symbolic.svg"
	install -Dm0644 extension/icons/bootrelay-symbolic.svg \
		"$(HOME)/.local/share/icons/hicolor/scalable/actions/bootrelay-symbolic.svg"
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

prepare-rpm:
	@mkdir -p "$(RPMTOP)/SOURCES" "$(RPMTOP)/SPECS"
	tar --exclude=./.git --exclude=./dist \
		--transform 's,^\.,bootrelay-$(VERSION),' \
		-czf "$(RPMTOP)/SOURCES/bootrelay-$(VERSION).tar.gz" .
	cp packaging/bootrelay.spec "$(RPMTOP)/SPECS/"

srpm: prepare-rpm
	rpmbuild -bs $(RPMDEF) "$(RPMTOP)/SPECS/bootrelay.spec"

rpm: prepare-rpm
	rpmbuild -ba $(RPMDEF) "$(RPMTOP)/SPECS/bootrelay.spec"
	@echo "built:"
	@find "$(RPMTOP)/RPMS" "$(RPMTOP)/SRPMS" -name '*.rpm' -print

rpmlint: rpm
	@if command -v rpmlint >/dev/null 2>&1; then \
		rpmlint "$(RPMTOP)"/RPMS/noarch/*.rpm "$(RPMTOP)"/SRPMS/*.src.rpm; \
	else \
		echo "rpmlint is not installed; skipping"; \
	fi

clean:
	rm -rf dist
