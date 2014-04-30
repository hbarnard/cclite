
=head1 NAME

Cardboardfish.pm

=head1 SYNOPSIS

Transaction conversion interfaces inwards for sms, mail etc.
via commercial sms gateway this will have to be modified
for any new gateway supplier

=head1 DESCRIPTION

This contains the interface for a complete sms based payment
system with pins supplied in the sms messages. The allowed messages are:

This does a small parse of the incoming message:

gwNumber  	The destination number
originator 	The sender's number in format 447779159452
message 	The message body
smsTime 	Time when the sms was sent
		Format: YYYY-MM-DD HH:MM:SS
timeZone 	An integer, indicating time zone
		(eg: if timeZone is 1 then it means smsTime is GMT + 1)
network 	Name of the originating network.
		Will be replaced with an SMSC reference number if the network is not recognised
id 		A unique identifier for the message
time 		Time the message received by gateway (UK time)
		Format: YYYY-MM-DD HH:MM:SS
coding 		Message coding 7 (normal), 8 (binary) or 16 (unicode)
status 		0 - Normal Message
		1 - Concatenated message, sent unconcatenated
		2 - Indecipherable UDH (possibly corrupt message)

status added for error messages



and dispatches to the appropriate internal function

Pin number is always first thing...

SMS Transactions
-> Confirm pin         p123456 confirm-> Change pin          p123456 change p345678
-> Pay                 p123456 pay 5 to 07855 524667 for stuff (note need to change strip regex)
                       p123456 pay 5 to 07855524667 for other stuff
                       p123456 pay 5 to 4407855 524667 for stuff

-> Query Balance       p123456 balance (not implemented yet will use one credit!)


=head1 AUTHOR

Hugh Barnard



=head1 SEE ALSO

Cchooks.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 - 2008 GPL Licenced
 
=cut    

package Ccsms::Cardboardfish;

use strict;

###use re 'debug';  # debugging for regular expressions, useful for problematic SMS messages

use vars qw(@ISA @EXPORT);
use Exporter;
my $VERSION = 1.00;

@ISA = qw(Exporter);

use LWP::UserAgent;

use Cclite;
use Cclitedb;
use Ccu;
use Ccsecure;
use Ccconfiguration;    # new style configuration method

###open (STDERR, ">&STDOUT"); # send STDERR out to page, then view source when debugging regular expressions

@EXPORT = qw(
  gateway_sms_transaction
  debug_hash_contents
  convert_cardboardfish
);

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash
 
=cut

#============== change the configuration to your registry and currency for sms

# messages will now use decide_language to get language, in Ccu.pm 08/2011
our %messages = readmessages();
my %configuration     = readconfiguration();
my %sms_configuration = readconfiguration('../../config/readsms.cf');

# this is a little unnecessary, but can stay for a while
our $registry     = $sms_configuration{'registry'};
our $currency     = $sms_configuration{'currency'};
our $sms_user     = $sms_configuration{'sms_user'};
our $sms_password = $sms_configuration{'sms_password'};

# this is the literal for source address SA in Cardboardfish protocol
our $sms_SA              = $sms_configuration{'sms_SA'};
our $sms_sponsor_message = $sms_configuration{'sms_sponsor_message'};

# FIXME: need this because the transaction return needs it
my $pages = new HTML::SimpleTemplate("$configuration{'templates'}/$language");

#=============================================================

=head3 debug_hash_contents

debug the contents of a hash, with stamp for calling routine

=cut

sub debug_hash_contents {

    my ($fields_ref) = @_;
    my $x;

    foreach my $hash_key ( keys %$fields_ref ) {
        $x .= "$hash_key: $fields_ref->{$hash_key}\n";

    }
    my ( $package, $filename, $line ) = caller;
    return;
}

=head3 gateway_sms_transaction

This does a validation (could move to ccvalidate) and
an initial parse of the incoming message and
then dispatches to the appropriate internal function

=cut

sub gateway_sms_transaction {

    my ( $class, $configurationref, $fields_ref, $token ) = @_;

    my ( $offset, $limit, $pin, $transaction_type );

    # no originator, so no lookup or no message...reject

    if ( !length( $fields_ref->{'originator'} ) ) {
        my $message =
"$fields_ref->{'message'} from $fields_ref->{'originator'} $messages{'smsoriginblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return;
    }

    # numbers are stored in database as 447855667524 for example
    $fields_ref->{'originator'} =
      format_for_standard_mobile( $fields_ref->{'originator'} );

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # no originator, so no lookup or no message...reject
    if ( !length( $fields_ref->{'message'} ) ) {
        my $message =
          "$fields_ref->{'originator'} $messages{'smsmessageblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return;
    }

    # no one with this number , so no lookup or no message...reject
    if ( !length( $from_user_ref->{'userLogin'} ) ) {
        my $message =
          "$fields_ref->{'originator'} $messages{'smsnumbernotfound'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return;
    }

    # initial parse to get transaction type
    my $input = lc( $fields_ref->{'message'} );    # canonical is lower case

    # if it hasn't got a pin, not worth carrying on, tell user
    if ( $input =~ m/^p?(\d+)\s+(\w+)/ ) {
        $pin              = $1;
        $transaction_type = $2;
    } else {
        my $message =
          "from: $fields_ref->{'originator'} $input -malformed transaction";
        log_entry( 'local', $registry, 'error', $message, $token );
        my ($mail_error) = _send_sms_mail_message(
            'local',
            $registry,
"from: $fields_ref->{'originator'} $input $messages{smsnopindetected}",
            $from_user_ref
        );
    }

    # can be ok, locked, waiting, fail
    my $pin_status = _check_pin( $pin, $transaction_type, $fields_ref, $token );

    return if ( $pin_status ne 'ok' );

    # activation is done in _check_pin, these are the allowed operations
    if ( $transaction_type eq 'confirm' ) {    #  p123456 confirm
        return $pin_status;
    } elsif ( $transaction_type eq 'change' ) {    # change pin
        _gateway_sms_pin_change( $fields_ref, $token );

        # allow pay or send as keyword to line up with email style...
    } elsif ( $transaction_type eq 'pay' || $transaction_type eq 'send' )
    {                                              # payment transaction
        _gateway_sms_pay( $configurationref, $fields_ref, $token );
    } elsif ( $transaction_type eq 'balance' ) {
        _gateway_sms_send_balance( $fields_ref, $token );
    } else {
        my $message =
          "from: $fields_ref->{'originator'} $input -unrecognised transaction";
        log_entry( 'local', $registry, 'error', $message, $token );
        return 'unrecognisable transaction';

        # this is a 'bad' transaction of some kind...
    }

    return;
}

=head3 _gateway_sms_pin_change
Change pin, same rules (three tries) about pin locking
=cut

sub _gateway_sms_pin_change {
    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit );
    my $input = lc( $fields_ref->{'message'} );    # canonical is lower case
    $input =~ m/^p?(\d+)\s+change\s+p?(\d+)\s*$/;
    my $new_pin    = $2;
    my $hashed_pin = text_to_hash($new_pin);

    my $message = $messages{'smspinchanged'};
    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    $from_user_ref->{'userPin'}      = $hashed_pin;
    $from_user_ref->{'userPinTries'} = 3;

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $from_user_ref,
        $token );

    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

    return;
}

=head3 _gateway_sms_pay

Specific transaction written for the tpound
using the gateway messaging gateway, may need modification for other gateways


=cut

sub _gateway_sms_pay {
    my ( $configurationref, $fields_ref, $token ) = @_;
    my ( %fields, %transaction, $offset, $limit, $class, $pages, @status );
    %fields = %$fields_ref;

    my ( $error, $from_user_ref ) =
      get_where( $class, $registry, 'om_users', '*', 'userMobile',
        $fields{'originator'}, $token, $offset, $limit );

    # begin parse on whitespace
    my $input = lc( $fields{'message'} );    # canonical is lower case

    my ( $parse_type, $transaction_description_ref ) =
      _sms_message_parse($input);

    # sms pay message didn't parse, not worth proceeding
    if ( $parse_type == 0 ) {
        my $message =
"pay attempt from $fields{'originator'} to $transaction_description_ref->{'tomobilenumber'} : $messages{'smsinvalidsyntax'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        my ($mail_error) = _send_sms_mail_message( 'local', $registry, $message,
            $from_user_ref );
        return;
    }

    # numbers are stored as 447855667524 for example
    $transaction_description_ref->{'tomobilenumber'} =
      format_for_standard_mobile(
        $transaction_description_ref->{'tomobilenumber'} );
    my ( $error1, $to_user_ref );

    # contains only figures so it's a mobile number
    if ( $transaction_description_ref->{'touserormobile'} =~ /^\d+\z/ ) {
        ( $error1, $to_user_ref ) =
          get_where( $class, $registry, 'om_users', '*', 'userMobile',
            $transaction_description_ref->{'touserormobile'},
            $token, $offset, $limit );
    } else {

        # else it's a userLogin ...
        ( $error1, $to_user_ref ) =
          get_where( $class, $registry, 'om_users', '*', 'userLogin',
            $transaction_description_ref->{'touserormobile'},
            $token, $offset, $limit );
    }

    # one of the above lookups fails, reject the whole transaction
    push @status, $messages{'smsnoorigin'}      if ( !length($from_user_ref) );
    push @status, $messages{'smsnodestination'} if ( !length($to_user_ref) );

    # recipient didn't confirm pin yet, transaction invalid
    if ( length( $to_user_ref->{'userPinStatus'} )
        && $to_user_ref->{'userPinStatus'} ne 'active' )
    {
        push @status, $messages{smsunconfirmedpin};

    }

    my $errors = join( ':', @status );
    if ( scalar(@status) > 0 ) {
        _send_sms_mail_message( 'local', $registry, "$errors $input",
            $from_user_ref );
        my $message =
"pay attempt from $fields{'originator'} to $transaction_description_ref->{'tomobilenumber'} : $errors";
        log_entry( 'local', $registry, 'error', $message, $token );
        return;
    }

    # convert to standard transaction input format, fields etc.
    #fromregistry : chelsea
    $transaction{fromregistry} = $registry;

    # no home, not a web transaction
    $transaction{home} = "";

    #subaction : om_trades
    $transaction{subaction} = 'om_trades';

    #toregistry : dalston
    $transaction{toregistry} = $registry;

    #tradeAmount : 23
    $transaction{tradeAmount} = $transaction_description_ref->{'quantity'};

#FIXME: tradeCurrency : if mentioned in sms overrides default: may not be a good idea?
    $transaction{tradeCurrency} = $transaction_description_ref->{'currency'}
      || $currency;

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = Ccu::getdateandtime( time() );
    $transaction{tradeDate} = $date;

    #tradeTitle : added by this routine: now improved 12/2008
    $transaction{tradeTitle} =
"$messages{'smstransactiontitle'} $from_user_ref->{'userLogin'} -> $to_user_ref->{'userLogin'}";

    #tradeDescription
    $transaction{tradeDescription} =
      $transaction_description_ref->{'description'};

    #tradeDestination : ddawg
    $transaction{tradeDestination} = $to_user_ref->{userLogin};

    #tradeSource : manager
    $transaction{tradeSource} = $from_user_ref->{userLogin};

    # tradestatus from configured initial status
    $transaction{tradeStatus} = $fields{initialPaymentStatus};

#FIXME: tradeItem not really identifiable from sms message/possible tax problem too!
    $transaction{tradeItem} = 'other';

 #FIXME: mode for this is csv, this is part of a general format upgrade later...
    $transaction{mode} = 'csv';

    # call ordinary transaction
    my $transaction_ref = \%transaction;

    my ( $metarefresh, $home, $error3, $output_message, $page, $c ) =
      transaction( 'sms', $transaction{fromregistry},
        'om_trades', $transaction_ref, $pages, $token );

    #build explicative message, transaction can fall at last hurdle
    #
    my $message;

    if ( !length($error3) ) {
        $message = <<EOT;
SMS $messages{'transactionaccepted'} $messages{'to'} $transaction{tradeDestination} $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

    } else {

        $message = <<EOT;
$error3    SMS $messages{'transactionrejected'} $messages{'to'} $transaction{tradeDestination} $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

    }

    _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

   # send SMS receipt, only if turned on for the user...
   #FIXME: doesn't deal with SMS for failed transactions, does it to be defined!
    if ( $to_user_ref->{'userSmsreceipt'} && ( !length($error3) ) ) {

        _send_cardboardfish_sms_receipt( $class, $registry, 'credit', $message,
            $from_user_ref, $to_user_ref, $transaction_ref );
    }

    return;
}

=head3 _gateway_sms_send_balance

Send balance, via email at present, sms later...
To be done...

=cut

sub _gateway_sms_send_balance {

    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit, $balance_ref, $volume_ref );

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    my %fields = ( 'userLogin', $from_user_ref->{'userLogin'} );
    my $fields_ref = \%fields;

# html to return html, values to return raw balances and volumes for each currency

    ( $balance_ref, $volume_ref ) =
      show_balance_and_volume( 'local', $registry,
        $from_user_ref->{'userLogin'},
        'values', $token );

    ###debug_hash_contents($balance_ref) ;
    ###debug_hash_contents($volume_ref) ;

    # current balance for this particular currency
    my $balance = $balance_ref->{$currency};
    my $balance_message =
"$messages{smsthebalancefor} $from_user_ref->{userLogin} $messages{at} $registry $messages{is} $balance $currency"
      . "s";
    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $balance_message,
        $from_user_ref );

    # send SMS balance, only if turned on for the user...new 16.08.2010
    # blank transaction ref, need to make 1 unit sms currency transaction
    my ( %transaction, $class, $to_user_ref );

    if ( $from_user_ref->{'userSmsreceipt'} ) {
        _send_cardboardfish_sms_receipt( $class, $registry, 'balance',
            $balance_message, $from_user_ref, $to_user_ref, \%transaction );
    }

    return;
}

=head3 sms_message_parse

This is now distinct from the transaction preparation etc.

Also, it returns a status, if the parse doesn't contain one
of the necessary elements for a successful transaction. In that
case the transaction -must- fail and it's not worth continuing

=cut

sub _sms_message_parse {

    my ($input) = @_;

    my $save_input = $input;

    my %transaction_description;
    my $parse_type = 0;

    # make the parse simpler by stripping pin and keyword
    $input =~ s/^p?(\d+)\s+(send|pay)\s+//;

  # currently allowed sms pay formats, some flexiblity, people won't remember...
  # 10 to 447779159453|test2

    $parse_type = 1 if ( $input =~ /^(\d+)\s+to\s+(\d{10,12}|\w+)\s*\z/xmis );

    # 10 limes to 447779159453|test2
    $parse_type = 2
      if ( $input =~ /^(\d+)\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s*\z/xmis );

    # 10 to 447779159453|test2 for numbering
    $parse_type = 3
      if ( $input =~ /^(\d+)\s+to\s+(\d{10,12}|\w+)\s+for\s+(.*)\z/xmis );

    # 10 limes to 447779159453|test2 for numbering
    $parse_type = 4
      if (
        $input =~ /^(\d+)\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s+for\s+(.*)\z/xmis );

# 10 limes to 447779159453|test2 at dalston for numbering : registry is thrown away, compatiblity with email
    $parse_type = 5
      if ( $input =~
        /^(\d+)\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s+at\s+(\w+)\s+for\s+(.*)\z/xmis
      );

    # touserormobile is resolved above when looking up om_users...
    if ( $parse_type == 1 ) {
        $transaction_description{'quantity'} = $1;
        $transaction_description{'currency'} =
          $currency;    # taken from top of package
        $transaction_description{'touserormobile'} = $2;

    } elsif ( $parse_type == 2 ) {

        $transaction_description{'quantity'} = $1;
        $transaction_description{'currency'} =
          $2;           # FIXME: dangerous, override with $currency?
        $transaction_description{'touserormobile'} = $3;

    } elsif ( $parse_type == 3 ) {

        $transaction_description{'quantity'}       = $1;
        $transaction_description{'currency'}       = $currency;
        $transaction_description{'touserormobile'} = $2;
        $transaction_description{'description'}    = $3;

    } elsif ( $parse_type == 4 ) {

        $transaction_description{'quantity'} = $1;
        $transaction_description{'currency'} =
          $2;    # FIXME: dangerous, override with $currency?
        $transaction_description{'touserormobile'} = $3;
        $transaction_description{'description'}    = $4;

    } elsif ( $parse_type == 5 ) {

        $transaction_description{'quantity'} = $1;
        $transaction_description{'currency'} =
          $2;    # FIXME: dangerous, override with $currency?
        $transaction_description{'touserormobile'} = $3;
        $transaction_description{'registryunused'} =
          $4;    # this is the registry unused at present
        $transaction_description{'description'} = $5;

    } else {

        my $message = "unparsed pay transaction is:$save_input  $input";
        log_entry( 'local', $registry, 'error', $message, '' );

    }

    # make english language plurals singular for currency, if found...
    $transaction_description{'currency'} =~ s/ies$/y/i;
    $transaction_description{'currency'} =~ s/s$//i;

    my $x = join( "|", %transaction_description );
    return ( $parse_type, \%transaction_description );

}

=head3 _check_pin

put the pin checking and locking processing into one place
used by every transansaction

returns:
ok 	- pin checks
locked 	- account is locked
waiting - account is not activated/transaction attempt
fail	- pin fail, counts down one off counter/locks if zero

less than 1 is test for try count, just-in-case

=cut

sub _check_pin {

    my ( $pin, $transaction_type, $fields_ref, $token ) = @_;
    my ( $offset, $limit, $mail_error );

    my $pin_status;
    my $message;
    my $hashed_pin = text_to_hash($pin);

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # already locked
    if ( $from_user_ref->{'userPinStatus'} eq 'locked' ) {
        $message = $messages{'smslocked'};
        $mail_error = _send_sms_mail_message( 'local', $registry, $message,
            $from_user_ref );
        return 'locked';
    }

    # ok, maybe need to reset pin tries though
    if ( $transaction_type ne 'confirm' ) {

        if ( $from_user_ref->{'userPin'} eq $hashed_pin ) {
            $pin_status = 'ok';

            return $pin_status
              if ( $from_user_ref->{'userPinTries'} == 3 )
              ;    # this is the main case
            $from_user_ref->{'userPinTries'} = 3;    # reset to three otherwise

        } elsif ( $from_user_ref->{'userPinTries'} > 1 ) {
            $pin_status = 'fail';
            $message    = $messages{'smspinfail'};
            $from_user_ref->{'userPinTries'}--;      # used one pin attempt
        } elsif ( $from_user_ref->{'userPinTries'} <= 1 ) {
            $pin_status = 'locked';
            $message    = "$registry: $messages{'smslocked'}";
            $from_user_ref->{'userPinStatus'} = 'locked';
            $from_user_ref->{'userPinTries'}  = 0;
        }
    }

    # waiting and confirm
    if (   ( $from_user_ref->{'userPinStatus'} ne 'locked' )
        && ( $transaction_type eq 'confirm' ) )
    {

        if ( $from_user_ref->{'userPin'} eq $hashed_pin ) {
            $pin_status = 'ok';
            $message    = $messages{smspinactive};
            $from_user_ref->{'userPinTries'} = 3;  # reset or set pin tries to 3
            $from_user_ref->{'userPinStatus'} = 'active';
        } elsif ( $from_user_ref->{'userPinTries'} > 1 ) {
            $pin_status = 'fail';
            $message    = $messages{'smspinfail'};
            $from_user_ref->{'userPinTries'}--;    # used one pin attempt
        } elsif ( $from_user_ref->{'userPinTries'} <= 1 ) {
            $pin_status                       = 'locked';
            $from_user_ref->{'userPinTries'}  = 0;
            $message                          = $messages{'smslocked'};
            $from_user_ref->{'userPinStatus'} = 'locked';
        }
    }

    # anything getting to here, needs to update the user record
    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $from_user_ref,
        $token );

    if ( length($message) ) {
        $mail_error = _send_sms_mail_message( 'local', $registry, $message,
            $from_user_ref );
    }

    return $pin_status;
}

=head3 _send_sms_mail_message

wrapper for notify_by_mail in package Cclite
with notification type 4

Within notify_by_mail, if net_smtp is switched on, the registry account rather
than the cclite.cf account is used for the mailout, this is preferred because
it separates 'business' between registries 11/2009

=cut

sub _send_sms_mail_message {

    my ( $class, $registry, $message, $from_user_ref ) = @_;
    my ( $mail_error, $urlstring, $hash, $smtp );

    my $mail_error = notify_by_mail(
        $class,
        $registry,
        $from_user_ref->{'userName'},
        $from_user_ref->{'userEmail'},
        $configuration{'systemmailaddress'},
        $configuration{'systemmailreplyaddress'},
        $from_user_ref->{'userLogin'},
        $smtp,
        $urlstring,
        $message,
        4,
        $hash
    );

    return $mail_error;

}

=head3 convert_cardboardfish

Convert incoming fields as per cardboardfish specification
Now deals with multiple messages parts and more stable data formats...

# cardboardfish plugin for this message format
# -1:[SOURCE]:DESTINATION:DCS::DATETIME:[UDH]:[MESSAGE]
#  1#-1:447779159452:447624804344:1::1274627205::53656E6420352020746F20746573743220666F72206261726B696E67

=cut

sub convert_cardboardfish {
    my ($input) = @_;

    $input =~ /^(\d+)/;    # this is the count for messages
    my $count = $1;
    $input =~ s/^(\d+)//;    # remove the count

    my @raw_messages = split( /\#/, $input );
    my @message_hash_refs;

    foreach my $raw_message (@raw_messages) {
        my %message_hash;
        (
            $message_hash{'status'},      $message_hash{'originator'},
            $message_hash{'destination'}, $message_hash{'dcs'},
            $message_hash{'notused'},     $message_hash{'datetime'},
            $message_hash{'udh'},         $message_hash{'message'}
        ) = split( /:/, $raw_message );

        $message_hash{'message'} = _hex_to_ascii( $message_hash{'message'} );

        # push a reference to this onto a list to be returned
        push @message_hash_refs, \%message_hash;

    }    # endof foreach

    return (@message_hash_refs);

}

=head3 _send_cardboardfish_sms_receipt

This is specific to cardboardfish and is therefore marked as such
Sends an sms message to confirm payment and send back balances

=cut

sub _send_cardboardfish_sms_receipt {

    my ( $class, $registry, $type, $message, $from_user_ref, $to_user_ref,
        $transaction_ref )
      = @_;

    #FIXME: add on sponsor message, if present, need rotating etc. etc.
    $message .= " $sms_configuration{'sms_sponsor_message'}"
      if ( length( $sms_configuration{'sms_sponsor_message'} ) );

#FIXME: note that SA source address is cclite for balance, maybe same for credit?

    my $urlstring;

    #FIXME: not read properly from the configuration file...
    $sms_configuration{'sms_DR'} ||= 0;

#FIXME: note that ST=5 for alphanumeric sender probably needs to be 'cclite' for all originating SMSes that needs to be linked to help-desk

    if ( $type eq 'credit' ) {
        $urlstring = <<EOT;
http://sms2.cardboardfish.com:9001/HTTPSMS?S=H&UN=$sms_user&P=$sms_password&DA=$to_user_ref->{'userMobile'}&SA=$sms_configuration{'sms_SA'}&M=$message&ST=5&DC=$sms_configuration{'sms_DC'}

EOT

    } elsif ( $type = 'balance' ) {

        $urlstring = <<EOT;
http://sms2.cardboardfish.com:9001/HTTPSMS?S=H&UN=$sms_user&P=$sms_password&DA=$from_user_ref->{'userMobile'}&SA=$sms_configuration{'sms_SA'}&M=$message&ST=5&DC=$sms_configuration{'sms_DC'}

EOT

    } else {
        my $message = "unknown or unimplemented sms type: $type";
        log_entry( 'local', $registry, 'error', $message, '' );
        return "$messages{smserror} $type";

    }

    # use LWP to send an SMS message via the cardborardfish gateway...
    my ($http_response) = __outbound_cardboardfish_http_sms($urlstring);

    my $ret = $http_response->code();

    if ( $http_response->code == 200 ) {
        _charge_one_sms_unit( $class, $registry, $type, $from_user_ref,
            $transaction_ref );
    } else {
        my $message = "$messages{smserror} $http_response->code";
        log_entry( 'local', $registry, 'error', $message, '' );
        return "$messages{smserror} $http_response->code";
    }
}

=head3 __outbound_cardboardfish_http_sms

Send the SMS message via a web transaction at carboardfish

=cut

sub __outbound_cardboardfish_http_sms {

    my ($sms_url) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->agent("cclite\/$configuration{'version'}");
    $ua->timeout(10);
    my $response = $ua->get($sms_url);
    return ($response);
}

=head3 _charge_one_sms_unit

Transfer an SMS unit from the transaction originator to sysaccount
to account for the sent SMS

$type is 'credit' or 'balance' at present. In the case of balance
need to build up a few transaction fields to charge it..always charged
to originator and monies put into sysaccount...

=cut

sub _charge_one_sms_unit {

    my ( $class, $registry, $type, $from_user_ref, $transaction_ref ) = @_;

    # for balances, extra fields to fill in are filled anyway by a credit
    if ( $type eq 'balance' ) {

        #subaction : om_trades
        $transaction_ref->{'subaction'} = 'om_trades';

        #toregistry : dalston
        $transaction_ref->{'fromregistry'} = $registry;

        #toregistry : dalston
        $transaction_ref->{'toregistry'} = $registry;

        $transaction_ref->{'tradeDescription'} =
          "$messages{'smsdebitfor'} $type";

        #tradeSource : manager
        $transaction_ref->{'tradeSource'} = $from_user_ref->{'userLogin'};

    }

#FIXME: tradeItem not really identifiable from sms message/possible tax problem too!
    $transaction_ref->{'tradeItem'} = 'other';

 #FIXME: mode for this is csv, this is part of a general format upgrade later...
    $transaction_ref->{'mode'} = 'csv';

    #FIXME: tradestatus is always accepted for sms-debit
    $transaction_ref->{'tradeStatus'} = 'accepted';

    # if HTTP 200, sent OK charge receipt to one unit of sms currency...
    $transaction_ref->{'tradeAmount'}   = '1';
    $transaction_ref->{'tradeCurrency'} = 'sms';

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = Ccu::getdateandtime( time() );
    $transaction_ref->{'tradeDate'} = $date;

    #tradeTitle : sms debit for sms receipt
    $transaction_ref->{'tradeTitle'} =
      "$messages{'smsdebitfor'} $messages{'smstransactiontitle'}";

    #tradeDestination : sysadmin is credited in sms currency
    $transaction_ref->{'tradeDestination'} = 'sysaccount';

    #FIXME: this should be passed into this subsystem, really...
    my $token;

    my ( $metarefresh, $home, $trans_error, $output_message, $page, $c ) =
      transaction( 'sms', $transaction_ref->{'fromregistry'},
        'om_trades', $transaction_ref, $pages, $token );

    return;
}

sub _ascii_to_hex ($) {
    ## Convert each ASCII character to a two-digit hex number.
    ( my $str = shift ) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
    return $str;
}

sub _hex_to_ascii ($) {
    ## Convert each two-digit hex number back to an ASCII character.
    ( my $str = shift ) =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;
    return $str;
}

1;

