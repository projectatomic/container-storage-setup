%define dsslibdir %{_prefix}/lib/docker-storage-setup

Name:           docker-storage-setup
Version:        0.5
Release:        1%{?dist}
Summary:        A simple service to setup docker storage devices

License:        ASL 2.0
URL:            http://github.com/a13m/docker-storage-setup/
Source0:        docker-storage-setup.sh
Source1:        docker-storage-setup.service
Source2:        docker-storage-setup.conf
Source3:        docker-storage-setup-override.conf
Source4:        libdss.sh

BuildRequires:  pkgconfig(systemd)

Requires:       lvm2
Requires:       systemd-units
Requires:       xfsprogs 

%description
This is a simple service to configure Docker to use an LVM-managed
thin pool.  It also supports auto-growing both the pool as well
as the root logical volume and partition table. 

%prep

%build

%install
install -d %{buildroot}%{_bindir}
install -p -m 755 %{SOURCE0} %{buildroot}%{_bindir}/docker-storage-setup
install -d %{buildroot}%{_unitdir}
install -p -m 644 %{SOURCE1} %{buildroot}%{_unitdir}
install -d %{buildroot}/%{dsslibdir}
install -p -m 644 %{SOURCE2} %{buildroot}/%{dsslibdir}/docker-storage-setup
install -d %{buildroot}%{_sysconfdir}/sysconfig/
install -p -m 644 %{SOURCE3} %{buildroot}%{_sysconfdir}/sysconfig/docker-storage-setup
install -d %{buildroot}/%{dsslibdir}
install -p -m 755 %{SOURCE4} %{buildroot}/%{dsslibdir}/libdss.sh

%post
%systemd_post %{name}.service

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun %{name}.service

%files
%{_unitdir}/docker-storage-setup.service
%{_bindir}/docker-storage-setup
%{dsslibdir}/docker-storage-setup
%config(noreplace) %{_sysconfdir}/sysconfig/docker-storage-setup
%{dsslibdir}/libdss.sh

%changelog
* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-2
- Fix rpm deps and scripts

* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-1
- Initial build

