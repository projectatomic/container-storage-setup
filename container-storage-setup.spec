%global project container-storage-setup
%global git0 https://github.com/projectatomic/%{repo}
%global csslibdir %{_prefix}/share/container-storage-setup
%global commit         79462e9565053fb1e0d87c336e6d980f0a56c41e
%global shortcommit    %(c=%{commit}; echo ${c:0:7})
%global repo %{project}

Name:           container-storage-setup
Version:        0.1.0
Release:        1%{?dist}
Summary:        A simple service to setup container storage devices

License:        ASL 2.0
URL:            http://github.com/projectatomic/container-storage-setup/
Source0: %{git0}/archive/%{commit}/%{repo}-%{shortcommit}.tar.gz
BuildArch: noarch

Requires:       lvm2
Requires:       xfsprogs 

%description
This is a simple service to configure Container Runtimes to use an LVM-managed
thin pool.  It also supports auto-growing both the pool as well
as the root logical volume and partition table. 

%prep
%setup -q -n %{repo}-%{commit}

%build

%install
%{__make} install-core DESTDIR=%{?buildroot}

%files
%doc README.md 
%{_bindir}/container-storage-setup
%dir %{csslibdir}
%{_mandir}/man1/container-storage-setup.1*
%{csslibdir}/container-storage-setup
%{csslibdir}/css-child-read-write
%{csslibdir}/libcss.sh

%changelog
* Mon Feb 27 2017 Dan Walsh <dwalsh@redhat.com> - 0.1.0-1
- Initial version of container-storage-setup
- Building to push through the fedora release cycle

* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-2
- Fix rpm deps and scripts

* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-1
- Initial build

