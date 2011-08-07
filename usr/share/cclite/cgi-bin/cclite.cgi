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

=head1 NAME
 
cclite.cgi


=head1 SYNOPSIS

Controller for user side Cclite

=head1 DESCRIPTION

Controller to find and dispatch various actions
 this is the version 2 controller for cclite:

 - multiple registry, registry passed in %fields
 - multiple transaction, logon and transfer can be one operation
 - maximum simplicity,  
 - sha1, ip + user + value based hashing
 - internal key never transmitted over network
 - mysql based database + DBI + ODBC (can even be access, for example)
 - web services retained
 - multilingual elements provided by translating screens + cookie
 - maximum use of static html for lightweight running
 - Taint flag should be on in final version, anyway

---------------------------------------------------------------------------
 THE cclite SOFTWARE IS PROVIDED TO YOU "AS IS," AND WE MAKE NO EXPRESS
 OR IMPLIED WARRANTIES WHATSOEVER WITH RESPECT TO ITS FUNCTIONALITY,
 OPERABILITY, OR USE, INCLUDING, WITHOUT LIMITATION,
 ANY IMPLIED WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE, OR INFRINGEMENT.
 WE EXPRESSLY DISCLAIM ANY LIABILITY WHATSOEVER FOR ANY DIRECT,
 INDIRECT, CONSEQUENTIAL, INCIDENTAL OR SPECIAL DAMAGES,
 INCLUDING, WITHOUT LIMITATION, LOST REVENUES, LOST PROFITS,
 LOSSES RESULTING FROM BUSINESS INTERRUPTION OR LOSS OF DATA,
 REGARDLESS OF THE FORM OF ACTION OR LEGAL THEORY UNDER
 WHICH THE LIABILITY MAY BE ASSERTED,
 EVEN IF ADVISED OF THE POSSIBILITY OR LIKELIHOOD OF SUCH DAMAGES.
---------------------------------------------------------------------------

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced 

=cut

BEGIN {

    my $base_module_dir = (
        -d '/home/ccliekh/perl'
        ? '/home/ccliekh/perl'
        : ( getpwuid($>) )[7] . '/perl/'
    );
    unshift @INC, map { $base_module_dir . $_ } @INC;

    use CGI::Carp qw(fatalsToBrowser set_message);
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );

}

use lib '../lib';
use strict;    # all this code is strict
use locale;

use HTML::SimpleTemplate;    # templating for HTML

use Log::Log4perl;

use Ccu;                     # utilities + config + multilingual messages
use Cccookie;                # use the cookie module
use Ccvalidate;              # use the validation and javascript routines
use Cclite;                  # use the main motor
use Cchooks;                 # API hooks, pretty empty at present
use Ccdirectory;             # yellow pages directory etc.
use Ccsecure;                # security and hashing
use Cclitedb;                # this probably should be delegated
use Ccinterfaces;            # need this for oscommerce gateway
use Ccconfiguration;         # new way of doing configuration

$ENV{IFS} = " ";             # modest security

my ( $fieldsref, $refresh, $metarefresh, $error, $html, $token, $cookies,
    $templatename, $registry_private_value );    # for the moment

my %configuration = readconfiguration();

Log::Log4perl->init( $configuration{'loggerconfig'} );
our $log = Log::Log4perl->get_logger("cclite");

my $cookieref = get_cookie();
my %fields    = cgiparse();
$fieldsref = \%fields;

# no soap and associated modules required,
# if you declare multiregistry=no in cclite.cf
if ( $configuration{multiregistry} eq "yes" ) {
    require SOAP::Lite;    # uses this for remote lookups etc.
    import SOAP::Lite;
}

#  this should use the version modules, but that makes life more
# complex for intermediate users

$fields{version} = $configuration{version};

#  this is part of conversion to transaction engine use. web mode, which
#  is the default will deliver html etc. engine mode will deliver data
#  as hash references, for example. There are quite a few things called 'mode'
#  in Cclite.pm, needs sorting out. csv currently 'means' Elgg and Drupal passthrough

$fields{mode} ||= 'html';

#  this is the remote address from the client. It acts as a simple check in a direct
#  pay transaction from the REST interface. This is obviously not sufficient and
#  will get upgraded in the future

$fields{client_ip} = $ENV{REMOTE_ADDR};

# moved from template because other routines need it
if (   $fields{action} ne "logoff"
    && length( $cookieref->{'userLogin'} )
    && $cookieref->{'userLevel'} ne "admin" )
{

    $fields{userLogin} = $cookieref->{'userLogin'};
}

#
#---------------------------------------------------------------------------
# change the language default here, languages should be ISO 639 lower case
#
my $language = decide_language($fieldsref) ;

###print "language = $language\n" ;

#---------------------------------------------------------------------------

my $pagename = $fields{name};
my $action   = $fields{action} || $configuration{defaultaction};
my $table    = $fields{subaction};
my $db       = $fields{registry} || $cookieref->{'registry'};
my $offset   = $fields{offset};

# now take these from configuration because of unreliable $ENV{SERVER_NAME} 11/2009
$fields{home}   = $configuration{home};
$fields{domain} = $configuration{domain};

# old style hash set type = 0
my $url_type = 0;

$fields{userHash} = hash_password( $url_type, $fields{userPassword} );

#
#--------------------------------------------------------------
# number of records per page in displayed lists ex-db tables, change at will
# 15 is about comfortable for full screen
#
my $limit = $fields{limit} || $configuration{linesperpage};

#--------------------------------------------------------------
#--------------------------------------------------------------
# means that multiregistry indication is accessible without passing
# configuration information everywhere: used to turn off select
# for partner registries etc.
$fields{multiregistry} = $configuration{multiregistry};

#--------------------------------------------------------------

#--------------------------------------------------------------
# initial user status for a user, if you want them to be active
# without email confirmation, set up as 'active'. If you want them
# to be unconfirmed and activated by email set to 'unconfirmed'
#
$fields{initialUserStatus} = $configuration{initialuserstatus};

#---------------------------------------------------------------
#--------------------------------------------------------------
# initial payment status for a payment, if you want a payment to be accepted
# immediately, set up as 'accepted'.
#
$fields{initialPaymentStatus} = $configuration{initialpaymentstatus};

#---------------------------------------------------------------

#--------------------------------------------------------------
# which mail address your notifications come from, this needs to be
# a valid address. This header is currently forged with -f, this is
# an area of concern to be re-coded/re-configured
#
#
$fields{systemMailAddress} = $configuration{systemmailaddress};

#---------------------------------------------------------------
#--------------------------------------------------------------
# which mail address your replies go to, this is normally a dead address
#
#
$fields{systemMailReplyAddress} = $configuration{systemmailreplyaddress};

#---------------------------------------------------------------
# A template object referencing a particular directory
#-------------------------------------------------------------------
# Change this if you change where the templates are...
#-------------------------------------------------------------------
my $pages = new HTML::SimpleTemplate("$configuration{templates}/$language");

#--------------------------------------------------------------------
# This is the token that is to be carried everywhere, preventing
# session hijack etc. It's probably going to be a GnuPg public key for the installation
# anyway it's a public key of some kind related to the cclite installations
# private key, not transcclite.cgimitted and protected by passphrase
#
$token = $registry_private_value =
  $configuration{publickeyid};    # for the moment, calculated later

#--------------------------------------------------------------------
# Switches on/off decimals, sent to index page
$fields{usedecimals} = $configuration{usedecimals};

#---------------------------------------------------------------------
# elementary controller based on the action field
# note that add database record also writes a record in the people file
# for use by the calendar

# these are generic actions which maintain the databases
# will be split into more specific code later
#
# 'local' is added to routines that are invoked locally to fill the class field
#  when they are invoked via soaplite, this is filled automatically
#
#  this needs to become ! valid_token when the hashing works
#  don't do anything except login and create new users
#
#  logon comes from auth in configuration or htaccess
#  check database and provide logon via this method
#  this will only do a single nominated registry though
#
if ( length( $ENV{REMOTE_USER} ) && !length( $cookieref->{'token'} ) ) {
    $fields{logontype} = 'remote';
    (
        (
            $refresh,  $metarefresh, $error, $html,
            $pagename, $fieldsref,   $cookies
        )
        = logon_user( 'local', $db, $table, $fieldsref, $token )
    );
}

#  no token, no remote user
$fields{menustyle} ||= 'menu';
$fields{logontype} ||= 'form';

# actions allowed without logon, yes etc. for fine grained security later
# note that widgets can't have cookies...at least in Opera 12/2009
#FIXME: this is becoming a disgrace, move to a gatekeeper function in Ccsecurity.pm
my %allowed_actions =
  qw(logon yes forgotpassword yes os_commerce_pay yes confirmuser yes adduser yes requesttoken yes accesstoken yes);

if (
       ( !length( $cookieref->{'token'} ) )
    && ( !exists $allowed_actions{$action} )

    && ( $ENV{QUERY_STRING} ne "action=template&name=newuser.html" )
    && ( $ENV{QUERY_STRING} ne "action=template&name=forgotpass.html" )
    && ( $fields{logontype} ne 'widget' )

  )

  # grey out all transaction menus and go back to login
{

    # grumble about installer and security problems etc.
    $fieldsref->{'errors'} = install_grumble( $configuration{templates} );
    display_template( 0, "", "", "", $pages, "logon.html", $fieldsref, $cookies,
        $token );
    exit 0;

} elsif (
    ( length( $cookieref->{'userLogin'} ) && length( $cookieref->{'token'} ) )

    ||

    (
           $fields{logontype} eq 'widget'
        && length( $fields{userLogin} )
        && length( $fields{token} )
    )

  )
{

    # calculate token to compare with cookie version
    my $compare_token;
    ( $compare_token, undef ) =
      calculate_token( $registry_private_value, $fieldsref, $cookieref,
        $ENV{REMOTE_ADDR} );

    if ( length( $cookieref->{'token'} )
        && ( $compare_token ne $cookieref->{'token'} ) )
    {
        my $fieldsref = \%fields;
        $log->warn(
"corrupt token or spoofing attempt from: $$cookieref{userLogin} $ENV{REMOTE_ADDR}"
        );

        $action = 'logoff';

        # widget logon doesn't use tokens
    } elsif ( length( $fields{token} )
        && $fields{logontype} eq 'widget'
        && ( $compare_token ne $fields{token} ) )
    {
        $action = 'logoff';

        # widget logon doesn't use tokens, but mobile phone must be confirmed...
    } elsif ( length( $fields{token} )
        && $fields{logontype} eq 'widget'
        && ( $compare_token eq $fields{token} ) )
    {

        my ( $error, $userref ) =
          get_where( 'local', $db, 'om_users', '*', 'userLogin',
            $fields{'userLogin'}, $token, $offset, $limit );

        # pin is not confirmed or locked etc. etc.
        #FIXME: should also decrement pin tries as well
        if ( $userref->{'userPinStatus'} ne 'active' ) {
            $action = 'logoff';
        }
    }
}

my $fieldsref = \%fields;

# logon to a registry
( $action eq "logon" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref, $cookies ) =
    logon_user( 'local', $db, $table, $fieldsref, $cookieref, $token ) );

# logoff, doesn't return, exits
( $action eq "logoff" )
  && logoff_user( 'local', $db, 'om_users', $pages, $cookieref, $fieldsref,
    $token );

# these are 'raw' db actions, need a bit of work, except for find_records...
( $action eq "insert" )
  && ( ( $refresh, $error, $html, $cookies ) =
    add_database_record( 'local', $db, $table, $fieldsref, $token ) );

# fieldslist as spaces added after fieldsref to display selected fields only 4/2010
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

( $action eq "modifyuser" )
  && (
    (
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    )
    = modify_database_record(
        'local', $db, 'om_users', $fieldsref, $cookieref, $pages, $token
    )
  );
( $action eq "display" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    show_record( 'local', $db, $table, $fieldsref, $token ) );

( $action eq "update" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    update_database_record(
        'local', $db, $table, 1, $fieldsref, $language, $pages, $token
    )
  );

# show a template
( $action eq "template" )
  && (
    ( $refresh, $error, $html, $cookies ) = display_template(
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    )
  );

# these are specific actions which belong to the application
# show my current transactions
( $action eq "showtrans" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local', $db, 'om_trades', $fieldsref,
        '',      '',  'html',      $token,
        $offset, $limit
    )
  );

# one shouldn't do this, but it's left in here as a place holder
# ($action eq "deletetrade") 	&&  (($refresh,$metarefresh,$error,$html,$pagename,$cookies)
#         = delete_trade('local',$db,'om_trades',$fieldsref,   $pages,$token)) ;
# this is now replaced by canceltrade, which modifies tradeStatus to cancelled

# this mainly only modifies the status field
# other parts of the trade should always remain integral
# actually the hash should change at this point?!

( $action eq "confirmtrade" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    modify_trade( 'local', $db, 'om_trades', $fieldsref, $pages, $token ) );

( $action eq "declinetrade" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    modify_trade( 'local', $db, 'om_trades', $fieldsref, $pages, $token ) );

( $action eq "canceltrade" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    modify_trade( 'local', $db, 'om_trades', $fieldsref, $pages, $token ) );

# show my yellow pages entries
( $action eq "showmyyellow" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local', $db, 'om_yellowpages', $fieldsref, 'fromuserid',
        $cookieref->{'userLogin'},
        'html', $token, $offset, $limit
    )
  );

# show yellow pages entries following category selection, space after fieldsref selects limited fields display
( $action eq "showyellowbycat" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    find_records(
        'local', $db,        'om_yellowpages', $fieldsref,
        ' ',     $cookieref, $token,           $offset,
        $limit
    )
  );

#FIXME: this is 0.4.0 code and will be removed soon, replaced by showyellowdir1

( $action eq "showyellowdir" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    show_yellow_dir(
        'local', $db, 'om_yellowpages', $fieldsref, 'fromuserid',
        $cookieref->{'userLogin'},
        'html', $token, $offset, $limit
    )
  );

( $action eq "showyellowdir1" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    show_yellow_dir1( 'local', $db, '', $fieldsref, $token, $offset, $limit ) );

( $action eq "addyellow" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_yellow( 'local', $db, 'om_yellowpages', $fieldsref, $token ) );

( $action eq "showyellow" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    show_yellow( 'local', $db, 'om_yellowpages', $fieldsref, $token ) );

# make a newly created user active
( $action eq "confirmuser" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref, $cookies ) =
    confirm_user( 'local', $db, $table, $fieldsref, $token ) );

# add an openid to the logged on user
# add a user with status unconfirmed
( $action eq "addopenid" )

  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_openid( 'local', $db, "om_openid", $fieldsref, $cookieref, $token ) );

# show my current openids
( $action eq "showopenid" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local',  $db,                 'om_openid', $fieldsref,
        'userId', $$cookieref{userId}, 'html',      $token,
        $offset,  $limit
    )
  );

# show my current openids
( $action eq "showcategories" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    get_many_items(
        'local',    $db, 'om_categories', $fieldsref,
        'category', '*', 'html',          $token,
        $offset,    $limit
    )
  );

# add a user with status unconfirmed
( $action eq "adduser" )

  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    add_user( 'local', $db, "om_users", $fieldsref, $token ) );

( $action eq "showuser" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $fieldsref ) =
    show_user( 'local', $db, 'om_users', $fieldsref, $token ) );

# email password: to be done..
( $action eq "forgotpassword" )
  && (

    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    forgotten_password(
        ( 'local', $db, $table, $fieldsref, $offset, $limit, $token )
    )
  );

# pay another user
( $action eq "transaction" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    transaction( 'local', $db, $table, $fieldsref, $token ) );

# pay another user in two currencies
( $action eq "splittransaction" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    split_transaction( 'local', $db, $table, $fieldsref, $token ) );

# pay another user from oscommerce shop
( $action eq "oscommerce_pay" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    oscommerce_transaction( 'local', $db, $table, $fieldsref, $token ) );

# show balance and volume
( $action eq "showbalvol1" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =

    # html to return html, values to return raw balances and volumes
    show_balance_and_volume1(
        'local', $db, $table, $fieldsref, "", $cookieref->{'userLogin'},
        $fieldsref->{'mode'}, $token, $offset, $limit
    )
  );

# show balance and volume, changed to non-hardcoded mode 2/2011
( $action eq "showbalvol" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =

    # html to return html, values to return raw balances and volumes
    show_balance_and_volume(
        'local', $db, $cookieref->{'userLogin'},
        $fieldsref->{'mode'}, $token
    )
  );

# sms and touchtone
( $action eq "smsemulate" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    sms_transaction( $fields{fromnumber}, $fields{smsmessage} ) );

# change language
( $action eq "lang" )
  && (
    (
        $refresh, $metarefresh, $error,     $html,
        $pages,   $pagename,    $fieldsref, $cookies
    )
    = change_language(
        $configuration{templates}, $fieldsref, $cookieref, $token
    )
  );

# get yellowpages as json tag cloud for remote users
( $action eq "showtags" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    show_tag_cloud( 'local', $db, $fieldsref, $token ) );

# get requestoken for remote oauth users
( $action eq "requesttoken" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    do_oauth( 'local', $db, $fieldsref, $token ) );

# get accesstoken for remote oauth users
( $action eq "accesstoken" )
  && ( ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    do_oauth( 'local', $db, $fieldsref, $token ) );

$fieldsref->{'news'} = get_news( 'local', $db, $token );

#FIXME: Probably only to be done when logged on?
# but nice to show a few 'public' listings....
# collect ad listing for bottom of screen, only want news field, don't disturb anything else

if ( length( $cookieref->{'userLogin'} ) ) {

    # get top line news for registry

    my $save = $fieldsref->{'getdetail'};
    $fieldsref->{'getdetail'} = 1;

    # choice between strict categories and free-form tags now...
    if ( $configuration{'usetags'} ne 'yes' ) {
        ( undef, undef, $error, $$fieldsref{righthandside}, undef, undef ) =

          show_yellow_dir1( 'local', $db, '', $fieldsref, $token, $offset,
            $limit );

    } else {

        ( $error, $fieldsref->{'righthandside'} ) =

          show_tag_cloud( 'local', $db, $fieldsref, $token );

    }
    $fieldsref->{'getdetail'} = $save;
}

# display an action result, all actions are consumed
display_template(
    $refresh,  $metarefresh, $error,   $html, $pages,
    $pagename, $fieldsref,   $cookies, $token
);

exit 0;

