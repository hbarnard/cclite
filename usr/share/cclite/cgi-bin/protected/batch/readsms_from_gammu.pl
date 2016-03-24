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

This is the batch program that reads files created by gammu, 
see http://www.gammu.org/wiki/index.php?title=Gammu:SMSD
processes them and unlinks them.

 On a linux system it can be run as a cron job
 or in a default form as a button controlled cgi
 
 Currently it is designed to read unicode format gammu sms files
 in the directory configured below

 If the data is not unicode, then removing
 
   $sms_data =~ s/\376\377// ; # remove binary stuff at start
   $sms_data = decode('UCS-2',lc($sms_data));                 

will probably work...ymmv...

 To install as cron:

 change lib path and hardcode registry name, for example

 This is the format for the input file name from gammu, contains
 date, time and phone number:
 IN20081112_114152_00_+447779159452_00.txt 

 Note:

=cut

=head3 sort_file_names

This sorts the incoming file names chronologically


=cut

sub sort_file_names {

    my (@file_names) = @_;
    my @sts;

    foreach my $file_name (@file_names) {

        next
          if ( $file_name !~ /\056txt$/i )
          ;    # not a txt extension, standard for gammu sms

        $file_name =~
m/IN(\d{4})(\d{2})(\d{2})\_(\d{2})(\d{2})(\d{2})\_00\_\+(\d{2})(\d+)\_00\.txt/;

        my ( $sms_year, $sms_month, $sms_day, $sms_hour, $sms_minute,
            $sms_second, $sms_int_code, $sms_phone_number )
          = ( $1, $2, $3, $4, $5, $6, $7, $8 );
        my $entry = [
            "$sms_year$sms_month$sms_day$sms_hour$sms_minute$sms_second",
            $file_name
        ];

        push @sts, $entry;

    }

    my @sorted_sts = sort { $a->[0] <=> $b->[0] } @sts;
    my @sorted     = map  { $_->[1] } @sorted_sts;

    return @sorted;

}

#-------------------------------------------------------------
use constant IS_MOD_PERL => exists $ENV{'MOD_PERL'};
use constant IS_CGI => IS_MOD_PERL || exists $ENV{'GATEWAY_INTERFACE'};

use strict;
use warnings;
use locale;

# full path for cron and read on receive April 2015
use lib '/usr/share/cclite/lib';

#-------------------------------------------------------------

use Ccu;
use Ccadmin;
use Cclitedb;    #FIXME: for log_entry
use Cccookie;
use Ccsms::Gammu;
use Ccconfiguration;
use Data::Dumper;

if (IS_CGI) {
    print STDOUT "Content-Type: text/html; charset=utf-8\n\n";
}

#use Time::HiRes qw( usleep ualarm gettimeofday  tv_interval nanosleep
#clock_gettime clock_getres clock_nanosleep clock
#stat );

#my $t0 = [gettimeofday];
# hardcode configuration path, if running from a cron
my %configuration = readconfiguration('/usr/share/cclite/config/cclite.cf');
my %sms_configuration =
  readconfiguration('/usr/share/cclite/config/readsms.cf');

# fixed needs testing
if ( !$sms_configuration{'smslocal'} ) {
    require SOAP::Lite;
}

my ( $token, $file );

my $cookieref = get_cookie();
my %fields    = cgiparse();

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

# inbox for gammu, so gammu must put messages there..
my $sms_dir = "$sms_configuration{'smsinpath'}/$registry"
  ;    # sms inbox for gammu, now divided by registry 11/2009

# outbox for this script, processed messages placed there..
#FIXME: smsout in main config and smsoutpath in sms config...
my $sms_done_dir = "$configuration{'smsout'}/$registry";

# Feburary 2014 testing shows that we need to sort chronologically
# otherwise sequence of transactions may be lost

opendir( DIR, $sms_dir );
my @files = readdir(DIR);
closedir DIR;

@files = sort_file_names(@files);

foreach my $file (@files) {

    my $sms_file = "$sms_dir/$file";

# parse file name and extract timing data and phone number, timing not used at present
# but useful if, for example, interface is off-lined

    # IN20081203_211658_00_+447779159452_00.txt

    $sms_file =~
m/IN(\d{4})(\d{2})(\d{2})\_(\d{2})(\d{2})(\d{2})\_00\_\+(\d{2})(\d+)\_00\.txt/;

    my ( $sms_year, $sms_month, $sms_day, $sms_hour, $sms_minute, $sms_second,
        $sms_int_code, $sms_phone_number )
      = ( $1, $2, $3, $4, $5, $6, $7, $8 );

    my $full_telephone_number = $sms_int_code . $sms_phone_number;

    open( SMS, $sms_file );

    my $sms_data;    # holds message text

    while (<SMS>) {
        ### s/\376\377//;  # moved from outside loop...11/2009
        $sms_data .= $_ if (/[\w\s]+/);

    }
    close SMS;

    # remove binary stuff at start

    # convert to current gateway format
    $fields{'originator'} = $full_telephone_number;
    $fields{'message'}    = $sms_data;
    $fields{'status'}     = 0;                        # status is forced

    my ( $status, $class, $array_ref, $soap, $token );

# remote transactions are transported via soap, local ones use the local library...
# TODO: SOAP access has never, never been tested as of 2014
    if ( !$sms_configuration{'smslocal'} ) {
        eval {
            $soap =
              SOAP::Lite->uri("http://$domain/Ccsmsgateway")
              ->proxy("http://$domain/cgi-bin/ccserver.cgi")
              ->gateway_sms_transaction( \%configuration, \%fields, $token );
        };
        die $soap->faultstring if $soap->fault;
        ( $class, $status, $array_ref ) = $soap->paramsout;

    } else {
        my $return_value =
          gateway_sms_transaction( 'local', \%configuration, \%fields, $token );
        if ( $return_value =~ /nok/ ) {
            log_entry( 'local', $registry, 'error', 'transaction error',
                undef );
        }
    }

 # move the processed file to a done directory, don't process twice
 # FIXME: The out file is under the web root and still in the main configuration
    system("mv $sms_file $configuration{smsout}/$registry");
}

exit 0;
