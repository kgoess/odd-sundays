#
# This SPEC file was automatically generated using the cpantorpm
# script.
#
#    Package:           perl-OddSundays
#    Version:           0.01
#    cpantorpm version: 1.09
#    Date:              Sun Oct 04 2020
#    Command:
# /home/kevin/perl5/bin/cpantorpm --spec-only /home/kevin/git/odd-sundays/OddSundays-0.01.tar.gz
#

%define appver 0.09

Name:           perl-OddSundays
Version:        %appver
Release:        1%{?dist}
Summary:        unknown
License:        GPL+ or Artistic
Group:          Applications/Internet
URL:            https://github.com/kgoess/odd-sundays
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

Provides:       perl(OddSundays) = %appver
Provides:       perl(OddSundays::Controller)
Provides:       perl(OddSundays::Controller::ModPerl)
Provides:       perl(OddSundays::Model::Recording)
Provides:       perl(OddSundays::Utils)
Provides:       perl(OddSundays::View)
BuildRequires:  perl(ExtUtils::MakeMaker)
BuildRequires:  perl(Test::Exception)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires: mod_perl => 2.0.11
Requires: perl(CGI::Cookie) => 1.30
Requires: perl(Class::Accessor::Lite) => 0.05
Requires: perl(Data::Dump) => 1.22
Requires: perl(DateTime) => 1.04
Requires: perl(DBD::SQLite) => 1.39
Requires: perl(DBI) => 1.627
Requires: perl(Digest::SHA) => 5.85
Requires: perl(File::Temp) => 0.2301
Requires: perl(Storable)
Requires: perl(Template) => 2.24
Requires: perl(Text::Wrap)

%description
webapp to handle recordings for the Odd Sundays project

%prep

rm -rf %{_builddir}/OddSundays-%{version}
%setup -D -n OddSundays-%{appver}
chmod -R u+w %{_builddir}/OddSundays-%{version}
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

# these are customized for our install:

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
# the other but of customized for our install:
/usr/local/odd-sundays/templates/
/var/www/bacds.org/public_html/odd-sundays-static/
%attr(755, root, root) %dir /var/lib/odd-sundays
%attr(755, apache, apache) %dir /var/lib/odd-sundays/uploads
%attr(755, apache, apache) %dir /var/lib/odd-sundays/db

%changelog
* Sun Oct 04 2020 Kevin M. Goess <cpan@goess.org> 0.01-1
- Generated using cpantorpm

