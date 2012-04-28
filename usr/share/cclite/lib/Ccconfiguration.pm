#!/usr/bin/perl -w

=head1 NAME

Ccconfiguration.pm

=head1 SYNOPSIS

Read configuration information

=head1 DESCRIPTION

Read configuration and supply hash

WARNING

If this doesn't work, nothing will work!

=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO


=head1 COPYRIGHT

(c) Hugh Barnard 2005-2009 GPL Licenced
 
=cut

package Ccconfiguration;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Cwd;
my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(
  readconfiguration
);

=head3 readconfiguration

Read the configuration data and return a hash


Skip comments marked with #
cgi parameters will override configuration file
information, always!

Included here, needs to be executed within BEGIN

Revised 1/2009 for Windows...
=cut

sub readconfiguration {

    my ($force_configuration_path) = @_;
    my $dir;
    my $default_config;

    my $os = $^O;

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
    my $configfile = $force_configuration_path || $default_config;

    my %configuration;
    if ( -e $configfile ) {
        open( CONFIG, $configfile );
        while (<CONFIG>) {
            s/\s$//g;
            next if /^#/;
            my ( $key, $value ) = split( /\=/, $_ );
            if ($value) {
                $key =~ lc($key);    #- make key canonic, all lower
                $configuration{$key} = $value if ( length($value) );
            }
            $key   = "";
            $value = "";
        }
    } elsif ( !-e $configfile && $0 =~ /ccinstall/ ) {
        return;
    } else {
        my $message = _dying_message($configfile);
        print "Content-type: text/html\n\n";
        print $message;
        die;
    }
    return %configuration;
}

sub _dying_message {

    my ($configfile) = @_;

    my (
        $package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
    ) = caller(4);

    my $message = <<EOT;
<html>
<head>
<link type="text/css" href="/styles/default.css" rel="stylesheet">
<title>
Configuration Not found
</title>
<body style="{margin-left:100px}">
<br/><br/>
<h1>Configuration not found</h1>
 en:   <br/>
    Configuration file not found at: <span class="failedcheck">$configfile</span>
    Use <a title="installer" href="/cgi-bin/protected/ccinstall.cgi">the installer to set it up</a>
    <br/><br/>
    Please use the <a title="help" href="http://groups.google.co.uk/group/cclite"> Cclite Google Group</a>
    for help, if necessary
    <br/><br/>
 es: <br/>
     Archivo de configuracion que no se encuentra en: <span class="failedcheck">$configfile</span>
     Utilizar <a title="configurarlo" href="/cgi-bin/protected/ccinstall.cgi">el instalador para configurarlo</a>
    <br/><br/>
     Por favor, utilice el <a title="ayuda" href="http://groups.google.co.uk/group/cclite"> Cclite Google Group</a>
     en busca de ayuda, si es necesario
    <br/><br/>
    package:$package line:$line function:$subroutine<br/><br/>
EOT

    return $message;
}

1;
