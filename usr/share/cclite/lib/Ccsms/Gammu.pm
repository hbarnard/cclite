
=head1 NAME

Gammu.pm

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

-> join                join hugh barnard
                           join hugh barnard hugh.barnard@example.com
                           
                           this sends back a setup message with a web password
                           and a pin for sms etc. everything is active at this stage
                           sets up with sms receipt switched on
                           
-> suspend             p123456 suspend 

                           suspends the account for fraud and for leaving the system                           
                           
-> confirm pin         p123456 confirm [not needed if setup from sms]
-> change pin          p123456 change p345678

-> change language     p123456 lang es

-> pay                 p123456 pay 5 to 07855 524667 for stuff (note need to change strip regex)
                       p123456 pay 5 to 07855524667 for other stuff
                       p123456 pay 5 to 4407855 524667 for stuff
                       p123456 pay test1 10 limes
                       p123456 pay 4477777777 10 limes 
                           

-> query Balance           p123456 balance


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
use Ccvalidate;
use Ccconfiguration;    # new style configuration method
use Data::Dumper;

use utf8;

### open (STDERR, ">&STDOUT"); # send STDERR out to page, then view source when debugging regular expressions

@EXPORT = qw(
  emulate_sms_file
  gateway_sms_transaction
  debug
);

#============== change the configuration to your registry and currency for sms
# messages will now use decide_language to get language, in Ccu.pm 08/2011

our %messages      = readmessages();
our %configuration = readconfiguration();
our %sms_configuration =
  readconfiguration('/usr/share/cclite/config/readsms.cf');

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

# set up debugging from readsms configuration file or via $fields_ref...
our $debug;
our $emulate;

#=============================================================

=head3 gateway_sms_transaction

This does a validation (could move to ccvalidate) and
an initial parse of the incoming message and
then dispatches to the appropriate internal function

=cut

sub gateway_sms_transaction {

    my ( $class, $configurationref, $fields_ref, $token ) = @_;

    # debugging and testing whether the transaction was emulated by a web form
    $debug = $sms_configuration{'debug'}
      || $fields_ref->{'debug'};    # don't use LWP just log etc.
    $emulate = $fields_ref->{'emulate'};   # transactions from the emulator page

    my ( $offset, $limit, $pin, $transaction_type, $return_value );

    # shortcode processing to change configuration file
    if ( $fields_ref->{'message'} =~ s/^(c\d+)\s+//i ) {
        my $configuration_file = "../../../config/readsms-$1.cf";
        if ( -e $configuration_file ) {
            %sms_configuration = readconfiguration($configuration_file);
        } else {

            #FIXME: This message needs to be multilingual
            log_entry( 'local', $registry, 'error',
                'configuration file not found', $token );
            return 'nok:configuration file not found';
        }
    }

    # no number, so no lookup or no message...reject
    if ( !length( $fields_ref->{'originator'} ) ) {
        my $message =
"$fields_ref->{'message'} from $fields_ref->{'originator'} $messages{'smsoriginblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # numbers are stored in database as 447855667524 for example
    $fields_ref->{'originator'} =
      format_for_standard_mobile( $fields_ref->{'originator'} );

    # setup transaction, special case
    if ( $fields_ref->{'message'} =~ /^$sms_configuration{'join_key'}\s+/i ) {
        return _gateway_sms_join( $fields_ref, $token );
    }

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # no number, so no lookup or no message...reject
    if ( !length( $fields_ref->{'message'} ) ) {
        my $message =
          "$fields_ref->{'originator'} $messages{'smsmessageblank'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        return "nok:$message";
    }

    # no one with this number , so no lookup or no message...reject
    if ( !length( $from_user_ref->{'userLogin'} ) ) {
        my $message =
          "$fields_ref->{'originator'} $messages{'smsnumbernotfound'}";
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
m/\s+$sms_configuration{'language_key'}\s+(en|zh|ar|pt|nl|el|it|ja|ru|fr|th|de|es|ro|vi|ko|fi|id|bn)\s*$/i
      )
    {
        $fields_ref->{'language'} = $1;
        return _gateway_sms_change_language( $fields_ref, $token );
    }

    # if it hasn't got a pin, not worth carrying on, tell user
    if ( $input =~ m/p?(\w+)\s+(\w+)/i ) {
        $pin              = $1;
        $transaction_type = $2;
    } else {
        my $message =
          "from: $fields_ref->{'originator'} $input -malformed transaction";

        log_entry( 'local', $registry, 'error', $message, $token );
        my ($mail_error) = _send_sms_message(
            'local',
            $registry,
            'error',
"from: $fields_ref->{'originator'} $input $messages{smsnopindetected}",
            $from_user_ref
        );
        return "nok:$message";
    }

    my $pin_status = _check_pin( $pin, $transaction_type, $fields_ref, $token );

    return "nok:$pin_status" if ( $pin_status ne 'ok' );

    # activation is done in _check_pin, these are the allowed operations

    if ( $transaction_type eq $sms_configuration{'confirm_key'} )
    {    #  p123456 confirm
        return $pin_status;
    } elsif ( $transaction_type eq $sms_configuration{'pinchange_key'} )
    {    # change pin
        $return_value = _gateway_sms_pin_change( $fields_ref, $token );
    } elsif ( $transaction_type eq $sms_configuration{'balance_key'} ) {
        $return_value = _gateway_sms_send_balance( $fields_ref, $token );
    } elsif ( $transaction_type eq $sms_configuration{'suspend_key'}
        || $transaction_type eq 'freeze' )
    {
        $return_value = _gateway_sms_suspend( $fields_ref, $token );

# allow pay or send as keyword to line up with email style, also '10 to ' is allowed
    } elsif ( $transaction_type eq $sms_configuration{'send_key'}
        || $transaction_type eq 'send'
        || $transaction_type =~ /^\w/ )
    {    # payment transaction
        $return_value =
          _gateway_sms_pay( $configurationref, $fields_ref, $token );
    } else {
        my $message =
          "from: $fields_ref->{'originator'} $input -unrecognised transaction";
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
    $input =~ m/^p?(\w+)\s+$sms_configuration{'pinchange_key'}\s+p?(\w+)\s*$/;
    my $new_pin    = $2;
    my $hashed_pin = text_to_hash($new_pin);

    if ( length($new_pin) >= 4 ) {

        $message = "$messages{'smspinchanged'}";
        ( my $error, $from_user_ref ) =
          get_where( 'local', $registry, 'om_users', '*', 'userMobile',
            $fields_ref->{'originator'},
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

    # but send it to the user's phone...
    if ( $from_user_ref->{'userSmsreceipt'} ) {
        $message = "$messages{'smspinchanged'}: $new_pin";
        _send_sms_message( 'local', $registry, 'pinchange', $message,
            $from_user_ref, undef, undef );

    }

    return 'ok';
}

=head3 _gateway_sms_suspend

Suspend account, before stopping using or fraud etc.
FIXME: Admin needs to be notified in admin interface

=cut

sub _gateway_sms_suspend {
    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit );
    my $message = $messages{'smssuspend'};

    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # suspended status for account
    $from_user_ref->{'userStatus'} = 'suspended';

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1,
        $from_user_ref, $token );

    # send mail to user
    log_entry( 'local', $registry, 'warn',
        "$message $fields_ref->{'originator'}", $token );
    my ($mail_error) =
      _send_sms_message( 'local', $registry, 'suspend', $message,
        $from_user_ref );

    # FIXME: send mail to registry supervisor
    #my ( $status, $registry_ref ) =
    #  get_where( 'local', $registry, 'om_registry', '*', 'id', '1', $token, '',
    #    '' );

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
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # change the user language preference...
    $language = $from_user_ref->{'userLang'} = $fields_ref->{'language'};

    my ( $dummy, $home_ref, $dummy1, $html, $template, $dummy2 ) =
      update_database_record( 'local', $registry, 'om_users', 1,
        $from_user_ref, $token );

    # user record available at this point, so change language to user preferred
    %messages = readmessages($language);

    my $message = "$messages{'smslanguagechanged'} $fields_ref->{'language'}";

    if ( $from_user_ref->{'userSmsreceipt'} ) {

        _send_sms_message( 'local', $registry, 'language', $message,
            $from_user_ref, undef, undef );
    }

    return 'ok';
}

=head3 _gateway_sms_join

Set up new user, warn admin by email?
tell user with password and pin via text message...
status of pin and user is defined by readsms.cf

join hugh barnard hugh.barnard\@example.com

=cut

sub _gateway_sms_join {

    my ( $fields_ref, $token ) = @_;
    my ( $offset, $limit, $message );
    my $input = lc( $fields_ref->{'message'} );    # canonical is lower case

    # check not already inscribed
    my ( $error, $from_user_ref ) =
      get_where( 'local', $registry, 'om_users', '*', 'userMobile',
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # there's a user with this number, send sms and refuse
    if ( length( $from_user_ref->{'userId'} ) ) {
        _send_sms_message( 'local', $registry, 'join',
            $messages{'smssetupnumberinuse'},
            $from_user_ref, undef, undef );
        return "nok:$messages{'smssetupnumberinuse'}";
    }

#  SELECT userLogin FROM om_users where userLogin like 'test%' order by userLogin desc
    my ( $first_name, $last_name, $email );

    if ( $input =~ m/$sms_configuration{'join_key'}\s+(\w+)\s+(\w+)$/i ) {
        $first_name = $1;
        $last_name  = $2;
    } elsif (
        $input =~ m/$sms_configuration{'join_key'}\s+(\w+)\s+(\w+)\s+(\S+)$/i )
    {
        $first_name = $1;
        $last_name  = $2;
        $email      = $3;
    } else {

        log_entry( 'local', $registry, 'error',
            "$messages{'smsbadjoin'} $fields_ref->{'originator'} $input",
            $token );

        _send_sms_message( 'local', $registry, 'error', $messages{'smsbadjoin'},
            $from_user_ref, undef, undef );

        # not enough parseable data to setup
        return "nok:$input $messages{'smsbadjoin'}";
    }

    # validation for email if supplied
    if ( length($email) ) {

        #FIXME: Bad email format, not sure how reliable this is...
        if ( $email !~
/^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/i
          )
        {
            _send_sms_message( 'local', $registry, 'join',
                $messages{'bademail'}, $from_user_ref, undef, undef );
            return 'nok';
        }

        # check that it isn't duplicated
        $fields_ref->{'userEmail'} = $email;
        my $user_ref =
          check_email_exists( 'local', $registry, $fields_ref, \%messages,
            undef, undef, undef );

        # user with this email already exists
        if ( length( $user_ref->{'userId'} ) ) {
            _send_sms_message( 'local', $registry, 'join',
                $messages{'emailexists'},
                $from_user_ref, undef, undef );
            return 'nok';
        }
    }

    # screen names are canonical lower case but...
    # candidate screen name is four of first, three of last
    # FIXME: what about 'small' names?!
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
    $fields_ref->{'userSmsreceipt'} = 1;

    # FIXME: These should not be hardcoded, 3 tries, not test yet + active
    $fields_ref->{'userPasswordTries'} = 3;
    $fields_ref->{'userPasswordStatus'} =
      $sms_configuration{'userpasswordstatus'};

    $fields_ref->{'userJoindate'} = $date;

    $fields_ref->{'userLevel'} = 'user';
    $fields_ref->{'userLang'}  = $sms_configuration{'language'};

    my $user_password = _generate_password(7);
    $fields_ref->{'userPassword'}        = text_to_hash($user_password);
    $fields_ref->{'userPasswordChanged'} = $fields_ref->{'userJoindate'} =
      $date;

    # add name field
    $fields_ref->{'userLogin'} = $screen_candidate;
    $fields_ref->{'userName'}  = "\u$first_name \u$last_name";

    my $user_pin = _generate_password(5);
    $fields_ref->{'userPin'}        = text_to_hash($user_pin);
    $fields_ref->{'userPinChanged'} = $date;

    # this should be OK, because of the gammu input file format
    $fields_ref->{'userMobile'} =
      format_for_standard_mobile( $fields_ref->{'originator'} );
    $fields_ref->{'userPinStatus'} = $sms_configuration{'userpinstatus'};
    $fields_ref->{'userPinTries'}  = 3;

    # status as in the configuration file...
    $fields_ref->{'userStatus'} = $sms_configuration{'userstatus'};

# FIXME: if the email is blank, then we probably shouldn't make the record active?!
    $fields_ref->{'userEmail'} = $email;    # may be blank of course

    # add the user to the registry database
    my ( $rc, $rv, $record_id ) =
      add_database_record( 'local', $registry, 'om_users', $fields_ref, undef );

    # send setup done message
    my $setup_complete_message = <<EOT;
Dear $first_name
Setup for cclite complete
Screen name: $screen_candidate
Web password: $user_password
SMS PIN: $user_pin    
EOT

    _send_sms_message( 'local', $registry, 'join', $setup_complete_message,
        $fields_ref, undef, undef );
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

    #FUXME: note $registry is global, probably should be fixed
    my ( $error, $from_user_ref ) =
      get_where( $class, $registry, 'om_users', '*', 'userMobile',
        $fields{'originator'}, $token, $offset, $limit );

    # FIXME: needs to deliver json etc...
    my $registry_status = get_registry_status(
        ( 'local', $registry, 'om_registry', $fields_ref, $token ) );

    # registry is closed or closing...no pay style transactions allowed...
    if ( $registry_status eq 'down' || $registry_status eq 'closing' ) {

        # send SMS to originator to say, can't be done...
        my $message;
        if ( $from_user_ref->{'userSmsreceipt'} ) {

            $message = $messages{'registryclosing'} . ':'
              . $messages{'notransfersallowed'};
            _send_sms_message( 'local', $registry, 'error', $message,
                $from_user_ref, undef, {} );

        }
        return "nok: $message";

    }

    # begin parse on whitespace
    my $input = lc( $fields{'message'} );    # canonical is lower case

    my ( $parse_type, $transaction_description_ref ) =
      _sms_payment_parse($input);

    # sms pay message didn't parse, not worth proceeding
    if ( $parse_type == 0 ) {
        my $message =
"pay attempt from $fields{'originator'} to $transaction_description_ref->{'tomobilenumber'} : $messages{'smsinvalidsyntax'}";
        log_entry( 'local', $registry, 'error', $message, $token );
        _send_sms_message( 'local', $registry, 'error', $message,
            $from_user_ref, undef, undef );
        return "nok:$input $message";
    }

    # toregistry is base registry if not specified
    # February 2014

    if ( $parse_type != 5
        || ( !length( $transaction_description_ref->{'toregistry'} ) ) )
    {
        $transaction{'toregistry'} = $registry;
    } else {
        $transaction{'toregistry'} =
          $transaction_description_ref->{'toregistry'};
    }

    # numbers are stored as 447855667524 for example
    $transaction_description_ref->{'tomobilenumber'} =
      format_for_standard_mobile(
        $transaction_description_ref->{'tomobilenumber'} );
    my ( $error1, $to_user_ref );

    # contains only figures so it's a mobile number
    if ( $transaction_description_ref->{'touserormobile'} =~ /^\d+\z/ ) {
        ( $error1, $to_user_ref ) = get_where(
            $class,       $transaction{'toregistry'},
            'om_users',   '*',
            'userMobile', $transaction_description_ref->{'touserormobile'},
            $token,       $offset,
            $limit
        );
    } else {

        # else it's a userLogin ...
        ( $error1, $to_user_ref ) = get_where(
            $class,      $transaction{'toregistry'},
            'om_users',  '*',
            'userLogin', $transaction_description_ref->{'touserormobile'},
            $token,      $offset,
            $limit
        );
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

    # check on currency name, since it can be supplied in some formats
    if (
        !_check_valid_currency(
            $registry, $transaction_description_ref->{'currency'}, undef
        )
      )
    {
        push @status,
"$messages{'nolocalcurrency'} $transaction_description_ref->{'currency'}";
    }

# check on the currency at the receiving end too, since inter-registry is allowed February 2014
    if (
        !_check_valid_currency(
            $transaction{'toregistry'},
            $transaction_description_ref->{'currency'},
            undef
        )
      )
    {
        push @status, $messages{'noremotecurrency'};
    }

    my $errors = join( ':', @status );

    # one or more errors in status array
    if ( scalar(@status) > 0 ) {
        my $message =
"pay attempt from $fields{'originator'} to $transaction_description_ref->{'tomobilenumber'} : $errors";
        log_entry( 'local', $registry, 'error', $message, $token );
        _send_sms_message( $class, $registry, 'error', $message,
            $from_user_ref, undef, {} );
        return "nok:$message";
    }

    # convert to standard transaction input format, fields etc.
    # FIXME: fromregistry : dalston, always one base 'from' registry in 2014
    $transaction{'fromregistry'} = $registry;

    # no home, not a web transaction
    $transaction{'home'} = "";

    #subaction : om_trades
    $transaction{'subaction'} = 'om_trades';

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

    # tradestatus from configured sms config
    $transaction{'tradeStatus'} = $sms_configuration{'initialpaymentstatus'};

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

            #FIXME: English language currencies only
            $transaction{'tradeCurrency'} =~
              s/y$/ies/i;    # english language currencies
            $transaction{'tradeCurrency'} =~ s/$/s/i
              if ( $transaction{'tradeCurrency'} !~ /s$/i );
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

    # send SMS receipt, only if turned on for the user...
    if ( $to_user_ref->{'userSmsreceipt'} && ( !length($error3) ) ) {
        _send_sms_message( $class, $registry, 'pay', $message, $from_user_ref,
            $to_user_ref, $transaction_ref );

        # transaction has failed in the engine part
    } elsif ( length($error3) ) {
        _send_sms_message( $class, $registry, 'error', $message, $from_user_ref,
            $to_user_ref, $transaction_ref );
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
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    my %fields = ( 'userLogin', $from_user_ref->{'userLogin'} );
    my $fields_ref = \%fields;

# mode is html to return html, mode is values to return raw balances and volumes for each currency
# probably should move to json for mobile applications...
    $fields_ref->{'mode'} = 'values';

    ( $balance_ref, $volume_ref ) =
      show_balance_and_volume( 'local', $registry,
        $from_user_ref->{'userLogin'},
        $fields_ref, $token );

    # current balance for this particular currency
    # May 2012 reveal all currencies in the registry, towards sms multicurrency
    my $balance = $balance_ref->{$currency};

    #FIXME: if currency balance spaces, not trading etc.?
    my $balance_table;
    foreach my $key ( sort keys %$balance_ref ) {

        my $literal_currency = $key;

        # make y currencies plural, if user language english
        $literal_currency =~ s/y$/ies/i
          if ( $from_user_ref->{'userLang'} eq 'en' );

        next if ( $balance_ref->{$key} =~ /^\s+$/ );    # skip space value
        $balance_table .= "$literal_currency:$balance_ref->{$key}\n";
    }

    my $balance_message =
"$messages{smsthebalancefor} $from_user_ref->{userLogin} $messages{at} $registry $messages{is}:\n$balance_table";

    # send SMS balance, only if turned on for the user...new 16.08.2010
    # blank transaction ref, need to make 1 unit sms currency transaction
    my ( %transaction, $class, $to_user_ref );

    if ( $from_user_ref->{'userSmsreceipt'} ) {
        _send_sms_message( $class, $registry, 'balance',
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

    #use re 'debugcolor' ;
    my $save_input = $input;

    my %transaction_description;

    # if parse type remains = 0, then the transaction wasn't parsed correctly
    my $parse_type = 0;

    # make the parse simpler by stripping pin and keyword
    $input =~ s/^p?(\w+)\s+//i;
    $input =~ s/^(send|$sms_configuration{'send_key'})\s+//i;

  # currently allowed sms pay formats, some flexiblity, people won't remember...

    # ^(\+44\s?7\d{3}|\(?07\d{3}\)?)\s?\d{3}\s?\d{3}$
    # p2323 pay 5 to 447534038239
    # p2323 pay 5 to 07534 038 239
    # p2323 pay 5 to 07534 038239
    # p2323 pay 5 to 07534038239
    # p2323 pay 5 to +447534038239
    # p2323 pay 5 to test1
    $parse_type = 1
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+to\s+((\+*$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s*\z/xmis
      );

    # 10 limes to 447779159453|test2: allows the currency to be specified
    # p2323 pay 5.2 dally to 07534038239
    # p2323 pay 5.2 dally to test1
    # p2323 pay 5 dally to 07534038239
    $parse_type = 2
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s*\z/xmis
      );

    # 10 to 447779159453|test2 for numbering
    #
    #
    $parse_type = 3
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+to\s+((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+for\s+(.*)\z/xmis
      );

    # 10 limes to 447779159453|test2 for numbering
    $parse_type = 4
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+for\s+(.*)\z/xmis
      );

    # send 5 limes to test2 at dalston for demo
    # 10 limes to 447779159453|test2 at dalston for numbering
    # this one won't accept currency default, probably correct...
    $parse_type = 5
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+to\s+((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+at\s+(\w+)\s+for\s+(.*)\z/xmis
      );

    # 447779159453|test2 10 limes for numbering
    $parse_type = 6
      if ( $input =~
/^((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\s+for\s+(.*)\z/xmis
      );

    # 447779159453|test2 10 limes
    $parse_type = 7
      if ( $input =~
/^((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+(\d+|\d+[\,\.]\d{1,2})\s+(\w+)\z/xmis
      );

    # 5 to 07534 038239 for format8
    $parse_type = 8
      if ( $input =~
/^(\d+|\d+[\,\.]\d{1,2})\s+to\s+((\+$sms_configuration{'sms_prefix'}\s*7\d{3}|\(?07\d{3}\)?)\s*\d{3}\s*\d{3}|[A-Za-z]\w+)\s+for\s+(.*)\z/xmis
      );

    #no re ;

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

        $transaction_description{'quantity'}       = $1;
        $transaction_description{'currency'}       = $2;
        $transaction_description{'touserormobile'} = $3;
        $transaction_description{'description'}    = $5;

    }

    # The registry is now used as a 'to' registry now, for parse type 5
    # February 2014
    elsif ( $parse_type == 5 ) {

        $transaction_description{'quantity'}       = $1;
        $transaction_description{'currency'}       = $2;
        $transaction_description{'touserormobile'} = $3;
        $transaction_description{'toregistry'}     = $5;
        $transaction_description{'description'}    = $6;

    } elsif ( $parse_type == 6 ) {

        $transaction_description{'quantity'}       = $3;
        $transaction_description{'currency'}       = $4;
        $transaction_description{'touserormobile'} = $1;

        $transaction_description{'description'} = $5;

    } elsif ( $parse_type == 7 ) {

        $transaction_description{'quantity'}       = $3;
        $transaction_description{'currency'}       = $4;
        $transaction_description{'touserormobile'} = $1;

        $transaction_description{'description'} = 'no description';
    } elsif ( $parse_type == 8 ) {

        $transaction_description{'quantity'}       = $1;
        $transaction_description{'touserormobile'} = $2;
        $transaction_description{'description'}    = $4;
        $transaction_description{'currency'}       = $currency;

    } else {

        my $message = "unparsed pay transaction is:$save_input  $input";
        log_entry( 'local', $registry, 'error', $message, '' );

    }

    # deal with badly formatted 'to' phone number for most cases remaining
    $transaction_description{'touserormobile'} =~
      s/^0/$sms_configuration{'sms_prefix'}/;
    $transaction_description{'touserormobile'} =~ s/\s+//g;
    $transaction_description{'touserormobile'} =~ s/^\+//g;

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
        $fields_ref->{'originator'},
        $token, $offset, $limit );

    # already locked
    if ( $from_user_ref->{'userPinStatus'} eq 'locked' ) {
        $message = $messages{'smslocked'};
        _send_sms_message( 'local', $registry, 'pinchange', $message,
            $from_user_ref, undef, undef );
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
    my ( undef, $home_ref, undef, $html, $template, undef ) =
      update_database_record( 'local', $registry, 'om_users', 1,
        $from_user_ref, $token );

    # Send logging message if pin locked
    if ( $message eq $messages{'smslocked'} ) {
        log_entry( 'local', $registry, 'error',
            "$from_user_ref->{'userLogin'}: $message", '' );
    }

    if ( length($message) ) {
        $mail_error =
          _send_sms_message( 'local', $registry, 'error', $message,
            $from_user_ref, undef, undef );
    }

    return $pin_status;
}

=head3 _send_sms_mail_message

wrapper for notify_by_mail in package Cclite
with notification type 4

Within notify_by_mail, if net_smtp is switched on, the registry account rather
than the cclite.cf account is used for the mailout, this is preferred because
it separates 'business' between registries 11/2009

FIXME: This is generally deprecated in 2014 because all communication should
probably be via phone and email de-emphasised

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

=head3 _send_sms_message

Implemented February 2014, Still incomplete
and partially tested. Works on gammu, since that makes
the whole project more 'autonomous' and separates it
from commercial http-based texting suppliers

 Used to send receipts balances etc.

 Work on external suppliers needs doing, always
 so, since external supplier will vary, see
  _send_cardboardfish_sms_receipt for example

=cut

sub _send_sms_message {

    my ( $class, $registry, $type, $message, $from_user_ref, $to_user_ref,
        $transaction_ref )
      = @_;

  #TODO: need weights for the messages, very probably, so some appear more often
    my @sms_sponsor_messages  = _collect_sponsor_messages();
    my $sponsor_message_count = scalar(@sms_sponsor_messages);

    # switch for sponsor messages, no need to blank them/restore them
    if (   $sms_configuration{'sponsor_message_status'}
        && $sponsor_message_count )
    {
        # delivers a random sponsor message from the list
        # TODO: Needs to deal with weights in next release
        my $sponsor_message_count = scalar(@sms_sponsor_messages) + 1;
        my $message_index         = int( rand($sponsor_message_count) );

        my $total_length =
          length( $sms_sponsor_messages[$message_index] ) + length($message);

# FIXME: Should be tested on input really, 135 not 140 because of the stars added!
        if ( $total_length > 135 ) {
            $sms_sponsor_messages[$message_index] =
              substr( $sms_sponsor_messages[$message_index],
                0, -( $total_length - 135 ) );
            log_entry( 'local', $registry, 'error',
                'sponsor sms message + message too big', '' );
        }
        $message .= "** $sms_sponsor_messages[$message_index] *";
    }

    my ( $urlstring, $send_to_this_mobile );

    if ( $type eq 'pay' ) {
        $send_to_this_mobile = $to_user_ref->{'userMobile'};
    } elsif ( $type =~
/$sms_configuration{'balance_key'}|$sms_configuration{'join_key'}|$sms_configuration{'suspend_key'}|$sms_configuration{'language_key'}|error|$sms_configuration{'pinchange_key'}/
      )
    {
        $send_to_this_mobile = $from_user_ref->{'userMobile'};
    } else {
        my $message = "unknown or unimplemented sms type: $type";
        log_entry( 'local', $registry, 'error', $message, '' );
        return "$messages{smserror} $type";

    }

    # write into gammu smsd outbox
    _write_sms_file( $send_to_this_mobile, $message );

    # sms scoring per user, sms currency is set up at registry create time
    _charge_one_sms_unit( $class, $registry, $type, $from_user_ref,
        $transaction_ref );

    #FIXME: Deal with errors
    #   my $message = "$messages{smserror} $http_response->code";
    #   log_entry( 'local', $registry, 'error', $message, '' );
    #   return "$messages{smserror} $http_response->code";
    return;
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
    if ( $type ne 'pay' ) {

        #subaction : om_trades
        $transaction_ref->{'subaction'} = 'om_trades';

        #fromregistry : dalston
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
      transaction( 'sms', $registry, 'om_trades', $transaction_ref, $pages,
        $token );

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

Debug into file, as opposed to using logging...

=cut

sub debug {

    my ( $message, $hash_ref ) = @_;

    my ( $date, $time ) = getdateandtime( time() );
    my ( $package, $filename, $line ) =
      caller $time =~ s/(\d\d)(\d\d)(\d\d)/$1:$2:$3/;
    $date =~ s/(\d{4})(\d\d)(\d\d)/$3:$2:$1/;

    if ($debug) {

        # just check that it's being accessed for the moment...
        open( my $debug_file, '>>', $sms_configuration{'sms_debug_file'} );

        #$| = 1;    # Before writing!

        print $debug_file "$date $time $line -> message is $message\n"
          if ( length($message) );
        print $debug_file "$date $time $line -> hash" . Dumper $hash_ref
          if ( length($hash_ref) );
        print $debug_file "-------------------------\n\n";
        close $debug_file;
    }

    #$| = 0;
    return;

}

=head3 write_sms_file

Write an output sms file to to be picked up by
the gammu sms daemon

Normally this is written to: 
/var/cclite/sms/outbox/<registryname>/
For example:
/var/cclite/sms/outbox/dalston/

=cut

sub _write_sms_file {

    my ( $phone_number, $message ) = @_;
    my $file_extension;
    my ( $numeric_date, $time ) = getdateandtime( time() );
    $numeric_date =~ s/\.//g;

    # make sure nothing gets sent, if debug, wrong file extension
    if ($debug) {
        $file_extension = 'doc';
    } else {
        $file_extension = 'txt';
    }

    # OUT20081203_211658_00_+447779159452_00.txt
    my $file_name =
        $sms_configuration{'smsoutpath'} . '/'
      . $registry . '/' . 'OUT'
      . $numeric_date . '_'
      . $time . '_00_+'
      . $phone_number . '_00.'
      . $file_extension;

    #debug("sms out $file_name",'') ;
    #FIXME: need something stronger than this for duplicate names
    if ( -e $file_name ) {
        return;
    }

    if ($debug) {
        debug( "\n$file_name contains\n$message", undef );
    } else {
        open my $fh, '>', "$file_name";
        print $fh $message;
        close $fh;
    }

    return;

}

=head3 _emulate_sms_file

This is pretty much the same as _write_sms_file
but allows writing to the inbox to emulate messages
and test without sending sms messages.

If you're worried about security/false messages etc.
delete this part of the library, which is, in fact only called
from the test script when debug is on. 

=cut

sub emulate_sms_file {

    my ( $phone_number, $message ) = @_;

    my ( $numeric_date, $time ) = getdateandtime( time() );
    $numeric_date =~ s/\.//g;
    my $file_name;

    # deal with spaces in the emulation form
    $phone_number =~ s/\s+//g;

    $file_name =
        $sms_configuration{'smsinpath'} . '/'
      . $registry . '/' . 'IN'
      . $numeric_date . '_'
      . $time . '_00_+'
      . $phone_number . '_00.' . 'txt';

    #FIXME: need something stronger than this for duplicate names
    if ( -e $file_name ) {
        return;
    }

    open my $fh, '>', "$file_name";
    print $fh $message;
    close $fh;

    return;

}

=head3 _check_valid_currency

Since we're now allowing currencies nominated in the SMS message
to be processed, we need to check that they are existing and 'live'
currencies 2014


=cut

sub _check_valid_currency {

    my ( $registry, $currency, $token ) = @_;

    my ( $hash_ref, $count ) = collect_items(
        'local', $registry, 'om_currencies', undef,
        'name',  'values',  $token,          undef,
        undef
    );

    my $found = 0;
    foreach my $key ( keys %$hash_ref ) {
        if ( $currency eq $hash_ref->{$key}->{'name'} ) {
            $found = 1;
        }
    }
    return $found;
}

=head3 _collect_sponsor_messages

Get the sponsors messages out of the configuration
file, if they exist, they are attached to sms messages
to provide national currency or other support for
the service

=cut

sub _collect_sponsor_messages {

    my @messages;
    foreach my $key ( keys %sms_configuration ) {

        if ( $key =~ /sponsor\d+/i ) {
            push @messages, $sms_configuration{$key};
        }

    }
    return @messages;
}

1;

