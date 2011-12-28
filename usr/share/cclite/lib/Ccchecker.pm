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

=head1 NAME
 
Ccchecker.pm


=head1 SYNOPSIS

Module and program installation checker for cclite

=head1 DESCRIPTION


=head1 AUTHOR

Hugh Barnard

=head1 COPYRIGHT

(c) Hugh Barnard 2005-2011 GPL Licenced 

=cut

=head3 print_header

Print the top of page and references to javascript etc.

=cut

package Ccchecker ;

use strict;
use vars qw(@ISA @EXPORT);


my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(check_cclite_preinstall);

sub check_cclite_preinstall {
	
# third version install checker, much more oriented towards exception reporting and
# neater handling of all the module test etc. Neater too, but someway to go yet! July 2010
# Dumped Test::More and just use eval to test modules. Thanks Perlmonks!

my %counter;
my $usable = 1;
my $diagnosis = "<ul>" ;
my $gammu_found = `which gammu`;
my $sendmail    = '/usr/sbin/sendmail';
my $disable_installer_button;

# removed Sendmail and Log4perl as of 12/2011

my %module = (
    'dbi|DBI'                   => '0:Database Connection',
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
    'fpt|File::Path'            => '0:OS Indep File Path',
    'gde|GD'                    => '2:Graphics for Graphs',
    'gde|GD::Text'              => '2:Graphics for Graphs',
    'gde|GD::Graph::lines'      => '2:Graphics for Graphs',
    'gds|GD::Graph::sparklines' => '2:Graphics for Graphs',
    'cgi|CGI'                   => '0:CGI Module',
    'ood|OpenOffice::OODoc'     => '2:Open Office for batch printing',
);


foreach my $key ( sort keys %module ) {
    my ( $level,    $literal )     = split( /\:/, $module{$key} );
    my ( $class,    $message );
    my ( $sort_key, $module_name ) = split( /\|/, $key );
   
    my $output = eval("use $module_name; 1") ? '' : $@;
    
    if ( ! length($output) ) {

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
"<li class=\"failedcheck\">cclite needs Digest::SHA2 or Digest::SHA1</li>";
}

if ( $usable == 0 ) {
    $diagnosis .=
"<li class=\"failedcheck\"><b>Cclite core is not usable currently</b></li>";
} else {
    $diagnosis .= "<li class=\"system\"><b>Cclite core is usable!</b></li>";
}

$diagnosis .=
  "<li class=\"failedcheck\">cclite can't use MySql needs DBI</li>"
  if ( $counter{'dbi'} == 0 );
$diagnosis .=
  "<li class=\"failedcheck\">cclite can't log needs Log::Log4perl</li>"
  if ( $counter{'log'} == 0 );
$diagnosis .=
"<li class=\"failedcheck\">cclite can't send mail needs Mail::Sendmail or better Net::SMTP </li>"
  if ( $counter{'snd'} == 0 );

$diagnosis .= "<hr/>\n";

# GD missing
$diagnosis .=
"<li class=\"optional\">cclite can't produce graphs GD module[s] missing</li>"
  if ( $counter{'gde'} < 3 );

# GnuPG missing
$diagnosis .=
"<li class=\"optional\">cclite can't process encrypted email: GnuPG missing</li>"
  if ( $counter{'mim'} < 3 );

# Net::XMPP missing
$diagnosis .=
"<li class=\"optional\">cclite can't process jabber based payment: Net::XMPP missing</li>"
  if ( $counter{'jab'} == 0 );

# OpenOffice missing
$diagnosis .=
"<li class=\"optional\">cclite can't print statements or yellowpages: OpenOffice::OODoc missing</li>"
  if ( $counter{'ood'} == 0 );

# OpenID miessing
$diagnosis .=
"<li class=\"optional\">cclite can't use OpenID: Net::OpenID::Consumer missing</li>"
  if ( $counter{'opi'} == 0 );

$diagnosis .= "<hr/>\n";

if ( -e $sendmail ) {
    $diagnosis .=
      "<li class=\"system\">cclite can use local sendmail at $sendmail</li>";
} elsif ( $counter{'snd'} == 1 ) {
    $diagnosis .=
"<li class=\"failedcheck\">$sendmail: cclite must use Net::Smtp or server elsewhere</li>";
}

$diagnosis .=
"<li class=\"system\">cclite is sms capable with local phone: gammu found</li>"
  if ( length($gammu_found) );
$diagnosis .=
"<li class=\"failedcheck\">cclite can't use sms locally from an attached phone: need gammu</li>"
  if ( !length($gammu_found) );


$diagnosis .= '</ul>' ;

# grey out installer button. to warn people, if the system isn't usable...

$disable_installer_button =
  "document.getElementById(\"installer1\").disabled = true;"
  if ( $usable == 0 );

  my $usable_message = 'cclite is usable' if ($usable) ;
   
return ($usable_message, $diagnosis) ;

}

1 ;
