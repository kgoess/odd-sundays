#!/bin/sh -x

set -e

perl Makefile.PL
make
make test
make dist
cp OddSundays-*tar.gz ~/rpmbuild/SOURCES/
rpmbuild -ba spec/perl-OddSundays.spec 

echo "*********************"
echo "here's your rpm!"
ls ~/rpmbuild/RPMS/noarch/perl-OddSundays*.rpm
