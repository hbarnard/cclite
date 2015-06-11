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

# this should give errors in the status line of the admin page
# decomment if there are problems running this as a web task
#my $data = join( '', <DATA> );
#eval $data;
#if ($@) {
#    print $@;
#    exit 1;
#}

=head3 description

This is the batch program that reads uses libgnokii to read
the SIM [SM] memory of a mobile dongle.

Tested with Huawei 1750 and Raspberry Pi 

 On a linux system it must be run as a cron job
 or in a default form as a button controlled cgi
 
 Currently it is designed to read unicode format gammu sms files
 in the directory configured below

 If the data is not unicode, then removing
 
   $sms_data =~ s/\376\377// ; # remove binary stuff at start
   $sms_data = decode('UCS-2',lc($sms_data));                 

will probably work...ymmv...

 To install as cron:

 change lib path and hardcode registry name, for example

=cut

#-------------------------------------------------------------
use constant IS_MOD_PERL => exists $ENV{'MOD_PERL'};
use constant IS_CGI => IS_MOD_PERL || exists $ENV{'GATEWAY_INTERFACE'};

use strict;
use warnings;
use locale;

# full path for cron and daemon use April 2015
use lib '/usr/share/cclite/lib';

#-------------------------------------------------------------


use Ccu;
use Ccadmin;
use Cclitedb;    #FIXME: for log_entry
use Cccookie;
use Ccsms::Gnokii;
use Ccconfiguration;
use Data::Dumper;

my ( $token, $file, %fields, $cookieref );

# this setting is just to clear out read SMSes from SM when testing
# it should normally be zero ;
my $remove_all_read = 1;

# sleep time for main loop
my $sleep = 60;

if (IS_CGI) {

    print STDOUT "Content-Type: text/html; charset=utf-8\n\n";
    $cookieref = get_cookie();
    %fields    = cgiparse();

}

# hardcode configuration path, if running from a cron
my %configuration = readconfiguration('/usr/share/cclite/config/cclite.cf');
my %sms_configuration =
  readconfiguration('/usr/share/cclite/config/readsms.cf');

# fixed needs testing
if ( !$sms_configuration{'smslocal'} ) {
    require SOAP::Lite;
}

# emulation code in here, to create the test file from the form input
if ( $fields{'emulate'} ) {
    my $return = emulate_sms_file( $fields{'originator'}, $fields{'message'} );
    exit 0;
}

# for cron: hardcode registry, cannot be read from web cookie
# read from cookie, but if not, from  sms configuration
my $registry = $cookieref->{'registry'} || $sms_configuration{'registry'};

my $domain =
  $configuration{'domain'};    # remote domain if the script is not local

# inbox for gnokki, so gammu must put messages there..
my $sms_dir = "$sms_configuration{'smsinpath'}/$registry"
  ;    # sms inbox for gammu, now divided by registry 11/2009

# outbox for this script, processed messages placed there..
#FIXME: smsout in main config and smsoutpath in sms config...
my $sms_done_dir = "$configuration{'smsout'}/$registry";
# 
#{driver=>'Gnokii',port=>'/dev/phone',model=>'AT',connection=>'serial'}

while (1) {
my $gsm = GSM::Gnokii->new({driver => 'Gnokii',device => '/dev/phone', options=> 'model:AT,connection:serial'});
$gsm->connect();


my $status = $gsm->GetSMSStatus();

=head2

status is, if there are no unread, exit
{
          'unread' => 0,
          'read' => 2
        };
=cut

    if ( $status->{'unread'} == 0 ) {

        # exit 0;
    }

    # get all of them and process them, should be any unread though!
    my $total = $status->{'read'} + $status->{'unread'};

    for ( my $i = 0 ; $i < $total ; $i++ ) {

        my $sms = $gsm->GetSMS( 'SM', $i );

        ###print Dumper $sms;

=head2 message format, location zero should be oldest/n newest

{
          'location' => 0,
          'memorytype' => 'SM',
          'status' => 'read',
          'date' => '0000-00-00 00:00:00',
          'smsc' => '+447782000800',
          'timestamp' => -1,
          'smscdate' => '2015-05-01 11:51:28',
          'text' => 'Psyuzm pay 35 leaf to susaste',
          'sender' => '+447472744450'
};
        
=cut

        # don't re-read but there shouldn't be any

        if ( $sms->{'status'} eq 'read' ) {

            # normally this delete will be switched on only during testing
            $gsm->DeleteSMS( 'SM', $i ) if ($remove_all_read);
            next;
        }

        # keep in file for audit
        my $file_name = $sms_dir . '/' . $sms->{'smscdate'} . $sms->{'sender'};
        $file_name =~ s/\s+/--/g;
        open( my $fh, '>', $file_name );
        print $fh Dumper $sms;
        close $fh;

   # convert to current gateway format, this is unecessary for gnokii, but keeps
   # everything roughly standard

        $sms->{'sender'} =~ s/^\+//;    # remove the +
        $fields{'originator'} = $sms->{'sender'};

        $fields{'message'} = $sms->{'text'};
        $fields{'status'}  = $sms->{'status'};

        # tacked onto description, this is message centre reception date.
        $fields{'smscdate'} = $sms->{'smscdate'};

        my ( $status, $class, $array_ref, $soap, $token );

# remote transactions are transported via soap, local ones use the local library...
# TODO: SOAP access has never, never been tested as of 2014
        if ( !$sms_configuration{'smslocal'} ) {
            eval {
                $soap =
                  SOAP::Lite->uri("http://$domain/Ccsmsgateway")
                  ->proxy("http://$domain/cgi-bin/ccserver.cgi")
                  ->gateway_sms_transaction( $gsm, \%configuration, \%fields,
                    $token );
            };
            die $soap->faultstring if $soap->fault;
            ( $class, $status, $array_ref ) = $soap->paramsout;

        }
        else {
            my $return_value =
              gateway_sms_transaction( 'local', $gsm, \%configuration, \%fields,
                $token );

            # if it didn't work, then leave the SMS as 'read' in SIM memory
            if ( $return_value =~ /nok/ ) {
                log_entry( 'local', $registry, 'error', 'transaction error',
                    undef );
            }
            else {

# delete the SMS, if everything is working only unread SMS should be in SIM memory
                my $sms = $gsm->DeleteSMS( 'SM', $i );
            }
        }

    }

$gsm->disconnect();

undef $gsm ;
print "sleeping \n" ;
sleep $sleep;
}
exit 0;
