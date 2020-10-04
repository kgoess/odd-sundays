use 5.016003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'OddSundays',
    VERSION_FROM      => 'lib/OddSundays.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
        'Apache2::Const' => 2.0,
        'Apache2::Request' => 2.0,
        'Apache2::RequestIO' => 2.0,
        'Apache2::RequestRec' => 2.0,
        'Apache2::Upload' => 2.0,
        'CGI::Cookie' => 1.30,
        'Class::Accessor::Lite' => 0.05,
        'Data::Dump' => 1.22,
        'DateTime' => 1.04,
        'DBD::SQLite' => 1.39,
        'DBI' => 1.627,
        'Digest::SHA' => 5.85,
        'File::Temp' => 0.2301,
        'Template' => 2.24,
        'Text::Wrap' => 0,
    }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/OddSundays.pm', # retrieve abstract from module
    AUTHOR            => 'Kevin M. Goess <cpan@goess.org>',
    LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);


