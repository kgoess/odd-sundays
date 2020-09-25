
package OddSundays::View;

use strict;
use warnings;

use Carp qw/croak/;
use Template;

use OddSundays::Model::Recording;
#use OddSundays::Logger;

# when either OddSundays::Controller::ModPerl or Goc::Controller::CGI loads
# this module, Perl calls this import() function and we set the location
# of the uri_for implementation
sub import {
    my ($class, $location) = @_;

    return unless $location;

    no warnings 'redefine';
    my $uri_for_implementation = join '::', $location, 'uri_for';
    *uri_for = \&{$uri_for_implementation};

    my $static_uri_for_implementation = join '::', $location, 'static_uri_for';
    *static_uri_for = \&{$static_uri_for_implementation};
}


sub main_page {
    my ($class, %p) = @_;

    my @recordings = OddSundays::Model::Recording->get_all();

    my $tt = get_tt();

    my $template = 'main-html.tt';
    my $vars = get_vars(
        \%p,
        message => $p{message},
        page_title => 'Download Page',
        recordings => @recordings,
    );
    my $output = '';

    $tt->process($template, $vars, \$output)
           || die $tt->error();

    return $output;
}

sub upload_recording {
    my ($class, %p) = @_;

    my $tt = get_tt();

    my $template = 'upload-recording.tt';
    my $vars = get_vars(
        \%p,
        message => $p{message},
        page_title => 'Upload Music',
    );
    my $output = '';

    $tt->process($template, $vars, \$output)
           || die $tt->error();

    return $output;
}

my $_tt;
sub get_tt {

    my $config = {
        INCLUDE_PATH => ($ENV{TT_INCLUDE_PATH} || './templates'),
        PRE_PROCESS => 'header.tt', # add config as arrayref with organization_name?
        POST_PROCESS => 'footer.tt',
    };

    $_tt ||= Template->new($config);
    return $_tt;
}

sub get_vars {
    my $p = shift;
    my %vars = @_;

    return {
        uri_for        => \&uri_for,
        static_uri_for => \&static_uri_for,
        %vars,
    };
}

1;