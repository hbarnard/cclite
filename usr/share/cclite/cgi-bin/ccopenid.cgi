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

ccopenid.cgi

=head1 SYNOPSIS

Openid for cclite: alpha implementation

=head1 DESCRIPTION

Logon using openid, tested mainly with yahoo, not certain
whether this will work for everything, very untidy too, like my room...


=head1 AUTHOR

Hugh Barnard

=head1 SEE ALSO


=head1 COPYRIGHT

(c) Hugh Barnard 2005 - 2010 GPL Licenced
 
=cut

# can remove these in a while, keep for debugging at present...
sub plog;

{
    my $done_header = 0;

    sub header {
        my $status = shift || 200;
        my $type   = shift || "text/html";
        if ( !$done_header ) {
            plog "Sending header with status $status and type $type";
            print "Status: $status Blahblah\n";
            print "Content-type: $type\n\n";
            $done_header = 1;
        }
    }

    sub redirect {
        my $url = shift;
        if ( !$done_header ) {
            plog "Redirecting to $url\n";
            print "Status: 302 Found\n";
            print "Content-type: text/html\n";
            print "Location: $url\n\n";
            print '<a href="' . $url . '">' . $url . '</a>';
        } else {
            die "Can't redirect. Header already sent!";
        }
    }
}

sub plog {
    print STDERR "\n\nConsumer-Test: ", @_, "\n";
}

=head3 openid_exists

Before doing anything else, check that this open id exists in the database...
Return a reference that includes the userId for the referenced openid, need
this when 'really' logging on

=cut

sub get_openid {

    my ( $class, $db, $identifier, $token ) = @_;
    my ( $status, $openid_ref ) = get_where(
        $class,   $db,         "om_openid", '*',
        "openId", $identifier, $token,      '',
        ''
    );
    my $userid = $openid_ref->{'userId'};
    my ( $package, $filename, $line ) = caller;
    if ( $openid_ref->{'userId'} > 0 ) {
        return ( 1, $openid_ref );
    } else {
        return ( 0, undef );
    }
}

# https://me.yahoo.com/a/s.04E3wakMfN_Px.mQAqkddxjLM.kp0KwrREmXs-

use lib '../lib';
use strict;
use locale;
use Ccu;
use Ccconfiguration;
use Cclite;
use Cclitedb;
use Cccookie;

use Net::OpenID::Consumer;

#use Data::Dumper; only for debugging
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use File::Temp;
use Cache::File;

my $cgi = CGI->new();

my %configuration = readconfiguration();
my %messages      = readmessages();

my $base_url   = "http://$configuration{domain}/";
my $return_url = "${base_url}cgi-bin/ccopenid.cgi";
my $setup_url  = "${base_url}cgi-bin/ccopenid.cgi?openiderrors=need setup";
my $home       = $configuration{home};

#FIXME: this should come from config, used to keep registry name...
# use to keep association data later...
my $cache_dir = '/tmp/openid-consumer-test';

#--------------------------------------------------------------------
# This is the token that is to be carried everywhere, preventing
# session hijack etc. It's probably going to be a GnuPg public key for the installation
# anyway it's a public key of some kind related to the cclite installations
# private key, not transmitted and protected by passphrase
#
my $token = my $registry_private_value =
  $configuration{publickeyid};    # for the moment, calculated later

my $cache = Cache::File->new( cache_root => $cache_dir, );

my $csr = Net::OpenID::Consumer->new(
    args            => $cgi,
    consumer_secret => "not very secret",
    required_root   => $base_url,
    debug           => 1,

    #    cache => $cache,
);

# hmm, not well defined...
#my $setup_url = $csr->user_setup_url ;

my $method = $ENV{REQUEST_METHOD};

if ( $method ne 'POST' ) {
    $csr->handle_server_response(

        not_openid => sub {
            redirect('/cgi-bin/cclite.cgi');

        },

        setup_required => sub {
            my $setup_url = shift;
            redirect($setup_url);
        },
        cancelled => sub {
            header();
            print "Cancelled.";
        },
        verified => sub {
            my $vident    = shift;
            my $cookieref = get_cookie();
            my $fieldsref;
            my $registry_private_value;

            #FIXME:  yahoo sticks stuff on the end of this, why/what is that?
            my $identity = $vident->url;
            $identity =~ s/#[^#]+$//;

            my $registry = $cache->get($identity);
            $cache->purge();

            my ( $openid_found, $openid_ref ) =
              get_openid( 'local', $registry, $identity, $token );
            my ( $status, $userref ) =
              get_where( 'local', $registry, "om_users", '*', "userId",
                $openid_ref->{'userId'},
                $token, '', '' );

            $fieldsref->{'domain'}    = $configuration{'domain'};
            $fieldsref->{'home'}      = $configuration{'home'};
            $fieldsref->{'userLogin'} = $userref->{'userLogin'};

            do_login( $fieldsref, $registry, $userref,
                $registry_private_value );

=item not_in_released_code

            # Leave this at present, probably needed for debugging
            header( 200, 'text/plain' );
            print "Authenticated as " . $vident->url . "\n\n";
            print Data::Dumper::Dumper($vident);
=cut

        },
        error => sub {
            my $err = shift;
            die($err);
        },
    );

} else {

# check the openid in the form in the database...
# and send back if it doesn't exist, apparently the ajax doesn't work on two forms on one page...

    my $identifier = $cgi->param('identifier');
    my $registry   = $cgi->param('registry');

    my ( $openid_found, $openid_ref );
    my $error = $messages{'openiderror'};

    if ( !length($registry) ) {
        $error .= $messages{'blankregistry'};
        redirect("/cgi-bin/cclite.cgi?openiderrors=$error");
    } else {
        ( $openid_found, $openid_ref ) =
          get_openid( 'local', $registry, $identifier, '' );
    }

    if ( !$openid_found ) {
        $error .= $messages{'openidnotfound'};
        redirect("/cgi-bin/cclite.cgi?openiderrors=$error");
    } else {
        my $claimed_identity = $csr->claimed_identity($identifier);
        my $check_url        = $claimed_identity->check_url(
            return_to      => $return_url,
            trust_root     => $base_url,
            delayed_return => 0,

        );
        $cache->purge();
        $cache->set( $identifier, $registry );
        redirect($check_url);
    }

}

