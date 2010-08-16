
=head1 NAME

Cccyrpto.pm

=head1 SYNOPSIS

Open GPG amd support functions for email and jabber transactions

=head1 DESCRIPTION


=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2004-2007 GPL Licenced 

=cut

package Cccrypto;

my $VERSION = 1.00;

@ISA    = qw(Exporter);
@EXPORT = qw(decode_decrypt_reformat
  encrypt_and_sign_notifications
  send_notifications );

use Log::Log4perl;

# these are decryption, transcoding etc. etc.
use MIME::Base64;
use MIME::Decoder;
use GnuPG;

# this is used to parse addresses (logically enough...)
#use Email::Address;

# jabber client library
use Net::XMPP;

use strict;

# for notify_by_mail, at the least
use Cclite;
use Ccconfiguration;

my %configuration = readconfiguration();
Log::Log4perl->init( $configuration{'loggerconfig'} );
our $log = Log::Log4perl->get_logger("Cccrypto");

=head3 decode_decryot_reformat

decode from quoted-printable (Yahoo), decrypt (verfiy signature) and reformat from base64 (Gmail)
there's probably quite a few variations of this, therefore systems are going to have choose/restrict
mail providers or face a lot of complexity in this bit.

The jabber etc. doesn't need the mime decoding, but I've kept for the moment, since all the logic is
pretty much roughed out anyway...everything should really take place /tmp and be cleared out asap,
since there are currently plaintext transactions in there...

Currently tested for Yahoo and Gmail, for obvious reasons, I don't care about hotmail

=cut

sub decode_decrypt_reformat {

    my ( $passphrase, $message, $reformat, $decrypt, $logfile, $trace ) = @_;

    open STDERR, ">>$logfile" if ( length($logfile) );

    # test whether there's actually a transaction in the mail message...
    my $transaction_found = 0;

    my $gpg = new GnuPG( 'trace' => $trace );
    my $decoder = new MIME::Decoder 'quoted-printable' or die "unsupported";

    # decode quoted printable for Yahoo, shouldn't change Gmail content?
    open( MAIL,     $message );
    open( REFORMAT, ">$reformat" );
    $decoder->decode( \*MAIL, \*REFORMAT );
    close(REFORMAT);
    close(MAIL);

    # decrypt the message which should also verify signature, goes into logile
    $gpg->decrypt(
        ciphertext => $reformat,
        output     => $decrypt,
        passphrase => $passphrase,
    );

    my $string;

    # write decrypted message back into string for base64 operation (Gmail)
    open( DECRYPT, $decrypt );
    while (<DECRYPT>) {
        $string .= $_;
    }
    close(DECRYPT);

    my $decoded;
    my ( $header, $base64 ) = split( /base64/, $string );

    # if there's a base64 header, decode otherwise it's fine..
    if ( length($base64) ) {
        $decoded = decode_base64($base64);
    } else {
        $decoded = $string;
    }

    my @lines = split( /\n/, $decoded );

# run through decoded lines and look for transaction line starts with send or SEND

    foreach my $line (@lines) {
        if ( $line =~ /send|balance/i ) {
            return ( 1, $line );
        }    # test for send

    }    #end foreach

    # no transaction line found, return line anyway...
    return ( 0, '' );

}

=head3 encrypt_and_sign_notifications

FIXME: encrypt and sign the receipt using a public key collected from the id in the originator record...either this key
is on a local keyring (done) or can be accessed from the chosen keyserver (not done or tested). These are implementatation 'gaps' or choices
at present...

=cut

sub encrypt_and_sign_notifications {

    my ( $passphrase, $transaction_description_ref, $message, $encrypted,
        $logfile, $trace, $messages_ref )
      = @_;

# need to encrypt with the public key that corresponds to cclite user, via email address, see recipient, below...
    my $encrypted_body;

    if ( length( $transaction_description_ref->{'userPublickeyid'} ) ) {

        open( MAIL, ">$message" );
        print MAIL
"$transaction_description_ref->{'error'}  $transaction_description_ref->{'output_message'}";
        close(MAIL);
        my $gpg = new GnuPG( 'trace' => $trace );
        eval {
            $gpg->encrypt(
                plaintext  => $message,
                output     => $encrypted,
                armor      => 1,
                sign       => 1,
                recipient  => $transaction_description_ref->{'userPublickeyid'},
                passphrase => $passphrase
            );

        };

        open( ENCRYPT, $encrypted );
        while (<ENCRYPT>) {
            $encrypted_body .= $_;
        }
        close(ENCRYPT);

    } else {

        $encrypted_body = $messages_ref->{'noencryptednotification'};
    }

    unlink $message, $encrypted;
    return $encrypted_body;

}

=head3 send_notifications

Send transaction notification to transaction originator

=cut

sub send_notifications {

    my ( $notifications_hash_ref, $passphrase, $message, $encrypted, $logfile,
        $encrypt_notifications, $trace, $messages_ref )
      = @_;

# reference info to the current signature for notify...
# $class (for soap),       $registry(database name),         $name (first name),
# $email (user email),       $systemfrom(not used),       $return_address (not used),
# $accountname (user screen name), $smtp(additional smtp host),             $urlstring (clickable string),
# $text (body text for notification),        $notificationtype(notification code), $hash
    foreach my $transaction_description_ref (@$notifications_hash_ref) {

        # encrypt and sign notifications, only if requested...
        my $body;
        if ($encrypt_notifications) {
            $body =
              encrypt_and_sign_notifications( $passphrase,
                $transaction_description_ref, $message, $encrypted, $logfile,
                $trace, $messages_ref );
        } else {
            $body =
"$transaction_description_ref->{'error'}  $transaction_description_ref->{'output_message'}";
        }

        #FIXME: notify_by_mail and these need sorting out, somewhat
        notify_by_mail(
            'local',
            $transaction_description_ref->{'registry'},
            $transaction_description_ref->{'name'},
            $transaction_description_ref->{'originator_email'},
            '',
            '',
            $transaction_description_ref->{'source'},
            '',
            '',
            $body,
            5,
            ''
        );
    }

    undef @$notifications_hash_ref;

    return;
}

1;

