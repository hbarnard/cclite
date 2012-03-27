#!/usr/bin/perl 

=head3 get_suggestions

Does a lookup corresponding to the data type presented and returns
the row count and a drop down format menu item...this is for newusers,
mobile phone numbers, transaction destinations and yellow page 'tag style'
categories for example...

=cut

sub get_suggestions {

    my ( $db, $cookieref, $type, $query_string, $token ) = @_;

    # split and deal with last entry only if 'free form' yellowpages tags
    # for example baking,bread,shop this will suggest for 'shop'

    my @tags;

# get the sql string corresponding to the autosuggest, moved to Cclitedb 9/5/2010
    my $sql = get_suggest_sql(
        $cookieref->{'userLevel'},
        $cookieref->{'userLogin'},
        $type, $query_string
    );

    # use registry error in new user to warn about invalid search
    my ( $registryerror, $array_ref ) =
      sqlraw_return_array( 'local', $db, $sql, '', $token );

    my $menu_select;
    my $menu_count = 0;

    foreach my $row_ref (@$array_ref) {
        my $menu_item;
        $menu_count++;

        # fixme: this probably shoudln't be true for tags
        if ( $type ne 'tag' ) {
            $menu_item = substr( $$row_ref[0], 0, 15 );
            $menu_select .= "$menu_item\n";
        } else {
            push @tags, "\"$$row_ref[0]\"";
        }
    }

    if ( $type eq 'tag' ) {

        # produce json for jquery-tagsuggest.js
        $menu_select = join( ",", @tags );
        $menu_select = "[$menu_select]";
    }

    return ( $registryerror, $menu_count, $menu_select );

}

BEGIN {
    use CGI::Carp qw(fatalsToBrowser set_message);
    set_message(
"Please use the <a title=\"cclite google group\" href=\"http://groups.google.co.uk/group/cclite\">Cclite Google Group</a> for help, if necessary"
    );
    print STDOUT "Content-type: text/html\n\n";
}

use lib '../lib';

use strict;    # all this code is strict
use locale;

# logger must be before Cc modules, since loggers are
# defined within those modules...

use Ccu;           # utilities + config + multilingual messages
use Cccookie;      # use the cookie module
use Ccvalidate;    # use the validation and javascript routines
use Cclite;        # use the main motor
use Ccsecure;      # security and hashing
use Cclitedb;      # this probably should be delegated

$ENV{IFS} = " ";   # modest security

my $token;
my $cookieref = get_cookie();

# message language now defined by decide_language
our %messages = readmessages();

# array of tags for yellowpage tags autosuggest
our @tags;

# registry1 is filled for newuser suggest, this is ugly but it avoids the untraceable
# bug where the value of the registry cookie is cumulated. Exists on mailing lists but
# no-one seems to have solved it 10/2009

my $db = $cookieref->{registry} || $cookieref->{registry1};
my %fields = cgiparse();

#FIXME: This script should probably use Ccconfiguration values...
$fields{'version'} = '0.8.1';

# $fields{'q'} is the query string
# $fields{'type'} is the type of query and therefore table used etc.
# all this supplied by jquery now via cclite.js as of 10/2009

# return if there's no token and we're not finding a unique name for a new user
# new mobile or new email..
# don't want to expose the interior of the database to non-logged on users
# FIXME: this token should be recalculated and compared...

if ( !length( $cookieref->{'token'} ) ) {

    if (   $fields{'type'} ne 'newuser'
        && $fields{'type'} ne 'newuseremail'
        && $fields{'type'} ne 'newusermobile' )
    {
        print $messages{'loginfirst'};
        exit 0;
    }
}

# need to format no spaces before looking up, if new mobile number, international format...
$fields{'q'} = format_for_standard_mobile( $fields{'q'} )
  if ( $fields{'type'} eq 'newusermobile' );

my ( $registryerror, $menu_count, $menu_select );

# using tagsuggest now for yellow pages tags, to be generalised 7/2011
if ( length( $fields{'tag'} ) ) {
    ( $registryerror, $menu_count, $menu_select ) =
      get_suggestions( $db, $cookieref, 'tag', $fields{'tag'}, $token );
} else {
    ( $registryerror, $menu_count, $menu_select ) =
      get_suggestions( $db, $cookieref, $fields{'type'}, $fields{'q'}, $token );
}

# menu suggest output
if (   $fields{'type'} ne 'newuser'
    && $fields{'type'} ne 'newuseremail'
    && $fields{'type'} ne 'newusermobile' )
{
    print $menu_select ;
}

# specific message output for new user, new email, new mobile...

else {
    if ( !length($registryerror) ) {

# tests for uniqueness and well-formed-ness on username, email and mobile number

        if ( $fields{'type'} eq 'newuser' ) {
            if (   $menu_count == 0
                && $fields{'q'} !~ /[^\w]/
                && ( length( $fields{'q'} ) > 3 ) )
            {
                print "$fields{'q'} \n $messages{'validaccountname'}";
            }
        }

        if ( $fields{'type'} eq 'newuseremail'
            && ( length( $fields{'q'} ) > 6 ) )
        {
            if (   $menu_count != 0
                && $fields{'q'} =~
/^\+?[a-z0-9](([-+.]|[_]+)?[a-z0-9]+)*@([a-z0-9]+(\.|\-))+[a-z]{2,6}$/
              )
            {
                print "$fields{'q'} \n email exists";
            }
        }

        if ( $fields{'type'} eq 'newusermobile'
            && ( length( $fields{'q'} ) > 10 ) )
        {

            if ( $menu_count != 0 ) {
                print "$fields{'q'} \n mobile number already exists";
            }
            if ( $fields{'q'} !~ /^[\d]+$/ ) {
                print "$fields{'q'} \n must contain only spaces and numbers";
            }
            if ( $menu_count == 0
                && ( length( $fields{'q'} ) > 11 && $fields{'q'} =~ /^[\d]+$/ )
              )
            {
                print "$fields{'q'} \n valid and unique mobile number";
            }
        }

    } else {
        print "$messages{'invalidregistry'} $db:$registryerror";

    }
}

exit 0;
