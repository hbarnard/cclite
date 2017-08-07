
=head1 NAME

Cccookie.pm

=head1 SYNOPSIS

Cookie handling functions

=head1 DESCRIPTION

$Id: Cccookie.pm,v 1.0 2004-07-23 09:40:25+01 hb48754 Exp hb48754 $

Copyright (c) 1998 Peter D. Kovacs  
Unpublished work.
Permission granted to use and modify this library so long as the
copyright above is maintained, modifications are documented, and
credit is given for any use of the library.

Portions of this library are taken, without permission (and much 
appreciated), from the cgi-lib.pl.  You may get that at 
http://cgi-lib.stanford.edu/cgi-lib

-$cookie{MyCookie} = "MyValue";
-set_cookie($expiration, $domain, $path, $secure,%cookies);
-get_cookie();
-delete_cookies($expiration, $domain, $path, $secure,%cookies);
-split_cookie
 
turned into a cookie module from its original form by Hugh Barnard
Copyright (c) 2004 Hugh B Barnard  
Unpublished work.

=head1 AUTHOR

Peter Kovacs
Hugh Barnard


=head1 SEE ALSO

http://cgi-lib.stanford.edu/cgi-lib

=head1 COPYRIGHT

(c) 1998 Peter D. Kovacs  

=cut

package Cccookie;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;

my $VERSION = 1.00;
@ISA    = qw(Exporter);
@EXPORT = qw(return_cookie_header delete_cookies get_cookie split_cookie);

=head3 get_cookie

Get a cookie. This returns a reference to a hash nowadays

=cut

sub get_cookie {
    my ( $chip, $val );
    my %cookie;
    foreach ( split( /; /, $ENV{'HTTP_COOKIE'} ) ) {

   # split cookie at each ; (cookie format is name=value; name=value; etc...)
   # Convert plus to space (in case of encoding (not necessary, but recommended)
        s/\+/ /g;

        # Split into key and value.
        ( $chip, $val ) = split( /=/, $_, 2 );    # splits on the first =.
                # Convert %XX from hex numbers to alphanumeric
        $chip =~ s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge;
        $val  =~ s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge;

        # Associate key and value
        $cookie{$chip} .= "\1"
          if ( defined( $cookie{$chip} ) );    # \1 is the multiple separator
        $cookie{$chip} .= $val;
    }
    return \%cookie;
}

=head3 return_cookie_header

Make and return an http cookie header
Set-cookie etc.

=cut

sub return_cookie_header {

# $expires must be in unix time format, if defined.  If not defined the cookie should expire at end of session
# If you want no expiration date set, set $expires = -1 (this causes the cookie to be deleted when user closes
# his/her browser).

    my ( $expires, $domain, $path, $sec, %cookie ) = @_;

    my $secure;
    my (@days) = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );
    my (@months) = (
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    );

    my ( $seconds, $min, $hour, $mday, $mon, $year, $wday );
    if ( $expires > 0 ) {    #get date info if expiration set.
        ( $seconds, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($expires);

        # expiry date format: Wdy, DD-Mon-YYYY HH:MM:SS GMT

        "0" . $seconds if ( $seconds < 10 );    # formatting of date variables
        "0" . $min     if ( $min < 10 );
        "0" . $hour    if ( $hour < 10 );
    }

    my (@secure) = ( "", "secure" )
      ; # add security to the cookie if defined.  I'm not too sure how this works.

    if ( !length($expires) ) {

        # was $expires = " expires\=Wed, 31-Dec-2004 00:00:00 GMT;"
        $expires = "Thu, 01-Jan-1970 00:00:00 GMT;";
    }    # if expiration not set, expire at
    elsif ( $expires == -1 ) {
        $expires = "Thu, 01-Jan-1970 00:00:00 GMT;";
    }    # if expiration set to -1, then eliminate expiration of cookie.
    else {
        $year += 1900;
        $expires =
"expires\=$days[$wday], $mday-$months[$mon]-$year $hour:$min:$seconds GMT; "
          ;    #form expiration from value passed to function.
    }

    if ( !defined $domain ) {
        $domain = $ENV{'SERVER_NAME'};
    }    #set domain of cookie.  Default is current host.
    if ( !defined $path ) { $path = "/"; }    #set default path = "/"
           #if ( !defined $secure ) { $secure = "0"; }

    my $header;
    foreach my $key ( keys %cookie ) {
        $cookie{$key} =~ s/ /+/g
          if ( length( $cookie{$key} ) );    #convert space to plus.
        $header .=
"Set-Cookie: $key\=$cookie{$key}; $expires path\=$path; domain\=$domain; $secure[$sec]\n";
    }
    return $header;
}

=head3 delete_cookies


Delete named cookies

=cut

sub delete_cookies {

# to delete a cookie, simply pass delete_cookie the name of the cookie to delete.
# you may pass delete_cookie more than 1 name at a time.
    my ( $expires, $domain, $path, $sec, %cookie ) = @_;
    my $header;

    foreach my $key ( keys %cookie ) {
        undef $cookie{ $key
        }; #undefines cookie so if you call set_cookie, it doesn't reset the cookie.
        $header .=
          "Set-Cookie: $key=deleted; expires=Thu, 01-Jan-1970 00:00:00 GMT;\n";

        #this also must be done before you print any content type headers.
    }
    return $header;
}

=head3 split_cookie

Split multivalued cookies into their component parts

=cut

sub split_cookie {

    # split_cookie
    # Splits a multi-valued parameter into a list of the constituent parameters

    my ($param) = @_;
    my (@params) = split( "\1", $param );
    return ( wantarray ? @params : $params[0] );
}

1;

