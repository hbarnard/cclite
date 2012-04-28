
=head1 NAME

Ccsmsgateway.pm

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
-> Confirm pin         p123456 confirm
-> Change pin          p123456 change p345678
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

package Ccsms::Gammu;

use strict;

###use re 'debug';  # debugging for regular expressions, useful for problematic SMS messages

use vars qw(@ISA @EXPORT);
use Exporter;
my $VERSION = 1.00;

@ISA = qw(Exporter);

use Cclite;
use Cclitedb;
use Ccu;
use Ccsecure;
use Ccconfiguration;    # new style configuration method
use Data::Dumper;

###open (STDERR, ">&STDOUT"); # send STDERR out to page, then view source when debugging regular expressions

@EXPORT = qw(
  gateway_sms_transaction
);

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash
 
=cut

# messages will now use decide_language to get language, in Ccu.pm 08/2011
our %messages = readmessages();

#============== change the configuration to your registry and currency for sms

my %sms_configuration =
  readconfiguration('/usr/share/cclite/config/readsms.cf');

# this is a little unnecessary, but can stay for a while
our $registry = $sms_configuration{'registry'};
our $currency = $sms_configuration{'currency'};

#=============================================================

=head3 gateway_sms_transaction

This does a validation (could move to ccvalidate) and
an initial parse of the incoming message and
then dispatches to the appropriate internal function

=cut

sub gateway_sms_transaction {

    my ( $class, $configurationref, $fieldsref, $token ) = @_;

    my ( $offset, $limit );

    print "registry is $registry";
    print "incoming data";
    print Dumper $fieldsref;
    print "<br><br>";

    my ( $error, $fromuserref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $$fieldsref{'originator'},
        $token, $offset, $limit );

    print "from user<br/>";
    print Dumper $fromuserref;
    print "<br><br>";

    # log and exit if there's a problem with the received messaged
    if ( defined( $$fieldsref{'status'} ) && $$fieldsref{'status'} > 0 ) {
        my $message =
"$$fieldsref{'message'} from $$fieldsref{'originator'} rejected with status $$fieldsref{'status'}";
        log_entry( 'local', $registry, $message, $token );
        return;
    }

    # no originator, so no lookup or no message...reject
    if ( !length( $$fieldsref{'originator'} ) ) {
        my $message =
"$$fieldsref{'message'} from $$fieldsref{'originator'} $messages{'smsoriginblank'}";
        log_entry( 'local', $registry, $message, $token );
        return;
    }

    # no originator, so no lookup or no message...reject
    if ( !length( $$fieldsref{'message'} ) ) {
        my $message = "$$fieldsref{'originator'} $messages{'smsmessageblank'}";
        log_entry( 'local', $registry, $message, $token );
        return;
    }

    # no one with this number , so no lookup or no message...reject
    if ( !length( $$fromuserref{'userLogin'} ) ) {
        my $message =
          "$$fieldsref{'originator'} $messages{'smsnumbernotfound'}";
        log_entry( 'local', $registry, $message, $token );
        return;
    }

    # initial parse to get transaction type
    my $input = lc( $$fieldsref{'message'} );    # canonical is lower case

    my $pin;
    my $transaction_type;

    # if it hasn't got a pin, not worth carrying on, tell user
    if ( $input =~ m/^p?(\d+)\s+(\w+)/ ) {
        $pin              = $1;
        $transaction_type = $2;
    } else {
        my $message =
          "from: $$fieldsref{'originator'} $input -malformed transaction";
        log_entry( 'local', $registry, $message, $token );
        my ($mail_error) = _send_sms_mail_message(
            'local',
            $registry,
"from: $$fieldsref{'originator'} $input $messages{smsnopindetected}",
            $fromuserref
        );
    }

    # numbers are stored in database as 447855667524 for example
    $$fieldsref{'originator'} =
      format_for_standard_mobile( $$fieldsref{'originator'} );

    # can be ok, locked, waiting, fail
    my $pin_status = _check_pin( $pin, $transaction_type, $fieldsref, $token );

    return if ( $pin_status ne 'ok' );

    # activation is done in _check_pin, these are the allowed operations
    if ( $transaction_type eq 'confirm' ) {    #  p123456 confirm
        return $pin_status;
    } elsif ( $transaction_type eq 'change' ) {    # change pin
        _gateway_sms_pin_change( $fieldsref, $token );

        # allow pay or send as keyword to line up with email style...
    } elsif ( $transaction_type eq 'pay' || $transaction_type eq 'send' )
    {                                              # payment transaction

        print "is a payment transaction";
        print "<br><br>";

        _gateway_sms_pay( $configurationref, $fieldsref, $token );
    } elsif ( $transaction_type eq 'balance' ) {
        _gateway_sms_send_balance( $fieldsref, $token );
    } else {
        my $message =
          "from: $$fieldsref{'originator'} $input -unrecognised transaction";
        log_entry( 'local', $registry, $message, $token );
        return 'unrecognisable transaction';

        # this is a 'bad' transaction of some kind...
    }

    return;
}

=head3 _gateway_sms_pin_change
Change pin, same rules (three tries) about pin locking
=cut

sub _gateway_sms_pin_change {
    my ( $fieldsref, $token ) = @_;
    my ( $offset, $limit );
    my $input = lc( $$fieldsref{'message'} );    # canonical is lower case
    $input =~ m/^p?(\d+)\s+change\s+p?(\d+)\s*$/;
    my $new_pin    = $2;
    my $hashed_pin = text_to_hash($new_pin);

    my $message = $messages{'smspinchanged'};
    my ( $error, $fromuserref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $$fieldsref{'originator'},
        $token, $offset, $limit );

    $$fromuserref{'userPin'}      = $hashed_pin;
    $$fromuserref{'userPinTries'} = 3;

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $fromuserref,
        $token );

    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $fromuserref );

    return;
}

=head3 _gateway_sms_pay

Specific transaction written for the tpound
using the gateway messaging gateway, may need modification for other gateways


=cut

sub _gateway_sms_pay {
    my ( $configurationref, $fieldsref, $token ) = @_;
    my ( %fields, %transaction, $offset, $limit, $class, $pages, @status );
    %fields = %$fieldsref;

    my ( $error, $fromuserref ) =
      get_where( $class, $registry, 'om_users', '*', 'userMobile',
        $fields{'originator'}, $token, $offset, $limit );

    # begin parse on whitespace
    my $input = lc( $fields{'message'} );    # canonical is lower case

    my ( $parse_type, $transaction_description_ref ) =
      _sms_message_parse($input);

    print "after parse<br/>";
    print Dumper $transaction_description_ref;
    print "<br><br>";

    # sms pay message didn't parse, not worth proceeding
    if ( $parse_type == 0 ) {
        my $message =
"pay attempt from $fields{'originator'} to $$transaction_description_ref{'tomobilenumber'} : $messages{'smsinvalidsyntax'}";
        log_entry( 'local', $registry, $message, $token );
        my ($mail_error) =
          _send_sms_mail_message( 'local', $registry, $message, $fromuserref );
        return;
    }

    # numbers are stored as 447855667524 for example
    $$transaction_description_ref{'tomobilenumber'} =
      format_for_standard_mobile(
        $$transaction_description_ref{'tomobilenumber'} );
    my ( $error1, $touserref );

    # contains only figures so it's a mobile number
    if ( $$transaction_description_ref{'touserormobile'} =~ /^\d+\z/ ) {
        ( $error1, $touserref ) =
          get_where( $class, $registry, 'om_users', '*', 'userMobile',
            $$transaction_description_ref{'touserormobile'},
            $token, $offset, $limit );
    } else {

        # else it's a userLogin ...
        ( $error1, $touserref ) =
          get_where( $class, $registry, 'om_users', '*', 'userLogin',
            $$transaction_description_ref{'touserormobile'},
            $token, $offset, $limit );
    }

    # one of the above lookups fails, reject the whole transaction
    push @status, $messages{'smsnoorigin'}      if ( !length($fromuserref) );
    push @status, $messages{'smsnodestination'} if ( !length($touserref) );

    # recipient didn't confirm pin yet, transaction invalid
    if ( length( $$touserref{'userPinStatus'} )
        && $$touserref{'userPinStatus'} ne 'active' )
    {
        push @status, $messages{smsunconfirmedpin};

    }

    my $errors = join( ':', @status );
    if ( scalar(@status) > 0 ) {
        _send_sms_mail_message( 'local', $registry, "$errors $input",
            $fromuserref );
        my $message =
"pay attempt from $fields{'originator'} to $$transaction_description_ref{'tomobilenumber'} : $errors";
        log_entry( 'local', $registry, $message, $token );
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
    $transaction{tradeAmount} = $$transaction_description_ref{'quantity'};

#FIXME: tradeCurrency : if mentioned in sms overrides default: may not be a good idea?
    $transaction{tradeCurrency} = $$transaction_description_ref{'currency'}
      || $currency;

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $transaction{tradeDate} = $date;

    #tradeTitle : added by this routine: now improved 12/2008
    $transaction{tradeTitle} =
"$messages{'smstransactiontitle'} $$fromuserref{'userLogin'} -> $$touserref{'userLogin'}";

    #tradeDescription
    $transaction{tradeDescription} =
      $$transaction_description_ref{'description'};

    #tradeDestination : ddawg
    $transaction{tradeDestination} = $$touserref{userLogin};

    #tradeSource : manager
    $transaction{tradeSource} = $$fromuserref{userLogin};

    # tradestatus from configured initial status
    $transaction{tradeStatus} = $fields{initialPaymentStatus};

    #FIXME: tradeItem not really identifiable from sms message
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

        my $message = <<EOT;
$error3    SMS $messages{'transactionrejected'} $messages{'to'} $transaction{tradeDestination} $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

    }

    _send_sms_mail_message( 'local', $registry, $message, $fromuserref );

    return;
}

=head3 _gateway_sms_send_balance

Send balance, via email at present, sms later...
To be done...

=cut

sub _gateway_sms_send_balance {

    my ( $fieldsref, $token ) = @_;
    my ( $offset, $limit, $balance_ref, $volume_ref );

    my ( $error, $fromuserref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $$fieldsref{'originator'},
        $token, $offset, $limit );

    my %fields = ( 'userLogin', $$fromuserref{'userLogin'} );
    my $fieldsref = \%fields;

    # html to return html, values to return raw balances and volumes
    # for each currency
    ( $balance_ref, $volume_ref ) =
      show_balance_and_volume( 'local', $registry, $$fromuserref{'userLogin'},
        'values', $token );

    # current balance for this particular currency
    my $balance = $$balance_ref{$currency};
    my $balance_message =
"$messages{smsthebalancefor} $fromuserref->{userLogin} $messages{at} $registry $messages{is} $balance $currency"
      . "s";
    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $balance_message,
        $fromuserref );

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

# 10 limes to 447779159453|test2 at dalston for numbering : registry is thrown away, ocmpatiblity with email
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
        log_entry( 'local', $registry, $message, '' );

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

    my ( $pin, $transaction_type, $fieldsref, $token ) = @_;
    my ( $offset, $limit, $mail_error );

    my $pin_status;
    my $message;
    my $hashed_pin = text_to_hash($pin);

    my ( $error, $fromuserref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $$fieldsref{'originator'},
        $token, $offset, $limit );

    # already locked
    if ( $$fromuserref{'userPinStatus'} eq 'locked' ) {
        $message = $messages{'smslocked'};
        $mail_error =
          _send_sms_mail_message( 'local', $registry, $message, $fromuserref );
        return 'locked';
    }

    # ok, maybe need to reset pin tries though
    if ( $transaction_type ne 'confirm' ) {

        if ( $$fromuserref{'userPin'} eq $hashed_pin ) {
            $pin_status = 'ok';

            return $pin_status
              if ( $$fromuserref{'userPinTries'} == 3 ); # this is the main case
            $$fromuserref{'userPinTries'} = 3;    # reset to three otherwise

        } elsif ( $$fromuserref{'userPinTries'} > 1 ) {
            $pin_status = 'fail';
            $message    = $messages{'smspinfail'};
            $$fromuserref{'userPinTries'}--;      # used one pin attempt
        } elsif ( $$fromuserref{'userPinTries'} <= 1 ) {
            $pin_status = 'locked';
            $message    = "$registry: $messages{'smslocked'}";
            $$fromuserref{'userPinStatus'} = 'locked';
            $$fromuserref{'userPinTries'}  = 0;
        }
    }

    # waiting and confirm
    if (   ( $$fromuserref{'userPinStatus'} ne 'locked' )
        && ( $transaction_type eq 'confirm' ) )
    {

        if ( $$fromuserref{'userPin'} eq $hashed_pin ) {
            $pin_status = 'ok';
            $message    = $messages{smspinactive};
            $$fromuserref{'userPinTries'} = 3;    # reset or set pin tries to 3
            $$fromuserref{'userPinStatus'} = 'active';
        } elsif ( $$fromuserref{'userPinTries'} > 1 ) {
            $pin_status = 'fail';
            $message    = $messages{'smspinfail'};
            $$fromuserref{'userPinTries'}--;      # used one pin attempt
        } elsif ( $$fromuserref{'userPinTries'} <= 1 ) {
            $pin_status                    = 'locked';
            $$fromuserref{'userPinTries'}  = 0;
            $message                       = $messages{'smslocked'};
            $$fromuserref{'userPinStatus'} = 'locked';
        }
    }

    # anything getting to here, needs to update the user record
    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $fromuserref,
        $token );

    if ( length($message) ) {
        $mail_error =
          _send_sms_mail_message( 'local', $registry, $message, $fromuserref );
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

    my ( $class, $registry, $message, $fromuserref ) = @_;
    my ( $mail_error, $urlstring, $hash, $smtp );

    my %configuration = readconfiguration();

    my $mail_error = notify_by_mail(
        $class,
        $registry,
        $$fromuserref{'userName'},
        $$fromuserref{'userEmail'},
        $configuration{'systemmailaddress'},
        $configuration{'systemmailreplyaddress'},
        $$fromuserref{'userLogin'},
        $smtp,
        $urlstring,
        $message,
        4,
        $hash
    );

    return $mail_error;

}

=head3 _send_cardboardfish_sms_receipt

This is specific to cardboardfish and is therefore marked as such
Sends an sms message to confirm payment and send back balances

=cut

sub _send_gammu_sms_receipt {

    my ( $class, $registry, $type, $message, $from_user_ref, $to_user_ref,
        $transaction_ref )
      = @_;

    #FIXME: add on sponsor message, if present, need rotating etc. etc.
    $message .= " $sms_configuration{'sms_sponsor_message'}"
      if ( length( $sms_configuration{'sms_sponsor_message'} ) );

#FIXME: note that SA source address is cclite for balance, maybe same for credit?

    my $urlstring;

    #FIXME: not read properly from the configuration file...

    if ( $type eq 'credit' ) {

        $to_user_ref->{'userMobile'} $message

    } elsif ( $type = 'balance' ) {

        $from_user_ref->{'userMobile'} $message

    } else {
        my $message = "unknown or unimplemented sms type: $type";
        log_entry( 'local', $registry, $message, '' );
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
        log_entry( 'local', $registry, $message, '' );
        return "$messages{smserror} $http_response->code";
    }
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

1;

