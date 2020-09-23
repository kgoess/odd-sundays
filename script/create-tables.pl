#!/usr/bin/perl


use strict;
use warnings;

use Data::Dump qw/dump/;
use DateTime;

use kg::OddSaturdays::Model::Recording;

die "set SQLITE_FILE first" unless $ENV{SQLITE_FILE};

open my $truncate, ">", $ENV{SQLITE_FILE};
close $truncate;

# DBD::SQLite::st execute failed: attempt to write a readonly database
# sudo chcon -R -t httpd_sys_content_rw_t /var/lib/berkmo-goc2/
# (and restart apache)
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/security-enhanced_linux/sect-security-enhanced_linux-working_with_selinux-selinux_contexts_labeling_files

kg::OddSaturdays::Model::Recording->create_table;

