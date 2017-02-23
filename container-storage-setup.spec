%define csslibdir %{_prefix}/lib/container-storage-setup

Name:           container-storage-setup
Version:        0.5
Release:        1%{?dist}
Summary:        A simple service to setup container storage devices

License:        ASL 2.0
URL:            http://github.com/a13m/container-storage-setup/

BuildRequires:  pkgconfig(systemd)

Requires:       lvm2
Requires:       systemd-units
Requires:       xfsprogs 

%description
This is a simple service to configure Container Runtimes to use an LVM-managed
thin pool.  It also supports auto-growing both the pool as well
as the root logical volume and partition table. 

%prep

%build

%install
%{__make} install-core DESTDIR=%{?buildroot}

%files
%{_bindir}/container-storage-setup
%{_bindir}/docker-storage-setup
%dir %{csslibdir}
%{_mandir}/man1/container-storage-setup.1

%changelog
* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-2
- Fix rpm deps and scripts

* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-1
- Initial build

