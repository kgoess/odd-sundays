package OddSundays::Controller;

use strict;
use feature 'state';
use warnings;

use Carp qw/croak/;
use CGI::Cookie;
use Data::Dump qw/dump/;
use Digest::SHA qw/sha256_hex/;
use Storable qw/dclone/;
use Text::Wrap;

use OddSundays::Model::Recording;
use OddSundays::Model::Log;
use OddSundays::Utils qw/today_ymdhms/;

my $TEST_MGMT_URI_KEY;
# when either OddSundays::Controller::ModPerl or Goc::Controller::CGI loads
# this module, Perl calls this import() function and we set the location
# of the uri_for implementation
sub import {
    my ($class, %args) = @_;

    if (my $key = $args{MGMT_URI_KEY}) {
        $TEST_MGMT_URI_KEY = $key;
    }

    if (my $location = $args{controller_class}) {

        no warnings 'redefine';
    #    my $uri_for_implementation = join '::', $location, 'uri_for';
    #    *uri_for = \&{$uri_for_implementation};
    #
    #    my $static_uri_for_implementation = join '::', $location, 'static_uri_for';
    #    *static_uri_for = \&{$static_uri_for_implementation};
    #
    #    my $manage_uri_for_implementation = join '::', $location, 'manage_uri_for';
    #    *manage_uri_for = \&{$manage_uri_for_implementation};
    }
}

sub get_handler_for_path {
    my ($path) = @_;

    state $manage_key = $ENV{MGMT_URI_KEY} || $TEST_MGMT_URI_KEY or die "MGMT_URI_KEY is unset in ENV";
    state $manage = "/manage/$manage_key";

    state $handler_for_path = {
        ''                         => sub { shift->main_page(@_) },
        '/'                        => sub { shift->main_page(@_) },
        '/download-recording'      => sub { shift->download_recording(@_) },
        "/show-dance-instructions" => sub { shift->show_dance_instructions(@_) },
        "$manage/upload-recording" => sub { shift->upload_recording(@_) },
        "$manage/edit-recording"   => sub { shift->edit_recording(@_) },
        "$manage/"                 => sub { shift->list_recordings_for_edit(@_) },
        "$manage/list-recordings"  => sub { shift->list_recordings_for_edit(@_) },
        "$manage/add-log"          => sub { shift->add_log(@_) },
    };

    return $handler_for_path->{$path};
}

sub go {
    my ($class, %p) = @_;

    if (my $handler = get_handler_for_path( $p{path_info} )) {
        return $handler->($class, %p),
    } else {
        die "missing handler for '$p{path_info}'";
    }
}

sub main_page {
    my ($class, %p) = @_;

    return {
        action => "display",
        content => OddSundays::View->list_recordings(
            message => scalar($p{request}->param('message')),
        ),
    }
}

sub upload_recording {
     my ($class, %p) = @_;

     if ($p{method} eq 'GET') {
        return {
            action => "display",
            content => OddSundays::View->upload_recording(
                message => scalar($p{request}->param('message')),
            ),
        }
    } elsif ($p{method} eq 'POST') {

        my $upload = $p{request}->upload("recording")
            or die "missing upload";

        my $upload_info = handle_upload($upload);

        my $title       = scalar($p{request}->param('title'));

        my $filename_for_download = 
            scalar($p{request}->param('filename_for_download'));
        $filename_for_download ||= $title;
        $filename_for_download =~ s/[^\w.-]//g;

        if (my $recording = OddSundays::Model::Recording
                                ->load_by_sha256($upload_info->{sha256})
        ) {
            die "that file already uploaded for ".$recording->title."[".$recording->id."]";
        }

        my $recording = OddSundays::Model::Recording->new();
        $recording->title($title);
        $recording->sha256       ($upload_info->{sha256});
        $recording->size         ($upload_info->{size});
        $recording->content_type ($upload_info->{content_type});
        $recording->orig_filename($upload_info->{filename});

        $recording->filename_for_download($filename_for_download);
        $recording->description(wrap_text(scalar($p{request}->param('description'))));
        foreach my $f (qw/
            album
            track_num
            track_of
            key
            tune_name
            tune_composer
            tune_composed_year
            tune_found_in
            tune_times_through
            tune_played_structure
            tune_copyright_notes
            dance_name
            dance_composer
            dance_composed_year
            dance_found_in
            dance_instructions
            /
        ) {
            $recording->$f( scalar($p{request}->param($f)) );
        }
        my $deleted = scalar($p{request}->param('deleted'));
        if ($deleted eq 'on') {
            $recording->deleted(1);
        } else {
            $recording->deleted(0);
        }

        $recording->save;

        OddSundays::Model::Log->new(
            recording_id => $recording->id,
            user => 'auto',
            message => 'recording uploaded from '.$upload_info->{filename},
        )->save;

        return {
            action => 'redirect',
            headers => {
                # maybe redirect to edit recording?
                Location  => $p{manage_uri_for}->(
                    path        => "/list-recordings",
                    message     => qq{Upload of $upload_info->{filename} complete},
                ),
            },
        };

    } else {
        die "unrecognized method $p{method} in call to upload_recording";
    }
}

sub handle_upload {
    my ($upload) = @_;

    # https://perl.apache.org/docs/1.0/guide/snippets.html#File_Upload_with_Apache__Request

    my $filename = $upload->filename;
    my $size = $upload->size;
    die "upload size $size is too big"
        if $size > 50_000_000;
    my $info = $upload->info;
    #while (my($hdr_name, $hdr_value) = each %$info) {
    #    # ...
    #}
    my $content_type = $upload->info->{"Content-type"};

    # there's other ways to do this besides slurp
    my $contents;
    my $slurp_size = $upload->slurp($contents);

    die "size mismatch $size != $slurp_size" if $size != $slurp_size;

    my $sha256 = sha256_hex($contents);

    my $upload_dir = $ENV{UPLOAD_DIR}
        or die "upload_dir not set in environment";
    my $fh;
    open $fh, ">", "$upload_dir/$sha256.mp3"
        or die "can't write to $upload_dir/$sha256.mp3 $!";
    print $fh $contents;
    close $fh or die "can't close $upload_dir/$sha256.mp3 $!";

    return {
        filename     => $filename,
        size         => $size,
        content_type => $content_type,
        sha256       => $sha256,
    }
}

sub list_recordings_for_edit {
    my ($class, %p) = @_;

    return {
        action => "display",
        content => OddSundays::View->list_recordings(
            message => scalar($p{request}->param('message')),
            is_mgmt => 1,
        ),
    }
}

sub edit_recording {
    my ($class, %p) = @_;

     if ($p{method} eq 'GET') {
        my $id = scalar($p{request}->param('id'))
            or die "missing param 'id' in edit_recording";
        my $recording = OddSundays::Model::Recording->load($id, include_deleted => 1)
            or die "no recording found for id '$id'";
        return {
            action => "display",
            content => OddSundays::View->edit_recording(
                message => scalar($p{request}->param('message')),
                recording => $recording,
            ),
        }

    } elsif ($p{method} eq 'POST') {

        my $id = scalar($p{request}->param('id'))
            or die "missing param 'id' in edit_recording";

        my $recording = OddSundays::Model::Recording->load($id, include_deleted => 1)
            or die "no recording found for id '$id'";

        my $orig = dclone($recording);

        my @log_msg;

        if (my $upload = $p{request}->upload("recording")) {
            my $upload_info = handle_upload($upload);
            $recording->sha256       ($upload_info->{sha256});
            $recording->size         ($upload_info->{size});
            $recording->content_type ($upload_info->{content_type});
            $recording->orig_filename($upload_info->{filename});
            push @log_msg, "upload from $upload_info->{filename}";
        }

        $recording->description(wrap_text(scalar($p{request}->param('description'))));

        if ($recording->description ne $orig->description) {
            push @log_msg, 'description changed';
        }

        foreach my $f (qw/
            title
            filename_for_download
            album
            track_num
            track_of
            key
            tune_name
            tune_composer
            tune_composed_year
            tune_found_in
            tune_times_through
            tune_played_structure
            tune_copyright_notes
            dance_name
            dance_composer
            dance_composed_year
            dance_found_in
            dance_instructions
            /
        ) {
            $recording->$f( scalar($p{request}->param($f)) );
            if ($recording->$f ne $orig->$f) {
                push @log_msg, "$f changed to ".$recording->$f;
            }
        }
        my $deleted = scalar($p{request}->param('deleted'));
        if (($deleted//'') eq 'on') {
            $recording->deleted(1);
        } else {
            $recording->deleted(0);
        }
        if ($recording->deleted ne $orig->deleted) {
            push @log_msg, 'deleted set to '. $recording->deleted;
        }

        $recording->save;

        OddSundays::Model::Log->new(
            recording_id => $recording->id,
            user => 'auto',
            message => join(', ', @log_msg),
        )->save;

        return {
            action => 'redirect',
            headers => {
                # maybe redirect to edit recording?
                Location  => $p{manage_uri_for}->(
                    path        => "/list-recordings",
                    message     => "Your edits to '".$recording->title."' have been saved.",
                ),
            },
        };

    } else {
        die "unrecognized method $p{method} in call to edit_recording";
    }
}

sub wrap_text {
    my $s = shift;

   $Text::Wrap::columns = 50;

    my @lines = split /\r?\n/, $s;
    foreach (@lines) {
        next unless length > 50;
        $_ = wrap('', '', $_);
    }
    dump \@lines;
    return join "\n", @lines;
}

sub download_recording {
    my ($class, %p) = @_;

    my $sha256 = scalar($p{request}->param('sha256'))
          or die "missing recording sha256";

    my $recording = OddSundays::Model::Recording->load_by_sha256($sha256)
        or die "can't find recording for sha256 $sha256";

    return {
        action => 'binary-data',
        content_type => 'audio/mpeg',
        #content_length => ?? needed?
        data_path => $recording->file_path,
        size => $recording->size,
    };
}

sub show_dance_instructions {
    my ($class, %p) = @_;

    my $id = scalar($p{request}->param('id'))
          or die "missing id";

    my $recording = OddSundays::Model::Recording->load($id)
        or die "can't find recording for id '$id'";

    return {
        action => "display",
        content => OddSundays::View->show_dance_instructions(
            message => scalar($p{request}->param('message')),
            recording => $recording,
        ),
    }
}

sub add_log {
    my ($class, %p) = @_;

    if ($p{method} eq 'GET') {
        die "this endpoint doesn't do GET's, what are you on about?";

    } elsif ($p{method} eq 'POST') {

        my $user         = scalar($p{request}->param('user'));
        my $message      = scalar($p{request}->param('message'));
        my $recording_id = scalar($p{request}->param('recording-id'));

        $user && $message && length($recording_id) > 0 || die "missing params";

        my $rec = OddSundays::Model::Recording->load($recording_id, include_deleted => 1)
            or die "no recording found for id $recording_id";

        my $log = OddSundays::Model::Log->new(
            user => $user,
            message => $message,
            recording_id => $recording_id,
        );
        $log->save;
        return {
            action => 'redirect',
            headers => {
                Location  => $p{manage_uri_for}->(
                    path    => "/edit-recording",
                    message => "Your log message has been recorded.",
                    id      => $recording_id,
                ),
            },
        };
    }
}

1;
