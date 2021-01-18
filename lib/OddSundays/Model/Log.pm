package OddSundays::Model::Log;

use strict;
use warnings;

use Carp qw/croak/;
use Data::Dump qw/dump/;
use DBI;
use DBD::SQLite;
use File::Temp qw/tempfile tempdir/;

use OddSundays::Utils qw/get_dbh now_iso8601/;

use Class::Accessor::Lite(
    new => 1,
    rw  => [
    'id',
    'recording_id',
    'user',
    'message',
    'datetime',
    ],
);


sub save {
    my ($self) = @_;

    if ($self->id) {
        croak "can't save log, already saved: ".dump($self);
    }
    if (!$self->recording_id) {
        croak "can't save log, missing recording_id";
    }

    my $sql = <<EOL;
    INSERT INTO log (
        recording_id,
        user,
        message,
        datetime
    )
    VALUES (?,?,?,?);
EOL

    if (! $self->datetime) {
        $self->datetime(now_iso8601());
    }

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute(
        map { $self->$_ }
        qw/ 
            recording_id
            user
            message
            datetime
        /
    );
    $self->id($dbh->sqlite_last_insert_rowid);
}

sub shortdate {
    my ($self) = @_;
    return $self->datetime =~ s/-\d\d\d\d$//r;
}

sub load {
    my ($class, $id) = @_;

    croak "missing id in call to $class->load" unless $id;

    my $sql = 'SELECT * FROM log WHERE id = ?';

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute($id);
    if (my $row = $sth->fetchrow_hashref) {
        return bless $row, $class;
    } else {
        return;
    }
}


sub get_logs_for_recording {
    my ($class, $recording_id) = @_;
    $recording_id or croak "missing recording_id in call to get_logs_for_recording";

    my $sql = <<EOL;
    SELECT * from log 
    WHERE recording_id = ? 
    ORDER BY datetime DESC
EOL

    my @rc;
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute($recording_id);
    while (my $row = $sth->fetchrow_hashref) {
        push @rc, $class->new($row);
    }
    return @rc;
}


sub create_table {
    my ($class) = @_;

    my $sql = <<EOL;
CREATE TABLE log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recording_id INTEGER NOT NULL,
    user VARCHAR(255) NOT NULL, /* length is ignored */
    message VARCHAR(1024),
    datetime TEXT(20) NOT NULL
);
EOL

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute;
}

1;
