Name:           docker-storage-setup
Version:        0.0.1
Release:        1%{?dist}
Summary:        A simple service to setup docker storage devices

License:        ASL 2.0
URL:            http://github.com/a13m/docker-storage-setup/
Source0:        docker-storage-setup.sh
Source1:        docker-storage-setup.service

Requires:       lvm2
Requires:       cloud-utils-growpart

%description
This is a simple service to divide available storage between
the OS and docker using LVM devices.

%prep

%build

%install
install -d %{buildroot}%{_bindir}
install -p -m 755 %{SOURCE0} %{buildroot}%{_bindir}/docker-storage-setup
install -d %{buildroot}%{_unitdir}
install -p -m 644 %{SOURCE1} %{buildroot}%{_unitdir}
# install -d %{buildroot}%{_sysconfdir}/sysconfig/
# install -p -m 644 %{SOURCE2} %{buildroot}%{_sysconfdir}/sysconfig/docker-storage-setup

%post
%systemd_post %{SOURCE1}

%preun
%systemd_preun %{SOURCE1}

%postun
%systemd_postun %{SOURCE1}

%files
%{_unitdir}/docker-storage-setup.service
%{_bindir}/docker-storage-setup
# %{_sysconfdir}/sysconfig/docker-storage-setup

%changelog
* Thu Oct 16 2014 Andy Grimm <agrimm@redhat.com> - 0.0.1-1
- Initial build

