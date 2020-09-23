package kg::OddSaturdays::Model::Recording;

use strict;
use warnings;

use Carp qw/croak/;
use DBI;
use DBD::SQLite;
use File::Temp qw/tempfile tempdir/;

use kg::OddSaturdays::Utils qw/get_dbh today_ymd/;

use Class::Accessor::Lite(
    new => 1,
    rw  => [
    'id',
    'title',
    'orig_filename',
    'filename_for_download',
    'size',
    'content_type',
    'description',
    'album',
    'track_num',
    'track_of',
    'key',
    'tune_name',
    'tune_composer',
    'tune_composed_year',
    'dance_name',
    'dance_composer',
    'dance_composed_year',
    'deleted',
    'date_created',
    'date_updated',
    ],
);

my $Upload_Dir = $ENV{UPLOAD_DIR} or die "missing UPLOAD_DIR in env";

sub save {
    my ($self) = @_;

    my $sql = <<EOL;
    INSERT INTO recording (
        id,
        title,
        orig_filename,
        filename_for_download,
        size,
        content_type,
        description,
        album,
        track_num,
        track_of,
        key,
        tune_name,
        tune_composer,
        tune_composed_year,
        dance_name,
        dance_composer,
        dance_composed_year,
        deleted,
        date_created,
        date_updated
    )
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
EOL

    if (! $self->date_created) {
        $self->date_created(today_ymd());
    }
    if (! $self->date_updated) {
        $self->date_updated(today_ymd());
    }
    if (! defined $self->deleted) {
        $self->deleted(0)
    }

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute(
        map { $self->$_ }
        qw/ id
            title
            orig_filename
            filename_for_download
            size
            content_type
            description
            album
            track_num
            track_of
            key
            tune_name
            tune_composer
            tune_composed_year
            dance_name
            dance_composer
            dance_composed_year
            deleted
            date_created
            date_updated
        /
    );
}

sub date_pretty {
    my ($self) = @_;
    my ($year, $month, $day) = $self->date =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;

    return date_format_pretty($year, $month, $day);
}


sub load {
    my ($class, $id, %p) = @_;

    croak "missing id in call to $class->load" unless $id;

    my $sql = 'SELECT * FROM recording WHERE id = ?';

    if ($p{include_deleted}) {
        $sql .= ' AND deleted = 1 ';
    } else {
        $sql .= ' AND deleted = 0 ';
    }

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute($id);
    if (my $row = $sth->fetchrow_hashref) {
        return bless $row, $class;
    } else {
        return;
    }
}

sub update {
    my ($self) = @_;

    my $sql = <<EOL;
        UPDATE recording SET
            id = ?,
            title = ?,
            orig_filename = ?,
            filename_for_download = ?,
            size = ?,
            content_type = ?,
            description = ?,
            album = ?,
            track_num = ?,
            track_of = ?,
            key = ?,
            tune_name = ?,
            tune_composer = ?,
            tune_composed_year = ?,
            dance_name = ?,
            dance_composer = ?,
            dance_composed_year = ?,
            deleted = ?,
            date_updated = ?
            /* date_created not updatable */
        WHERE id = ?
EOL

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $self->date_updated(today_ymd());
    $sth->execute(
        map { $self->$_ }
        qw/ id
            title
            orig_filename
            filename_for_download
            size
            content_type
            description
            album
            track_num
            track_of
            key
            tune_name
            tune_composer
            tune_composed_year
            dance_name
            dance_composer
            dance_composed_year
            deleted
            date_updated
            id
        /
    );
}

sub get_all {
    my ($class, %p) = @_;

    my $sql = <<EOL;
    SELECT * from recording
EOL

    if ($p{include_deleted}) {
        $sql .= ' WHERE deleted = 1 ';
    } else {
        $sql .= ' WHERE deleted = 0 ';
    }

    my @rc;
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
        push @rc, $class->new($row);
    }
    return \@rc;
}

sub file_path {
    my ($self) = @_;
    my $id = $self->id;

    return "$Upload_Dir/$id.mp3";
}

sub upload_dir {
    return $Upload_Dir;
}

#sub get_past_events {
#    my ($class, %p) = @_;
#
#    #my $type = $p{type} || croak "missing event type in call to $class->get_past_events";
#
#    my $tomorrow = tomorrow_ymd();
#
#    my $sql = <<EOL;
#    SELECT * FROM event
#    WHERE date <= '$tomorrow'
#    --AND type = ?
#    AND deleted != 1
#    ORDER BY date DESC, name ASC
#    LIMIT ?
#EOL
#    my $limit = $p{limit} || 50;
#    my $dbh = get_dbh();
#    my $sth = $dbh->prepare($sql);
#    $sth->execute($limit);
#    my @rc;
#    while (my $row = $sth->fetchrow_hashref) {
#        push @rc, kg::OddSaturdays::Model::Event->new($row);
#    }
#    return \@rc;
#}
#
sub create_table {
    my ($class) = @_;

    my $sql = <<EOL;
CREATE TABLE recording (
    id VARCHAR(64) PRIMARY KEY NOT NULL,
    title VARCHAR(255) NOT NULL, /* length is ignored */
    orig_filename VARCHAR(255),
    filename_for_download VARCHAR(255),
    size INT(255) default 0,
    content_type VARCHAR(255),
    description VARCHAR(4096),
    album VARCHAR(255),
    track_num VARCHAR(255),
    track_of VARCHAR(255),
    key VARCHAR(16),
    tune_name VARCHAR(255),
    tune_composer VARCHAR(255),
    tune_composed_year INT default 0,
    dance_name VARCHAR(255),
    dance_composer VARCHAR(255),
    dance_composed_year INT default 0,
    deleted BOOLEAN NOT NULL DEFAULT 0,
    date_created TEXT(20) NOT NULL,
    date_updated TEXT(20) NOT NULL
);
EOL

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute;
}

1;
__DATA__
