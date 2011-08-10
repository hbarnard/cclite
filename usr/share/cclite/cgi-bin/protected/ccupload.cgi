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

my %configuration;
%configuration = readconfiguration();

Log::Log4perl->init( $configuration{'loggerconfig'} );
our $log = Log::Log4perl->get_logger("ccupload");

# note that uploads are per registry as of 10/2009
my $upload_dir = "$configuration{csvpath}/$$cookieref{registry}";


my ( $fieldsref, $refresh, $metarefresh, $error, $html, $token, $db, $cookies,
    $templatename, $registry_private_value );    # for the moment


my $language = decide_language() ;

# message language now decided by decide_language, within readmessages 08/2011
my %messages = readmessages();

my $query = new CGI ;
 
#---------------------------------------------------------------
# A template object referencing a particular directory
#-------------------------------------------------------------------
# Change this if you change where the templates are...
#-------------------------------------------------------------------
my $pages     = new HTML::SimpleTemplate("$configuration{templates}/$language");
my $home      = $configuration{home};
my $user_home = $home;
$user_home =~ s/(\/protected)\/ccadmin.cgi/\/cclite.cgi/;

# since this uploads, need to be an admin and the cookies need to work
if ( $$cookieref{userLevel} ne 'admin' ) {
    display_template(
        "1",    $user_home,    "",         $messages{notanadmin},
        $pages, "result.html", $fieldsref, $cookies,
        $token
    );
    exit 0;
}

my $compare_token;

# there is a token but it's been modified or spoofed
if ( length( $$cookieref{token} ) && ( $compare_token != $$cookieref{token} ) )
{
###    $log->warn(
###"corrupt2 token or spoofing attempt from: $$cookieref{userLogin} $ENV{REMOTE_ADDR}\n"
###    );


    display_template( 0, "", "", "", $pages, "logon.html", $fieldsref, $cookies,
        $token );
    exit 0;
}

# A template object referencing a particular directory
$pages = new HTML::SimpleTemplate("$configuration{templates}/$language/admin");


# server file  name is in the AJAX parameter name: in the  upload object in cclite.js

my $filename         = $query->param("userfile");
my $filehandle       = $query->upload("userfile");

open UPLOADFILE, ">$upload_dir/$filename";
binmode UPLOADFILE;
while (<$filehandle>) {
    print UPLOADFILE;
}

close UPLOADFILE;

exit 0;

