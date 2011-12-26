#!/usr/bin/perl 

=head1 NAME

read_pop_mail_gpg.pl

=head1 SYNOPSIS

Read gpg encrypted mail transactions, process and send motifications
Only currently deals with payments (send) and balance (balance) at present
all the parsing etc. is 'english' this needs to be dealt with real-soon

=head1 DESCRIPTION


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



=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2004-2010 GPL Licenced 

=cut

# these batch scripts are kept as eval, if they fail they print their problems
# onto the status web page

#print STDOUT "Content-type: text/html\n\n";

###my $data = join( '', <DATA> );
###eval $data;
###if ($@) {
###    print $@;
###   exit 1;
###}
###__END__

=head3 check_parameters

Check that the set up can work and exit otherwise..
FIXME: Only checks non blank not valid file names

=cut

sub check_parameters {

    my ( $registry, $passphrase, $temp_directory, $message, $encrypted,
        $logfile, $debug, $trace )
      = @_;
    my @error_messages;

    push @error_nessages, 'registry blank'   if ( !length($registry) );
    push @error_nessages, 'passphrase blank' if ( !length($passphrase) );
    push @error_nessages, 'temporary directory blank'
      if ( !length($temp_directory) );
    push @error_nessages, 'message file blank'    if ( !length($message) );
    push @error_nessages, 'encryption file blank' if ( !length($encrypted) );

    if ( length($registry) ) {
        my ( $error, $registryref ) = get_where(
            'local', $registry, 'om_registry', '*',
            'name',  $registry, $token,        '',
            ''
        );
        push @error_nessages, $error if ( length($error) );
    }

    # print errors and exit, if problems with set up
    if ( scalar @error_messages ) {
        my $errors = join( "\n", @error_messages );
        print $errors ;
        exit 0;
    } else {
        return;
    }
}

# --- start of main script ---#

use strict;
use lib '../../../lib';

# this is mailbox access
use Net::POP3;

# this is used to parse addresses (logically enough...)
use Email::Address;

use Ccconfiguration;
use Ccmailgateway;
use Cclitedb;
use Cclite;
use Cccrypto;

#use Ccinterfaces;
use Cccookie;
use Ccu;

BEGIN {
    use CGI::Carp qw(fatalsToBrowser set_message);
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );

}

# read configuration and messages
my %configuration          = readconfiguration;
my $configuration_hash_ref = \%configuration;

# language now decided by decide_language 08/2011
our %messages = readmessages();

# note this is a first version, these values will be configured  with the rest later
#-------------------------------------------------------------------------------------------------------------

my %gpg_configuration = readconfiguration('../../../config/readmailgpg.cf');

my $temp_directory = $gpg_configuration{'temp_directory'};

my $message =
  "$gpg_configuration{'temp_directory'}/$gpg_configuration{'message'}";
my $reformat =
  "$gpg_configuration{'temp_directory'}/$gpg_configuration{'reformat'}";
my $decrypt =
  "$gpg_configuration{'temp_directory'}/$gpg_configuration{'decrypt'}";
my $encrypted =
  "$gpg_configuration{'temp_directory'}/$gpg_configuration{'encrypted'}";

# send receipts etc. encrypted with users public key
my $encrypt_notifications = $gpg_configuration{'encrypt_notifications'};

# STDERR for gpg operations, if specified...
my $logfile =
  "$gpg_configuration{'temp_directory'}/$gpg_configuration{'logfile'}";

# turns gpg trace on and off, prints to STDOUT (or STDERR?)
my $trace = $gpg_configuration{'trace'};

# sleep in seconds for processing loop
my $sleep = $gpg_configuration{'sleep'};

# clearly this is very insecure, should be held as a smartcard token for example, this
# passphrase unlocks the private key for decrpyting the incoming transactions
# users private key on client is used to sign transactions

# note the key and the running user must correspond, otherwise the key won't get released by gpg
my $passphrase = $gpg_configuration{'passphrase'};

# this will leave data in the intermediate files and mail in the mailbox, if set to 1, avoids
# resetting/resending etc. when debugging
my $debug = $gpg_configuration{'debug'};

# for cron, replace these with hardcoded registry name, for example
my $hardcoded_registry = $gpg_configuration{'hardcoded_registry'};

if ($debug) {
    foreach my $key ( keys %gpg_configuration ) {
        print "$key = $gpg_configuration{$key}\n";

    }
}

my %fields    = cgiparse();
my $cookieref = get_cookie();

#FIXME: needs higher barrier than this and something a little more general
my $registry = $$cookieref{registry} || $hardcoded_registry;

# check that the set up works before starting to process...
check_parameters( $registry, $passphrase, $temp_directory, $message, $encrypted,
    $logfile, $debug, $trace );

# store of references to transactions to be notified
my @notifications;

# read the current registry to pick up per-registry email values, that's where the email
# transactions are picked up from
my ( $class, $token );
my ( $error, $registryref ) = get_where(
    $class, $registry, 'om_registry', '*',
    'name', $registry, $token,        '',
    ''
);

if ( length($error) ) {
    log_entry("database error for $registry: $error");
    exit 0;
}

my $username = $registryref->{postemail};
my $password = $registryref->{postpass};
my $host     = $username;
my $count    = 0;
my $originator_email;

#FIXME: get the domain part as postbox...this is weak...
$host =~ s/^(.*?)\@(.*)$/$2/;

while (1) {

    print "running";
    print "\nwarning debug mode!" if ($debug);
    print "\n";

    # clear up, just in case...
    unlink $message, $reformat, $decrypt, $encrypted if ( !$debug );

    my $pop = Net::POP3->new( $host, Timeout => 60, Debug => $debug );

    if ( $pop->login( $username, $password ) > 0 ) {

        my $msgnums = $pop->list;    # hashref of msgnum => size
        my @from_array;
        my @to_array;
        my ( $output_message, $batch_email_box, $transaction_description_ref );

        foreach my $msgnum ( keys %$msgnums ) {

            my $msg = $pop->get($msgnum);

            # put the message in a file for decrypt and reformat

            my ( $subject, $parse_type );

            # detect pgp, decryption attempy stops script, if no PGP banner
            my $pgp_detected = 0;

            open( MAIL, ">$message" );
            foreach my $part (@$msg) {

                $pgp_detected = 1 if ( $part =~ /BEGIN PGP MESSAGE/ );

                print MAIL $part;

                if ( $part =~ /From:/ ) {

                    @from_array = Email::Address->parse($part);

                    # deal with Yahoo parse etc. may need more tweaking...
                    if ( $from_array[0] =~ /\<(.*?)\>/ ) {
                        $from_array[0] = $1;
                    }

                    # these are just to understand the data
                    $originator_email = $from_array[0];

                } elsif ( $part =~ /To:/ ) {
                    @to_array = Email::Address->parse($part);

                    # these are just to understand the data
                    $batch_email_box = $to_array[0];

                } elsif ( $part =~ /Subject:\s+(\S.*)/ ) {

                    $subject = $1;

                }    #endif for message parse

            }    # end foreach of message parse all bits consumed

            # current message is now in mail.txt for decryption
            close(MAIL);

            # non pgp mails are thrown away...

# $transaction_found is true, if there's a transaction line beginning with 'send' in the decrypted message
            if ($pgp_detected) {
                my ( $transaction_found, $transaction_unparsed ) =
                  decode_decrypt_reformat(
                    $passphrase, $message, $reformat,
                    $decrypt,    $logfile, $trace
                  );

                if ($transaction_found) {
                    ( $parse_type, $transaction_description_ref ) =
                      mail_message_parse( 'local', $registry, $originator_email,
                        $batch_email_box, $subject, $transaction_unparsed );

                    # add 'via email' literal to description of transaction
                    $transaction_description_ref->{'description'} =
                      "$messages{'viagpgmail'} "
                      . $transaction_description_ref->{'description'};

    #FIXME: we have output, error and text within transaction, needs simplifying
                    if ( !length( $transaction_description_ref->{error} )
                        && $transaction_description_ref->{type} eq 'send' )
                    {
                        $transaction_description_ref->{output_message} =
                          mail_transaction($transaction_description_ref);
                    } elsif (
                        $transaction_description_ref->{'type'} eq 'balance' )
                    {

                        $transaction_description_ref->{'output_message'} =
                        $transaction_description_ref->{'text'};
                    }

           # as mailbox is opened by pop and maybe need to encrypt notifications
           # store in data structures amd do when mailbox closed for reading...

                    $transaction_description_ref->{'originator_email'} =
                      $originator_email;

            # keep the references to be notified in an array of references...
            # FIXME: maybe this should notify for every mail in the batch inbox?
                    push @notifications, $transaction_description_ref;

                }    # end of transaction found

                $count++;

                # pgp not detected, mail is thrown away...
            } else {

                log_entry("discarded non-pgp transaction\n");
            }

            # these should be destroyed asap and possibly done in-memory
            unlink $message, $reformat, $decrypt if ( !$debug );

            $pop->delete($msgnum) if ( !$debug );

        }    #end foreach of all messages

    }    # endif pop login

    $pop->quit;

    # send encrypted notifications to originator...
    send_notifications( \@notifications, $passphrase, $message, $encrypted,
        $logfile, $encrypt_notifications, $trace, \%messages );
         
    $count = 0;
    sleep $sleep;

}
exit 0 ;
