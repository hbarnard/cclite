#!/usr/bin/perl -w
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
 
checkinstall.cgi


=head1 SYNOPSIS

Module and program installation checker for cclite

=head1 DESCRIPTION


=head1 AUTHOR

Hugh Barnard

=head1 COPYRIGHT

(c) Hugh Barnard 2005-2010 GPL Licenced 

=cut

=head3 print_header

Print the top of page and references to javascript etc.

=cut

sub print_header {

    print STDOUT <<EOT;
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<meta name="description" content="cclite community currency system" />
<meta name="keywords" content="LETS CC" />
<meta name="author" content="hugh barnard" />

<link type="text/css" href="/styles/cc.css" rel="stylesheet">
<title>Cclite 0.8.1: Check and diagnose install</title>
<script src="/javascript/jquery-1.3.2.js"></script>
<script src="/javascript/jquery-validation-1.5.5.js"></script>
<script src="/javascript/jquery-cookies.js"></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/jquery.bgiframe.min.js'></script>

<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/jquery.ajaxQueue.js'></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/lib/thickbox-compressed.js'></script>
<script type='text/javascript' src='/javascript/jquery-autocomplete/jquery.autocomplete.js'></script>

<script src="/javascript/cookies.js" type="text/javascript"></script>

<script src="/javascript/striper.js" type="text/javascript"></script>
<script src="/javascript/cclite.js" type="text/javascript"></script>

</head>
<body>
<div id="page" align="left">
	<div id="page" align="center">
		<div id="toppage" align="center">
			<div id="date">
				<!-- top left -->
			</div>
			<div id="topbar">
			Cclite Installation and Perl Module Checker
			</div>
		</div>
		<div id="header" align="center">
		 <!-- top right -->
			<div class="titletext" id="logo">
Cclite
                             <div align="right" style="padding:12px;" class="smalltext"></div>
				<div class="logotext" style="margin:30px"><span class="orangelogotext"></span></div> 
				
			</div>
			
			<div id="pagetitle">
			<div align="right" class=\"system\"><a title="Go to Cclite installer" href="/cgi-bin/protected/ccinstall.cgi">Go to Installer</a> |
                          <a title="Cclite Google Discussion Group" href="http://groups.google.co.uk/group/cclite?hl=en">Help with Cclite</a></div>

                          </div>
				<div id="title" class="titletext" align="right"></div>
                                <span class="news"></span>
			
		</div>
		<div id="content" align="center">
		
			<div id="menu" align="right">
				<div align="right" style="width:189px; height:8px;"><img src="/cclite/images/mnu_topshadow.gif" width="189" height="8" alt="mnutopshadow" /></div>
				<div id="linksmenu" align="center">



				</div>
				
			</div>
 
		<div id="contenttext">


			<div class="bodytext" style="padding:12px;" align="justify">

<div>Running Tests...</div>

<div class=\"system\">
EOT

    return;
}

=head3 print_results

Print the analysis of the tests

=cut

sub print_results {
    my ( $diagnosis, $disable_installer_button ) = @_;

    print <<EOT;

                        
			</div>
			<div class="bigpanel" align="justify">

<h2>Analysis of Installed Modules and Programs</h2>				
$diagnosis
<!-- bottom text here-->

		</div>

		</div>			
		</div>
		<div id="footer" class="smallgraytext" align="center">

			<a href="#">Home</a> | <a title="Help with Cclite" href="http://groups.google.co.uk/group/cclite?hl=en">Help with Cclite</a><br />
			Cclite &copy; Hugh Barnard 2003-2009
		</div>
	
</body>
</html>
EOT

    return;
}

# second version install checker, much more oriented towards exception reporting and
# neater handling of all the module test etc. Neater too, but someway to go yet! July 2010

use strict;
use Test::More qw(no_plan);

my %counter;
my $usable = 1;
my $diagnosis;
my $gammu_found = `which gammu`;
my $sendmail    = '/usr/sbin/sendmail';
my $disable_installer_button;

my %module = (
    'dbi|DBI'                   => '0:Database Connection',
    'snd|Mail::Sendmail'        => '0:Send Mail, old method',
    'dig|Digest::SHA2'          => '1:512 Digest',
    'dig|Digest::SHA1'          => '1:256 Digest',
    'wse|SOAP::Lite'            => '1:Web Services',
    'rss|XML::RSS'              => '2:RSS for ad feed',
    'rss|XML::Simple'           => '2:RSS for ad feed',
    'wse|LWP::Simple'           => '1:Web Client',
    'cgi|CGI::Carp'             => '0:Web Error Reporting',
    'snd|Net::SMTP'             => '0:Mail Current Method',
    'net|Net::POP3'             => '1:Mail Current Method',
    'opi|Net::OpenID::Consumer' => '2:Open ID consumer',
    'mim|MIME::Base64'          => '2:Mail/Jabber Encryption',
    'mim|MIME::Decoder'         => '2:Mail/Jabber Encryption',
    'mim|GnuPG'                 => '2:Mail/Jabber Encryption',
    'jab|Net::XMPP'             => '2:Jabber Transport',
    'log|Log::Log4perl'         => '0:Logging for Perl',
    'fpt|File::Path'            => '0:OS Indep File Path',
    'gde|GD'                    => '2:Graphics for Graphs',
    'gde|GD::Text'              => '2:Graphics for Graphs',
    'gde|GD::Graph::lines'      => '2:Graphics for Graphs',
    'gds|GD::Graph::sparklines' => '2:Graphics for Graphs',
    'cgi|CGI'                   => '0:CGI Module',
    'ood|OpenOffice::OODoc'     => '2:Open Office for batch printing',
);

print STDOUT "Content-type: text/html\n\n";
print_header();

foreach my $key ( sort keys %module ) {
    my ( $level,    $literal )     = split( /\:/, $module{$key} );
    my ( $class,    $message );
    my ( $sort_key, $module_name ) = split( /\|/, $key );

    print "<br/>\n";
    if ( use_ok($module_name) ) {

        $class   = 'system';
        $message = 'usable';
        $counter{$sort_key}++;    # count modules in a particular group
    } else {
        if ( $level == 0 ) {
            $usable =
              0;    # if a level 0 module is missing the core is not usable...
            $class   = 'failedcheck';
            $message = 'is required for core operation';
        } elsif ( $level == 1 ) {
            $class   = 'optional';
            $message = 'is optional';
        } elsif ( $level == 2 ) {
            $class   = 'extra';
            $message = 'is really optional';
        }
    }
}

# can be SHA1 or SHA2

if ( $counter{'dig'} == 0 ) {
    $usable = 0;
    $diagnosis .=
"<div class=\"failedcheck\">cclite needs Digest::SHA2 or Digest::SHA1</div>";
}

if ( $usable == 0 ) {
    $diagnosis .=
"<div class=\"failedcheck\"><b>Cclite core is not usable currently</b></div>";
} else {
    $diagnosis .= "<div class=\"system\"><b>Cclite core is usable!</b></div>";
}

$diagnosis .=
  "<div class=\"failedcheck\">cclite can't use MySql needs DBI</div>"
  if ( $counter{'dbi'} == 0 );
$diagnosis .=
  "<div class=\"failedcheck\">cclite can't log needs Log::Log4perl</div>"
  if ( $counter{'log'} == 0 );
$diagnosis .=
"<div class=\"failedcheck\">cclite can't send mail needs Mail::Sendmail or better Net::SMTP </div>"
  if ( $counter{'snd'} == 0 );

$diagnosis .= "<br/>\n";

# GD missing
$diagnosis .=
"<div class=\"optional\">cclite can't produce graphs GD module[s] missing</div>"
  if ( $counter{'gde'} < 3 );

# GnuPG missing
$diagnosis .=
"<div class=\"optional\">cclite can't process encrypted email: GnuPG missing</div>"
  if ( $counter{'mim'} < 3 );

# Net::XMPP missing
$diagnosis .=
"<div class=\"optional\">cclite can't process jabber based payment: Net::XMPP missing</div>"
  if ( $counter{'jab'} == 0 );

# OpenOffice missing
$diagnosis .=
"<div class=\"optional\">cclite can't print statements or yellowpages: OpenOffice::OODoc missing</div>"
  if ( $counter{'ood'} == 0 );

# OpenID miessing
$diagnosis .=
"<div class=\"optional\">cclite can't use OpenID: Net::OpenID::Consumer missing</div>"
  if ( $counter{'opi'} == 0 );

$diagnosis .= "<br/>\n";

if ( -e $sendmail ) {
    $diagnosis .=
      "<div class=\"system\">cclite can use local sendmail at $sendmail</div>";
} elsif ( $counter{'snd'} == 1 ) {
    $diagnosis .=
"<div class=\"failedcheck\">$sendmail: cclite must use Net::Smtp or server elsewhere</div>";
}

$diagnosis .=
"<div class=\"system\">cclite is sms capable with local phone: gammu found</div>"
  if ( length($gammu_found) );
$diagnosis .=
"<div class=\"failedcheck\">cclite can't use sms locally from an attached phone: need gammu</div>"
  if ( !length($gammu_found) );

# grey out installer button. to warn people, if the system isn't usable...
print "usable is $usable\n";
$disable_installer_button =
  "document.getElementById(\"installer1\").disabled = true;"
  if ( $usable == 0 );

#FIXME: removed install button disable because test is not totally reliable 08/2011
print_results( $diagnosis, '' );

exit 0;
