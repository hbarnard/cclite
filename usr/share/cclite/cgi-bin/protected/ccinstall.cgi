#!/usr/bin/perl -w

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

ccinstall.cgi

=head1 SYNOPSIS

autonomous web installer for cclite


=head1 description

This is a web installer for the cclite configuration file. It makes
a guess at the directory and domain values and provides these as web page.
It, obviously, can't guess database passwords etc.

It will also check mysql for compatibility with cclite.

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


Package types:

0 Generic tarball/generic install [Fedora]
1 Windows
2 Debian/Ubuntu via package
3 Debian/Ubuntu unpackaged

=head1 SEE ALSO

 cclite.cgi
 ccadmin.cgi

=head1 COPYRIGHT

(c) Hugh Barnard 2005-2007 GPL Licenced 

=cut

=head3 readconfiguration

Read the configuration data and return a hash,
normally this routine now exist only in Ccconfiguration.pm
but the install is a 'special case'

Skip comments marked with #
cgi parameters will override configuration file
information, always!

=cut

sub readconfiguration {

    my $os = $^O;
    my $dir;
    my $default_config;

    # if it's windows use cd to find the directory
    if ( $os =~ /^ms/i ) {
        $dir = getcwd() || `cd`;
    } else {
        $dir = getcwd() || `pwd`;
    }

    # make an informed guess at the config file not explictly supplied
    $dir =~ s/\bcgi-bin.*//;
    $default_config = "${dir}config/cclite.cf";
    $default_config =~ s/\s//g;

    # either supply it explicitly with full path or it will guess..
    my $configfile = $_[0] || $default_config;

    my %configuration;
    if ( -e $configfile ) {
        open( CONFIG, $configfile );
        while (<CONFIG>) {
            s/\s$//g;
            next if /^#/;
            my ( $key, $value ) = split( /\=/, $_ );
            if ( length($value) ) {
                $key =~ lc($key);    #- make key canonic, all lower
                $configuration{$key} = $value;
            }
            undef $key;
            undef $value;
        }
    } else {
        $configuration{error} = "no configuration file found at $configfile";
        
    }

    return %configuration;
}

=head3 get_os_and_distribution


FIXME: Duplicated in Ccu.pm

Now that the package is widening in application
Need a little precision about the platform
This is not infallible, btw...

If the package flag is set, then the supplied default
configuration should work...

package types
0 unpackaged *nix
1 windows
2 debian
3 probable cpanel guessed via public html

=cut

sub get_os_and_distribution {

    my ( $os, $distribution );
    my $checkdir;
    my $package_type = 0;    # 0 is unpackaged *nix, default tarball
    if ( $^O =~ /^ms/i ) {
        $os           = 'windows';
        $package_type = 1;           # 1 is windows
    } elsif ( $^O =~ /^linux/i ) {
        $os = 'linux';
    } elsif ( $^O =~ /^openbsd/i ) {
        $os = 'openbsd';
    } else {
        $os = 'nocurrentsupport';
    }

    # try and find out distribution
    if ( $os eq 'linux' ) {
        my $dist_string = `cat /proc/version`;
        $dist_string =~ m/(fedora|ubuntu|debian|red hat)/i;
        $distribution = lc($1);
    }

    
    # if ubuntu or debian, test whether packaged by looking
    # in /usr/share/cclite

    if ( $distribution eq 'ubuntu' || $distribution eq 'debian' ) {
        $checkdir     = '/usr/share/cclite' ;
    if (-e $checkdir) {
        $package_type = 2 ;    # 2 is debian and derivatives
    } else  {
        $package_type = 3 ;    # debian/ubuntu but unpackaged
     }    
    }
       

    # guessing at cpanel because the whole thing is under the document root
    my $path = `pwd` if ( $os eq 'linux' );
    if ( $path =~ /public_html/i && $os eq 'linux' ) {
        $distribution .= ' probably cpanel';
    }

    return ( $os, $distribution, $package_type );
}

=head3 check_log_path

test whether the log path is present and writable
on Fedora/Redhat and commodity hosting this is often of form:

/home/<domain>/var/cclite/log/cclite.log
/home/<domain>/domains/<subdomain>/var/cclite/log/cclite.log

=cut

sub check_log_path {

    my ($dir) = @_;
    my $message;
    my $log_path = "$dir/var/cclite/log";
    
    #FIXME: remove double slash in some log paths
    $log_path =~ s/\/\//\//; 
    
    
    
    ###print "log path is $log_path" ;
    
    # can't find log directory or can't write to it..
    if ( !-e $log_path || !-w $log_path ) {
        $message = <<EOT;
    <table><tr class="even"><td>
<h5>Error 5:Ccinstall: Cclite installer</h5>
Can't find or write to the log directory: $log_path
does not exist or unreadable (needs chmod o+w, for example)?
The owner should be the web server or virtual server user
</td></tr></table><br/><br/>
Please fix this manually
EOT

    }

    return $message;

}

=head3 check_paths

Checks that the path to the cclite libraries
exists and is readable. Returns message, if not.

Amended 10.2009 to force libpath and base directory for testing
and general extra flexibility

Amended 7.2010 to simplify and deal with debian non-package install

=cut

sub check_paths {

    my ($package_type) = @_;
    my ( $message, $libpath, $dir );

    my $os = $^O;

    # if it's windows use cd to find the directory
    if ( $os =~ /^ms/i ) {
        $dir = getcwd() || `cd`;
    } else {
        $dir = getcwd() || `pwd`;
    }

    chomp $dir;
    $dir =~ s/\bcgi-bin.*//;

    # in standard place, so package is -very probably- being used
    if ( $dir =~ /^\/usr/ && $package_type == 2 ) {
        $dir = '/usr/share/cclite';
    }
     
    # but, if not in standard place, for example in /home, path is preserved 7/2010
   
    if ( !length($dir) ) {
        $message = <<EOT;
 <h5>Error  in ccintall::check_paths</h5>
 Can't find base dir $dir  does not exist or unreadable?
 Please fix manually
EOT

    }
   ###print "os is $os, dir is $dir, package type is $package_type" ;
    return ( $message, $dir, "${dir}lib" );

}

=head3 _format_base_directory

Interanl routine, avoid ugly code repetition

=cut

sub _format_base_directory {

    my ($base_directory) = @_;

    chomp $base_directory;
    $base_directory =~ s/\s+$//;           # if cgi called
    $base_directory =~ s/\/cgi-bin.*$//;
    $libpath = "$base_directory/lib";

    return ( $base_directory, $libpath );

}

=head3 check_template_path

test whether the template path is present and readable

=cut

sub check_template_path {

    my ($basedir) = @_;
    my $message;
    my $templates = "$basedir/templates";

    # can't find templates

    if ( !length($templates) ) {
        $message = <<EOT;
    <table><tr class="even"><td>        
<h5>Error 4:Ccinstall: Cclite installer</h5>
Can't find template directory: $templates
</td></tr></table>
<br/><br/>
Please fix this manually
EOT

    }

    return $message;

}

=head3 test_sha

Test whether digest module is present, otherwise whinge...
Logic rationalised somewhat 1/2009
FIXME: Needs test in test suite

=cut

sub test_sha {

    my $type;
    my $message;

    eval { require Digest::SHA2 };

    if ($@) {
        eval { require Digest::SHA1 };
        $type = "sha1";
        if ($@) {
            $message = <<EOT;
    <table><tr class="even"><td>
 <h5>Error 1:Ccinstall: Cclite installer</h5>
 $@
 </td></tr></table>
 <br/>
 Can't find either Digest::SHA1 or Digest::SHA2
 Please use perl -MCPAN -e shell or other tool to install
EOT
            undef $type;
        }

    } else {
        $type = "sha2";
    }
    return ( $message, $type );
}

=head3 test_dbi

test whether digest module is present, otherwise whinge...

=cut

sub test_dbi {

    my $message;
    eval { require DBI };

    if ($@) {
        $message = <<EOT;
    <table><tr class="even"><td>
 <h5>Error 2:Ccinstall: Cclite installer</h5>
 $@
 </td></tr></table>
 <br/><br/>
 Please fix manually
 Please use perl -MCPAN -e shell or other tool to install
EOT

    }
    return $message;
}

=head3 test_log

test whether digest module is present, otherwise whinge...

=cut

sub test_log {

    my $message;
    eval { require Log::Log4perl };

    if ($@) {
        $message = <<EOT;
 <h5>Error 3:Ccinstall: Cclite installer</h5>
 $@ 
 <br/>
 Please fix manually
 Please use perl -MCPAN -e shell or other tool to install
EOT

    }
    return $message;
}

sub write_log_config {

    my ( $dir, $os, $distribution, $package_type ) = @_;
    my $log_config ;
    my $log_base        = 'var/cclite/log';
    my $log_config_file = "$dir/config/logging.cf";
    my $error;

    # default case...
    my $log_file = "$dir/$log_base/cclite.log";

    # non-standard debian/ubuntu, especially home/username/cclite
    if ($package_type == 3 && $dir =~ /home/) {
        my @components = split(/\//,$dir) ;
        $log_file = "/$components[1]/$components[2]/$components[3]/$log_base/cclite.log" ;
        
    }    

    if ( !( -w $log_file ) ) {
        $error .=
"can't write:<br/><pre> $log_file </pre> <br/>Please change permissions to web cgi user";
    }

    eval { `touch $log_file`; };
    if ($@) {
        $error = $@;
    }

    $log_config = <<EOT;
log4perl.rootLogger=DEBUG, LOGFILE    
log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=$log_file
log4perl.appender.LOGFILE.mode=append   
log4perl.appender.LOGFILE.layout=PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern=%d %p> %F{1}:%L %M - %m%n
EOT

    if ( !( -w $log_config_file ) ) {
        $error .= <<EOT;
    <table><tr class="even"><td>    
can't write:<br/><br/><pre> $log_config </pre> <br/><br/>to $log_config_file<br/>Please edit by hand
    </td></tr></table>
EOT

    }

    eval {
        open( CONFIG, ">$log_config_file" );
        print CONFIG $log_config;
        close CONFIG;
    };

    if ($@) {
        $error .= " $@";
    }
    return ( $error, $log_config );

}

=head3 show_problems

Print out detected problems for the install


=cut

sub show_problems {

    my ( $os, $distribution, $package_type, $login, @messages ) = @_;
    my $errors = join( "</td></tr><tr><td>", @messages );

    print "Content-type: text/html\n\n";
    print <<EOT;
     <html>
      <head>
      <link type="text/css" href="/styles/cc.css" rel="stylesheet">
<link rel="stylesheet" type="text/css" href="/styles/print.css" media="print" />

<link rel="stylesheet" type="text/css" href="/javascript/jquery-autocomplete/jquery.autocomplete.css" />
<link rel="stylesheet" type="text/css" href="/javascript/jquery-autocomplete/lib/thickbox.css" />

<title>Cclite 0.8.1 Installer: Problems</title>



<script src="/javascript/jquery-1.3.2.js"></script>
<script type='text/javascript' src='/javascript/jquery-tooltip/jquery.qtip-1.0.0-rc3.min.js'></script>
<script src="/javascript/jquery-validation-1.5.5.js"></script>
<script src="/javascript/jquery-cookies.js"></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/jquery.bgiframe.min.js'></script>

<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/jquery.ajaxQueue.js'></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/thickbox-compressed.js'></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/jquery.autocomplete.js'></script>

<script src="/javascript/cookies.js" type="text/javascript"></script>

<script src="/javascript/striper.js" type="text/javascript"></script>
<script src="/javascript/cclite.js" type="text/javascript"></script>

 <title>Cclite Installer Errors for $os type $distribution</title>


      </head>
      <body>
      <h3>Cclite Installer Errors for $os $distribution running as $login</h3>
      <h3>Package type guessed as $package_type</h3>
      <table width="50%"><tr><td>$errors</td></tr></table>
      <br/><br/>
      <a href="http://groups.google.co.uk/group/cclite">Ask for Help at the Cclite Group</a>
      </body>
     </html>
EOT

    return;
}

#===================================================================

use strict;
use locale;

my (
    %configuration, $libpath,      $dir,        @messages,
    $os,            $distribution, $log_config, $login,
    $package_type,  $newinstall,   $default_config,
);

my $hash_type;    # contains the hash type used for hashing

BEGIN {
    use CGI::Carp qw(fatalsToBrowser set_message);
    use Cwd;
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );
    
    # checks that the installation is feasible, necessary modules are there

    ( $os, $distribution, $package_type ) = get_os_and_distribution();

    ( $messages[0], $dir, $libpath ) =
      check_paths($package_type);    # check libraries exist

    # make an informed guess at the config file path if not explictly supplied
    # for ccinstall this needs to be the cclite config
    $default_config = "$dir/config/cclite.cf";

    %configuration = main::readconfiguration($default_config);

    if ( length( $configuration{error} ) ) {

        # currently the default is not implemented, most values
        # are supplied in _guess_configuration
        $newinstall = 1;

    }

# if this is a windows or debian style package, already setup, so don't do this...
# but if it's a tarball or non-standard debian/ubuntu need to set up log config...


    if ( ( $package_type == 0 || $package_type == 3 ) && $newinstall ) {
        ( $messages[6], $log_config ) =
          write_log_config( $dir, $os, $distribution, $package_type );

        $messages[3] = check_template_path($dir);    # check template directory

        $messages[5] = check_log_path($dir);
    }

    ( $messages[1], $hash_type ) = test_sha();       # test for sha2 module
    $messages[2] = test_dbi();                       # for dbi module
    $messages[4] = test_log();

    $login = getpwuid($<) if ( $os ne 'windows' );

    # can't tell which entry will be present...
    my $test_results ;
    foreach my $message (@messages) {
    $test_results .= $message ;
    }
    # complain and stop..
    if ( length($test_results) ) {
        show_problems( $os, $distribution, $package_type, $login, @messages );
        exit 0;
    }
 
}

use lib '../../lib';

use Log::Log4perl;

# must remain hardcoded the config file may not exist yet...
eval {
    Log::Log4perl->init( \$log_config );
    our $log = Log::Log4perl->get_logger("ccinstall");
};

if ($@) {
    show_problems( $os, $distribution, $login, ($@) );
    exit 0;
}

use Cccookie;              # use the cookie module
use Ccu;                   # use the utilities module
use Ccvalidate;            # use the validation and javascript routines
use Cclite;                # use the main motor
use HTML::SimpleTemplate;  # this is used for cgi and for webservices
use Ccadmin;
use Ccsecure;
use Cclitedb;              # probably should be via Cclite.pm only, not directly

my %fields = cgiparse();
my $offset = $fields{offset};

# hash type is passed into the configuration, only if newinstall
$fields{hash_type} = $hash_type if ($newinstall);

#FIXME: no configuration file at this stage, but hard-code horror...
$fields{version} ||= "0.8.1";

# number of records per page in lists ex-db tables, provided in cclite.cf
my $limit = $fields{limit} || 15;

( $fields{home}, $fields{domain} ) =
  get_server_details();    # this is in Ccsecure, may need extra measures

my ( $fieldsref, $refresh, $metarefresh, $error, $html, $token, $db, $cookies,
    $templatename, $registry_private_value );    # for the moment

my $cookieref = get_cookie();
my $pagename = $fields{name} || "registry.html";    # default is the index page

my $action = $fields{action} || "updateconfig1";

my $table = $fields{subaction};
$db = $fields{registry};

# A template object referencing a particular directory
# Uses $dir to try and locate template from directory it's loaded into
# Install is english only, at present

my $language = "en";

my $pages = new HTML::SimpleTemplate("$dir/templates/html/$language/install");

my $user_pages = new HTML::SimpleTemplate("$dir/templates/html/$language");
$token = $registry_private_value =
  "testtoken";    # for the moment, calculated later

#

$fields{os}           = $os;
$fields{package_type} = $package_type;
$fields{distribution} = $distribution;

#
my $fieldsref = \%fields;

# there may or may not be cookies at this stage, used by add registry to create batch paths, if present
my $cookieref = get_cookie();

#
( $action eq "template" )
  && (
    ( $refresh, $error, $html, $cookies ) = display_template(
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    )
  );

# these are specific actions which belong to the admin application

# create a trading group which is a database + batch paths for csv, rss etc. etc.
( $action eq "addregistry" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =

    #   $operation, $configref, $fieldsref, $cookieref

    add_registry(
        'local',    $fields{registry}, '', \%configuration,
        $cookieref, $fieldsref,        $token
    )
  );
( $action eq "showregistries" )
  && (
    ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
    show_registries(
        'local', $fields{registry}, '', $fieldsref, 'html', $token
    )
  );

# this will guess at values, if newinstall is signalled
( $action eq "updateconfig1" )
  && (
    ( $refresh, $metarefresh, $error, $fieldsref, $pagename, $cookies ) =
    update_config1(
        $newinstall,     $default_config,    $fields{home},
        $fields{domain}, $fields{hash_type}, $dir
    )
  );
( $action eq "updateconfig2" )
  && (
    ( $refresh, $metarefresh, $error, $fieldsref, $html, $pagename, $cookies ) =
    update_config2( $default_config, $fieldsref ) );

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
