=head1 NAME

OddSundays::Controller::ModPerl - mod_perl controller

=head2 SYNOPSIS

    <Location /odd-sundays>
        PerlSetEnv SQLITE_FILE /var/lib/odd-sundays/db/odd-sundays.sqlite
        PerlSetEnv TT_INCLUDE_PATH /usr/local/odd-sundays/templates
        PerlSetEnv UPLOAD_DIR /var/lib/odd-sundays/uploads
        PerlSetEnv URI_BASE /odd-sundays
        PerlSetEnv STATIC_URI_BASE /odd-sundays-static
        PerlSetEnv MGMT_URI_KEY 014e846f-9148-45f6-b5a8-f0025afbd494
        # (uuidgen is helpful to generate that)

        SetHandler perl-script
        PerlHandler OddSundays::Controller::ModPerl
    </Location>

=cut

package OddSundays::Controller::ModPerl;

use strict;
use warnings;

use Apache2::RequestRec (); # for $r->content_type
use Apache2::RequestIO ();  # for print
use Apache2::Upload; # loads ->upload
use Apache2::Const -compile => qw/:common :http/;
use Apache2::Request;

use OddSundays::Controller __PACKAGE__;
use OddSundays::View __PACKAGE__;

sub handler {
    my $controller = 'OddSundays::Controller';
    my $r = shift;

    #$r->content_type('text/plain');
    
    my $query_string = $r->args();

    # request input headers table
    my $headers_in = $r->headers_in();

    my $method = $r->method();

    # PATH_INFO
    my $path_info = $r->path_info();
    #   see also http://www.informit.com/articles/article.aspx?p=27110&seqNum=5

    $r->content_type('text/html');
    my $result;

    eval {
        ($result) = $controller->go(
            headers   => $headers_in,
            method    => $method,
            path_info => $path_info,
            request   => Apache2::Request->new($r),
            uri_for   => \&uri_for,
            static_uri_for => \&static_uri_for,
            manage_uri_for => \&manage_uri_for,
        );
        1;
    } or do {
        my $err = $@;

        $r->content_type('text/plain');
        $r->print("Oops! The server encountered an error:\n\n$err\n\nUse the back button to change stuff and try again.");
        return Apache2::Const::OK;

    };

    if ($result->{action} eq 'redirect') {
        $r->headers_out->set($_ => $result->{headers}{$_}) for keys %{$result->{headers}};
        $r->status(Apache2::Const::REDIRECT);

        return Apache2::Const::OK;
    } elsif ($result->{action} eq 'display') {
        $r->content_type('text/html');
        $r->print($result->{content});
        return Apache2::Const::OK;

    } elsif ($result->{action} eq 'binary-data') {
        # might be better to put all this checking into the controller where
        # we can die on errors
        #  If the byte-range-set is unsatisfiable, the server SHOULD return a
        #  response with a status of 416 (Requested range not satisfiable).
        #  Otherwise, the server SHOULD return a response with a status of 206
        #  (Partial Content) containing the satisfiable ranges of the
        #  entity-body.V
        #  see discussion https://stackoverflow.com/a/18745164/514032
        #  need a "/" with the file size, should return 206 partial content
        #
        # safari's wacky behavior: https://stackoverflow.com/questions/1995589/html5-audio-safari-live-broadcast-vs-not

        my @sendfile_args = ($result->{data_path});
        my $size = $result->{size};

        if (my $range = $r->headers_in->{range}) {

            # they want Range
            if ($range =~ /bytes=([0-9]+)-([0-9]+)?/) {
                my ($start, $end) = ($1, $2);
                $end ||= $size-1;

                if ($start > $end or $end > $size) {
                    # bad Range
                    warn "bad range: $range (size is $size)";
                    $r->headers_out->set('Content-Range' => "bytes 0-");
                    $r->headers_out->set('Content-Length' => $size);

                } else {
                    # Range is ok
                    if ($range eq 'bytes=0-') {
                        # They want it all, but just give them a sample
                        my $dribble = 65536;
                        if ($dribble < $size) {
                            $end = $dribble-1;
                        }
                    }

                    my $content_length = $end + 1 - $start;
                    $r->headers_out->set('Content-Range' => "bytes $start-$end/$size");
                    $r->headers_out->set('Content-Length' => $content_length);
                    push @sendfile_args, $start, $content_length;
                }
            } else {
                warn "bad value for content-range: $range";
                my $end = $size-1;
                $r->headers_out->set('Content-Range' => "bytes 0-$end/$size");
                $r->headers_out->set('Content-Length' => $size);
            }
            $r->status(Apache2::Const::HTTP_PARTIAL_CONTENT);
        } else {
            $r->headers_out->set('Content-Length' => $result->{size});
        }
        $r->content_type($result->{content_type});
        $r->headers_out->set('Accept-Ranges' => 'bytes');
        $r->sendfile(@sendfile_args);
        return Apache2::Const::OK;
    }
}

# TODO need to worry about escaping here
sub uri_for {
    my %p;
    if (ref $_[0] eq 'HASH') { # TT sends a hashref
        %p = %{ $_[0] };
    } else {
        %p = @_;
    }

    my $path        = delete $p{path} || '/';
    my $want_manage = delete $p{want_manage} || '';

    my $base       = $ENV{URI_BASE} or die "URI_BASE is unset in ENV";
    my $manage_key = $ENV{MGMT_URI_KEY} or die "MGMT_URI_KEY is unset in ENV";

    my $url_params = '';
    if (keys %p) {
        $url_params = '?'; # will also be different for mod_perl
        $url_params .= join '&', map { "$_=$p{$_}" } sort keys %p;
    }

    my $manage = $want_manage ? "/manage/$manage_key" : '';

    return "$base$manage$path$url_params";
}

sub manage_uri_for {
    my %p;
    if (ref $_[0] eq 'HASH') { # TT sends a hashref
        %p = %{ $_[0] };
    } else {
        %p = @_;
    }

    return uri_for(%p, want_manage => 1);
}

sub static_uri_for {
    my ($path) = @_;

    my $base = $ENV{STATIC_URI_BASE} or die "STATIC_URI_BASE is unset in ENV";

    return "$ENV{STATIC_URI_BASE}/$path";
}


1;
