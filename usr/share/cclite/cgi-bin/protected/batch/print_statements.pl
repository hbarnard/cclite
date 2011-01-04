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

sub print_statements {

    my ( $class, $db, $user, $document, $title, $table_lines, $column_headers_hash_ref,
        $token )
      = @_;

    # starts at 1 to give headings ...
    my $item_counter      = 1;
    my $table_row_counter = 1;
    my $table_counter     = 1;

    my ($error, $count, $trade_hash_ref) = get_trades ( $class, $db, $user, 'active', $token, '', '' ) ;
    # tradeId,tradeStatus,tradeDate,tradeSource,tradeDestination,tradeMirror,tradeCurrency,tradeType,tradeAmount
    # how many records in total in the yellow pages
    my $total_lines = scalar keys %$trade_hash_ref;
    my $table_count = $total_lines / $table_lines;
    $total_lines % $table_lines ? $table_count++ : $table_count;

    # print "total lines are $total_lines\n" ;

    # write out empty table pages + page break paragraph, ready to fill
    for ( $x = 1 ; $x <= $table_count ; $x++ ) {
        my $table = $document->appendTable( "t$user$x", ( $table_lines + 1 ), 10);
     #   paragraph( $document, $title, 1 );

        $document->cellValue( "t$user$x", 0, 0,
            $column_headers_hash_ref->{'tradeId'} );
        $document->cellValue( "t$user$x", 0, 1,
            $column_headers_hash_ref->{'tradeStatus'} );
        $document->cellValue( "t$user$x", 0, 2,
            $column_headers_hash_ref->{'tradeDate'} );
        $document->cellValue( "t$user$x", 0, 3,
            $column_headers_hash_ref->{'tradeSource'} );
        $document->cellValue( "t$user$x", 0, 4,
            $column_headers_hash_ref->{'tradeDestination'} );
        $document->cellValue( "t$user$x", 0, 5,
            $column_headers_hash_ref->{'tradeMirror'} );
 $document->cellValue( "t$user$x", 0, 6,
            $column_headers_hash_ref->{'tradeCurrency'} );
 $document->cellValue( "t$user$x", 0, 7,
            $column_headers_hash_ref->{'tradeType'} );
 $document->cellValue( "t$user$x", 0, 8,
            $column_headers_hash_ref->{'tradeAmount'} );
 
    }

    foreach my $key ( sort keys %$trade_hash_ref) {

        my $current_table = "t$user$table_counter" ;

        $document->cellValue( $current_table, $item_counter, 0,
            $trade_hash_ref->{$key}->{'tradeId'} );
        $document->cellValue( $current_table, $item_counter, 1,
            $trade_hash_ref->{$key}->{'tradeStatus'} );
        $document->cellValue( $current_table, $item_counter, 2,
            $trade_hash_ref->{$key}->{'tradeDate'} );
        $document->cellValue( $current_table, $item_counter, 3,
            $trade_hash_ref->{$key}->{'tradeSource'} );
        $document->cellValue( $current_table, $item_counter, 4,
            $trade_hash_ref->{$key}->{'tradeDestination'} );
        $document->cellValue( $current_table, $item_counter, 5,
            $trade_hash_ref->{$key}->{'tradeMirror'} );
        $document->cellValue( $current_table, $item_counter, 6,
            $trade_hash_ref->{$key}->{'tradeCurrency'} );
        $document->cellValue( $current_table, $item_counter, 7,
            $trade_hash_ref->{$key}->{'tradeType'} );
        $document->cellValue( $current_table, $item_counter, 8,
            $trade_hash_ref->{$key}->{'tradeAmount'} );

        # testing only
        ### $document->cellValue( $current_table, $item_counter, 5,
        ###     $yellowdirectory_hash_ref->{$key}->{'sortal'} );

        $table_row_counter++;
        $item_counter++;

        # move to next table and reset table rows
        if ( $table_row_counter > $table_lines ) {
            $table_counter++;
            $table_row_counter = 1;
        }

    }

}

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

my %configuration = readconfiguration();

my %fields = cgiparse();

my $cookieref = get_cookie();
my $registry  = $$cookieref{registry} || 'dalston';
my $language  = $$cookieref{language} || 'en';

# lines in one page of table
my $table_lines = 40;

# where to create the open-office output
my $output_file = "/home/hbarnard/cclite-support-files/testing/statements.odt";

# title of each page
my $title = "Statement";

# headings for table columns
my $column_headers_hash_ref;

# change these, where necessary, column headers
            $column_headers_hash_ref->{'tradeId'} = 'Id';
            $column_headers_hash_ref->{'tradeStatus'} = 'Status';
            $column_headers_hash_ref->{'tradeDate'} = 'Date';
            $column_headers_hash_ref->{'tradeSource'} = 'From';
            $column_headers_hash_ref->{'tradeDestination'} = 'To';
            $column_headers_hash_ref->{'tradeMirror'} = 'Registry';
            $column_headers_hash_ref->{'tradeCurrency'} = 'Currency';
            $column_headers_hash_ref->{'tradeType'} = 'Type';
            $column_headers_hash_ref->{'tradeAmount'} = 'Quantity';



my ( $token, $offset, $limit );

# write the printed document out by directory and language...

my $document = odfDocument(
    file   => $output_file,
    create => 'text'
);
style($document);

my ($registry_error,$user_hash_ref) = get_where_multiple (
        'local', $registry,    'om_users',  '*','userLogin',
        '*',  '', 0, 9999999 );


foreach my $key ( sort keys %$user_hash_ref) {

print "$user_hash_ref->{$key}->{'userLogin'} \n" ;

paragraph( $document, "$title for $user_hash_ref->{$key}->{'userLogin'}", 0 );


print_statements( 'local', $registry, $user_hash_ref->{$key}->{'userLogin'}, $document, $title, $table_lines,
    $column_headers_hash_ref, $token );
}


$document->save;
exit 0;

