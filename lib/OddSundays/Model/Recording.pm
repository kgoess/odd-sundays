package OddSundays::Model::Recording;

use strict;
use warnings;

use Carp qw/croak/;
use DBI;
use DBD::SQLite;
use File::Temp qw/tempfile tempdir/;

use OddSundays::Utils qw/get_dbh today_ymd/;

use Class::Accessor::Lite(
    new => 1,
    rw  => [
    'id',
    'sha256',
    'title',
    'orig_filename',
    'filename_for_download',
    'size',
    'content_type',
    'description',
    'ok_to_publish',
    'album',
    'track_num',
    'track_of',
    'key',
    'tune_name',
    'tune_composer',
    'tune_composed_year',
    'tune_found_in',
    'tune_times_through',
    'tune_played_structure',
    'tune_copyright_notes',
    'dance_name',
    'dance_composer',
    'dance_composed_year',
    'dance_found_in',
    'dance_instructions',
    'deleted',
    'date_created',
    'date_updated',
    ],
);

sub upload_dir {
    my $upload_dir = $ENV{UPLOAD_DIR} or die "missing UPLOAD_DIR in env";
    return $upload_dir;
}


sub save {
    my ($self) = @_;

    if ($self->id) {
        return $self->update;
    }

    my $sql = <<EOL;
    INSERT INTO recording (
        sha256,
        title,
        orig_filename,
        filename_for_download,
        size,
        content_type,
        description,
        ok_to_publish,
        album,
        track_num,
        track_of,
        key,
        tune_name,
        tune_composer,
        tune_composed_year,
        tune_found_in,
        tune_times_through,
        tune_played_structure,
        tune_copyright_notes,
        dance_name,
        dance_composer,
        dance_composed_year,
        dance_found_in,
        dance_instructions,
        deleted,
        date_created,
        date_updated
    )
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
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
        qw/ sha256
            title
            orig_filename
            filename_for_download
            size
            content_type
            description
            ok_to_publish
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
            deleted
            date_created
            date_updated
        /
    );
    $self->id($dbh->sqlite_last_insert_rowid);
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

    if (!$p{include_deleted}) {
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

sub load_by_sha256 {
    my ($class, $sha256, %p) = @_;

    croak "missing id in call to $class->load" unless $sha256;

    # by default deleted ones aren't returned, so two records
    # can have the same sha256
    my $sql = 'SELECT * FROM recording WHERE sha256 = ?';

    if (!$p{include_deleted}) {
        $sql .= ' AND deleted = 0 ';
    }

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute($sha256);
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
            sha256 = ?,
            title = ?,
            orig_filename = ?,
            filename_for_download = ?,
            size = ?,
            content_type = ?,
            description = ?,
            ok_to_publish = ?,
            album = ?,
            track_num = ?,
            track_of = ?,
            key = ?,
            tune_name = ?,
            tune_composer = ?,
            tune_composed_year = ?,
            tune_found_in = ?,
            tune_times_through = ?,
            tune_played_structure = ?,
            tune_copyright_notes = ?,
            dance_name = ?,
            dance_composer = ?,
            dance_composed_year = ?,
            dance_found_in = ?,
            dance_instructions = ?,
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
        qw/ sha256
            title
            orig_filename
            filename_for_download
            size
            content_type
            description
            ok_to_publish
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

    my @wheres;
    if (!$p{include_deleted}) {
        push @wheres, 'deleted = 0';
    }
    if ($p{ok_to_publish}) {
        push @wheres, 'ok_to_publish = 1';
    }
    if (@wheres) {
        $sql .= ' WHERE '.join(' AND ', @wheres);
    }

    my @rc;
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref) {
        push @rc, $class->new($row);
    }
    return @rc;
}

sub file_path {
    my ($self) = @_;
    my $id = $self->sha256;

    return upload_dir()."/$id.mp3";
}

sub create_table {
    my ($class) = @_;

    my $sql = <<EOL;
CREATE TABLE recording (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sha256 VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL, /* length is ignored */
    orig_filename VARCHAR(255),
    filename_for_download VARCHAR(255),
    size INT(255) default 0,
    content_type VARCHAR(255),
    description VARCHAR(4096),
    ok_to_publish INTEGER,
    album VARCHAR(255),
    track_num VARCHAR(255),
    track_of VARCHAR(255),
    key VARCHAR(16),
    tune_name VARCHAR(255),
    tune_composer VARCHAR(255),
    tune_composed_year INT default 0,
    tune_found_in VARCHAR(255),
    tune_times_through VARCHAR(16), -- no need to force INT because who knows?
    tune_played_structure VARCHAR(64), -- e.g. AABB
    tune_copyright_notes VARCHAR(255),
    dance_name VARCHAR(255),
    dance_composer VARCHAR(255),
    dance_composed_year INT default 0,
    dance_found_in VARCHAR(255),
    dance_instructions VARCHAR(8192),
    deleted BOOLEAN NOT NULL DEFAULT 0,
    date_created TEXT(20) NOT NULL,
    date_updated TEXT(20) NOT NULL
);
EOL

    my $dbh = get_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute;

    # not unique so two entries could share the same file
        my $index_sql = <<EOL;
CREATE INDEX idx_recording_sha256
ON recording
(sha256);
EOL

    $sth = $dbh->prepare($index_sql);
    $sth->execute;

}

sub size_hr {
    my ($self) = @_;

    if ($self->size > 1024 * 1024) {
        return sprintf "%.2f mb", $self->size / 1024 / 1024;
    } elsif ($self->size > 1024) {
        return sprintf "%.2f kb", $self->size / 1024 ;
    } else {
        return $self->size . ' bytes';
    }
}


1;
