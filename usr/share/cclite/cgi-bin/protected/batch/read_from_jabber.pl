#!/usr/bin/perl

=head3 stop

stop the scriot, on signal

=cut

sub stop {
    print "Exiting...\n";
    $connection->Disconnect();
    exit(0);
}

=head3 set_signals

Set the signals that will stop the script
This probably needs review for cron etc/

=cut

sub set_signals {

    $SIG{HUP}  = \&stop;
    $SIG{KILL} = \&stop;
    $SIG{TERM} = \&stop;
    $SIG{INT}  = \&stop;

    return;
}

=head3 in_message

Processing for messages coming in from human
client. All messages processed for cclite


=cut

sub in_message {
    my $sid     = shift;
    my $message = shift;

    my $type    = $message->GetType();
    my $fromJID = $message->GetFrom("jid");

    my $from       = $fromJID->GetUserID();
    my $originator = $message->GetFrom();
    my $resource   = $fromJID->GetResource();
    my $subject    = $message->GetSubject();
    my $body       = $message->GetBody();

    process_cclite_message( $body, $fromJID );

    if ($debug) {
        print "===\n";
        print "Message ($type)\n";
        print "  From: $from ($resource) $from\n";
        print "  Subject: $subject\n";
        print "  Body: $body\n";
        print "===\n";
        print $message->GetXML(), "\n";
        print "===\n";
    }

}

=head3 in_iq

Another message type, not sure what this does?
AOL?

=cut

sub in_iq {
    my $sid = shift;
    my $iq  = shift;

    my $from  = $iq->GetFrom();
    my $type  = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();

    if ($debug) {
        print "===\n";
        print "IQ\n";
        print "  From $from\n";
        print "  Type: $type\n";
        print "  XMLNS: $xmlns";
        print "===\n";
        print $iq->GetXML(), "\n";
        print "===\n";
    }

}

=head3 in_presence

Prcoessing presence messages

=cut

sub in_presence {
    my $sid      = shift;
    my $presence = shift;

    my $from   = $presence->GetFrom();
    my $type   = $presence->GetType();
    my $status = $presence->GetStatus();

    if ($debug) {
        print "===\n";
        print "Presence\n";
        print "  From $from\n";
        print "  Type: $type\n";
        print "  Status: $status\n";
        print "===\n";
        print $presence->GetXML(), "\n";
        print "===\n";
    }

}

=head3 process_cclite_message

A crude first attempt to process GPG encoded Jabber input bodies
containing 'send' or 'balance' transactions. Does not send encrypted
receipts at present...

=cut

sub process_cclite_message {

    my ( $body, $fromJID ) = @_;

    my ( $transaction_found, $transaction_line, $transaction_description_ref,
        $parse_type );

    # originator is mail style address + resource stub, parse
    $originator =~ s/^([^\/]+)\/.*?$/$1/;

    # if encoded, assumed to be a transaction...
    if ( $body =~ /BEGIN PGP MESSAGE/ ) {
        open( JABBER, ">$message_file" );
        print JABBER $body;
        close(JABBER);
        ( $transaction_found, $transaction_line ) =
          decode_decrypt_reformat( $passphrase, $message_file, $reformat,
            $decrypt, $logfile, $trace );

        ( $parse_type, $transaction_description_ref ) =
          mail_message_parse( 'local', $registry, $originator, '', '',
            $transaction_line );

        # add 'via jabber' literal to description of transaction
        $transaction_description_ref->{'description'} =
          "$messages{'viajabber'} "
          . $transaction_description_ref->{'description'};

#FIXME: we have output, error and text within transaction, needs simplifying
# also add the Via Jabber/Via Email prefix at this stage before transaction processing...
        if ( !length( $transaction_description_ref->{'error'} )
            && $transaction_description_ref->{'type'} eq 'send' )
        {
            $transaction_description_ref->{'output_message'} =
              mail_transaction($transaction_description_ref);
        } elsif ( $transaction_description_ref->{'type'} eq 'balance' ) {
            $transaction_description_ref->{'output_message'} =
            $transaction_description_ref->{'text'};
        }

    }

=item message_fields


message fields for refereence...

             to=>string|JID,    - set multiple fields in the <message/>
             from=>string|JID,    at one time.  This is a cumulative
             type=>string,        and over writing action.  If you set
             subject=>string,     the "to" attribute twice, the second
             body=>string,        setting is what is used.  If you set
             thread=>string,      the subject, and then set the body
             errorcode=>string,   then both will be in the <message/>
             error=>string

=cut

  
    my $output =
"$transaction_description_ref->{'error'} $transaction_description_ref->{'output_message'}";
    my $type = $transaction_description_ref->{'type'};
  

    if ( !$transaction_found ) {

        $connection->MessageSend(
            'to'   => $fromJID,
            'type' => 'chat',
            'body' => "no transaction detected"
        );
    } else {
        my $output =
"$transaction_description_ref->{'error'} $transaction_description_ref->{'output_message'}";
        $connection->MessageSend(
            'to'   => $fromJID,
            'type' => 'chat',
            'body' => $output
        );
    }

    return;
}

#------------------------------------------------------------------------------------------------------------------
# Start of main script
#------------------------------------------------------------------------------------------------------------------

use strict;

use lib '../../../lib';

# and cclite support
use Ccconfiguration;
use Ccmailgateway;
use Cclitedb;
use Cclite;
use Cccrypto;
use Cccookie;
use Ccu;

my %configuration          = readconfiguration;
my $configuration_hash_ref = \%configuration;

# message language now decided by decide_language 08/2011
our %messages = readmessages();

# don't need at present run from command line...
my $cookieref = get_cookie();

# specific configuration file for this, for the moment...
my %jabber_configuration = readconfiguration('../../../config/readjabber.cf');

my $server   = $jabber_configuration{'server'};
my $port     = $jabber_configuration{'port'};
my $username = $jabber_configuration{'username'};
my $password = $jabber_configuration{'password'};

# this is experimental, multiple cclite bots, distinguished by registry name
my $resource = $jabber_configuration{'hardcoded_registry'};

my $temp_directory = $jabber_configuration{'temp_directory'};

our $message_file =
  "$jabber_configuration{'temp_directory'}/$jabber_configuration{'message'}";
our $reformat =
  "$jabber_configuration{'temp_directory'}/$jabber_configuration{'reformat'}";
our $decrypt =
  "$jabber_configuration{'temp_directory'}/$jabber_configuration{'decrypt'}";
our $encrypted =
  "$jabber_configuration{'temp_directory'}/$jabber_configuration{'encrypted'}";

# STDERR for gpg operations, if specified...
our $logfile =
  "$jabber_configuration{'temp_directory'}/$jabber_configuration{'logfile'}";

# turns gpg trace on and off, prints to STDOUT (or STDERR?)
our $trace = $jabber_configuration{'trace'};

# sleep in seconds for processing loop, not needed...
our $sleep = $jabber_configuration{'sleep'};

# clearly this is very insecure, should be held as a smartcard token for example, this
# passphrase unlocks the private key for decrpyting the incoming transactions
# users private key on client is used to sign transactions

# note the key and the running user must correspond, otherwise the key won't get released by gpg
our $passphrase = $jabber_configuration{'passphrase'};

# this will leave data in the intermediate files and mail in the mailbox, if set to 1, avoids
# resetting/resending etc. when debugging
my $debug = $jabber_configuration{'debug'};

# for cron, replace these with hardcoded registry name
our $registry = $jabber_configuration{'hardcoded_registry'}
  || $$cookieref{registry};

# print out all the values in the configuration file, if debugging...
if ($debug) {
    foreach my $key ( keys %jabber_configuration ) {
        print "$key = $jabber_configuration{$key}\n";

    }
}

# validate the current registry
#FIXME: this routine is repeated needs to go into a library
my ( $class, $token );
my ( $error, $registryref ) = get_where(
    $class, $registry, 'om_registry', '*',
    'name', $registry, $token,        '',
    ''
);

if ( length($error) ) {
    log_entry($class,$registry,"database error for $registry: $error",$token);
    exit 0;
}

# set the stop signals, probably needs review, depending on how run...
set_signals();

our $connection = new Net::XMPP::Client();

$connection->SetCallBacks(
    message  => \&in_message,
    presence => \&in_presence,
    iq       => \&in_iq
);

my $status = $connection->Connect(
    hostname => $server,
    port     => $port
);

if ( !( defined($status) ) ) {
    print "ERROR:  Jabber server is down or connection was not allowed.\n";
    print "        ($!)\n";
    exit(0);
}

=item signed_presence_not_working

#my $gpg = new GnuPG( 'trace' => $trace );

#FIXME: Signed prssence to be sorted out, something in the Perl libraries
# input but not put into the presence XML stanza


$gpg->sign(
    plaintext  => "/tmp/online.txt",
    passphrase => $passphrase,
    output     => "/tmp/sign.txt",
    'armor'    => 1
);

=cut

my $signature = 'dummy signature for testing';

my @result = $connection->AuthSend(
    username => $username,
    password => $password,

    # registry is used as resource at present...
    resource => $resource

);

if ( $result[0] ne "ok" ) {
    print "ERROR: Authorization failed: $result[0] - $result[1]\n";
    exit(0);
}

print "Logged in to $server:$port...\n";

$connection->RosterGet();

print "Getting Roster to tell server to send presence info...\n";
my %x;

###my $pres = new Net::XMPP::Presence(%x, 'signature' => $signature) ;

# this doesn't seem to send anything in the signature stanza though...
$connection->PresenceSend( 'signature' => $signature );

print "Sending presence to tell world that we are logged in...\n";

while ( defined( $connection->Process() ) ) { }

print "ERROR: The connection was killed...\n";

exit(0);

