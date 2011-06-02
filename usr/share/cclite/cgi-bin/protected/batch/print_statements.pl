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

=pod get_balances_to_date

This duplicates show_balance_and_colume somewhat but with date restrictions
since we don't want to include the current transactions in the -previous- balance figures 

Although it would be elegant to merge the two, it may just create extra complexity...

=cut

sub get_balances_to_date {

    my ( $class, $db, $user, $statement_month, $statement_year ) = @_;

    my $sqlstring = <<EOT;
 SELECT tradeId,tradeCurrency as currency, sum(tradeAmount) as sum from om_trades 
where tradeType = 'credit' and
tradeDestination = '$user' and
( tradeStatus = 'waiting' or tradeStatus = 'accepted' ) and
tradeDestination != 'cash' and (datediff(tradeDate,'$statement_year-$statement_month-1') < 0)
group by currency
union

SELECT tradeId,tradeCurrency as currency, -(sum(tradeAmount)) as sum from om_trades 
where tradeType = 'debit' and
tradeSource = '$user' and
( tradeStatus = 'waiting' or tradeStatus = 'accepted' ) and
tradeDestination != 'cash' and (datediff(tradeDate,'$statement_year-$statement_month-1') < 0)
group by currency     
EOT

    my %total_balance;

    my ( $registryerror, $balance_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'tradeId', '' );

    foreach my $key ( keys %$balance_hash_ref ) {

        $total_balance{ $balance_hash_ref->{$key}->{'currency'} } +=
          $balance_hash_ref->{$key}->{'sum'};
    }

    my $balances;

    # this is a little ugly, formatted a second variable for printed
    # and kept a hash ref in 'pence' for the cumulative addition 5/2011
    foreach my $key ( sort keys %total_balance ) {
        
          my $printed_balance = $total_balance{$key} ;
          $printed_balance = sprintf "%.2f",
          ( $printed_balance/100 )
          if ( $configuration{usedecimals} eq 'yes' );
          
        $balances .= "$key = $printed_balance \n";
    }

    $balances = <<EOT;
Previous balances are:
$balances
-----------------------
EOT

    return ( $balances, \%total_balance );

}


=pod print_statements

There are three parts to this, like Gaul:

1. Get the balances on file from previous months for all currencies
2. Print and cumulate the current month
3. Calculate and print balances reported at the end of the month

Since there's now a facility for decimals, all arithmetic is done with
'pence', 'cents' etc and reformatted at the end

=cut



sub print_statements {

    my (
        $class,    $db,              $user_hash_ref,
        $document, $statement_month, $statement_year,
        $title,    $table_lines,     $column_headers_hash_ref,
        $token
    ) = @_;

    # starts at 1 to give headings ...
    my $item_counter      = 1;
    my $table_row_counter = 1;
    my $table_counter     = 1;
    my %total_this_month ;    # hash keyed by currency

    # individual statement lines..
    my $sqlstring = <<EOT;
SELECT tradeId,tradeType,tradeDate,tradeTitle, tradeSource,tradeDestination, tradeCurrency, -(tradeAmount) as tradeAmount from om_trades 
 where (tradeSource = '$user_hash_ref->{'userLogin'}' and tradeType = 'debit' and month(tradeDate) = '$statement_month' and year(tradeDate) = '$statement_year')
union
SELECT tradeId,tradeType,tradeDate,tradeTitle, tradeSource,tradeDestination, tradeCurrency, tradeAmount from om_trades 
 where (tradeDestination = '$user_hash_ref->{'userLogin'}' and tradeType = 'credit' and month(tradeDate) = '$statement_month' and year(tradeDate) = '$statement_year')

EOT

    my ( $registryerror, $trade_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'tradeId', '' );

    # no trade data, return
    return if ( !scalar keys %$trade_hash_ref );

# tradeId,tradeStatus,tradeDate,tradeSource,tradeDestination,tradeMirror,tradeCurrency,tradeType,tradeAmount
# how many records in total in the yellow pages
    my $total_lines = scalar keys %$trade_hash_ref;
    my $table_count = $total_lines / $table_lines;

    # if there's a remainder increment table count...
    $total_lines % $table_lines ? $table_count++ : $table_count;

    my $address = <<EOT;
    $user_hash_ref->{'userName'}
    $user_hash_ref->{'userNameornumber'} $user_hash_ref->{'userStreet'},
    $user_hash_ref->{'userTown'} $user_hash_ref->{'userPostcode'}
EOT

    # address at the top of the statement
    $document->appendParagraph(
        text  => $address,
        style => 'Text body'
    );

    # formatting done already, perhaps that's a misteak...
    my ( $balances, $total_balance_todate_ref ) =
      get_balances_to_date( $class, $db, $user_hash_ref->{'userLogin'},
        $statement_month, $statement_year );

    $document->appendParagraph(
        text  => $balances,
        style => 'Text body'
    );

    $document->cellStyle( $table_id, 0, 0, 'BlueStyle' );

    # print "total lines are $total_lines\n" ;

    # write out empty table pages + page break paragraph, ready to fill
    for ( $x = 1 ; $x <= $table_count ; $x++ ) {

        my $table_id = "t$user_hash_ref->{'userLogin'}$x";
        my $table =
          $document->appendTable( $table_id, ( $table_lines + 1 ), 8 );

        $document->textStyle( $column_headers_hash_ref->{'tradeDate'},
            'BlueStyle' );

        $document->cellValue( $table_id, 0, 0,
            $column_headers_hash_ref->{'tradeDate'} );

        $document->cellValue( $table_id, 0, 1,
            $column_headers_hash_ref->{'tradeSource'} );

        $document->cellValue( $table_id, 0, 2,
            $column_headers_hash_ref->{'tradeDestination'} );

        $document->cellValue( $table_id, 0, 3,
            $column_headers_hash_ref->{'tradeCurrency'} );
        $document->cellValue( $table_id, 0, 4,
            $column_headers_hash_ref->{'tradeTitle'} );
        $document->cellValue( $table_id, 0, 5,
            $column_headers_hash_ref->{'debit'} );
        $document->cellValue( $table_id, 0, 6,
            $column_headers_hash_ref->{'credit'} );

    }    # endif write out empty table

    foreach my $key ( sort keys %$trade_hash_ref ) {

        my $current_table = "t$user_hash_ref->{'userLogin'}$table_counter";

        $document->cellValue( $current_table, $item_counter, 0,
            $trade_hash_ref->{$key}->{'tradeDate'} );
        $document->cellValue( $current_table, $item_counter, 1,
            $trade_hash_ref->{$key}->{'tradeSource'} );
        $document->cellValue( $current_table, $item_counter, 2,
            $trade_hash_ref->{$key}->{'tradeDestination'} );
        $document->cellValue( $current_table, $item_counter, 3,
            $trade_hash_ref->{$key}->{'tradeCurrency'} );
        $document->cellValue( $current_table, $item_counter, 4,
            $trade_hash_ref->{$key}->{'tradeTitle'} );

        # different column for credits and Debits
        my $column ;
        $trade_hash_ref->{$key}->{'tradeType'} eq 'credit'? ($column = 6) : ($column = 5) ;
        
        # running totals but in pence, format at end...    
        $total_this_month{ $trade_hash_ref->{$key}->{'tradeCurrency'} } +=
              $trade_hash_ref->{$key}->{'tradeAmount'};
                      
        # experimental: show decimal places for trades
        if ( $configuration{usedecimals} eq 'yes' ) {
            $trade_hash_ref->{$key}->{'tradeAmount'} = sprintf "%.2f",
              ( $trade_hash_ref->{$key}->{'tradeAmount'} / 100 );
        }


        my $cell;
        if ( $item_counter % 2 == 0 ) {
            $cell = $document->getCell( $current_table, $item_counter, 1 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 2 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 3 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 4 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 5 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 6 );
            $document->cellStyle( $cell, 'TelCell' );
            $cell = $document->getCell( $current_table, $item_counter, 7 );
            $document->cellStyle( $cell, 'TelCell' );

        }    # endif write blue cells

        #
        $document->cellValue( $current_table, $item_counter, $column,
            $trade_hash_ref->{$key}->{'tradeAmount'} );

        $table_row_counter++;
        $item_counter++;

        # move to next table and reset table rows
        if ( $table_row_counter > $table_lines ) {
            $table_counter++;
            $table_row_counter = 1;
        }

    }    #end foreach main transaction printing loop

   # print balances for the end of the statement, add previous totals to current
    my $balances_now;

    foreach my $key ( keys %total_this_month ) {
     
        my $total = $total_this_month{$key} + $total_balance_todate_ref->{$key};
     ###   print "$user_hash_ref->{'userLogin'} $total\n" ;
        
        # convert to decimals, if switched on
         $total = sprintf "%.2f",
          ( $total/100 )
          if ( $configuration{usedecimals} eq 'yes' );
        $balances_now .= "Current balance for $key = $total\n";
    }
    $document->appendParagraph(
        text  => $balances_now,
        style => 'Text body'
    );

}

#create experimental style

sub style {

    my ($document) = @_;
    $document->createStyle(
        "BlueStyle",
        parent     => 'Text body',
        family     => 'paragraph',
        properties => {
            area       => 'text',
            'fo:color' => rgb2oo('blue')
        }
    );

    return;
}

# create style for cell

sub tablestyle {

    my ($document) = @_;

    $document->createStyle(
        'TelCell',
        family     => 'table-cell',
        properties => {
            -area => 'table-cell',

            'fo:background-color' => '#BDEDFF',
        }
    );

=pod
sub tablestyle {
    
my ($document) = @_;

$document->createStyle ( 'TelCell', family => 'table-cell',
                        properties => { -area => 'table-cell', 
                        'fo:padding-left' => '1.00mm', 
                        'fo:padding-right' => '1.00mm', 
                        'fo:padding-top' => '1.00mm', 
                        'fo:padding-bottom' => '1.00mm',
                        'fo:background-color' => rgb2oo('blue'), 
                        'fo:border' => '0.02mm solid #000000', }
); 
=cut

    return;
}

sub paragraph {

    my ( $document, $text, $break ) = @_;

    my $para = $document->appendParagraph(
        text  => $text,
        style => "BlueStyle"
    );

    $document->setPageBreak($para) if $break;
    return;

}

=head3 comments


=cut

use lib "../../../lib";
use strict;
use locale;

use Log::Log4perl;

#Log::Log4perl->init( $configuration{'loggerconfig'} );
#our $log = Log::Log4perl->get_logger("cclite");

use OpenOffice::OODoc;
use Ccdirectory;    # yellow pages directory etc.
use Ccsecure;       # security and hashing
use Cclitedb;       # this probably should be delegated
use Cclite;         # for gettrades, at least
use Ccconfiguration;
use Ccu;
use Cccookie;

print "Content-type: text/html\n\n";

our %configuration = readconfiguration();
my %fields = cgiparse();

#replace entirely with cgi in a while...
my $statement_month = $fields{'month'}     || $ARGV[0];
my $statement_year  = $fields{'year'}      || $ARGV[1];
my $user_or_all     = $fields{'userorall'} || $ARGV[2] || 'all';

if ( !length($statement_month) || !length($statement_year) ) {
    print "need month and year for statements\n\n";
    exit 0;
}

my $cookieref = get_cookie();
my $registry  = $$cookieref{registry} || 'dalston';
my $language  = $$cookieref{language} || 'en';

# lines in one page of table
my $table_lines = 40;

# where to create the open-office output, whilst testing
my $output_file = "/home/hbarnard/cclite-support-files/testing/statements.odt";

# correct path for output file
# my $output_file = "$configuration{'printdir'}/$registry/$language"

# title of each page
my $title = "Statement";

# headings for table columns
my $column_headers_hash_ref;

# change these, where necessary, column headers
$column_headers_hash_ref->{'tradeId'}          = 'Id';
$column_headers_hash_ref->{'tradeStatus'}      = 'Status';
$column_headers_hash_ref->{'tradeDate'}        = 'Date';
$column_headers_hash_ref->{'tradeSource'}      = 'From';
$column_headers_hash_ref->{'tradeDestination'} = 'To';
$column_headers_hash_ref->{'tradeMirror'}      = 'Registry';
$column_headers_hash_ref->{'tradeCurrency'}    = 'Currency';
$column_headers_hash_ref->{'tradeType'}        = 'Type';
$column_headers_hash_ref->{'tradeTitle'}       = 'Description';

# these don't correspond to fields...
$column_headers_hash_ref->{'debit'}  = 'Money Out';
$column_headers_hash_ref->{'credit'} = 'Money In';

my ( $token, $offset, $limit );

# write the printed document out by directory and language...

my $document = odfDocument(
    file   => $output_file,
    create => 'text'
);

style($document);
tablestyle($document);

# get all users
my ( $registry_error, $user_hash_ref ) =
  get_where_multiple( 'local', $registry, 'om_users', '*', 'userLogin', '*', '',
    0, 9999999 );

foreach my $key ( sort keys %$user_hash_ref ) {

    # don't print system accounts as printed statements
    next
      if ( $user_hash_ref->{$key}->{'userLevel'} eq 'sysaccount'
        || $user_hash_ref->{$key}->{'userLevel'} eq 'admin' );

    paragraph(
        $document,
"$title for $user_hash_ref->{$key}->{'userLogin'} $statement_month/$statement_year",
        1
    );

    print_statements(
        'local',   $registry,        $user_hash_ref->{$key},
        $document, $statement_month, $statement_year,
        $title,    $table_lines,     $column_headers_hash_ref,
        $token
    );

}

$document->save;
exit 0;

