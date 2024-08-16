#
# This SPEC file was automatically generated using the cpantorpm
# script.
#
#    Package:           perl-OddSundays
#    Version:           0.16
#    cpantorpm version: 1.16
#    Date:              Thu Aug 15 2024
#    Command:
# /home/kevin/git/App-CPANtoRPM/bin/cpantorpm --spec-only --packager Kevin\ M.\ Goess\ <kevin@goess.org> --no-deps OddSundays-0.16.tar.gz
#

Name:           perl-OddSundays
Version:        0.16
Release:        1%{?dist}
Summary:        unknown
License:        GPL+ or Artistic
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/OddSundays/
BugURL:         http://search.cpan.org/dist/OddSundays/
BuildArch:      noarch
Source0:        OddSundays-%{version}.tar.gz

#
# Unfortunately, the automatic provides and requires do NOT always work (it
# was broken on the very first platform I worked on).  We'll get the list
# of provides and requires manually (using the RPM tools if they work, or
# by parsing the files otherwise) and manually specify them in this SPEC file.
#

AutoReqProv:    no
AutoReq:        no
AutoProv:       no

Provides:       perl(OddSundays) = 0.16
Provides:       perl(OddSundays::Controller) = 0.16
Provides:       perl(OddSundays::Controller::ModPerl) = 0.16
Provides:       perl(OddSundays::Model::Log) = 0.16
Provides:       perl(OddSundays::Model::Recording) = 0.16
Provides:       perl(OddSundays::Utils) = 0.16
Provides:       perl(OddSundays::View) = 0.16
Requires:       perl(Apache2::Const) >= 2
Requires:       perl(Apache2::Request) >= 2
Requires:       perl(Apache2::RequestIO) >= 2
Requires:       perl(Apache2::RequestRec) >= 2
Requires:       perl(Apache2::Upload) >= 2
Requires:       perl(CGI::Cookie) >= 1.3
Requires:       perl(Class::Accessor::Lite) >= 0.05
Requires:       perl(DBD::SQLite) >= 1.39
Requires:       perl(DBI) >= 1.627
Requires:       perl(Data::Dump) >= 1.22
Requires:       perl(DateTime) >= 1.04
Requires:       perl(Digest::SHA) >= 5.85
Requires:       perl(File::Temp) >= 0.2301
Requires:       perl(Template) >= 2.24
Requires:       perl(Text::Wrap)
BuildRequires:  perl(Apache2::Const) >= 2
BuildRequires:  perl(Apache2::Request) >= 2
BuildRequires:  perl(Apache2::RequestIO) >= 2
BuildRequires:  perl(Apache2::RequestRec) >= 2
BuildRequires:  perl(Apache2::Upload) >= 2
BuildRequires:  perl(CGI::Cookie) >= 1.3
BuildRequires:  perl(Class::Accessor::Lite) >= 0.05
BuildRequires:  perl(DBD::SQLite) >= 1.39
BuildRequires:  perl(DBI) >= 1.627
BuildRequires:  perl(Data::Dump) >= 1.22
BuildRequires:  perl(DateTime) >= 1.04
BuildRequires:  perl(Digest::SHA) >= 5.85
BuildRequires:  perl(File::Temp) >= 0.2301
BuildRequires:  perl(Template) >= 2.24
BuildRequires:  perl(ExtUtils::MakeMaker)
BuildRequires:  perl(Text::Wrap)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
A perl module

%prep

rm -rf %{_builddir}/OddSundays-%{version}
%setup -D -n OddSundays-0.16
chmod -R u+w %{_builddir}/OddSundays-%{version}

# customized for our install
mkdir -p %{buildroot}/usr/local/odd-sundays/templates

if [ -f pm_to_blib ]; then rm -f pm_to_blib; fi

%build

%{__perl} Makefile.PL OPTIMIZE="$RPM_OPT_FLAGS" INSTALLDIRS=site INSTALLSITEBIN=%{_bindir} INSTALLSITESCRIPT=%{_bindir} INSTALLSITEMAN1DIR=%{_mandir}/man1 INSTALLSITEMAN3DIR=%{_mandir}/man3 INSTALLSCRIPT=%{_bindir}
make %{?_smp_mflags}

#
# This is included here instead of in the 'check' section because
# older versions of rpmbuild (such as the one distributed with RHEL5)
# do not do 'check' by default.
#

if [ -z "$RPMBUILD_NOTESTS" ]; then
   make test
fi

%install

rm -rf $RPM_BUILD_ROOT
make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -type f -name '*.bs' -size 0 -exec rm -f {} \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*


# customized for our install:

# 1. templates/ directory
mkdir -p %{buildroot}/usr/local/odd-sundays/templates
cp -r %{_builddir}/OddSundays-%{version}/templates/* %{buildroot}/usr/local/odd-sundays/templates/

# 2. static files directory
mkdir -p %{buildroot}/var/www/bacds.org/public_html/odd-sundays-static/
cp -r %{_builddir}/OddSundays-%{version}/static/* %{buildroot}/var/www/bacds.org/public_html/odd-sundays-static/

# 3. sqlite and uploaded files
mkdir -p %{buildroot}/var/lib/odd-sundays/uploads
mkdir -p %{buildroot}/var/lib/odd-sundays/db


%clean

rm -rf $RPM_BUILD_ROOT

%files

%defattr(-,root,root,-)
%{perl_sitelib}/*
%{_mandir}/man3/*

# customized for our install:
/usr/local/odd-sundays/templates/
/var/www/bacds.org/public_html/odd-sundays-static/
%attr(755, root, root) %dir /var/lib/odd-sundays
%attr(755, apache, apache) %dir /var/lib/odd-sundays/uploads
%attr(755, apache, apache) %dir /var/lib/odd-sundays/db

%changelog
* Sun Oct 04 2020 Kevin M. Goess <cpan@goess.org> 0.01-1
* Thu Aug 15 2024 Kevin M. Goess <cpan@goess.org> 0.16-1
- Generated using cpantorpm

