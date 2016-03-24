#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

# --debug isn't read at present, but later!
# note that this script is hardwired for Raspberry Pi at present

my $daemon = Daemon::Control->new(
    {
        name      => "Cclite ReadSMS",
        lsb_start => '$syslog $local_fs',
        lsb_stop  => '$syslog',
        lsb_sdesc => 'Cclite:Read SMS From Gnokii',
        lsb_desc  => 'Cclite:Read SMS From Gnokii Daemon',
        path      => '/etc/init.d/readsms_from_gnokii',

        program =>
          '/usr/share/cclite/cgi-bin/protected/batch/readsms_from_gnokii.pl',
        program_args => ['--debug'],

        pid_file    => '/tmp/readsms.pid',
        stderr_file => '/tmp/readsms.out',
        stdout_file => '/tmp/readsms.out',

        fork => 2,

    }
);

my $exit = $daemon->run;

