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

    my ( $class, $db, $user_hash_ref, $document, $title, $table_lines, $column_headers_hash_ref,
        $token )
      = @_;

    # starts at 1 to give headings ...
    my $item_counter      = 1;
    my $table_row_counter = 1;
    my $table_counter     = 1;
 

    my $sqlstring = <<EOT; 
SELECT tradeId,tradeType,tradeDate,tradeTitle, tradeSource,tradeDestination, tradeCurrency, format((tradeAmount/100),2) as total from om_trades 
 where (tradeSource = '$user_hash_ref->{'userLogin'}' and tradeType = 'debit' and month(tradeDate) = '4')
union
SELECT tradeId,tradeType,tradeDate,tradeTitle, tradeSource,tradeDestination, tradeCurrency, format((tradeAmount/100),2) as total from om_trades 
 where (tradeDestination = '$user_hash_ref->{'userLogin'}' and tradeType = 'credit' and month(tradeDate) = '4')

EOT

 
    my ($registryerror, $trade_hash_ref) =  sqlraw  ( $class, $db, $sqlstring, 'tradeId', '' ) ;
 
 
    # tradeId,tradeStatus,tradeDate,tradeSource,tradeDestination,tradeMirror,tradeCurrency,tradeType,tradeAmount
    # how many records in total in the yellow pages
    my $total_lines = scalar keys %$trade_hash_ref;
    my $table_count = $total_lines / $table_lines;
    
    # if there's a remainder increment table count...
    $total_lines % $table_lines ? $table_count++ : $table_count;


    my $address =<<EOT;
    $user_hash_ref->{'userName'}
    $user_hash_ref->{'userNameornumber'} $user_hash_ref->{'userStreet'},
    $user_hash_ref->{'userTown'} $user_hash_ref->{'userPostcode'}
EOT
    
    $document->appendParagraph
                        (
                        text    => $address,
                        style   => 'Text body'
                        );






    # print "total lines are $total_lines\n" ;

    # write out empty table pages + page break paragraph, ready to fill
    for ( $x = 1 ; $x <= $table_count ; $x++ ) {
        
        my $table_id  = "t$user_hash_ref->{'userLogin'}$x" ;
        my $table = $document->appendTable( $table_id , ( $table_lines + 1 ), 10);
     #   paragraph( $document, $title, 1 );

        $document->cellValue( $table_id, 0, 0,
            $column_headers_hash_ref->{'tradeId'} );
        $document->cellValue( $table_id, 0, 1,
            $column_headers_hash_ref->{'tradeStatus'} );
        $document->cellValue( $table_id, 0, 2,
            $column_headers_hash_ref->{'tradeDate'} );
        $document->cellValue( $table_id, 0, 3,
            $column_headers_hash_ref->{'tradeSource'} );
        $document->cellValue( $table_id, 0, 4,
            $column_headers_hash_ref->{'tradeDestination'} );
        $document->cellValue( $table_id, 0, 5,
            $column_headers_hash_ref->{'tradeMirror'} );
 $document->cellValue( $table_id, 0, 6,
            $column_headers_hash_ref->{'tradeCurrency'} );
 $document->cellValue( $table_id, 0, 7,
            $column_headers_hash_ref->{'tradeTitle'} );
                        
 $document->cellValue( $table_id, 0, 8,
            $column_headers_hash_ref->{'debit'} );
            
 $document->cellValue( $table_id, 0, 9,
            $column_headers_hash_ref->{'credit'} );           
 
    }

    foreach my $key ( sort keys %$trade_hash_ref) {

        my $current_table = "t$user_hash_ref->{'userLogin'}$table_counter" ;

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
            $trade_hash_ref->{$key}->{'tradeTitle'} );
 
    # different column for credits and Debits    
        my $column ;
        $trade_hash_ref->{$key}->{'tradeType'} eq 'debit' ? ($column = 8) : ($column = 9) ; 
        print "$trade_hash_ref->{$key}->{'tradeType'} $column\n" ;          
        $document->cellValue( $current_table, $item_counter, $column,
            $trade_hash_ref->{$key}->{'total'} );

 
 
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

# correct path for output file
# my $output_file = "$configuration{'printdir'}/$registry/$language"

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
            # these don't correspond to fields...
            $column_headers_hash_ref->{'debit'} = 'Money Out';
            $column_headers_hash_ref->{'credit'} = 'Money In';



my ( $token, $offset, $limit );

# write the printed document out by directory and language...

my $document = odfDocument(
    file   => $output_file,
    create => 'text'
);
style($document);


# get all users
my ($registry_error,$user_hash_ref) = get_where_multiple (
        'local', $registry,    'om_users',  '*','userLogin',
        '*',  '', 0, 9999999 );


foreach my $key ( sort keys %$user_hash_ref) {

# don't print system accounts as printed statements
next if ($user_hash_ref->{$key}->{'userLevel'} eq 'sysaccount' || $user_hash_ref->{$key}->{'userLevel'} eq 'admin') ;

print "$user_hash_ref->{$key}->{'userLogin'} \n" ;

paragraph( $document, "$title for $user_hash_ref->{$key}->{'userLogin'}", 0 );


print_statements( 'local', $registry, $user_hash_ref->{$key}, $document, $title, $table_lines,
    $column_headers_hash_ref, $token );
}


$document->save;
exit 0;

