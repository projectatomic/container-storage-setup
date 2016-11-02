%define dsslibdir %{_prefix}/lib/docker-storage-setup

Name:           docker-storage-setup
Version:        0.5
Release:        1%{?dist}
Summary:        A simple service to setup docker storage devices

License:        ASL 2.0
URL:            http://github.com/a13m/docker-storage-setup/

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
%make_install

%post
%systemd_post %{name}.service

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun %{name}.service

%files
%{_unitdir}/docker-storage-setup.service
%{_bindir}/docker-storage-setup
%config(noreplace) %{_sysconfdir}/sysconfig/docker-storage-setup
%dir %{dsslibdir}
%{_mandir}/man1/docker-storage-setup.1

%changelog
* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-2
- Fix rpm deps and scripts

* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-1
- Initial build

