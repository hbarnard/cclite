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

#-----------------------------------------------------------
# This is the batch program that reads mail files, processes
# them and unlinks them.
#
# On a linux system it will be run as a cron job..on some
# Windows, as an 'at' of some kind, I guess.
#
# Currently it is designed to read any file of form:
# <registryname>.cclite
#
# It will derive the registry name which is also the database
# name from the mailbox name
#
# To install:
#
# Change the library path and the mail file, since
# this is installation dependent. Probably, one mail file
# will belong to one registry
#
#-------------------------------------------------------------

=head3 readconfiguration

Read the configuration data and return a hash, this routine
also exists in ccserver.cgi


Skip comments marked with #
cgi parameters will override configuration file
information, always!

Included here, needs to be executed within BEGIN

=cut

use lib '../../../lib';

use Ccadmin;
use Cccookie;
use Ccu;
use Ccinterfaces;
use Ccconfiguration;

my $token;

my %configuration = readconfiguration();

#--------------------------------------------------------------
# change these two, if necessary
my $mail_dir = $configuration{'mailpath'};    # mail directory in readmail.cf
my %fields   = cgiparse();

# for cron, replace these with hardcoded registry name
# my $registry  = 'dogtown' ;
my $cookieref = get_cookie();
my $registry  = $$cookieref{registry};

#---------------------------------------------------------------
# mail file and therefore mailbox must be postfixed as cclite
# for example /var/spool/mail/dalston.cclite
#---------------------------------------------------------------

opendir( DIR, $mail_dir );

my $mail_file = "$mail_dir/$registry\.cclite";

read_mail_transactions( 'local', $registry, 'om_trades', $mail_file, $token,
    "", "" );

closedir(DIR);
exit 0;

