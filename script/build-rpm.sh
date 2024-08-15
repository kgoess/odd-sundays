#!/bin/sh -x

set -e

perl Makefile.PL
make
make test
make dist
cp OddSundays-*tar.gz ~/rpmbuild/SOURCES/

# These macros used to be (centos-7) defined in /usr/lib/rpm/macros.perl (from
# the rpm-build rpm) but in alma-9 the file (from the perl-macros rpm) does not
# contain them.
# They're produced by cpan2rpm https://github.com/SBECK-github/App-CPANtoRPM/
# so we need to have them defined.
rpmbuild \
    --define 'perl_sitelib    %(eval "`perl -V:installsitelib`"; echo $installsitelib)'   \
    --define 'perl_sitearch   %(eval "`perl -V:installsitearch`"; echo $installsitearch)' \
    -ba spec/perl-OddSundays.spec


echo "*********************"
echo "here's your rpm!"
ls ~/rpmbuild/RPMS/noarch/perl-OddSundays*.rpm
