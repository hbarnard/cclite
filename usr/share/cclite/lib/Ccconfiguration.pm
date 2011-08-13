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
    } else {
        my $message = _dying_message($configfile);
        die $message;
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
 en:   
    Configuration file not found at: $configfile    
    Use cgi-bin/protected/ccinstall.cgi to set it up 
    
    Please use the http://groups.google.co.uk/group/cclite Cclite Google Group
    for help, if necessary
 es:
     Archivo de configuración que no se encuentra en: $ configfile
     Use cgi-bin/protected/ccinstall.cgi para configurarlo
    
     Por favor, utilice el http://groups.google.co.uk/group/cclite Cclite Google Group
     en busca de ayuda, si es necesario
 zh:    
    没有找到配置文件：$configfile
    使用cgi-bin/protected/ccinstall.cgi设置它
    
    请使用http://groups.google.co.uk/group/cclite Cclite谷歌集团
    为帮助，如有必要，
    
    package:$package line:$line function:$subroutine
EOT    
    package:$package line:$line function:$subroutine
EOT

    return $message;
}

1;
