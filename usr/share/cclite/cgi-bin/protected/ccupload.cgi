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

=head1 NAME

ccupload.cgi

=head1 SYNOPSIS

upload for Cclite batch files

=head1 DESCRIPTION

This will probably be extended to allow upload of user content for example

=head1 AUTHOR

Hugh Barnard

=head1 SEE ALSO

cclite.cgi
=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced 

=cut

BEGIN {
    use CGI::Carp qw(fatalsToBrowser set_message);
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );

}

use strict;
use lib "../../lib";

use Log::Log4perl;


use HTML::SimpleTemplate;
use Ccu;
use CGI ;  # sorry need this for the parsing of multipart...
use Cclite;
use Cccookie;
use Ccconfiguration;    # new 2009 style configuration supply...

my $cookieref = get_cookie();

my %configuration = readconfiguration();

Log::Log4perl->init( $configuration{'loggerconfig'} );
our $log = Log::Log4perl->get_logger("ccupload");

# note that uploads are per registry as of 10/2009
my $uploaddir = "$configuration{csvpath}/$cookieref->{'registry'}";

my ( $fieldsref, $refresh, $metarefresh, $error, $html, $token, $db, $cookies,
    $templatename, $registry_private_value );    # for the moment

# message language now decided by decide_language, within readmessages 08/2011
my %messages = readmessages();
my $language = decide_language() ;

my $maxFileSize = 2 * 1024 * 1024; # 2mb max file size...

my $query = new CGI;
my $file = $query->param('POSTDATA');
my $temp_id = $query->param('temp_id');

# make a filename
my $name = time() . '.' . $cookieref->{'registry'} . '.csv' ;

open(UPLOAD, ">$uploaddir/$name") or die "Cant write to $uploaddir/$name. Reason: $!";
   print UPLOAD $file;
close(UPLOAD);

my $check_size = -s "$uploaddir/$name";

print $query->header();
if ($check_size < 1) {
        print STDERR "$messages{fileempty}\n";
        print qq|{ "success": false, "error": "$messages{fileempty}" }|;
        print STDERR "$messages{filenotuploaded}\n";
} elsif ($check_size > $maxFileSize) {
        print STDERR "$messages{filetoolarge}\n";
        print qq|{ "success": false, "error": "$messages{filetoolarge}" }|;
        print STDERR "$messages{filenotuploaded}\n";
} else  {
        print qq|{ "success": true }|;
        $log->debug('success') ;
        print STDERR "$messages{fileuploaded}\n";
}

exit 0 ;
