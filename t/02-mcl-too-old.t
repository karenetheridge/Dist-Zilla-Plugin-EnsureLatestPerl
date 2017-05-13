use strict;
use warnings;

use Test::More 0.88;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Deep;
use Test::Fatal;
use Path::Tiny;
use Test::MockTime 'set_absolute_time';
use POSIX 'mktime';

use lib 't/lib';
use Versions;

# instead of faking Module::CoreList's version and release list, it is much
# easier to fake today's date and current running perl version...
my ($year, $month, $day) = (2100, 6, 0);    # a long time from now...
my $fakenow = mktime(0, 0, 0, $day, $month - 1, $year - 1900);
set_absolute_time($fakenow);

# fake the current perl version to be the latest known stable release.
local $] = Versions::latest_stable_perl();

$ENV{DZIL_ANY_PERL} = 0;

my $tzil = Builder->from_config(
    { dist_root => 'does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MetaConfig => ],
                [ 'EnsureLatestPerl' ],
                [ FakeRelease => ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);
### BEGIN $tzil->release check
like(
    exception { $tzil->release },
    qr/^\[EnsureLatestPerl\] Module::CoreList is not new enough to check if this is the latest Perl \(expected at least 5\.2100\d\d\d\d\) -- disable check with DZIL_ANY_PERL=1/,
    'release halts if Module::CoreList is too much out of date',
);
### END $tzil->release check

cmp_deeply(
    $tzil->distmeta,
    superhashof({
        x_Dist_Zilla => superhashof({
            plugins => supersetof(
                {
                    class => 'Dist::Zilla::Plugin::EnsureLatestPerl',
                    config => {
                        'Dist::Zilla::Plugin::EnsureLatestPerl' => {
                            'Module::CoreList' => Module::CoreList->VERSION,
                        },
                    },
                    name => 'EnsureLatestPerl',
                    version => Dist::Zilla::Plugin::EnsureLatestPerl->VERSION,
                },
            ),
        }),
    }),
    'plugin metadata, including dumped configs',
) or diag 'got distmeta: ', explain $tzil->distmeta;

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
