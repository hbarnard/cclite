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

print STDOUT "Content-type: text/html\n\n";

#my $data = join( '', <DATA> );
#eval $data;
#if ($@) {
#    print $@;
#    exit 1;
#}
#__END__

sub print_yellow_dir {

    my ( $class, $db, $document, $title, $table_lines, $column_headers_hash_ref,
        $token )
      = @_;

    # starts at 1 to give headings ...
    my $item_counter      = 1;
    my $table_row_counter = 1;
    my $table_counter     = 1;

    my ( $yellowdirectory_hash_ref, $category_hash_ref ) =
      get_yellowpages_directory_print( $class, $db, $token );

    # how many records in total in the yellow pages
    my $total_lines = scalar keys %$yellowdirectory_hash_ref;
    my $table_count = $total_lines / $table_lines;
    $total_lines % $table_lines ? $table_count++ : $table_count;

    # write out empty table pages + page break paragraph, ready to fill
    for ( $x = 1 ; $x <= $table_count ; $x++ ) {
        my $table = $document->appendTable( "t$x", ( $table_lines + 1 ), 6 );
        paragraph( $document, $title, 1 );

        $document->cellValue( "t$x", 0, 0,
            $column_headers_hash_ref->{'Category'} );
        $document->cellValue( "t$x", 0, 1,
            $column_headers_hash_ref->{'Mobile'} );
        $document->cellValue( "t$x", 0, 2,
            $column_headers_hash_ref->{'Fixed'} );
        $document->cellValue( "t$x", 0, 3,
            $column_headers_hash_ref->{'Subject'} );
        $document->cellValue( "t$x", 0, 4,
            $column_headers_hash_ref->{'Description'} );
        $document->cellValue( "t$x", 0, 5,
            $column_headers_hash_ref->{'Price'} );
    }

    foreach my $key ( sort keys %$yellowdirectory_hash_ref ) {

        my $current_table = 't' . $table_counter;

        # change this, to change expressed price...uses / to remain multilingual
        my $price_expression =
"$yellowdirectory_hash_ref->{$key}->{'price'} $yellowdirectory_hash_ref->{$key}->{'tradeCurrency'} \/  $yellowdirectory_hash_ref->{$key}->{'unit'}";

        # category, name of category + wanted/offered
        my $category =
"$category_hash_ref->{$key}->{'description'}\:$yellowdirectory_hash_ref->{$key}->{'type'}";

        $document->cellValue( $current_table, $item_counter, 0, $category );

        $document->cellValue( $current_table, $item_counter, 1,
            $yellowdirectory_hash_ref->{$key}->{'userMobile'} );
        $document->cellValue( $current_table, $item_counter, 2,
            $yellowdirectory_hash_ref->{$key}->{'userTelephone'} );
        $document->cellValue( $current_table, $item_counter, 3,
            $yellowdirectory_hash_ref->{$key}->{'subject'} );
        $document->cellValue( $current_table, $item_counter, 4,
            $yellowdirectory_hash_ref->{$key}->{'description'} );
        $document->cellValue( $current_table, $item_counter, 5,
            $price_expression );

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
use strict;    # all this code is strict
use locale;

use Log::Log4perl;

#Log::Log4perl->init( $configuration{'loggerconfig'} );
#our $log = Log::Log4perl->get_logger("cclite");

use OpenOffice::OODoc;
use Ccdirectory;    # yellow pages directory etc.
use Ccsecure;       # security and hashing
use Cclitedb;       # this probably should be delegated
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
my $output_file = "/home/hbarnard/cclite-support-files/testing/directory.odt";

# title of each page
my $title = "Yellow Pages";

# headings for table columns
my $column_headers_hash_ref;
$column_headers_hash_ref->{'Category'}    = 'Category';
$column_headers_hash_ref->{'Mobile'}      = 'Mobile';
$column_headers_hash_ref->{'Fixed'}       = 'Fixed';
$column_headers_hash_ref->{'Subject'}     = 'Subject';
$column_headers_hash_ref->{'Description'} = 'Description';
$column_headers_hash_ref->{'Price'}       = 'Price';

my ( $token, $offset, $limit );

# write the printed document out by directory and language...

my $document = odfDocument(
    file   => $output_file,
    create => 'text'
);
style($document);
paragraph( $document, $title, 0 );
print_yellow_dir( 'local', $registry, $document, $title, $table_lines,
    $column_headers_hash_ref, $token );

$document->save;
exit 0;

