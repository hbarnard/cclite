#!/usr/bin/perl 
#---------------------------------------------------------------------------
#THE cclite SOFTWARE IS PROVIDED TO YOU "AS IS," AND WE MAKE NO EXPRESS
#OR IMPLIED WARRANTIES WHATSOEVER WITH RESPECT TO ITS FUNCTIONALITY,
#OPERABILITY, OR USE, INCLUDING, WITHOUT LIMITATION,
#ANY IMPLIED WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE, OR INFRINGEMENT.
#WE EXPRESSLY DISCLAIM ANY LIABILITY WHATSOEVER FOR ANY DIRECT,
#INDIRECT, CONSEQUENTIAL, INCIDENTAL OR SPECIAL DAMAGES,
#INCLUDING, WITHOUT LIMITATION, LOST REVENUES, LOST PROFITS,
#LOSSES RESULTING FROM BUSINESS INTERRUPTION OR LOSS OF DATA,
#REGARDLESS OF THE FORM OF ACTION OR LEGAL THEORY UNDER
#WHICH THE LIABILITY MAY BE ASSERTED,
#EVEN IF ADVISED OF THE POSSIBILITY OR LIKELIHOOD OF SUCH DAMAGES.
#---------------------------------------------------------------------------
#
# shutdown and restart gammu-smsd
#
#Sat 2015/04/25 05:24:29 gammu-smsd[2270]: Going to 30 seconds sleep because of too much connection errors
#Sat 2015/04/25 05:24:59 gammu-smsd[2270]: Starting phone communication...
#Sat 2015/04/25 05:25:09 gammu-smsd[2270]: Error at init connection: No response in specified timeout. Probably phone not connected.

use strict ;

my $debug = 0 ;
my $sleep = 300 ; #five minutes

while (1) {
`tail -3 /var/log/gammu/gammu-smsd.log > /tmp/gammu-test.txt`;

open my $fh, '<', '/tmp/gammu-test.txt';
my @lines = <$fh>;

my $ok = 1;
foreach my $line (@lines) {
    if ( $line =~ /connection errors/ || $line =~ /no response/i || $line =~ /Already hit 250 errors/) {
        $ok = 0;
    }
}

if ( !$ok ) {
    `udevadm trigger` ;
    sleep 10 ;
    `/etc/init.d/gammu-smsd stop`;
    sleep 20;
    `/etc/init.d/gammu-smsd start`;
    print "restarting gammu\n" if $debug ;

}


sleep $sleep ;

}
