%global uuid bootrelay@rarroy2.github.io

Name:           bootrelay
Version:        0.3.0
Release:        1%{?dist}
Summary:        GNOME Quick Settings button to reboot into another operating system

License:        MIT
URL:            https://github.com/rarroy2/bootrelay
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

Obsoletes:      hello-depression < 0.3.0
Provides:       hello-depression = %{version}-%{release}

Requires:       bash
Requires:       efibootmgr
Requires:       gnome-shell
Requires:       polkit
Recommends:     grub2-tools

%description
BootRelay adds an "Ir a Windows" toggle to the GNOME Quick Settings grid. It
configures a one-shot UEFI BootNext entry (or a GRUB next_entry fallback) and
reboots into Windows, then returns to the normal boot order. Support for more
operating systems is planned.

The package installs the bootrelay helper, a narrowly scoped polkit rule and the
GNOME Shell extension. A deprecated boot-to-windows symlink is kept for
compatibility with the 0.2.x release.

%prep
%setup -q

%build

%install
install -Dpm0755 bin/bootrelay %{buildroot}%{_bindir}/bootrelay
ln -s bootrelay %{buildroot}%{_bindir}/boot-to-windows
install -Dpm0644 polkit/49-bootrelay.rules %{buildroot}%{_datadir}/polkit-1/rules.d/49-bootrelay.rules
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/%{uuid}
cp -a extension/. %{buildroot}%{_datadir}/gnome-shell/extensions/%{uuid}/
install -Dpm0644 extension/icons/bootrelay-symbolic.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/actions/bootrelay-symbolic.svg

%post
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
    %{_bindir}/gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor 2>/dev/null || :
fi

%postun
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
    %{_bindir}/gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor 2>/dev/null || :
fi

%files
%license LICENSE
%doc README.md docs assets
%{_bindir}/bootrelay
%{_bindir}/boot-to-windows
%{_datadir}/polkit-1/rules.d/49-bootrelay.rules
%{_datadir}/gnome-shell/extensions/%{uuid}
%{_datadir}/icons/hicolor/scalable/actions/bootrelay-symbolic.svg

%changelog
* Wed Nov 25 2026 Raúl Arroyo <199929731+rarroy2@users.noreply.github.com> - 0.3.0-1
- Rename project from hello-depression to BootRelay
- Install /usr/bin/bootrelay and a deprecated boot-to-windows symlink
- Move the polkit rule and GNOME Shell extension to the new names

* Tue Nov 24 2026 Raúl Arroyo <199929731+rarroy2@users.noreply.github.com> - 0.2.0-1
- Initial RPM package
