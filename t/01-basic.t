# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl kg-OddSundays.t'

#########################

use strict;
use warnings;

use Test::More tests => 11;
use Test::Exception;
use OddSundays::Model::Recording;
use OddSundays::Model::Log;

$ENV{SQLITE_FILE} = 'goctest';
unlink $ENV{SQLITE_FILE};
$ENV{UPLOAD_DIR} ='t/upload_dir';
mkdir $ENV{UPLOAD_DIR};

OddSundays::Model::Recording->create_table;
OddSundays::Model::Log->create_table;

test_recording_CRUD();
test_log_CRUD();

sub test_recording_CRUD {
    my $rec = OddSundays::Model::Recording->new(
        sha256 => 'fdd208e2ba23e3334c1c1115c4aff566f18b5ab28e7d4dc44dd63920e548e770',
        title => 'some test recording',
    );

    $rec->save;
    is $rec->id, 1;

    $rec = OddSundays::Model::Recording->load(1);
    is $rec->title, 'some test recording';

    $rec->title('changed title');
    $rec->save;

    $rec = OddSundays::Model::Recording->load(1);
    is $rec->title, 'changed title';

    $rec->title('The End');
    is $rec->title_for_sort, 'end', 'title_for_sort ok';
}

sub test_log_CRUD {
    my $log = OddSundays::Model::Log->new(
        user => 'alice',
        message => 'some log message',
    );

    throws_ok {
        $log->save;
    } qr/missing recording_id/;

    $log->recording_id(123);
    $log->save;
    is $log->id, 1;

    $log = OddSundays::Model::Log->load(1);
    is $log->user, 'alice';
    is $log->recording_id, 123;
    is $log->message, 'some log message';
    like $log->datetime, qr/^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d-\d\d\d\d$/;

    OddSundays::Model::Log->new(
        user => 'bob',
        recording_id => 123,
        message => 'a message from bob',
    )->save;

    OddSundays::Model::Log->new(
        user => 'chuck',
        recording_id => 987,
        message => 'some other recording',
    )->save;

    my @logs = OddSundays::Model::Log->get_logs_for_recording(123);
    is @logs, 2;

    # not sure the sort is going to work this close together,
    # so skipping testing it

}
