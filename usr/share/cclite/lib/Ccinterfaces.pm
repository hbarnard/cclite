
=head1 NAME

Ccinterfaces.pm

=head1 SYNOPSIS

Transaction conversion interfaces inwards for sms, mail etc.

=head1 DESCRIPTION

This contains interfaces for mail and SMS to be used by demons
It also contains currently abandoned work for touch-tone
If there's smart card, it'll go here

=head1 AUTHOR

Hugh Barnard

=head1 SEE ALSO

Cchooks.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced
 
=cut

package Ccinterfaces;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Cclite;
use Cclitedb;
use Ccu;
###use Encode qw(encode decode);

my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(sms_transaction
  sms_message_parse
  oscommerce_transaction
  read_mail_transactions
  read_csv_transactions
);

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash
 
=cut

# language of messages decided now by Ccu::decide_language
our %messages = readmessages();
our $log      = Log::Log4perl->get_logger("Ccinterfaces");

=head3 sms_transaction

This accepts an SMS  transaction and reformats it into
an ordinary one. It therefore has to do a mobile phone to user name
look up, data reformatting etc.

Mobile phone numbers must have the internation prefix 44.... etc.
This is to enable wide-area registries at some stage...

This will use up a credit, so mabye it should be configured.
This will only go registry-a to registry-a, at present
when you say 'at' it's assumed that the to and from registries
at the same

Text messaging transfer is allowed home -> remote
more expressivity in the message and auth via phone number
For example mobile number 1234 text message:
--------------------------------------------------------------
  1234: [send|snd] 4 duckets to ddawg at dalston for
         advertising and computer help
--------------------------------------------------------------

=cut

sub sms_transaction {
    my ( $class, $mobilenumber, $input ) = @_;    # mobile number + raw string
    my ( $token, $offset, $limit, $class, $pages, $token );

    # return values for screen, not really used by scripts
    my ( $metarefresh, $home, $error, $output_message, $page, $c );

    my %transaction;

    ### $input = decode( 'UCS-2', lc($input) );  # if sms is stored as unicode

    my ( $found_count, $transaction_description_ref ) =
      sms_message_parse($input);

    return ( $metarefresh, $home, 'sms incomplete message error',
        $output_message, $page, $c )
      if ( $found_count < 5 );

    my %transaction_description = %$transaction_description_ref;

    my ( $error, $fromuserref ) =
      get_where( $class, $transaction_description{'fromregistry'},
        'om_users', '*', 'userMobile', $mobilenumber, $token, $offset, $limit );
    my ( $error, $touserref ) = get_where(
        $class, $transaction_description{'toregistry'},
        'om_users', '*', 'userLogin', $transaction_description{'touser'},
        $token, $offset, $limit
    );
    my ( $error, $currencyref ) = get_where(
        $class,          $transaction_description{'fromregistry'},
        'om_currencies', '*',
        'name',          $transaction_description{'currency'},
        $token,          $offset,
        $limit
    );

    # one of the above lookups fails, reject the whole transaction
    if (   ( !length($fromuserref) )
        || ( !length($fromuserref) )
        || ( !length($fromuserref) ) )
    {
        return ( $metarefresh, $home, 'sms database lookup error',
            $output_message, $page, $c );
    }

    # convert to standard transaction input format, fields etc.
    #fromregistry : chelsea
    $transaction{fromregistry} = $transaction_description{'fromregistry'};

    #home : http://cclite.caca-cola.com:83/cgi-bin/cclite.cgi, for example
    $transaction{home}      = "";            # no home, not a web transaction
                                             #subaction : om_trades
    $transaction{subaction} = 'om_trades';

    #toregistry : dalston
    $transaction{toregistry} = $transaction_description{'toregistry'};

    #tradeAmount : 23
    $transaction{tradeAmount} = $transaction_description{'quantity'};

    #tradeCurrency : ducket
    $transaction{tradeCurrency} = $$currencyref{name};

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $transaction{tradeDate} = $date;

    #FIXME: should be multilingual tradeTitle : added by this routine
    $transaction{tradeTitle} = "SMS transaction: see description";

    #tradeDescription
    $transaction{tradeDescription} = $transaction_description{'description'};

    #tradeDestination : ddawg
    $transaction{tradeDestination} = $$touserref{userLogin};

    #tradeItem : test to see variables
    #tradeSource : manager
    $transaction{tradeSource} = $$fromuserref{userLogin};

    #FIXME: this should be taken from a configuration file
    $transaction{initialPaymentStatus} = 'waiting';

    #
    # call ordinary transaction
    my $transaction_ref = \%transaction;
    my ( $metarefresh, $home, $error, $output_message, $page, $c ) =
      transaction( 'sms', $transaction{fromregistry},
        'om_trades', $transaction_ref, $pages, $token );
    return ( $metarefresh, $home, $error, $output_message, $page, $c );
}

=head3 read_mail_transactions

This accepts a /var/spool/mail/xxx and reformats it into
a set of transactions. It therefore has to do a email address to user name
look up, data reformatting etc.

This will only go registry-a to registry-a, at present
when you say 'at' it's assumed that the to and from registries
are the same
 
example mail text
--------------------------------------------------------------
        [send|snd] 4 duckets to ddawg at dalston for
         advertising and computer help
--------------------------------------------------------------

This will move to GPG encoded mail at -some- stage, real soon now...

This is probably replaced by Ccmailgateway now, reads via POP3 11/2009


=cut

sub read_mail_transactions {
    my ( $class, $db, $table, $mail_file, $token, $offset, $limit ) = @_;

    my ( $messages, $error, $offset, $limit, $class, $pages, $token );
    my %transaction;

    # parse the mail file into messages
    my ( %subject, %from, %message, $fromregistry, $toregistry, $counter );
    ### From: "Hugh Barnard" <hugh.barnard@hughbarnard.org>

    # mail file format is <toregistry>.cclite, registry is parsed out
    $mail_file =~ /\057([^\057]+)\056cclite$/;
    $fromregistry = $toregistry = $1;

    open( MAIL, $mail_file );
    $/ = '';    # read paragraphs

    while (<MAIL>) {
        if (/^From/) {
            /^Subject:\s*(?:Re:\s*)*(.*)/mi;
            $counter++;
            $subject{$counter} = $1;
            /From\:.*\<(.*)\>/m;
            $from{$counter} = $1;
        }       # endif
        $message{$counter} .= $_;
    }    # endwhile
    close(MAIL);

    foreach my $key ( keys %subject ) {
        my $input = lc( $message{$key} );      # canonical is lower case
        my @words = split( /\s+/m, $input );

        # fuzzy ark parsing the terms mainly go two-by-two!

        my $counter = 0;                       # used for term lookahead
        my ( $description, $currency, $quantity, $touser );
        foreach my $word (@words) {
            if ( $word =~ /^(\d+)$/ ) {
                $quantity = $word;    # quantity is the only numeric thing
                $currency =
                  $words[ ( $counter + 1 ) ];    # currency is next to quantity
                $currency =~ s/s$//;             # singulate or deplural...
            }

            # deals with yahoo footer etc. stupid format though
            if ( $word eq "to" && !length($touser) ) {    # found 'to'
                $touser = $words[ ( $counter + 1 ) ];     # touser is next
            }
            $counter++;
        }
        ($description) =
          $input =~ /for\s+(\w.*)$/mi;    # description is everything at end
             # look up sending user, receiving user and currency
        my ( $error, $fromuserref ) = get_where(
            $class,      $fromregistry, 'om_users', '*',
            'userEmail', $from{$key},   $token,     $offset,
            $limit
        );
        my ( $error, $touserref ) = get_where(
            $class,      $toregistry, 'om_users', '*',
            'userLogin', $touser,     $token,     $offset,
            $limit
        );
        my ( $error, $currencyref ) = get_where(
            $class, $fromregistry, 'om_currencies', '*',
            'name', $currency,     $token,          $offset,
            $limit
        );

        # one of the above lookups fails, reject the whole transaction
        if (   ( !length($fromuserref) )
            || ( !length($fromuserref) )
            || ( !length($fromuserref) ) )
        {
            ###send_mail_message($from{$key},"transaction invalid: $input") ;
        }

        # convert to standard transaction input format, fields etc.
        #fromregistry : chelsea
        $transaction{fromregistry} = $fromregistry;

        #home : http://cclite.caca-cola.com:83/cgi-bin/cclite.cgi, for example
        $transaction{home}      = "";           # no home, not a web transaction
                                                #subaction : om_trades
        $transaction{subaction} = 'om_trades';

        #toregistry : dalston
        $transaction{toregistry} = $toregistry;

        #tradeAmount : 23
        $transaction{tradeAmount} = $quantity;

        #tradeCurrency : ducket
        $transaction{tradeCurrency} = $$currencyref{name};

        #tradeDate : this is date of reception and processing, in fact
        my ( $date, $time ) = &Ccu::getdateandtime( time() );
        $transaction{tradeDate} = $date;

        #tradeTitle : added by this routine
        $transaction{tradeTitle} = "Mail transaction: see description";

        #tradeDescription
        $transaction{tradeDescription} = $description;

        #tradeDestination : ddawg
        $transaction{tradeDestination} = $$touserref{userLogin};

        #tradeItem : test to see variables
        #tradeSource : manager
        $transaction{tradeSource} = $$fromuserref{userLogin};

        # call ordinary transaction
        my $transaction_ref = \%transaction;
        my ( $metarefresh, $home, $error, $output_message, $page, $c ) =
          transaction( 'mail', $transaction{fromregistry},
            'om_trades', $transaction_ref, $pages, $token );
    }                     # end of each on letters
    unlink $mail_file;    # delete mail file when read

    # need to decide how this returns, processes multiple transactions
    return ( 0, "", $error, $messages, 'result.html', "" );
}

=head3 read_csv_transactions

This accepts a /var/cclite/xxx.csv and reformats it into
a set of transactions. 

Prints a new file showing accepted transactions and rejected ones

example text
   0 date     1 from 2 to	3 fromreg 4 toreg  5 currency 6 type 7 taxflag  8 amount   9 description
"10-04-2005","ddawg","manager","dalston","dalston","ducket","credit","N",345,"test1"
This will move to GPG encoded at -some- stage

Note that $db is empty, the registries are declared in the transactions
themselves. It has remained to keep the function signatures consistent.

Skip # lines which are expected to be comments. Only allow debits, currently.

=cut

sub read_csv_transactions {
    my (
        $class,    $db,        $table,
        $csv_file, $file_name, $configuration_ref,
        $token,    $offset,    $limit
    ) = @_;

    my (
        $messages, $error, $offset,      $limit,  $class,
        $pages,    $token, %transaction, @errors, $ok
    );

    open( CSV, $csv_file ) or die "can\'t open csv file: $csv_file";

    # timestamp output files so that they don't get confused
    my ( $numeric_date, $time ) = getdateandtime( time() );

    # results written per registry now...11/2009
    my $results_out =
      "$$configuration_ref{csvout}/$db/$file_name\056$numeric_date$time\056txt";
    open( OUT, ">$results_out" )
      or die "can\'t open csv output file: $results_out";

    while (<CSV>) {

        ###$log->debug("input is $_") ;
        s/"//g;    # remove quotes
        next if (/^#|^\s/);    # skip comment lines and space lines
        chop($_);
        my @transaction_array = split( /\,/, $_ );
        my $ok = 1;    # turned off for non-ok transaction
                       # look up sending user, receiving user and currency
                       # fail on from user not within this registry, policy
        my ( $error, $fromuserref ) = get_where(
            $class,      $transaction_array[3],
            'om_users',  '*',
            'userLogin', $transaction_array[1],
            $token,      $offset,
            $limit
        );

# don't fail on destination registry, could be remote...
#my ($error,$touserref)   = get_where($class,$transaction_array[4],'om_users','userLogin',$transaction_array[2],$token,$offset,$limit) ;
# fail on currency not within this registry, cannot succeed
        my ( $error, $currencyref ) = get_where(
            $class,          $transaction_array[3],
            'om_currencies', '*',
            'name',          $transaction_array[5],
            $token,          $offset,
            $limit
        );

        # one of the above lookups fails, reject the whole transaction

        if ( !length($fromuserref) ) {
            push @errors, $messages{invalidsending};
            $ok = 0;
        }

        # removed, user can be a remote user
        ###if (! length($touserref) ) {
        ###  push @errors, $messages{invalidreceiving} ;
        ###  $ok  = 0;
        ###}

        if ( !length($currencyref) ) {
            push @errors, $messages{invalidcurrency};
            $ok = 0;
        }

        # only debit transactions allowed at present
        if ( $transaction_array[6] ne "debit" ) {
            push @errors, $messages{notadebit};
            $ok = 0;
        }

        # convert to standard transaction input format, fields etc.
        #fromregistry : chelsea
        $transaction{fromregistry} = $transaction_array[3];

        #home : http://cclite.caca-cola.com:83/cgi-bin/cclite.cgi, for example
        $transaction{home}      = "";           # no home, not a web transaction
                                                #subaction : om_trades
        $transaction{subaction} = 'om_trades';

        #toregistry : dalston
        $transaction{toregistry} = $transaction_array[4];

        #tradeAmount : 23
        $transaction{tradeAmount} = $transaction_array[8];

        #tradeCurrency : ducket
        $transaction{tradeCurrency} = $transaction_array[5];

        #tradeDate : this is date of reception and processing, in fact
        my ( $date, $time ) = &Ccu::getdateandtime( time() );

        # read from configuration file in cron job
        $transaction{initialPaymentStatus} =
          $$configuration_ref{initialpaymentstatus};

        # reformat date if necessary ;
        $transaction_array[0] =~ m/(\d\d)\D(\d\d)\D(\d\d\d\d)/;
        my $tdate = ( length($3) == 0 ) ? $transaction_array[0] : "$3-$2-$1";

        $transaction{tradeDate} = $tdate;

        #tradeTitle : added by this routine
        $transaction{tradeTitle} = $messages{batchtransaction};

        #tradeDescription
        $transaction{tradeDescription} = $transaction_array[9];

        #tradeDestination : ddawg
        $transaction{tradeDestination} = $transaction_array[2];

        #tradeItem : test to see variables
        #tradeSource : manager
        $transaction{tradeSource} = $transaction_array[1];

        # this is new 01/2006 and needs adding everywhere
        $transaction{tradeTaxflag} = $transaction_array[7];

        # call ordinary transaction
        my $transaction_ref = \%transaction;
        my ( $metarefresh, $home, $error, $output_message, $page, $c );

        ###$log->debug("ok is $ok");
        if ($ok) {
            ( $metarefresh, $home, $error, $output_message, $page, $c ) =
              transaction( 'batch', $transaction{fromregistry},
                'om_trades', $transaction_ref, $pages, $token );
        }

        # add a message to the output transaction and print in output file
        if ( length($error) || !$ok && length($_) ) {
            push @errors, $error;
            my $error_messages = join( ",", @errors );
            $_ .= ",$error_messages\n";
        } else {
            $_ .= ",$messages{accepted}\n";
        }
        undef $error;
        @errors = ();
        print OUT $_;
    }    # end of while on csv files

    # need to decide how this returns, processes multiple transactions
    return ( 0, "", $error, $messages, 'result.html', "" );
}

=head3 oscommerce_transaction

transaction from oscommerce, authorised with merchantkey
this is a work in progress at present. 

Several transactions are generated depending on the (Cclite) user
in the OsCommerce manufacturer fields. This is the 'link' between the two systems

Currently there's still work to be
done to generate a merchant key: hotbits + hashing probably for the moment.

=cut

sub oscommerce_transaction {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $html, $offset, $limit, $ok, %transaction );
    my %fields = %$fieldsref;    # for code simplicity, really

# test whether the merchant key from the interface = that stored in the registry

    my ( $merror, $registryref ) = get_where(
        $class,         $fields{registry},
        'om_registry',  '*',
        'merchant_key', $fields{merchant_key},
        $token,         $offset,
        $limit
    );

    # deduce paying 'shopper' from email address sent from osCommerce
    my ( $uerror, $fromuserref ) = get_where(
        $class,      $fields{registry}, 'om_users', '*',
        'userEmail', $fields{email},    $token,     $offset,
        $limit
    );

    # (new 2007) get list of allowed IP addresses for oscommerce and
    # for straight through RESTful transactions. no list = anything goes!

    my @allowed_ips = split( /\s+/, $$registryref{allowed_ip_list} );

    # loop through allowed ips
    if ( scalar(@allowed_ips) >= 1 ) {
        my $found = 0;
        foreach my $ip (@allowed_ips) {
            if ( $ip eq $$fieldsref{client_ip} ) {
                $found = 1;
                last;
            }
        }
        print "Location: $fields{cancel_url}" if ( !$found );
    }

# deduce currency from currency symbol sent from osCommerce : only one allowed at present
    my ( $cerror, $currencyref ) =
      get_where( $class, $fields{registry}, 'om_currencies', '*', 'code',
        $fields{currency_code}, $token, $offset, $limit );
    my $message = "cclite $fields{version} gateway ";

    # invalid 'from' user or invalid currency, returns straight away
    if (   !length($fromuserref)
        || !length($currencyref)
        || !length($registryref) )
    {
        $message .= "$messages{merchantkeyerror}:" if ( !length($registryref) );
        $message .= "$messages{notregisterederror}->$fields{email}:"
          if ( !length($fromuserref) );
        $message .= "$messages{currencysymbolerror}->$fields{currency_code}:"
          if ( !length($currencyref) );
        print
"Location: $fields{cancel_url}?$fields{osCsid}&payment_error=1&error_message=$message\n\n";
    }

# now construct and do a transaction for each 'manufacturer' who is, in fact a Cclite 'userLogin'
# from om_users, each to payment is of form "to:userLogin"
# this is two-pass, it needs to make sure that ALL the users (manufacturers) are
# present otherwise it won't process ANY of the order. This is cleaner than
# partially processing the order.
#
    $ok = 1;
    foreach my $key ( keys %fields ) {
        if ( $key =~ /^to:(\w+)/ && $fields{onlinestatus} eq "live" ) {
            my $touser = $1;    # payment destination
            my ( $terror, $touserref ) = get_where(
                $class,      $fields{registry},
                'om_users',  '*',
                'userLogin', $touser,
                $token,      $offset,
                $limit
            );
            $ok = 0 if ( !length($touserref) );
            $message .= "$messages{manufacturererror}->$touser"
              if ( !length($touserref) );
        }
    }

    # don't go on if even one 'manufacturer' is not found
    print
"Location: $fields{cancel_url}?$fields{osCsid}&payment_error=1&error_message=$message\n\n"
      if ( !$ok );

    foreach my $key ( keys %fields ) {
        $html .= "$key:$fields{$key}<br/>";

        if ( $key =~ /^to:(\w+)/ && $fields{onlinestatus} eq "live" ) {
            my $touser = $1;    # payment destination
                 # convert to standard transaction input format, fields etc.
                 #fromregistry : chelsea
            $transaction{fromregistry} = $fields{registry};
            $transaction{home} = "";    # no home, not a web transaction
                                        #subaction : om_trades
            $transaction{subaction} = 'om_trades';

            #toregistry : chelsea, single registry only, currently
            $transaction{toregistry} = $fields{registry};

           #tradeAmount : 23 : this value is in the to:userLogin key is quantity
            $transaction{tradeAmount} = $fields{$key};

            #tradeCurrency : ducket
            $transaction{tradeCurrency} = $$currencyref{name};

            #tradeDate : 20050423
            # added by transaction routine at point of processing
            # configured intial status in cclite.cf
            $transaction{tradeStatus} = $fields{initialPaymentStatus};

            #tradeDescription : test
            $transaction{tradeTitle} =
              "store payment from osc: $fields{item_id}";

            #tradeDestination : ddawg
            $transaction{tradeDestination} = $touser;

            #tradeItem : test to see variables
            #tradeSource : manager
            $transaction{tradeSource} = $$fromuserref{userLogin};

            # trade tax flag
            $transaction{tradeTaxflag} = $fields{taxflag};

            # make a reference to the transaction hash and
            # call ordinary transaction
            my $transaction_ref = \%transaction;
            if ($ok) {
                my ( $metarefresh, $home, $error, $output_message, $page, $c ) =
                  transaction( 'osc', $transaction{fromregistry},
                    'om_trades', $transaction_ref, "", $token );
            }    # endif
        }    # endif: search for manufacturers
    }    # end foreach

    if ( $fields{onlinestatus} eq "live" ) {
        print "Location: $fields{return_url}?$fields{osCsid}\n\n";
    } else {
        return ( "0", $fields{home}, "", $html, "result.html", "" );
    }
}

1;

