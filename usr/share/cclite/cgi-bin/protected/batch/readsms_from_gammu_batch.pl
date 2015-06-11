#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;
 
exit Daemon::Control->new(
    name        => 'Cclite ReadSMS',
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'Cclite:Read SMS From Gammu',
    lsb_desc    => 'Cclite:Read SMS From Gammu Daemon',
    path        => '/etc/init.d/readsms_from_gammu',
 
    program     => '/usr/share/cclite/cgi-bin/protected/batch/readsms_from_gammu.pl',
    program_args => ['--debug'],
 
    pid_file    => '/tmp/readsms.pid',
    stderr_file => '/tmp/readsms.out',
    stdout_file => '/tmp/readsms.out',
 
    fork        => 2,
 
)->run;

