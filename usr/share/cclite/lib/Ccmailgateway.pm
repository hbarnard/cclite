
=head1 NAME

Ccmailgateway.pm

=head1 SYNOPSIS

Transaction conversion interfaces inwards for mail etc.

=head1 DESCRIPTION

This is the second generation mail transaction logic:

- better checking
- provides some feedback
- remote mailboxes rather than local read of mail file
- in separate module to prepare for gpg etc. etc.



Mail Transactions
-> Confirm pin         p123456 confirm (to be done)
-> Change pin          p123456 change p345678 (to be done)
-> Pay                 send 5 <currencyname> to <username> at <registry_name> for stuff
-> Query Balance       balance (to be done, like sms mailed balance transaction)


=head1 AUTHOR

Hugh Barnard



=head1 SEE ALSO

Cchooks.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 - 2008 GPL Licenced
 
=cut

package Ccmailgateway;
use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
my $VERSION = 1.00;
@ISA = qw(Exporter);

use Cclite;
use Cclitedb;
use Ccu;
###use Ccsecure;
use Ccconfiguration;    # new style configuration method
###use Net::POP3;
###use Net::SMTP;

my %configuration = readconfiguration;

@EXPORT = qw(
  mail_message_parse
  mail_transaction
);

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash
 
=cut

# changed to get language from decide_language 08/2011
our %messages = readmessages();

=head3 _check_to_and_from

Check the sender, receiver and currency exist in the registry
Also get userPublickeyid for the transaction originator so that the key
can be retrieved...

=cut

sub _check_to_and_from {

    my ( $registry, $transaction_description_ref ) = @_;

    my ( $message, $token, $offset, $limit );

    ###print "transaction description is $transaction_description_ref->{'text'}\n" ;

    # this is an email address, need to escape at least @
    my $from = quotemeta( $transaction_description_ref->{'from'} );

    my ( $error, $fromuserref ) =
      get_where( 'local', $transaction_description_ref->{'registry'},
        'om_users', '*', 'userEmail', $from, $token, '', '' );

    #
    my ( $error, $touserref ) = get_where(
        'local',     $transaction_description_ref->{'registry'},
        'om_users',  '*',
        'userLogin', $transaction_description_ref->{'destination'},
        $token,      $offset,
        $limit
    );

    my ( $error, $currencyref ) = get_where(
        'local',         $transaction_description_ref->{'registry'},
        'om_currencies', '*',
        'name',          $transaction_description_ref->{'currency'},
        $token,          $offset,
        $limit
    );

    my $error;

    # added test for blank from to guard against bad email parse etc..
    $error = "$messages{'unknownsender'} "
      if ( !length($fromuserref) || ( !length($from) ) );
    $error .= "$messages{'unknownrecipient'} " if ( !length($touserref) );
    $error .= "$messages{'unknowncurrency'} "  if ( !length($currencyref) );

   #FIXME: cross registry is not allowed in batch processes at present 12/3/2010
    if ( $transaction_description_ref->{'registry'} ne $registry ) {
        $error .= "$messages{'nocrossregistry'} ";
    }

    # one of the above lookups fails, reject the whole transaction
    if ( length($error) ) {
        $message =
"$transaction_description_ref->{'from'} transaction invalid: $transaction_description_ref->{'error'} $error";
    }
    return $message;
}

=head3 _fuzzy_ark_parse


Items go two by two, I hate this but it seems more solid
than the all-at-once parser, for mail anyway...
FIXME: If you want another language you need to replace this..


=cut

sub _fuzzy_ark_parse {

    my ($input) = @_;

    # begin parse on whitespace
    my ( %transaction_description, $status );
    my $found_count = 0;    # used to count elements parsed
    $input = lc($input);    # canonical is lower case

    # tokenise on white space...
    my @words = split( /\s+/, $input );

    # fuzzy ark parsing the terms mainly go two-by-two!
    # count of found elements should be 5 in a valid transaction

    my $counter = 0;        # used for term lookahead

    # this should be send, balance, confirm etc...
    $transaction_description{'type'} = $words[0];

    foreach my $word (@words) {

        if ( $word =~ /^(\d+)$/ ) {
            $transaction_description{'amount'} =
              $word;        # amount is the only numeric thing
            $found_count++;
            $transaction_description{'currency'} =
              $words[ ( $counter + 1 ) ];    # currency is next to quantity

# make singular for english language currencies dallies = dally, limes = lime...
            $transaction_description{'currency'} =~ s/ies$/y/i;
            $transaction_description{'currency'} =~ s/s$//i;

            $found_count++
              if ( length( $transaction_description{'currency'} ) );

        }
        if ( $word eq "to" ) {               # found 'to'
            $transaction_description{'destination'} =
              $words[ ( $counter + 1 ) ];    # touser is next
            $found_count++
              if ( length( $transaction_description{'destination'} ) );

        }
        if ( $word eq "at" ) {               # found 'at'
            $transaction_description{'registry'} =
              $words[ ( $counter + 1 ) ];    # toregistry is next
            $found_count++
              if ( length( $transaction_description{'fromregistry'} ) );

        }
        $counter++;
    }

    $input =~ /for\s+(\w.*)$/i;              # description is everything at end
         # look up sending user, receiving user and currency
    $transaction_description{'description'} = $1;
    $found_count++ if ( length( $transaction_description{'description'} ) );

    return ( $found_count, \%transaction_description );

}

=head3 mail_message_parse

This is parse, validation both for mail and jabber, needs a new name perhaps
Will only do 'send' and 'balance' at the moment. This whole area probably
needs merging with SMS and smart phone widgets too...

=cut

sub mail_message_parse {

    my ( $class, $registry, $from, $to, $subject, $text ) = @_;

    # '$to' here is the registry batch email address, not the destination user!
    # send 4 duckets to unknown at dalston for barking lessons

    my $parse_type = 0;
    my ( $count, $transaction_description_ref, $error_message, $token );

    ( $count, $transaction_description_ref ) = _fuzzy_ark_parse($text);

    #FIXME: this quoting needs to go down into the db layer...
    # necessary for mail but not for jabber?
    my $quote_from = quotemeta($from);

    my ( $error, $fromuserref ) = get_where(
        $class,      $registry,   'om_users', '*',
        'userEmail', $quote_from, $token,     '',
        ''
    );

    $transaction_description_ref->{'userPublickeyid'} =
      $fromuserref->{'userPublickeyid'};
    $transaction_description_ref->{'source'} = $fromuserref->{'userLogin'};
    $transaction_description_ref->{'name'}   = $fromuserref->{'userName'};

    if ( $transaction_description_ref->{'type'} eq 'send' ) {

        $transaction_description_ref->{'text'} =
          _make_pretty_transaction_description($transaction_description_ref);

        # need this later to deduce the payer...
        $transaction_description_ref->{'from'}  = $from;
        $transaction_description_ref->{'title'} = $subject;

# check currency, registry and destination are OK, if not cumulate with errors
# deduce tradeSource using 'from' email, get public key id from originator record

        (

            $error_message ) =
          _check_to_and_from( $registry, $transaction_description_ref );

        my $text = $transaction_description_ref->{'text'};

        # there must be at least 4 components in a send message
        $transaction_description_ref->{'error'} .=
          $messages{'incompletetransaction'}
          if ( $count < 4 );

    } elsif ( $transaction_description_ref->{'type'} eq 'balance' ) {

# FIXME: probably needs regression testing with non-encrpyted...
# FIXME: no reason not to parse/allow multiregistry query via 'balance <registryname>'

        $transaction_description_ref->{'registry'} = $registry;

        # this is a balance request...

        $transaction_description_ref->{'text'} =
          _mail_get_balance( $registry, $quote_from,
            $transaction_description_ref->{'currency'} );

    } else {
        $transaction_description_ref->{'error'} =
          "$messages{'incompletetransaction'}: $text";
    }

    $transaction_description_ref->{'error'} .= $error_message
      if ( length($error_message) );

    return ( $parse_type, $transaction_description_ref );

}

sub _make_pretty_transaction_description {

    my ($transaction_description_ref) = @_;
    my $pretty_description;

    # this is the description for the email...
    foreach my $key ( keys %$transaction_description_ref ) {
        $pretty_description .= "$key: $$transaction_description_ref{$key}\n";
    }

    return $pretty_description;
}

sub mail_transaction {

    my ($transaction_description_ref) = @_;
    my %transaction;

    # convert to standard transaction input format, fields etc.
    #fromregistry : chelsea
    $transaction{fromregistry} = $transaction_description_ref->{'registry'};

    #home : http://cclite.caca-cola.com:83/cgi-bin/cclite.cgi, for example
    $transaction{home}      = "";            # no home, not a web transaction
                                             #subaction : om_trades
    $transaction{subaction} = 'om_trades';

    #toregistry : dalston
    $transaction{toregistry} = $transaction_description_ref->{'registry'};

    #tradeAmount : 23
    $transaction{tradeAmount} = $transaction_description_ref->{'amount'};

    #tradeStatus : default taken from configuration
    $transaction{tradeStatus} = $configuration{'initialpaymentstatus'};

    #tradeCurrency : ducket
    $transaction{tradeCurrency} = $transaction_description_ref->{'currency'};

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $transaction{tradeDate} = $date;

    $transaction{tradeTitle} = $transaction_description_ref->{'title'};

    #tradeDescription : added by this routine
    $transaction{tradeDescription} =
      $transaction_description_ref->{'description'};

    #tradeDestination : ddawg
    $transaction{tradeDestination} =
      $transaction_description_ref->{'destination'};

    #tradeItem : test to see variables
    #tradeSource : manager
    $transaction{tradeSource} = $transaction_description_ref->{'source'};

    # remove html from response, this is not true csv though..

    $transaction{mode} = 'csv';

    # call ordinary transaction
    my ( $token, $pages );
    my $transaction_ref = \%transaction;
    my ( $metarefresh, $home, $error, $output_message, $page, $c ) =
      transaction( 'mail', $transaction{fromregistry},
        'om_trades', $transaction_ref, $pages, $token );

    return "$output_message\n $transaction_description_ref->{'text'}";
}

=head3 _mail_get_balance

FIXME: duplicate in Ccsmsgateway and needed for jabber
Send balance, via email at present, sms later...
To be done...

=cut

sub _mail_get_balance {

    my ( $registry, $quote_from, $currency ) = @_;
    my ( $token, $offset, $limit, $balance_ref, $volume_ref );

    my ( $error, $fromuserref ) = get_where(
        'local',     $registry,   'om_users', '*',
        'userEmail', $quote_from, $token,     $offset,
        $limit
    );

    my %fields = ( 'userLogin', $fromuserref->{'userLogin'} );
    my $fieldsref = \%fields;

    # html to return html, values to return raw balances and volumes
    # for each currency
    ( $balance_ref, $volume_ref ) =
      show_balance_and_volume( 'local', $registry, $fromuserref->{'userLogin'},
        'values', $token );

    # current balance for this particular currency
    my $message;

    if ( !length($currency) ) {
        foreach my $curr ( sort keys %$balance_ref ) {
            $message .= "$curr= $balance_ref->{$curr}\n";
        }
    } else {
        $message .= "$currency = $balance_ref->{$currency}\n";
    }
    return $message;
}

1;
