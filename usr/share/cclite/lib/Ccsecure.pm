
=head1 NAME

Ccsecure.pm

=head1 SYNOPSIS

Security routines for Cclite

=head1 DESCRIPTION


This package deals with session and security management. Currently sessions
are via tokens. Tokens are hashes of IP address and validated password.
They shouldn't work from a new address by being transported.

Action completes OK or it's a violation. If it's a violation, it's logged.

Note that nearly every other routine within Cclite can consume a token.
This is usually the last input paramter for any given subroutine.

This isn't used at present but the idea is many watertight doors rather
than a perimeter and a leaky interior.

I expect to put public key processing for GPG email
and similar here too.

This can now use the pure Perl SHA package.
The idea is to enable a full installation where a user may not be able
to use CPAN. However Digest::SHA2 will be much faster.

=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced 

=cut

#
package Ccsecure;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Ccu;
use Cclitedb;
use Cccookie;
use Ccconfiguration;    # new style configuration, read hash type...
###use GnuPG qw( :algo );

my $VERSION = 1.00;
@ISA    = qw(Exporter);
@EXPORT = qw(login
  logout
  hash_password
  get_server_details
  install_grumble
  is_admin
  compare_password
  random_password
  calculate_token
  calculate_api_key
  compare_api_key
  valid_token
  parse_remote_user
  log_violation
  text_to_hash
  encode_base64
  decode_base64
);

# this will choose the hashing module type, hash processing
# depends on this within _get_digest

our $log = Log::Log4perl->get_logger("Ccsecure");

=head3  _get_digest

Returns a SHA digest. Digest SHA1
is potentially collision prone but available on
many commodity hosting platforms, so it's default
if cclite can't find SHA2


FIXME: 7/2010 use Digest changed to require, so these are invoked at runtime,
performance hit but easier setup, also they are in a function, at present
=cut

sub _get_digest {

    my ( $url_type, @hash_items ) = @_;
    my $digest;
    my $sha2obj;
    my $type;
    my %configuration = readconfiguration();
    my ( $os, $distribution, $package_type ) = get_os_and_distribution();
    eval {
        if ( $configuration{hash_type} eq 'sha2' && $os ne 'windows' )
        {
            require Digest::SHA2;
            $type = "sha2";
        } elsif ( $configuration{hash_type} eq 'sha1' ) {
            require Digest::SHA1;
            $type = "sha1";
        } else {
            die
"bad hash type in configuration $configuration{hash_type}, must sha2 or sha1";
        }
    };
    if ($@) {
        die
"bad hash type in configuration $configuration{hash_type}, or digest sha1 or sha2 not present";
    }

    if ( $type eq "sha2" ) {
        $sha2obj = new Digest::SHA2 512;
    } elsif ( $type eq "sha1" ) {
        $sha2obj = new Digest::SHA1;
    }
    $sha2obj->add(@hash_items);
    $digest = $sha2obj->b64digest();

    # make base64 digest URL safe without using encoder/decoder 12/2008
    # only do this for strings to be put into urls...
    ###$digest =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg if ($url_type);
    ###$digest =~ tr!\+\|\=!\\-\_! if ($url_type);    # transform dificult escapes
    $digest =~ s/[\+\\\s\/\|\=]+//g if ($url_type);   # remove difficult escapes
       #$digest = encode_base64($digest) if ($url_type);   # remove spaces newlines, experimental
    return $digest;
}

=head3 text_to_hash

This is a tramp function that exposes _get_digest

=cut

sub text_to_hash {

    my ($text) = @_;
    my $url_type = 0;
    my $hash = _get_digest( $url_type, ($text) );
    return $hash;

}

=head3 compare_password

Compares the input hashed password with the stored one.
Normally this would take place over an https connection too.

=cut

sub compare_password {
    my ( $password_in, $cleartext, $password_stored ) = @_;
    if ( $password_in ne $password_stored ) {    # already hashed
        return 0;
    } else {
        return 1;
    }
}

=head3 calculate_token

The token is a hash of the user, their current address (avoids some man
in the middle and some replay and the private value which is never exposed
to the network and changed frequently (we hope).

As of 2008, there's 

The hashref is either the fields reference or the cookie reference

=cut

sub calculate_token {
    my ( $registry_private_value, $fieldsref, $cookieref, $remote_address ) =
      @_;
    my ( $package, $filename, $line ) = caller;
    my $token;
    my $url_type = 1;    # these are url type hashes
    if ( !length($cookieref) ) {
        my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
          localtime(time);

        #FIXME: time gives a little volatility but improve EGD perhaps?
        my $nonce = join( '', $sec, $min, $hour );
        $nonce = _get_digest( $url_type, $nonce );
        $token = _get_digest( $url_type, $fieldsref->{'userLogin'},
            $nonce, $remote_address );
        return ( $token, $nonce );
    } else {
        $token = _get_digest( $url_type, $cookieref->{'userLogin'},
            $cookieref->{'token1'}, $remote_address );

        return ( $token, undef );
    }
###    $log->error(
###"in token calc, fatal problem: $registry_private_value, u:$fieldsref->{'userLogin'}, ip:$remote_address"
###    );
}

=head3 valid_token

recalculate the token for existing input, return true, if it still works
and compare it. Return 1 if the recalculated token is valid.

This is switched off at present and maybe should become dead code...

=cut

sub valid_token {

    my ( $registry_private_value, $user, $remote_address, $token ) = @_;
    my $url_type = 0;
    my $compare =
      _get_digest( $url_type, $registry_private_value, $user, $remote_address );
    if ( $compare == $token ) {
        return 1;
    } else {
        return 1;
    }
}

=head3 calculate_api_key

The hashed api key is the api key + the remote address

FIXME:This version loops through a list of comma separated allowed ip addresses. This is not very scalable and possibly error-prone
however, it does permit one cclite installation to serve several passthroughs

=cut

sub calculate_api_hash {

    my ( $db, $token ) = @_;
    my @calculated_hashes;
    my ( $registry_error, $hash_ref ) =
      Cclitedb::get_where( 'local', $db, 'om_registry', '*', 'id', 1, '',
        '', '' );

 # space separated list of IP addresses, relaxed in 5/2010 to multiple spaces...
    my @allowed_ip_addresses = split( /\s+/, $hash_ref->{'allow_ip_list'} );

 ###$log->debug("in get ip address: $registry_error $hash_ref\n") ;

    foreach my $ip_address (@allowed_ip_addresses) {
        my $merchant_key_hash =
          _get_digest( 0, ( $hash_ref->{'merchant_key'} . $ip_address ) );
      ###    $log->debug("in get ip hash:$merchant_key_hash\n") ;
        push @calculated_hashes, $merchant_key_hash;
    }

    return \@calculated_hashes;
}

=head3 compare_api_key

FIXME: This is not in its final form, which should be OAuth based, this is proof of concept
If this fails, some logging should be included, possible break-in
The hashed api key is the api key (which should be a gpg key after a while) for the registry, the remote address

FIXME:This version loops through a list of comma separated addresses. This is not very scalable and possibly error-prone
however, it does permit a single cclite installation to serve several passthroughs

=cut

sub compare_api_key {

    my ( $db, $merchant_key_hash, $token ) = @_;
    my $merchant_hash_array_ref = calculate_api_hash( $db, $token );
    my @calculated_hashes = @$merchant_hash_array_ref;

    # retranslate from url-safe translation in php module
    $merchant_key_hash =~ tr/-_/+\//;

# not pretty because if any of them match, it returns...bad scale and doesn't ensure that the 'right' one...
    foreach my $hash (@calculated_hashes) {
    ###    $log->debug(
###"comparing hashes: calculated_hash:$hash, merchant:$merchant_key_hash\n\n"
###        );

        if ( $hash eq $merchant_key_hash ) {
            return 1;
        }
    }
    return 0;
}

=head3 hash_password

put the password into a hash
changed this to change the hashing method, currently sha2

url_type is 0 
=cut

sub hash_password {
    my ( $url_type, $cleartext ) = @_;

    # password is always passed around as hash
    my $hash_value = _get_digest( $url_type, $cleartext );
    my $l = length($cleartext);
    return $hash_value;
}

=head3 get_server_details

find out where served using environment variables
 ---- check for phishing here?

Domain is now deduced as first bit of path, not server correctly
on desktop debian for example 11/2009, this affects cookie release
as Laura's note...

FIXME: Not rigorous since https and 443 aren't 'married'

=cut

sub get_server_details {

    my $portstring = ":$ENV{SERVER_PORT}"
      if ( $ENV{SERVER_PORT} != 80 && $ENV{SERVER_PORT} != 443 );

    my $domain = $ENV{SERVER_NAME};

    my $httpstring = "http://";
    $httpstring = "https://" if ( $ENV{SERVER_PORT} == 443 );

    my $home = "$httpstring$domain$portstring$ENV{SCRIPT_NAME}";

    return ( $home, $domain );

}

=head3 log_violation

Log token failures etc. here..needs a new db table
creates a record in om_log, type, user, ipaddress

There also needs to be a fingerprint log for transactions too

This is probably taken care of using log4perl right now

=cut

sub log_violation {

    return 1;
}

=head3 random_password

Generate a fairly random password for one that's
been forgotten

=cut

sub random_password {
    my $password;
    my $_rand;

    my $password_length = $_[0];
    if ( !$password_length ) {
        $password_length = 10;
    }

    my @chars = split(
        " ",
        "a b c d e f g h i j k l m n o p q r s t u v w x y z 
  - _ % # |
  0 1 2 3 4 5 6 7 8 9"
    );

    srand;

    for ( my $i = 0 ; $i <= $password_length ; $i++ ) {
        $_rand = int( rand 41 );
        $password .= $chars[$_rand];
    }
    return $password;
}

=head3 grumble

grumble about installer present and writable files etc.
mainly installer for the present

=cut

sub install_grumble {
    my ($templatepath) = @_;

    # strip back to base path for cclite
    $templatepath =~ s/templates\/html//;
    my $base_path = $templatepath;

    my @grumbles;
    my $configfile = "$base_path/config/cclite.cf";
    if ( -e $configfile && -w $configfile ) {
        push @grumbles,
          "cclite.cf is writable, this is very insecure, please change";
    }
    my $cgiinstall = "$base_path/cgi-bin/protected/ccinstall.cgi";
    if ( -e $cgiinstall && -x $cgiinstall ) {
        push @grumbles,
"ccinstall.cgi present and executable, this is very insecure, please remove";
    }

    # grumble about soap server also insecure
    my $soapserver = "$base_path/cgi-bin/ccserver.cgi/";
    if ( -e $soapserver && -x $soapserver ) {
        push @grumbles,
"ccserver.cgi present and executable, this is insecure, please remove unless used";
    }

    # turn off this grumble for the moment: people don't want it 10/2009
    # and hard to fix...
    ###   if ( $ENV{SERVER_PORT} != 443 ) {
    ###       push @grumbles, "please use https if possible!";
    ###  }
    my ( $os, $distribution, $package_type ) = get_os_and_distribution();
    my $grumbling;
    $grumbling = join( "<br/>", @grumbles ) if ( $os ne 'windows' );
    return $grumbling;
}

=head3 is_admin

Very crude method of determining whether the administration script is being run.
Should be replaced by something more secure and subtle.

Should also check token to provide some assurance that session is not hijacked

=cut

sub is_admin {
    my $is_admin  = 0;
    my $cookieref = get_cookie();
    $is_admin = 1 if ( $cookieref->{userLevel} eq "admin" );
    return $is_admin;
}

sub encode_base64 {
    my $data = $_[0];
    $data =~ tr|+/=|\-_|d;
    return $data;
}

sub decode_base64 {
    my $data = $_[0];

    # +/ should not be handled, so convert them to invalid chars
    # also, remove spaces (\t..\r and SP) so as to calc padding len
    $data =~ tr|\-_\t-\x0d |+/|d;
    my $mod4 = length($data) % 4;
    if ($mod4) {
        $data .= substr( '====', $mod4 );
    }
    return $data;
}

1;

