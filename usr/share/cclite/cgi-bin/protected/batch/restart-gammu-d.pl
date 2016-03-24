#!/usr/bin/perl

use warnings;
use strict;
use Daemon::Control;

exit Daemon::Control->new(
    name      => "Check",
    lsb_start => '$syslog $remote_fs',
    lsb_stop  => '$syslog',
    lsb_sdesc => 'Cclite - Check restart the gammu daemon',
    lsb_desc  => 'Cclite - Check restart the gammu daemon',
    path      => '/etc/init.d/check_gammu',

    program => '/usr/share/cclite/cgi-bin/protected/batch/restart_gammu.pl',
    program_args => [],

    pid_file    => '/var/run/check_gammu.pid',
    stderr_file => '/tmp/checkgammu.out',
    stdout_file => '/tmp/checkgammu.out',

    fork => 2,

)->run;

