#!/usr/bin/perl
my $test = 0;
if ($test) {
    print STDOUT "Content-type: text/html\n\n";
    my $data = join( '', <DATA> );
    eval $data;
    if ($@) {
        print "<H1>Syntax  error!</H1>\n<PRE>\n";
        print $@;
        print "</PRE>\n";
        exit;
    }
}
###__END__

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

ccadmin.cgi

=head1 SYNOPSIS

administration controller for Cclite

=head1 DESCRIPTION

 this is the version 2 administration controller for cclite:

 - multiple registry, registry passed in %fields
 - multiple transaction, logon and transfer can be one operation
 - maximum simplicity, nearly everything is passed as %fields
 - sha1, ip + user + value based hashing
 - internal key never transmitted over network
 - mysql based database + DBI + ODBC (can be access, for example)
 - web services retained
 - multilingual elements provided by translating screens + cookie
 - maximum use of static html for lightweight running

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
use lib '../../lib';

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash 

=cut

# no soap and associated modules required,
# if you declare multiregistry=no in cclite.cf
if ( $configuration{multiregistry} eq "yes" ) {
    require SOAP::Lite;    # uses this for remote lookups etc.
    import SOAP::Lite;
}

# no rss and XML::Rss and associated modules required,
# if you declare userss=no in cclite.cf
if ( $configuration{userss} eq "yes" ) {
    require Ccrss;         # uses this for remote lookups etc.
    import Ccrss;
}

use Log::Log4perl;

use HTML::SimpleTemplate;

use Cccookie;              # use the cookie module
use Ccu;                   # use the utilities module
use Ccvalidate;            # use the validation and javascript routines
use Cclite;                # use the main motor
use Ccconfiguration;       # new style configuration

use Ccadmin;
use Ccsecure;
use strict;
use locale;
use Cclitedb;              # probably should be via Cclite.pm only, not directly

my ( $fieldsref, $refresh, $metarefresh, $error, $html, $token, $cookies,
    $templatename, $registry_private_value );    # for the moment

my %configuration = readconfiguration();
my $configref     = \%configuration;
my %fields        = cgiparse();
my $offset        = $fields{offset};
our %messages = readmessages("en");

Log::Log4perl->init( $configuration{'loggerconfig'} );
our $log = Log::Log4perl->get_logger("ccadmin");

#  this should use the version modules, but that makes life more
# complex for intermediate users
$fields{version} = $configuration{version};

# This is the token that is to be carried everywhere, preventing
# session hijack etc. It's probably going to be a GnuPg public key
# anyway it's a public key of some kind related to the cclite installations
# private key, not transmitted and protected by passphrase
$registry_private_value = $token =
  $configuration{registrypublickey};    # for the moment, calculated later

# means that multiregistry indication is accessible without passing
# configuration information everywhere
$fields{multiregistry} = $configuration{multiregistry};

# means service charge will be tested against this maximum if there's
# a numeric value in this field
$fields{servicechargelimit} = $configuration{servicechargelimit};

# number of records per page in lists ex-db tables, change at will
my $limit = $fields{limit} || $configuration{linesperpage};

# now take these from configuration because of unreliable $ENV{SERVER_NAME} 11/2009
#FIXME: But creates problem with certain admin actions...modify currency etc...
$fields{home}   = $configuration{home};
$fields{domain} = $configuration{domain};

# get the html path, this is needed to create extra subdirectories for graphs etc.
$fields{htmlpath} = $configuration{htmlpath};

# change these to suit
my $home      = $fields{home};
my $user_home = $home;
$user_home =~ s/(\/protected)\/ccadmin.cgi/\/cclite.cgi/;
$fields{home} = $user_home if ( $fields{action} eq "logoff" );

my $cookieref = get_cookie();

my $language = $fields{language}
  || $$cookieref{language}
  || "en";    # default is english

my $pagename = $fields{name} || "front.html";    # default is the index page

my $action = $fields{action};
my $table  = $fields{subaction};
my $db     = $$cookieref{registry} || $fields{registry};

# A template object referencing a particular directory
my $pages = new HTML::SimpleTemplate("../../templates/html/$language/admin");
my $user_pages = new HTML::SimpleTemplate("../../templates/html/$language");

# FIXME:
# this sequence deals with the security of admin actions, probably
# need to be abstracted away from both ccadmin.cgi and cclite.cgi, duplicated

# need to be an admin, need to be logged on, back to logon
if ( length( $$cookieref{userLevel} ) && ( $$cookieref{userLevel} ne 'admin' ) )
{

###    $log->debug("l:$$cookieref{userLevel}  t:$$cookieref{token}");
    $fields{menustyle} = "grey";
    $fieldsref = \%fields;
    my $pages = $user_pages;
    display_template(
        "1",         $user_home,
        "",          $messages{notanadmin},
        $user_pages, "result.html",
        $fieldsref,  $cookies,
        $token
    );
    exit 0;
}

# grumble about installer etc.
$fields{errors} = install_grumble( $configuration{librarypath} );

# just to give upper case display for admin menu
$fields{registrytitle} = "\u$$fieldsref{name}";

$fieldsref = \%fields;

# display fields and status for all the batch file paths
my ( $errors, $report_ref, $file_ref ) =
  get_set_batch_files( 'get', $configref, $fieldsref, $cookieref );

foreach my $key ( sort keys %$report_ref ) {
    $$fieldsref{displaybatchfiles} .= $$report_ref{$key};
}

# there is a token but it's been modified or spoofed
if ( length( $$cookieref{userLogin} ) && length( $$cookieref{token} ) ) {

    # calculate token to compare with cookie version
    my $compare_token;
    ( $compare_token, undef ) =
      calculate_token( $registry_private_value, $fieldsref, $cookieref,
        $ENV{REMOTE_ADDR} );

    if ( length( $$cookieref{token} )
        && ( $compare_token ne $$cookieref{token} ) )
    {
        $fieldsref = \%fields;
###        $log->warn(
###"corrupt token or spoofing attempt from login:$$cookieref{userLogin} token:$$cookieref{token} token1:$$cookieref{token1} at:$ENV{REMOTE_ADDR}"
###        );
        ###$log->debug("action is $action: $compare_token\n  ne \n$$cookieref{token} \ntoken1:$$cookieref{token1}");

        # attempt to exit cleanly
        $action = 'logoff';
    }

    # no userLogin or no token, don't allow anything, go back to logon
} else {

    $fieldsref = \%fields;
    my $pages = $user_pages;
    display_template(
        "1",         $user_home,
        "",          $messages{notanadmin},
        $user_pages, "result.html",
        $fieldsref,  $cookies,
        $token
    );
    exit 0;

}

# Controller based on the action field
# 'local' is added to routines that are invoked locally to fill the class field
# when they are invoked via soaplite, this is filled automatically
#
( $action eq "insert" )
  && ( ( $refresh, $error, $html, $cookies ) =
    add_database_record( 'local', $db, $table, $fieldsref, $token ) );
( $action eq "find" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    find_records(
        'local', $db,     $table, $fieldsref, ' ', $cookieref,
        $token,  $offset, $limit
    )
  );
( $action eq "delete" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    delete_database_record( 'local', $db, $table, $fieldsref, $token ) );

( $action eq "modify" )
  && (
    (
        $refresh,  $home,      $error,   $html, $pages,
        $pagename, $fieldsref, $cookies, $token
    )
    = modify_database_record(
        'local', $db, $table, $fieldsref, $cookieref, $pages, $token
    )
  );
( $action eq "display" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    show_record( 'local', $db, $table, $fieldsref, $token ) );

( $action eq "update" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    update_database_record(
        'local', $db, $table, 1, $fieldsref, $language, $token
    )
  );

# add a registry partner either local or soap proxy
( $action eq "addpartner" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_partner( 'local', $db, "om_partners", $fieldsref, $token ) );

#
( $action eq "template" )
  && (
    ( $refresh, $error, $html, $cookies ) = display_template(
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    )
  );

#
# these are specific actions which belong to the admin application
#
( $action eq "addcurrency" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_currency( 'local', $db, $table, $fieldsref, $token ) );

( $action eq "servicecharge" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename ) =
    apply_service_charge( 'local', $db, 'om_trades', $fieldsref, $token ) );

( $action eq "createrss" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    create_rss_feed(
        'local', $user_home, 'desc', 'hugh,barnard@laposte.net', $db, $table,
        $fieldsref, $token
    )
  );

#
# show registry currencies
( $action eq "showcurrencies" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local', $db, 'om_currencies', $fieldsref,
        'id',    '*', 'html',          $token,
        $offset, $limit
    )
  );

# show partner registries
( $action eq "showpartners" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local', $db, 'om_partners', $fieldsref,
        'id',    '*', 'html',        $token,
        $offset, $limit
    )
  );

# build batch files for registry, used principally to fix problems and for cpanel
( $action eq "setbatchdirs" )
  && ( get_set_batch_files( 'set', $configref, $fieldsref, $cookieref ) );

#
( $action eq "logon" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref, $cookies ) =
    logon_user( 'local', $db, $table, $fieldsref, $token ) );

( $action eq "logoff" )
  && logoff_user( 'local', $db, 'om_users', $user_pages, $cookieref, $fieldsref,
    $token );

#
( $action eq "functiondoc" ) && functiondoc( $configuration{librarypath} );

#
( $action eq "lang" )
  && (
    (
        $refresh, $metarefresh, $error,     $html,
        $pages,   $pagename,    $fieldsref, $cookies
    )
    = change_language( $pages, $fieldsref, $cookieref, $token )
  );

# show balance and volume
( $action eq "showbalvol" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    show_balance_and_volume( 'local', $db, 'manager', 'html', $token ) );

# pro-tem, read the mail file
#
( $action eq "readmail" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    read_mail_transactions(
        'local', $db, $table, $fieldsref, $token, $offset, $limit
    )
  );

( $action eq "addcategory" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_category( 'local', $db, $table, $fieldsref, $token, $offset, $limit ) );

# display the a template, if requested
$action =~ /template/
  && (
    ( $refresh, $error, $html, $cookies ) = display_template(
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    )
  );

# display an action result, all actions are consumed
display_template(
    $refresh,  $metarefresh, $error,   $html, $pages,
    $pagename, $fieldsref,   $cookies, $token
);
exit 0;

