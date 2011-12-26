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
# these batch scripts are kept as eval, if they fail they print their problems
# onto the status web page

print STDOUT "Content-type: text/html\n\n";
my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}
__END__


# --- start of main script ---#

use strict;
use Net::POP3;

use lib '../../../lib';

use Ccconfiguration;
use Ccmailgateway;
use Cclitedb;
use Cclite ;
use Ccinterfaces;
use Cccookie;
use Ccu;

BEGIN {
    use CGI::Carp qw(fatalsToBrowser set_message);
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );

}

my %configuration = readconfiguration;

# for cron, replace these with hardcoded registry name
my $hardcoded_registry  = '' ;

my %fields = cgiparse();
my $cookieref = get_cookie();
my $registry  = $hardcoded_registry || $$cookieref{registry};

#FIXME: needs slightly higher barrier than this...
exit unless ( length($registry) );

# read the current registry to pick up per-registry email values
my ($class,$token) ;
my ( $error, $registryref ) =
  get_where( $class, $registry, 'om_registry','*', 'name', $registry, $token, '',
    '' );
    
if (length($error) ) {
    log_entry("database error for $registry: $error") ;
    exit 0 ;
}       
    

# message language now decided by decide_language 08/2011    
our %messages = readmessages();

my $username = $registryref->{postemail};
my $password = $registryref->{postpass};
my $host     = $username;
my $count = 0 ;

# get the domain part as postbox...
$host =~ s/^(.*?)\@(.*)$/$2/;

my $pop = Net::POP3->new( $host, Timeout => 60, Debug => 0 );

if ( $pop->login( $username, $password ) > 0 ) {
  
    my $msgnums = $pop->list;    # hashref of msgnum => size
    foreach my $msgnum ( keys %$msgnums ) {
        my $msg = $pop->get($msgnum);
        my ( $from, $to, $subject, $parse_type, $transaction_description_ref ) ;
        # make a message object
        my $output_message;
        foreach my $part (@$msg) {
            
            if ( $part =~ /From:\s.*?\W([\.-\w]+@([-\w]+\.)+[A-Za-z]{2,4})\W/ )
            {
                $from = $1; 

            } elsif ( $part =~ /To:\s.*?\W([^@]+@([-\w]+\.)+[A-Za-z]{2,4})\W/ )
            {
                $to = $1;

# want the send line but not twice if multipart/alternate, so reject if html fragments
            } elsif ( $part =~ /(send.*?)/i && $part !~ /\</ ) {
            
                ( $parse_type, $transaction_description_ref ) =
                  mail_message_parse( 'local', $registry, $from, $to, $subject, $part );

                
                # add 'via email' literal to description of transaction
                $transaction_description_ref->{'description'}  = "$messages{'viaemail'} " . $transaction_description_ref->{'description'} ;
    
                if ( !length( $transaction_description_ref->{error} ) ) {
                    $output_message =
                      mail_transaction($transaction_description_ref);

                } else {
                    $output_message = $transaction_description_ref->{error};
                }  # endif parsed body of message

             } elsif ( $part =~ /Subject:\s+(\S.*)/ ) {

                $subject = $1;

            } #endif for message parse
            
        }  # end foreach of message parse all bits consumed
          my ($accountname, $smtp) ;
          notify_by_mail( 'local', $registry, $transaction_description_ref->{name},
                          $transaction_description_ref->{from}, $transaction_description_ref->{from}, $transaction_description_ref->{from},
                          $transaction_description_ref->{source}, $smtp, '',
                          $output_message, 5,'' );
                          
            # reference to the current signature for notify...
            # $class,       $registry,         $name,
            # $email,       $systemfrom,       $return_address,
            # $accountname, $smtp,             $urlstring,
            # $text,        $notificationtype, $hash
           $count++ ;         
           $pop->delete($msgnum);
        } #end foreach of all messages
    } # endif pop login

    $pop->quit;
    
    # print into management status area, if at least one message was processed...
    print "processed $count transactions" if ($count > 0);
exit 0 ;

