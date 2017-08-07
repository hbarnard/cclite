
=head1 NAME

Textmarketer.pm

=head1 SYNOPSIS

Transaction conversion interfaces inwards for sms, mail etc.
via commercial sms gateway this will have to be modified
for any new gateway supplier

=head1 DESCRIPTION

This contains the interface for a complete sms based payment
system with pins supplied in the sms messages. The allowed messages are:


and dispatches to the appropriate internal function

Pin number is always first thing can be alphanumeric and is set up as a password
rather than a 5 figure number

SMS Transactions

-> 2cc join                join hugh barnard
                           join hugh barnard hugh.barnard@example.com
                           
                           this sends back a setup message with a web password
                           and a pin for sms etc. everything is active at this stage
                           sets up with sms receipt switched on
                           
-> 2cc suspend             p123456 suspend 

                           suspends the account for fraud and for leaving the system                           
                           
-> 2cc Confirm pin         p123456 confirm [not needed if setup from sms]

-> 2cc Change pin          p123456 change p345678

-> 2cc Pay                 p123456 pay 5 to 07855 524667 for stuff (note need to change strip regex)
                           p123456 pay 5 to 07855524667 for other stuff
                           p123456 pay 5 to 4407855 524667 for stuff
                           p123456 pay test1 10 limes
                           p123456 pay 4477777777 10 limes 
                           

-> Query Balance           p123456 balance


=head1 AUTHOR

Hugh Barnard



=head1 SEE ALSO

Cchooks.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 - 2008 GPL Licenced
 
=cut    

package Ccsms::Textmarketer;

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
use Ccvalidate;
use Ccconfiguration;    # new style configuration method
use Data::Dumper;
use CGI;

use utf8;

###open (STDERR, ">&STDOUT"); # send STDERR out to page, then view source when debugging regular expressions

@EXPORT = qw(
  gateway_sms_transaction
  convert_cardboardfish
  debug
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
our $sms_user     = $sms_configuration{'user'};
our $sms_password = $sms_configuration{'password'};

# hierachy of language decision, probably over the top, really...
our $language =
     $sms_configuration{'language'}
  || $configuration{'language'}
  || 'en';

our @sms_sponsor_messages =
  split( /,/, $sms_configuration{'sponsor_messages'} );

# FIXME: need this because the transaction return needs it
my $pages = {};

# set up debugging from readsms configuration file...
our $debug = $sms_configuration{'debug'};    # don't use LWP just log etc.

#=============================================================

=head3 gateway_sms_transaction

This does a validation (could move to ccvalidate) and
an initial parse of the incoming message and
then dispatches to the appropriate internal function

The textmarketer version goes through a short code which needs to be stripped off
so parsing and validation is different for this...

=cut

sub gateway_sms_transaction {

    my ( $class, $configurationref, $fields_ref, $token ) = @_;

    my ( $offset, $limit, $pin, $transaction_type, $return_value );

    debug( 'fields inwards', $fields_ref );

    # no number, so no lookup or no message...reject
    if ( !length( $fields_ref->{'number'} ) ) {
        my $message =
"$fields_ref->{'message'} from $fields_ref->{'number'} $messages{'smsoriginblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # numbers are stored in database as 447855667524 for example
    $fields_ref->{'number'} =
      format_for_standard_mobile( $fields_ref->{'number'} );

    # setup transaction, special case
    if ( $fields_ref->{'message'} =~ /\s+join\s+/i ) {
        return _gateway_sms_join( $fields_ref, $token );
    }

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'number'},
        $token, $offset, $limit );

    # no number, so no lookup or no message...reject
    if ( !length( $fields_ref->{'message'} ) ) {
        my $message = "$fields_ref->{'number'} $messages{'smsmessageblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # no one with this number , so no lookup or no message...reject
    if ( !length( $from_user_ref->{'userLogin'} ) ) {
        my $message = "$fields_ref->{'number'} $messages{'smsnumbernotfound'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # user record available at this point, so change language to user preferred
    # language...
    $language = $fields_ref->{'language'} = $from_user_ref->{'userLang'};
    %messages = readmessages($language);

    # initial parse to get transaction type
    my $input = lc( $fields_ref->{'message'} );    # canonical is lower case

    # experimental language change...
    if ( $input =~
m/^$sms_configuration{shortcode}\s+(en|zh|ar|pt|nl|el|it|ja|ru|fr|th|de|es|ro|vi|ko|fi|id|bn)/i
      )
    {
        $fields_ref->{'language'} = $1;
        return _gateway_sms_change_language( $fields_ref, $token );
    }

    # if it hasn't got a pin, not worth carrying on, tell user
    if ( $input =~ m/^$sms_configuration{shortcode}\s+p?(\w+)\s+(\w+)/i ) {
        $pin              = $1;
        $transaction_type = $2;
    } else {
        my $message =
          "from: $fields_ref->{'number'} $input -malformed transaction";
        log_entry( 'local', $registry, 'error', $message, $token );
        my ($mail_error) = _send_sms_mail_message(
            'local',
            $registry,
            "from: $fields_ref->{'number'} $input $messages{smsnopindetected}",
            $from_user_ref
        );
        return "nok:$message";
    }

    my $pin_status = _check_pin( $pin, $transaction_type, $fields_ref, $token );

    return "nok:$pin_status" if ( $pin_status ne 'ok' );

    # activation is done in _check_pin, these are the allowed operations

    # strip 2cc or other short code before parsing
    $fields_ref->{'message'} =~ s/^$sms_configuration{shortcode}\s+//i;

    if ( $transaction_type eq 'confirm' ) {    #  p123456 confirm
        return $pin_status;
    } elsif ( $transaction_type eq 'change' ) {    # change pin
        $return_value = _gateway_sms_pin_change( $fields_ref, $token );

        # allow pay or send as keyword to line up with email style...
    } elsif ( $transaction_type eq 'pay' || $transaction_type eq 'send' )
    {                                              # payment transaction
        $return_value =
          _gateway_sms_pay( $configurationref, $fields_ref, $token );
    } elsif ( $transaction_type eq 'balance' ) {
        $return_value = _gateway_sms_send_balance( $fields_ref, $token );
    } elsif ( $transaction_type eq 'suspend' || $transaction_type eq 'freeze' )
    {
        $return_value = _gateway_sms_suspend( $fields_ref, $token );
    } else {
        my $message =
          "from: $fields_ref->{'number'} $input -unrecognised transaction";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";

        # this is a 'bad' transaction of some kind...
    }

    return $return_value;
}

=head3 _gateway_sms_pin_change

Change pin, same rules (three tries) about pin locking

=cut

sub _gateway_sms_pin_change {
    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit, $message, $from_user_ref );
    my $input = lc( $fields_ref->{'message'} );    # canonical is lower case
    $input =~ m/^p?(\w+)\s+change\s+p?(\w+)\s*$/;
    my $new_pin    = $2;
    my $hashed_pin = text_to_hash($new_pin);

    if ( length($new_pin) >= 4 ) {

        $message = "$messages{'smspinchanged'}";
        ( my $error, $from_user_ref ) =
          get_where( 'local', $registry, 'om_users', '*', 'userMobile',
            $fields_ref->{'number'},
            $token, $offset, $limit );

        $from_user_ref->{'userPin'}        = $hashed_pin;
        $from_user_ref->{'userPinTries'}   = 3;
        $from_user_ref->{'userPinChanged'} = getdateandtime( time() );

        my ( undef, $home_ref, undef, $html, $template, undef ) =
          update_database_record( 'local', $registry, 'om_users', 1,
            $from_user_ref, $token );

    } else {

        # pin is too short, not changed...
        $message = "$messages{'smspinnotchanged'}";
    }

    # don't send new pin in email
    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

    # but send it to the user's phone...
    if ( $from_user_ref->{'userSmsreceipt'} ) {
        $message = "$messages{'smspinchanged'}: $new_pin";
        _send_textmarketer_sms_message( 'local', $registry, 'pinchange',
            $message, $from_user_ref, undef, undef );
    }

    return 'ok';
}

=head3 _gateway_sms_suspend

Suspend account, before stopping using or fraud etc.

=cut

sub _gateway_sms_suspend {
    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit );
    my $message = $messages{'smssuspend'};

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'number'},
        $token, $offset, $limit );

    # suspended status for account
    $from_user_ref->{'userStatus'} = 'suspended';

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $from_user_ref,
        $token );

    # send mail to user
    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

    # send mail to registry supervisor
    my ( $status, $registry_ref ) =
      get_where( 'local', $registry, 'om_registry', '*', 'id', '1', $token, '',
        '' );

    notify_by_mail(
        'local',                       $registry,
        undef,                         $registry_ref->{'admemail'},
        undef,                         $registry_ref->{'admemail'},
        $from_user_ref->{'userLogin'}, undef,
        undef,                         $message,
        6,                             undef
    );

    # end of send mail to registry supervisor

    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

    if ( $from_user_ref->{'userSmsreceipt'} ) {
        _send_textmarketer_sms_message( 'local', $registry, 'suspend', $message,
            $from_user_ref, undef, undef );
    }

    return 'ok';
}

=head3 _gateway_sms_change_language

Change user language

=cut

sub _gateway_sms_change_language {
    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit );

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'number'},
        $token, $offset, $limit );

    # change the user language preference...
    $language = $from_user_ref->{'userLang'} = $fields_ref->{'language'};

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1, $from_user_ref,
        $token );

    # user record available at this point, so change language to user preferred
    %messages = readmessages($language);

    my $message = "$messages{'smslanguagechanged'} $fields_ref->{'language'}";

    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $message, $from_user_ref );

    if ( $from_user_ref->{'userSmsreceipt'} ) {
        _send_textmarketer_sms_message( 'local', $registry, 'language',
            $message, $from_user_ref, undef, undef );
    }

    return 'ok';
}

=head3 _gateway_sms_join

Set up new user, warn admin by email?
tell user with password and pin via text message...
status of pin and user is defined by readsms.cf

=cut

sub _gateway_sms_join {

    my ( $fieldsref, $token ) = @_;
    my ( $offset, $limit, $message );
    my $input = lc( $fieldsref->{'message'} );    # canonical is lower case

    ###print $debug_file "in join routine" . Dumper $fieldsref . "\n" if ($debug) ;

    # check not already inscribed
    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fieldsref->{'number'},
        $token, $offset, $limit );

    # there's a user with this number, send sms and refuse
    if ( length( $from_user_ref->{'userId'} ) ) {
        _send_textmarketer_sms_message( 'local', $registry, 'join',
            $messages{'smssetupnumberinuse'},
            $from_user_ref, undef, undef );
        return "nok:$messages{'smssetupnumberinuse'}";
    }

# for example -2cc join hugh Barnard- and
# in general /2cc join first-name last-name/ or /2cc join first-name last-name email/
#  SELECT userLogin FROM om_users where userLogin like 'test%' order by userLogin desc
    my ( $first_name, $last_name, $email );

    if ( $input =~ m/^2cc\s+join\s+(\w+)\s+(\w+)$/i ) {
        $first_name = $1;
        $last_name  = $2;
    } elsif ( $input =~ m/^2cc\s+join\s+(\w+)\s+(\w+)\s+(\S+)$/i ) {
        $first_name = $1;
        $last_name  = $2;
        $email      = $3;
    } else {

        # not enough parseable data to setup
        return "nok:$input $messages{'smsbadjoin'}";
    }

    # validation for email if supplied
    if ( length($email) ) {

        # bad email format, not sure how reliable this is...
        if ( $email !~
/^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/i
          )
        {
            _send_textmarketer_sms_message( 'local', $registry, 'join',
                $messages{'bademail'}, $from_user_ref, undef, undef );
            return 'nok';
        }

        # check that it isn't duplicated
        $fieldsref->{'userEmail'} = $email;
        my $user_ref =
          check_email_exists( 'local', $registry, $fieldsref, \%messages,
            undef, undef, undef );

        # user with this email already exist they must be distinct
        if ( length( $user_ref->{'userId'} ) ) {
            _send_textmarketer_sms_message( 'local', $registry, 'join',
                $messages{'emailexists'},
                $from_user_ref, undef, undef );
            return 'nok';
        }
    }

    # screen names are canonical lower case but...
    # candidate screen name is four of first, three of last
    my $screen_candidate =
      substr( $first_name, 0, 4 ) . substr( $last_name, 0, 3 );

    my ( $registry_error, $hash_ref ) = sqlraw(
        'local',
        $registry,
"SELECT userId,userLogin FROM om_users where lower(userLogin) like \'$screen_candidate%\' order by userLogin asc limit 1",
        'userId',
        ''
    );

    # there's something like this already in the database ;
    my $key = ( keys %$hash_ref )[-1];
    if ( length($key) ) {
        $key++;
        $screen_candidate .= $key;
    }

    #FIXME: remove checkdigit stuff for the moment...
    ###$screen_candidate .= _check_digit_iso_7064($screen_candidate);

    my ( $date, $time ) = getdateandtime( time() );

    # force sms receipt for this kind of setup
    $fieldsref->{'userSmsreceipt'} = 1;

    # FIXME: These should not be hardcoded, 3 tries, not test yet + active
    $fieldsref->{'userPasswordTries'} = 3;
    $fieldsref->{'userPasswordStatus'} =
      $sms_configuration{'userPasswordStatus'};

    $fieldsref->{'userJoindate'} = $date;

    $fieldsref->{'userLevel'} = 'user';
    $fieldsref->{'userLang'}  = $sms_configuration{'language'};

    my $user_password = _generate_password(7);
    $fieldsref->{'userPassword'} = text_to_hash($user_password);
    $fieldsref->{'userPasswordChanged'} =

      $fieldsref->{'userJoindate'} = $date;

    # add name field
    $fieldsref->{'userLogin'} = $screen_candidate;
    $fieldsref->{'userName'}  = "\u$first_name \u$last_name";

    my $user_pin = _generate_password(5);
    $fieldsref->{'userPin'}        = text_to_hash($user_pin);
    $fieldsref->{'userPinChanged'} = $date;

    #FIXME: don't assume that all mobiles are UK based, drop  this..
    $fieldsref->{'userMobile'} =
      format_for_standard_mobile( $fieldsref->{'number'} );
    $fieldsref->{'userPinStatus'} = $sms_configuration{'userPinStatus'};
    $fieldsref->{'userPinTries'}  = 3;

    # status as in the configuration file...
    $fieldsref->{'userStatus'} = $sms_configuration{'userStatus'};

    $fieldsref->{'userEmail'} = $email;    # may be blank of course

    # add the user to the registry database
    my ( $rc, $rv, $record_id ) =
      add_database_record( 'local', $registry, 'om_users', $fieldsref, undef );

    # send setup done message
    my $setup_complete_message = <<EOT;
Dear $first_name
Setup for cclite complete
Screen name: $screen_candidate
Web password: $user_password
SMS PIN: $user_pin    
EOT

    _send_textmarketer_sms_message( 'local', $registry, 'join',
        $setup_complete_message, $fieldsref, undef, undef );
    return 'ok';
}

=head3 _gateway_sms_pay

Specific transaction written for the tpound
using the gateway messaging gateway, may need modification for other gateways


=cut

sub _gateway_sms_pay {
    my ( $configurationref, $fields_ref, $token ) = @_;
    my ( %fields, %transaction, $offset, $limit, $class, $pages, @status,
        $return_value );

    %fields = %$fields_ref;

    my ( $error, $from_user_ref ) = get_where(
        $class,       $registry,         'om_users', '*',
        'userMobile', $fields{'number'}, $token,     $offset,
        $limit
    );

    # FIXME: needs to deliver json etc...
    my $registry_status = get_registry_status(
        ( $class, $registry, 'om_registry', $fields_ref, $token ) );

    # registry is closed or closing...no pay style transactions allowed...
    if ( $registry_status eq 'down' || $registry_status eq 'closing' ) {

        # send SMS to originator to say, can't be done...
        my $message;
        if ( $from_user_ref->{'userSmsreceipt'} ) {

            $message =
                $messages{'registryclosing'} . ':'
              . $messages{'notransfersallowed'};
            _send_textmarketer_sms_message( $class, $registry, 'error',
                $message, $from_user_ref, undef, {} );

        }
        return "nok: $message";

    }

    # begin parse on whitespace
    my $input = lc( $fields{'message'} );    # canonical is lower case

    my ( $parse_type, $transaction_description_ref ) =
      _sms_payment_parse($input);

    debug( "payment parse type is $parse_type\n", undef );

    # sms pay message didn't parse, not worth proceeding
    if ( $parse_type == 0 ) {
        my $message =
"pay attempt from $fields{'number'} to $transaction_description_ref->{'tomobilenumber'} : $messages{'smsinvalidsyntax'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        my ($mail_error) = _send_sms_mail_message( 'local', $registry, $message,
            $from_user_ref );
        return "nok:$input $message";
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
"pay attempt from $fields{'number'} to $transaction_description_ref->{'tomobilenumber'} : $errors";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # convert to standard transaction input format, fields etc.
    #fromregistry : chelsea
    $transaction{'fromregistry'} = $registry;

    # no home, not a web transaction
    $transaction{'home'} = "";

    #subaction : om_trades
    $transaction{'subaction'} = 'om_trades';

    #toregistry : dalston
    $transaction{'toregistry'} = $registry;

    #tradeAmount : 23
    $transaction{'tradeAmount'} = $transaction_description_ref->{'quantity'};

#FIXME: tradeCurrency : if mentioned in sms overrides default: may not be a good idea?
    $transaction{tradeCurrency} = $transaction_description_ref->{'currency'}
      || $currency;

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = Ccu::getdateandtime( time() );
    $transaction{'tradeDate'} = $date;

    #tradeTitle : added by this routine: now improved 12/2008
    $transaction{'tradeTitle'} =
"$messages{'smstransactiontitle'} $from_user_ref->{'userLogin'} -> $to_user_ref->{'userLogin'}";

    #tradeDescription
    $transaction{'tradeDescription'} =
      $transaction_description_ref->{'description'};

    #tradeDestination : ddawg
    $transaction{'tradeDestination'} = $to_user_ref->{'userLogin'};

    #tradeSource : manager
    $transaction{'tradeSource'} = $from_user_ref->{'userLogin'};

    # tradestatus from configured sms config or fall back to initial status
    $transaction{'tradeStatus'} = $sms_configuration{'initialPaymentStatus'}
      || $fields{'initialPaymentStatus'};

#FIXME: tradeItem not really identifiable from sms message/possible tax problem too!
    $transaction{'tradeItem'} = 'other';

 #FIXME: mode for this is csv, this is part of a general format upgrade later...
    $transaction{'mode'} = 'json';

    # call ordinary transaction
    my $transaction_ref = \%transaction;

    my ( $metarefresh, $home, $error3, $output_message, $page, $c ) =
      transaction( 'sms', $transaction{fromregistry},
        'om_trades', $transaction_ref, $pages, $token );

    #build explicative message, transaction can fall at last hurdle
    #
    my ( $message, $type, $mail_message );

    if ( !length($error3) ) {

        # message to receiver of credit is sent in their preferred language
        %messages = readmessages( $to_user_ref->{'userLang'} );

        $type = 'credit';

        # make currencies plural if qty > 1
        if ( $transaction{'tradeAmount'} > 1 ) {
            $transaction{'tradeCurrency'} =~
              s/y$/ies/i;    # english language currencies
            $transaction{'tradeCurrency'} =~ s/$/s/i;
        }

        $message = <<EOT;
SMS $messages{'transactionaccepted'} $messages{'from'} $transaction{tradeSource} $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

        $mail_message = <<EOT;
SMS $messages{'transactionaccepted'} $messages{'to'} $transaction{tradeDestination}  $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

    } else {
        $type         = 'error';
        $return_value = 'nok';

        $mail_message = $message;

        $message = <<EOT;
$error3    SMS $messages{'transactionrejected'} $messages{'to'} $transaction{tradeDestination} $messages{'forvalue'} $transaction{tradeAmount} $transaction{tradeCurrency}
EOT

    }

# note that the mail/sms messages are not the same for payment, the person paying
# gets an email and the paid person gets an sms advising them of payment arrival...
    my $mail_error =
      _send_sms_mail_message( 'local', $registry, $mail_message,
        $from_user_ref );

    debug( undef, $transaction_ref );

   # send SMS receipt, only if turned on for the user...
   #FIXME: doesn't deal with SMS for failed transactions, does it to be defined!
    if ( $to_user_ref->{'userSmsreceipt'} && ( !length($error3) ) ) {

        _send_textmarketer_sms_message( $class, $registry, $type, $message,
            $from_user_ref, $to_user_ref, $transaction_ref );

    }

    if ( $return_value eq 'nok' ) {
        return "nok: $error3 $message";
    } else {
        return 'ok';
    }

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
        $fields_ref->{'number'},
        $token, $offset, $limit );

    my %fields = ( 'userLogin', $from_user_ref->{'userLogin'} );
    my $fields_ref = \%fields;

# html to return html, values to return raw balances and volumes for each currency
# probably should move to json for mobile applications...
    $fields_ref->{'mode'} = 'values';

    ( $balance_ref, $volume_ref ) =
      show_balance_and_volume( 'local', $registry,
        $from_user_ref->{'userLogin'},
        $fields_ref, $token );

    my $literal_currency = $currency;
    $literal_currency =~ s/y$/ies/i;    # make y currencies plural...

    # current balance for this particular currency
    # May 2012 reveal all currencies in the registry, towards sms multicurrency
    my $balance = $balance_ref->{$currency};

    #FIXME: balance ref key is spaces not trading etc.?
    my $balance_table;
    foreach my $key ( sort keys %$balance_ref ) {
        $balance_ref->{$key} =~ s/^\s+$/na/;    # make space = not applicable
        $key =~ s/y$/ies/i;                     # make y currencies plural...
        $balance_table .= "$key:$balance_ref->{$key}\n";
    }

    my $balance_message =
"$messages{smsthebalancefor} $from_user_ref->{userLogin} $messages{at} $registry $messages{is}:\n$balance_table";

    my ($mail_error) =
      _send_sms_mail_message( 'local', $registry, $balance_message,
        $from_user_ref );

    # send SMS balance, only if turned on for the user...new 16.08.2010
    # blank transaction ref, need to make 1 unit sms currency transaction
    my ( %transaction, $class, $to_user_ref );

    if ( $from_user_ref->{'userSmsreceipt'} ) {
        _send_textmarketer_sms_message( $class, $registry, 'balance',
            $balance_message, $from_user_ref, $to_user_ref, \%transaction );
    }

    return;
}

=head3 sms_payment_parse

This is now distinct from the transaction preparation etc.

Also, it returns a status, if the parse doesn't contain one
of the necessary elements for a successful transaction. In that
case the transaction -must- fail and it's not worth continuing

Note this now allows decimal currency, allows . and , only for example

=cut

sub _sms_payment_parse {

    my ($input) = @_;

    my $save_input = $input;

    my %transaction_description;

    # if parse type remains = 0, then the transaction wasn't parsed correctly
    my $parse_type = 0;

    # make the parse simpler by stripping pin and keyword
    $input =~ s/^p?(\w+)\s+(send|pay)\s+//i;

  # currently allowed sms pay formats, some flexiblity, people won't remember...

    # 10 to 447779159453|test2: payment in the default currency
    $parse_type = 1
      if (
        $input =~ /^(\d+|\d+[\,\.]\d{1,2})\s+to\s+(\d{10,12}|\w+)\s*\z/xmis );

    # 10 limes to 447779159453|test2: allows the currency to be specified
    $parse_type = 2
      if ( $input =~
        /^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s*\z/xmis );

    # 10 to 447779159453|test2 for numbering
    $parse_type = 3
      if ( $input =~
        /^(\d+|\d+[\,\.]\d{1,2})\s+to\s+(\d{10,12}|\w+)\s+for\s+(.*)\z/xmis );

    # 10 limes to 447779159453|test2 for numbering
    $parse_type = 4
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s+for\s+(.*)\z/xmis
      );

# send 5 limes to test2 at dalston for demo
# 10 limes to 447779159453|test2 at dalston for numbering : registry is thrown away, compatiblity with email
# this one won't accept currency default, probably correct...
    $parse_type = 5
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+(\d{10,12}|\w+)\s+at\s+(\w+)\s+for\s+(.*)\z/xmis
      );

    # 447779159453|test2 10 limes for numbering
    $parse_type = 6
      if ( $input =~
        /^(\d{10,12}|\w+)\s+(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+for\s+(.*)\z/xmis
      );

    # 447779159453|test2 10 limes
    $parse_type = 7
      if (
        $input =~ /^(\d{10,12}|\w+)\s+(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\z/xmis );

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

    } elsif ( $parse_type == 6 ) {

        $transaction_description{'quantity'} = $2;
        $transaction_description{'currency'} =
          $3;    # FIXME: dangerous, override with $currency?
        $transaction_description{'touserormobile'} = $1;

        $transaction_description{'description'} = $4;

    } elsif ( $parse_type == 7 ) {

        $transaction_description{'quantity'} = $2;
        $transaction_description{'currency'} =
          $3;    # FIXME: dangerous, override with $currency?
        $transaction_description{'touserormobile'} = $1;

        $transaction_description{'description'} = 'no description';

    } else {

        my $message = "unparsed pay transaction is:$save_input  $input";
        log_entry( 'local', $registry, 'error', $message, '' );

    }

    $transaction_description{'quantity'} =~
      s/\,/\./;    # forward with decimal point only

    # make english language plurals singular for currency, if found...

    if ( $language eq 'en' ) {
        $transaction_description{'currency'} =~ s/ies$/y/i;
        $transaction_description{'currency'} =~ s/s$//i;
    }
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
    my ( $offset, $limit, $mail_error, $pin_status, $message );

    my $hashed_pin = text_to_hash($pin);

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'number'},
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

        if ( $from_user_ref->{'userPin'} eq $hashed_pin
            || ( length($pin) >= 4 && $debug == 2 ) )
        {
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

        if ( $from_user_ref->{'userPin'} eq $hashed_pin
            || ( $pin eq '1234' && $debug == 2 ) )
        {
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
    my ( undef, $home_ref, undef, $html, $template, undef ) =
      update_database_record( 'local', $registry, 'om_users', 1, $from_user_ref,
        $token );

    # send mail to registry supervisor, if pin locked
    if ( $message eq $messages{'smslocked'} ) {
        my ( $status, $registry_ref ) =
          get_where( 'local', $registry, 'om_registry', '*', 'id', '1', $token,
            '', '' );

        notify_by_mail(
            'local',                       $registry,
            undef,                         $registry_ref->{'admemail'},
            undef,                         $registry_ref->{'admemail'},
            $from_user_ref->{'userLogin'}, undef,
            undef,                         $message,
            6,                             undef
        );

        # end of send mail to registry supervisor
    }

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

    # SMS setup may not include email, so only send email if defined...
    if ( length( $from_user_ref->{'userEmail'} ) ) {
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
    } else {
        $mail_error = 'no email defined';
    }

    return $mail_error;

}

=head3 convert_textmarketer

Convert incoming fields as per textmarketer specification

# textmarketer plugin for this message format
# this is probably not used in this module...

=cut

sub convert_textmarketer {
    my ($input) = @_;

    $input =~ /^(\d+)/;    # this is the count for messages
    my $count = $1;
    $input =~ s/^(\d+)//;    # remove the count

    my @raw_messages = split( /\#/, $input );
    my @message_hash_refs;

    foreach my $raw_message (@raw_messages) {
        my %message_hash;
        (
            $message_hash{'status'},      $message_hash{'number'},
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

=head3 _send_textmarketer_sms_message

This is specific to textmarketer and is therefore marked as such
Sends an sms message to confirm payment and send back balances

=cut

sub _send_textmarketer_sms_message {

    my ( $class, $registry, $type, $message, $from_user_ref, $to_user_ref,
        $transaction_ref )
      = @_;

    #FIXME: add on sponsor message, if present, needs rotating etc. etc.
    #FIXME: needs testing for 140 or below too...
    my $index = rand( ( scalar @sms_sponsor_messages ) - 1 );

    # add a sponsor message on, if there's room
    my $total_length =
      length($message) + length( $sms_sponsor_messages[$index] );
    $message .= $sms_sponsor_messages[$index]
      if ( scalar @sms_sponsor_messages && $total_length <= 140 );

    debug( "message is $message", undef );

    # url escape setup message text
    $message = CGI::escape($message);

    my $preamble =
"$sms_configuration{'sms_url'}?username=$sms_configuration{'user'}&password=$sms_configuration{'password'}";

    my $urlstring;

    # makes ccdalston, cclimehouse for index entry on phone etc. but truncates
    my $orig = $sms_configuration{'orig'} . $registry;
    $orig = substr( $orig, 0, 11 ) if ( length($orig) > 11 );

    # credits and pinchanges are notified to the user receiving them...
    if ( $type eq 'credit' ) {
        $urlstring = <<EOT;
$preamble&number=$to_user_ref->{'userMobile'}&message=$message&orig=$orig&custom=$orig&option=$sms_configuration{'option'}

EOT

    }

# other operations are reported back to the originating user, including failed credit attempts (error type)
    elsif ( $type =~ /balance|join|suspend|language|error|pinchange/ ) {

        $urlstring = <<EOT;
$preamble&number=$from_user_ref->{'userMobile'}&message=$message&orig=$orig&custom=$orig&option=$sms_configuration{'option'}
EOT

    } else {
        my $mess = "unknown or unimplemented sms type: $type";
        log_entry( 'local', $registry, 'error', $mess, '' );
        return "nok:$mess";

    }

    # use LWP to send an SMS message via the cardborardfish gateway...
    my ($http_response) = __outbound_textmarketer_http_sms($urlstring);

    my $ret = $http_response->code();

    if ( $http_response->code == 200 ) {
        my $x = $http_response->decoded_content;
        debug( "return content is $x", undef );

        _charge_one_sms_unit( $class, $registry, $type, $from_user_ref,
            $transaction_ref );
        return 'ok';
    } else {
        my $x = $http_response->status_line;
        debug( "status line is $x", undef );

        my $message = "$messages{smserror} $http_response->code";
        log_entry( 'local', $registry, 'error', $message, '' );
        return "nok:$message";
    }
}

=head3 __outbound_textmarketer_http_sms

Send the SMS message via a web transaction at carboardfish

=cut

sub __outbound_textmarketer_http_sms {

    my ($sms_url) = @_;

    debug( $sms_url, undef );
    if ( $debug == 2 ) {
        print "OK exiting<\br>\n";
        debug( "debug level $debug exiting", undef );
        exit 0;
    }

    my $ua = LWP::UserAgent->new;
    $ua->agent("cclite\/$configuration{'version'}");

    #$ua->timeout(10);
    my $response = $ua->get($sms_url);
    return ($response);
}

=head3 _charge_one_sms_unit

Transfer an SMS unit from the transaction number to sysaccount
to account for the sent SMS

$type is 'credit' or 'balance' at present. In the case of balance
need to build up a few transaction fields to charge it..always charged
to number and monies put into sysaccount...

FIXME: A number of other things are charged for now, need to
improve the messages below when charging

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

=head3 _check_digit_iso_7064

slightly modified bloodbank check digit scheme
since alphas go in, alphas should come out...

FIXME: this needs debugging...

=cut

sub _check_digit_iso_7064 {

    my ($input) = @_;

    my %lookup = qw(0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 0 0
      a 10 b 11 c 12 d 13 e 14 f 15 g 16 h 17 i 18 j 19 k 20 l 21 m 22
      n 23 o 24 p 25 q 26 r 27
      s 28 t 29 u 20 v 31 w 32 x 33 y 34 z 35);
    my %out_digits = reverse(%lookup);

    my @characters = split( //, $input );
    my $weight = length($input);
    my $sum;

    foreach my $character ( shift @characters ) {

        #FIXME: doesn't deal with rogue characters...
        $sum += $lookup{$character} * 2**$weight;
        $weight--;
    }
    my $check_digit = 38 - ( $sum % 37 );
    return $out_digits{$check_digit};

}

=head3 _generate_password

Generate simple password and pin for setup
needs to be changed afterwards..

=cut	

sub _generate_password {
    my $length   = shift;
    my $possible = 'abcdefghjkmnqrstuvwxyz';
    my $password;
    while ( length($password) < $length ) {
        $password .=
          substr( $possible, ( int( rand( length($possible) ) ) ), 1 );
    }
    return $password;
}

=head3 debug

Deep debug...

=cut

sub debug {

    my ( $message, $hash_ref ) = @_;

    my $pretty = pretty_status( 3, 'OK', undef );
    my ( $date, $time ) = getdateandtime( time() );

    if ($debug) {

        # just check that it's being accessed for the moment...
        open( my $debug_file, '>>', $sms_configuration{'debug_file'} );

        $| = 1;    # Before writing!

        print $debug_file $pretty . "\n";
        print $debug_file "$time-> message is $message\n"
          if ( length($message) );
        print $debug_file "$time-> hash" . Dumper $hash_ref
          if ( length($hash_ref) );
        print $debug_file "-------------------------\n\n";
        close $debug_file;
    }

    return;

}

1;

