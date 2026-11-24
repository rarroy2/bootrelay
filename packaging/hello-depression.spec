%global uuid hello-depression@rarroy2.github.io

Name:           hello-depression
Version:        0.2.0
Release:        1%{?dist}
Summary:        GNOME Quick Settings button to reboot into Windows

License:        MIT
URL:            https://github.com/rarroy2/hello-depression
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

Requires:       bash
Requires:       efibootmgr
Requires:       gnome-shell
Requires:       polkit
Recommends:     grub2-tools

%description
Hello Depression adds an "Ir a Windows" toggle to the GNOME Quick Settings
grid. It configures a one-shot UEFI BootNext entry (or a GRUB next_entry
fallback) and reboots into Windows, then returns to the normal boot order.

The package installs the boot-to-windows helper, a narrowly scoped polkit rule
and the GNOME Shell extension.

%prep
%setup -q

%build

%install
install -Dpm0755 bin/boot-to-windows %{buildroot}%{_bindir}/boot-to-windows
install -Dpm0644 polkit/49-hello-depression.rules %{buildroot}%{_datadir}/polkit-1/rules.d/49-hello-depression.rules
install -d %{buildroot}%{_datadir}/gnome-shell/extensions/%{uuid}
cp -a extension/. %{buildroot}%{_datadir}/gnome-shell/extensions/%{uuid}/
install -Dpm0644 extension/icons/hello-depression-symbolic.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/actions/hello-depression-symbolic.svg

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
%doc README.md
%{_bindir}/boot-to-windows
%{_datadir}/polkit-1/rules.d/49-hello-depression.rules
%{_datadir}/gnome-shell/extensions/%{uuid}
%{_datadir}/icons/hicolor/scalable/actions/hello-depression-symbolic.svg

%changelog
* Tue Nov 24 2026 Raúl Arroyo <199929731+rarroy2@users.noreply.github.com> - 0.2.0-1
- Initial RPM package
