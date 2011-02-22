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

=head1 NAME

ccdirectory.cgi

=head1 SYNOPSIS

first version for printed directory from database

=head1 DESCRIPTION

This uses open office modules to provide a printed directory
from the cclite database. It is currently experimental and
rather incomplete.


=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO

cclite.cgi

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced
 
=cut

#-----------------------------------------------------------
# This is the batch program that writes out yellow pages as an open office
# document, first ordered by category and then by user
#
# To get to word or pdf, load into Open Office tidy up
# and re-output

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
use Ccconfiguration;
use Ccu;
use Cccookie;

my %configuration;
%configuration = readconfiguration();

my $doc = odfDocument(
    file   => 'directory.odt',
    create => 'text'
);

my %fields = cgiparse();

#  this should use the version modules, but that makes life more
# complex for intermediate users

$fields{version} = $configuration{version};

# get admin level and registry from cookies, slightly more secure
# than 'just' assuming them

my $cookie_ref = get_cookie();
my $db         = $cookie_ref->{registry};
my $user_level = $cookie_ref->{userLevel};

# only admins can create printable directories

exit 0 if ( $user_level ne 'admin' );

my $columnsize = $fields{cols}
  || 3;    # change this if you want larger or smaller rows

my $class = "local";

# don't use if there's only a small amount of ads
my $bigheading = $fields{bigheading}
  || 0;    # gives banner type heading for categories

# modify these for different directory presentations
# or add, in which case, also add to @sqlstrings and @headings

my $sqlcatstring = <<EOT;
SELECT DISTINCT o.parent, o.description AS ds, y.id, y.subject, y.description, u.userEmail, u.userMobile, u.userTelephone, y.fromuserid
FROM om_yellowpages y, om_users u, om_categories o
WHERE y.fromuserid = u.userLogin
AND y.parent = o.parent
AND y.category = o.category
ORDER BY y.parent,ds
EOT

my $sqluserstring = <<EOT;
SELECT DISTINCT o.parent, o.description AS ds, y.id, y.subject, y.description, u.userEmail, u.userMobile, u.userTelephone, y.fromuserid
FROM om_yellowpages y, om_users u, om_categories o
WHERE y.fromuserid = u.userLogin
AND y.parent = o.parent
AND y.category = o.category
ORDER BY y.fromuserid
EOT

my @sqlstrings = ( $sqlcatstring, $sqluserstring );
my @headings = ( "Directory by Category", "Directory by User" );
my $sqlstring;

my $row;
my $html;
my ( $major, $save_major, $minor, $save_minor );
my $first_pass = 1;

# experimental style creation and use

my $style_doc->createStyle(
    "Colour",
    family     => 'text',
    parent     => 'Default',
    properties => {
        'fo:text-align'       => 'justify',
        'style:font-name'     => 'Courier',
        'fo:font-size'        => '14pt',
        'fo:font-weight'      => 'bold',
        'fo:font-style'       => 'italic',
        'fo:color'            => '#000080',
        'fo:background-color' => '#ffff00'
    }
);

my $token ;

$doc->cloneContent($style_doc);

# set up table and first column
my $table_counter = 0;
my $page_counter  = 0;

foreach $sqlstring (@sqlstrings) {

# o.parent, o.description AS ds, y.id, y.subject, y.description, u.userEmail, u.userMobile, u.userTelephone, y.fromuserid
# 0	     1                    2     3          4              5            6             7                8
# get equi-joined table
    my ( $error, $row_ref ) =
      sqlraw_return_array( $class, $db, $sqlstring, 'id', $token );

    my $heading = shift(@headings);
    $doc->appendHeader(
        text  => $heading,
        level => '1',
        style => 'Heading 1'
    );

    my $column_counter = 0;
    my $row_counter    = 0;
    my $table = $doc->appendTable( "Directory$table_counter", 1, $columnsize,
        'text-style' => 'Colour' );

    foreach $row (@$row_ref) {

        my $text = join( "\r\n", @$row[ 3 .. 5 ] );
        ###$text = "<text:p text:style-name=\"Coucou\">$text</text:p>";
        $doc->textStyle( $text, 'Coucou' );
        my $cell =
          $doc->getCell( "Directory$table_counter", $row_counter,
            $column_counter );

        $doc->cellValue( $cell, $text );

        # print a heading line, if necessary
        if ( ( $first_pass || $save_major ne $$row[1] ) && $bigheading ) {

        } else {

        }

        # if there aren't big headings put an extra row on each record

        if ( !$bigheading ) {

        }

        # cumulating into n column table row
        # end of row
        if ( $column_counter == ( $columnsize - 1 ) ) {
            $doc->appendRow($table);
            $column_counter = 0;
            $row_counter++;
        } else {
            $column_counter++;
        }

        $save_major = $$row[1];
        $first_pass = 0;
    }    # end foreach table row

    $table_counter++;

}    # end foreach sqlstatement

$doc->save("directory.odt");
###$style_doc->save("directory.sxw");

# now download the file

print <<EOT;
 Content-Type: application/vnd.sun.xml.writer
 Content-Disposition: filename="directory.odt"

EOT

open( DIR, "directory.odt" );
while (<DIR>) {
    print $_;
}
exit 0;

