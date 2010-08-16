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
my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}
__END__


=head3 comments

FIXME:
This is just a test harness for the improved Oodoc module at present
It needs to be merged with writedirectory.pl

=cut

use lib "../../../lib";
use strict;    # all this code is strict
use locale;

#use Log::Log4perl;
#Log::Log4perl->init( $configuration{'loggerconfig'} );
#our $log = Log::Log4perl->get_logger("cclite");


use OpenOffice::OODoc;
use Ccdirectory;             # yellow pages directory etc.
use Ccsecure;                # security and hashing
use Cclitedb;                # this probably should be delegated
use Ccconfiguration ;

my  %configuration = readconfiguration();

my %fields    = cgiparse();

# for cron, replace these with hardcoded registry name

my $cookieref = get_cookie();
my $registry  = $$cookieref{registry} ;
my $language  = $$cookieref{language} || 'en' ;

my $token ;

# write the printed document out by directory and language...
my $document = odfDocument(file => "$configuration{printpath}/$registry/$language/directory.odt");

my $sqlstring = 'SELECT description,type FROM om_yellowpages o LIMIT 0,1000' ;

my ( $registry_error, $array_ref ) =
      sqlraw_return_array( 'local', 'dalston', $sqlstring, undef, $token );

foreach my $row (@$array_ref)  {
        
        my $text = "$$row[0]\n$$row[1]" ;
        print "$text<br/>" ;
        $document->appendParagraph
                        (
                        text    => $text,
                        style   => 'Text body'
                        );
 ##       $document->appendTable("My Table", 6, 4);
 ##     $document->cellValue("My Table", 2, 1, "New value");
        

}

$document->save;
exit 0;

