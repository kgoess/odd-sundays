package kg::OddSaturdays::Controller;

use strict;
use warnings;

use Carp qw/croak/;
use CGI::Cookie;
use Data::Dump qw/dump/;
use Digest::SHA qw/sha256_hex/;

#use kg::OddSaturdays::Logger;
#use kg::OddSaturdays::Model::Event;
#use kg::OddSaturdays::Model::Person;
#use kg::OddSaturdays::Model::PersonEventMap;
use kg::OddSaturdays::Model::Recording;
use kg::OddSaturdays::Utils qw/today_ymdhms/;

my %handler_for_path = (
    ''                    => sub { shift->main_page(@_) },
    '/'                   => sub { shift->main_page(@_) },
    '/upload-recording'   => sub { shift->upload_recording(@_) },
    '/download-recording' => sub { shift->download_recording(@_) },
);

sub go {
    my ($class, %p) = @_;

    if (my $handler = $handler_for_path{ $p{path_info} }) {
        return $handler->($class, %p),
    } else {
        die "missing handler for '$p{path_info}'";
    }
}

# when either kg::OddSaturdays::Controller::ModPerl or Goc::Controller::CGI loads
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

    return {
        action => "display",
        content => kg::OddSaturdays::View->main_page(
            message => scalar($p{request}->param('message')),
        ),
    }
}

sub upload_recording {
     my ($class, %p) = @_;

     if ($p{method} eq 'GET') {
        return {
            action => "display",
            content => kg::OddSaturdays::View->upload_recording(
                message => scalar($p{request}->param('message')),
            ),
        }
    } elsif ($p{method} eq 'POST') {
        # https://perl.apache.org/docs/1.0/guide/snippets.html#File_Upload_with_Apache__Request
        my $upload = $p{request}->upload("recording")
            or die "missing upload";

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

        my $upload_dir = '/var/lib/odd-saturdays/uploads';
        my $fh;
        open $fh, ">", "$upload_dir/$sha256.mp3"
            or die "can't write to $upload_dir/$sha256.mp3 $!";
        print $fh $contents;
        close $fh or die "can't close $upload_dir/$sha256.mp3 $!";

        open $fh, ">", "$upload_dir/$sha256.txt"
            or die "can't write to $upload_dir/$sha256.txt $!";
        my $date = scalar localtime;

        my $name        = scalar($p{request}->param('name'));
        my $description = scalar($p{request}->param('description'));
        my $filename_for_download = scalar($p{request}->param('filename_for_download'));
        $filename_for_download ||= $name;
        $filename_for_download =~ s/[^\w.-]//g;

        my $fill_in = sub {
            my $recording = shift;
            $recording->title($name);
            $recording->orig_filename($filename);
            $recording->filename_for_download($filename_for_download);
            $recording->size($size);
            $recording->content_type($content_type);
            $recording->description($description);
        };

        if (my $recording = kg::OddSaturdays::Model::Recording->load($sha256)) {
            $fill_in->($recording);
            $recording->date_updated(today_ymdhms());
            $recording->update;
        } else {
            my $recording = kg::OddSaturdays::Model::Recording->new();
            $fill_in->($recording);
            $recording->id($sha256);
            $recording->save;
        }


        return {
            action => 'redirect',
            headers => {
                Location  => uri_for(
                    path        => "/upload-recording",
                    message     => qq{Upload of $filename complete},
                ),
            },
        };

    } else {
        die "unrecognized method $p{method} in call to login_page";
    }
}

sub download_recording {
    my ($class, %p) = @_;

    my $id = scalar($p{request}->param('id'))
          or die "missing recording id";

    my $recording = kg::OddSaturdays::Model::Recording->load($id)
        or die "can't find recording for id $id";

    return {
        action => 'binary-data',
        content_type => 'audio/mpeg',
        #content_length => ?? needed?
        data_path => $recording->file_path,
        size => $recording->size,
    };
}



#sub login_page {
#    my ($class, %p) = @_;
#
#    if ($p{method} eq 'GET') {
#        return {
#            action => 'display',
#            content => kg::OddSaturdays::View->login_page(
#                request      => $p{request},
#            ),
#        }
#
#    } elsif ($p{method} eq 'POST') {
#        my $id = scalar($p{request}->param('login_id'))
#            or die "missing login_id";
#
#        my $person = kg::OddSaturdays::Model::Person->load($id)
#            or die "no user found for id $id";;
#
#         my $cookie = CGI::Cookie->new(
#            -name  => 'Berkmo-GoC',
#            -value => "user_id:$id",
#            -expires => '+3M',
#         );
#
#        kg::OddSaturdays::Logger->new(current_user => $person)->debug("logged in");
#        return {
#            action => 'redirect',
#            headers => {
#                Location  => uri_for(path => "/"),
#            },
#            cookie => $cookie,
#        };
#    } else {
#        die "unrecognized method $p{method} in call to login_page";
#    }
#
#}
#
#sub change_status {
#    my ($class, %p) = @_;
#
#    my $person_id = scalar($p{request}->param('person_id'))
#        or die "missing person_id";
#
#    my $person = kg::OddSaturdays::Model::Person->load($person_id)
#        or die "no user found for id $person_id";
#
#    my $event_id = scalar($p{request}->param('event_id'))
#        or die "missing event_id";
#
#    my $event = kg::OddSaturdays::Model::Event->load($event_id)
#        or die "no event found for id $event_id";
#
#    my $for_role = scalar($p{request}->param('for_role'))
#        or die "missing for_role";
#
#    $for_role =~ /^(?:muso|dancer)$/
#        or die "wrong value for role: $for_role";
#
#    my $status = scalar($p{request}->param('status'))
#        or die "missing status";
#
#    $status =~ /^[yn?]$/
#        or die "wrong value for status: $status";
#
#    my $current_tab = scalar($p{request}->param('current_tab')) // '';
#    $current_tab =~ s/[^a-z0-9-]//g;
#
#    kg::OddSaturdays::Model::PersonEventMap->delete_person_from_event($person, $event);
#    kg::OddSaturdays::Model::PersonEventMap->add_person_to_event($person, $event, $for_role, $status);
#
#    my $person_log_str = join '', $person->name, '[', $person->id, ']';
#    my $event_log_str  = join '', $event->name,  '[', $event->id, ']';
#    $p{logger}->info("status change $person_log_str for event $event_log_str for role $for_role to status $status");
#
#    return {
#        action => 'redirect',
#        headers => {
#            Location  => uri_for(
#                path        => "/event",
#                id          => $event_id,
#                current_tab => $current_tab,
#                message     => qq{Your status for this event has been updated to "$for_role: $status"},
#            ),
#        },
#    };
#
#
#}
#
#sub logout {
#    my ($class, %p) = @_;
#     my $cookie = CGI::Cookie->new(
#        -name  => 'Berkmo-GoC',
#        -expires => '-1y',
#        -value => 'whatever',
#     );
#    $p{logger}->debug("logged out") ;
#    return {
#        action => 'redirect',
#        headers => {
#            Location => uri_for(path => '/'),
#        },
#        cookie => $cookie,
#    };
#}
#
#sub main_page {
#    my ($class, %p) = @_;
#    return {
#        action => "display",
#        content => kg::OddSaturdays::View->main_page(
#            current_user => $p{current_user},
#            message => scalar($p{request}->param('message')),
#        ),
#    }
#}
#
#sub event_page {
#    my ($class, %p) = @_;
#
#    my $show_prev_next = scalar($p{request}->param('show_prev_next')) // 1;
#
#    return {
#        action => "display",
#        content => kg::OddSaturdays::View->event_page(
#            event_id => scalar($p{request}->param('id')), # an Apache2::Request object
#            current_user => $p{current_user},
#            message => scalar($p{request}->param('message')),
#            current_tab => scalar($p{request}->param('current_tab')),
#            show_prev_next => $show_prev_next,
#        ),
#    }
#}
#
#sub activity_logs {
#    my ($class, %p) = @_;
#    return {
#        action => "display",
#        content => kg::OddSaturdays::View->activity_logs(
#            current_user => $p{current_user},
#        ),
#    }
#}
#
#{
#package EmptyRequest;
#    sub new { return bless {} };
#    sub param {};
#}
#
#sub create_event {
#    my ($class, %p) = @_;
#    if ($p{method} eq 'GET') {
#        return {
#            action => 'display',
#            content => kg::OddSaturdays::View->create_event_page(
#                current_user => $p{current_user},
#                request => EmptyRequest->new(),
#            ),
#        }
#
#    } elsif ($p{method} eq 'POST') {
#
#        my @errors;
#        foreach my $f (qw/event-name event-date event-type/) {
#            if (! scalar($p{request}->param($f))) {
#                push @errors, "missing data for $f";
#            }
#        }
#        foreach my $f (qw/num-dancers-required num-musos-required/) {
#            my $val = scalar($p{request}->param($f)) // next;
#            if ($val =~ /\D/) {
#                push @errors, "invalid data for $f";
#            } elsif ($val < 0 || $val > 99) {
#                push @errors, "value for $f out of range";
#            }
#        }
#        my $event_date = scalar($p{request}->param('event-date')) // '';
#        if ($event_date !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
#                push @errors, "wrong format for event-date, should be yyyy-mm-dd, not '$event_date'";
#        }
#        if (my $email = scalar($p{request}->param('event-notification-email'))) {
#            if ($email !~ /^[^@]+@[^@]+\.[a-zA-Z]+$/) {
#                push @errors, "that doesn't look like an email to me";
#            }
#        }
#        if (@errors) {
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->create_event_page(
#                    current_user => $p{current_user},
#                    errors       => \@errors,
#                    request      => $p{request},
#                ),
#            }
#        }
#
#        my $r = $p{request};
#        my $event = kg::OddSaturdays::Model::Event->new(
#            name => scalar($r->param('event-name')),
#            date => scalar($r->param('event-date')),
#            queen => scalar($r->param('event-queen')),
#            notification_email => scalar($r->param('event-notification-email')),
#            type => scalar($r->param('event-type')),
#            notes => scalar($r->param('event-notes')),
#            num_dancers_required => scalar($r->param('num-dancers-required')),
#            num_musos_required => scalar($r->param('num-musos-required')),
#        );
#        $event->save;
#
#        my $user = $p{current_user};
#        my $person_log_str = join '', $user->name, '[', $user->id, ']';
#        my $event_log_str  = join '', $event->name,  '[', $event->id, ']';
#        $p{logger}->info("created event $event_log_str by $person_log_str");
#
#        my $msg = uri_escape("Event successfully created");
#        return {
#            action => 'redirect',
#            headers => {
#                Location => uri_for( path => '/event', id => $event->id, message => $msg),
#            },
#        };
#    }
#}
#
#sub edit_event {
#    my ($class, %p) = @_;
#    if ($p{method} eq 'GET') {
#        return {
#            action => 'display',
#            content => kg::OddSaturdays::View->edit_event_page(
#                current_user => $p{current_user},
#                event_id => scalar($p{request}->param('event-id')),
#                request => EmptyRequest->new(),
#            ),
#        }
#
#    } elsif ($p{method} eq 'POST') {
#
#        croak "missing event-id in POST to edit_event"
#            unless scalar($p{request}->param('event-id'));
#
#        my @errors;
#        foreach my $f (qw/event-name event-date event-type/) {
#            if (! scalar($p{request}->param($f))) {
#                push @errors, "missing data for $f";
#            }
#        }
#        foreach my $f (qw/num-dancers-required num-musos-required/) {
#            my $val = scalar($p{request}->param($f)) // next;
#            if ($val =~ /\D/) {
#                push @errors, "invalid data for $f";
#            } elsif ($val < 0 || $val > 99) {
#                push @errors, "value for $f out of range";
#            }
#        }
#        if (scalar($p{request}->param('event-date'))  !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
#                push @errors, "wrong format for event-date, should be yyyy-mm-dd";
#        }
#        if (my $email = scalar($p{request}->param('event-notification-email'))) {
#            if ($email !~ /^[^@]+@[^@]+$/) {
#                push @errors, "that doesn't look like an email to me";
#            }
#        }
#        if (@errors) {
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->edit_event_page(
#                    current_user => $p{current_user},
#                    event_id     => scalar($p{request}->param('event-id')),
#                    errors       => \@errors,
#                    request      => $p{request},
#                ),
#            }
#        }
#
#        my $r = $p{request};
#        my $event_id = scalar($p{request}->param('event-id'));
#        my $event = kg::OddSaturdays::Model::Event->load($event_id)
#            or croak "no event found for id $event_id";
#        my $orig = $event->clone();
#        $event->name(scalar($r->param('event-name')));
#        $event->date(scalar($r->param('event-date')));
#        $event->queen(scalar($r->param('event-queen')));
#        $event->notification_email(scalar($r->param('event-notification-email')));
#        $event->type(scalar($r->param('event-type')));
#        $event->notes(scalar($r->param('event-notes')));
#        $event->num_dancers_required(scalar($r->param('num-dancers-required')));
#        $event->num_musos_required(scalar($r->param('num-musos-required')));
#        $event->update;
#
#        my @delta_log_str;
#        foreach my $f (qw/name date queen notification_email type num_dancers_required num_musos_required/) {
#            no warnings 'uninitialized';
#            if ($orig->$f ne $event->$f) {
#                push @delta_log_str, "$f to '".$event->$f."'";
#            }
#        }
#        if ($orig->notes ne $event->notes) {
#             push @delta_log_str, "made edits to the notes";
#        }
#        my $delta_log_str = join ', ', @delta_log_str;
#        $delta_log_str ||= 'nothing';
#
#
#        my $person_log_str = join '', $p{current_user}->name, '[', $p{current_user}->id, ']';
#        my $event_log_str  = join '', $event->name,  '[', $event->id, ']';
#        $p{logger}->info($event->type." event edited: $event_log_str by $person_log_str changing $delta_log_str");
#
#        my $msg = uri_escape('Event "'.$event->name.'" successfully edited');
#        return {
#            action => 'redirect',
#            headers => {
#                Location => uri_for( path => '/event', id => $event_id, message => $msg),
#            },
#        };
#    }
#}
#sub delete_event {
#    my ($class, %p) = @_;
#    if ($p{method} eq 'GET') {
#        return {
#            action => 'redirect',
#            headers => {
#                Location => uri_for(
#                    path => '/',
#                    message => 'GET not supported for /delete-event',
#                ),
#            },
#        };
#
#    } elsif ($p{method} eq 'POST') {
#
#        my @errors;
#
#        my $event_id = scalar($p{request}->param('event-id'))
#            or croak "missing event-id param for /delete-event";
#
#        my $r = $p{request};
#        my $event = kg::OddSaturdays::Model::Event->load($event_id)
#            or croak "no event found for id $event_id";
#        $event->deleted(1);
#        $event->update;
#
#        my $person_log_str = join '', $p{current_user}->name, '[', $p{current_user}->id, ']';
#        my $event_log_str  = join '', $event->name,  '[', $event->id, ']';
#        $p{logger}->info($event->type." event marked deleted: $event_log_str by $person_log_str");
#
#        my $msg = uri_escape('Event "'.$event->name.'" has been marked as deleted');
#        return {
#            action => 'redirect',
#            headers => {
#                Location => uri_for( path => '/', message => $msg),
#            },
#        };
#    }
#}
#sub create_person {
#    my ($class, %p) = @_;
#    if ($p{method} eq 'GET') {
#        return {
#            action => 'display',
#            content => kg::OddSaturdays::View->create_person_page(
#                current_user => $p{current_user},
#                request => EmptyRequest->new(),
#                action => 'create',
#            ),
#        }
#
#    } elsif ($p{method} eq 'POST') {
#
#        my @errors;
#        if (! scalar($p{request}->param('person-name'))) {
#                push @errors, "I need a name for the person";
#        }
#        if (@errors) {
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->create_person_page(
#                    current_user => $p{current_user},
#                    errors       => \@errors,
#                    request      => $p{request},
#                    action => 'create',
#                ),
#            }
#        }
#
#        my $r = $p{request};
#        my $person = kg::OddSaturdays::Model::Person->new(
#            name  => scalar($r->param('person-name')),
#            status  => scalar($r->param('person-status')),
#        );
#        $person->save;
#        my $person_log_str = join '', $person->name, '[', $person->id, ']';
#        my $user_log_str = join '', $p{current_user}->name, '[', $p{current_user}->id, ']';
#        $p{logger}->info("New user $person_log_str created by $user_log_str");
#
#        my $msg = uri_escape("Person successfully created");
#        return {
#            action => 'redirect',
#            headers => {
#                Location => uri_for(path => '/', message => $msg),
#            },
#        };
#    }
#}
#
#sub edit_person {
#    my ($class, %p) = @_;
#    if ($p{method} eq 'GET') {
#        if (my $person_id = $p{request}->param('person-id')) {
#            my $person = kg::OddSaturdays::Model::Person->load($person_id)
#                or die "can't find person for id $person_id";
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->create_person_page(
#                    current_user => $p{current_user},
#                    person =>  $person,
#                    action => 'edit',
#                ),
#            }
#        } else {
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->pick_person_to_edit_page (
#                    current_user => $p{current_user},
#                    request => $p{request},
#                ),
#            }
#        }
#
#    } elsif ($p{method} eq 'POST') {
#        my $person_id = $p{request}->param('person-id')
#            or die "missing person_id in POST to edit_person";
#        my $person = kg::OddSaturdays::Model::Person->load($person_id)
#            or die "can't find person for id $person_id";
#
#        my $orig = $person->clone;
#
#        my @errors;
#        if (! $p{request}->param('person-name')) {
#            push @errors, "You can't change the person's name to a blank.";
#        }
#        if (@errors) {
#            return {
#                action => 'display',
#                content => kg::OddSaturdays::View->create_person_page(
#                    current_user => $p{current_user},
#                    errors       => \@errors,
#                    request      => $p{request},
#                    person       => $person,
#                    action       => 'edit',
#                ),
#            }
#        }
#
#        $person->name(scalar($p{request}->param('person-name')));
#        $person->status(scalar($p{request}->param('person-status')));
#        $person->update;
#
#        my @delta_log_str;
#        foreach my $f (qw/name status/) {
#            no warnings 'uninitialized';
#            if ($orig->$f ne $person->$f) {
#                push @delta_log_str, "$f to '".$person->$f."'";
#            }
#        }
#        my $delta_log_str = join ', ', @delta_log_str;
#        $delta_log_str ||= 'nothing';
#
#        my $person_log_str = join '', $person->name, '[', $person->id, ']';
#        my $user_log_str = join '', $p{current_user}->name, '[', $p{current_user}->id, ']';
#        $p{logger}->info("User $person_log_str edited by $user_log_str, changing $delta_log_str");
#
#        my $msg = uri_escape('Person "'.$person->name.'" has been updated');
#        return {
#            action => 'redirect',
#            headers => {
#                Location  => uri_for(path => "/", message => $msg),
#            },
#        };
#    }
#}
#sub old_grid {
#    my ($class, %p) = @_;
#    return {
#        action => 'display',
#        content => kg::OddSaturdays::View->old_grid(
#            current_user => $p{current_user},
#        ),
#    }
#}
#
#sub past_events {
#    my ($class, %p) = @_;
#    return {
#        action => 'display',
#        content => kg::OddSaturdays::View->past_events(
#            current_user => $p{current_user},
#        ),
#    }
#}

1;
