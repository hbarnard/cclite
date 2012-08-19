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

#print STDOUT "Content-Type: application/json\n\n";

print STDOUT "Content-Type: text/html; charset=utf-8\n\n";

# this should result in errors printed in the status line of the management page

my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}

__END__

use strict;    # all this code is strict
use locale;
use lib '../../../lib' ;	
#-------------------------------------------------------------

use Ccu;
use Cccookie ;
use Ccinterfaces;
use Ccconfiguration;

my $token;
my $file;
my %configuration;

%configuration = readconfiguration();

my $cookieref = get_cookie();
my %fields    = cgiparse();

# cron: hardwire the registry name into the script
my $registry = $cookieref->{'registry'} ;

###testing from command line...
###$registry = 'dalston' ;

# timestamp output files so that they don't get confused
my ($numeric_date,$time) = getdateandtime(time()) ;

my $language = decide_language() ;

# message language now decided by decide_language, within readmessages 08/2011
my %messages = readmessages();


# change these two, if necessary, note that as of 2009, files are by registry
my $csv_dir = "$configuration{csvpath}/$registry" ;    # csv directory

if (-e $csv_dir && -w $csv_dir) {
} else {
  print "$csv_dir $messages{nocsvdir}\n";
  exit 1 ;
}

opendir( DIR, $csv_dir );

while ( defined( $file = readdir(DIR) ) ) {

    next if ( $file !~ /\056csv$/ );      # not a csv extension, for example don't re-do .done files!!
    
    my $csv_file = "$csv_dir\/$file";
    
    # registry and configuration passed into this now, paths per registry etc. 10/2009
    my $report_ref = read_csv_transactions( 'local', $registry, 'om_trades', $csv_file, $file,
        \%configuration, \%fields,
        $token, "", "" );

    # give the input file a 'done' extension so that it doesn't get re-processed
    system("mv $csv_file $csv_file\056done\056$numeric_date$time");
    ###print "$messages{justprocessed} $csv_file\n" ;
    my $json = deliver_remote_data ( $registry, 'om_trades', '', $report_ref, '', $token );
    print $json ;
}

closedir(DIR);
exit 0;

