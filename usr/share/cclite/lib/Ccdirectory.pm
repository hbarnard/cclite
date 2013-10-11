
=head1 NAME

Ccdirectory.pm

=head1 SYNOPSIS

Ccdirectory main

=head1 DESCRIPTION

This is the the directory/yellow pages module for Cclite. It's now separated from
the transaction motor, so that custom directories can be built

These functions assume that all the local data has been validated
Probably this is done via Ccvalidate.pm. 
There are extra actions for remote registry checks already

=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2004-2007 GPL Licenced 

=cut

package Ccdirectory;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Ccu;
use Cclitedb;
use Cclite;
use Ccvalidate;
use Ccsecure;

my $VERSION = 1.00;
@ISA    = qw(Exporter);
@EXPORT = qw(add_yellow
  show_yellow
  show_yellow_dir
  show_yellow_dir1
  show_tag_cloud
);

# read messages from literals file
our %messages = readmessages();

# used in several places now, moved up here 4/2011
our %configuration = Ccconfiguration::readconfiguration();

=head3 add_yellow

add a yellow page, promoted from raw add_database_record to
do specific validations etc. needs fleshing out...
now added, parse of option fields so that the category, parent
category and keywords work out

=cut

sub add_yellow {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $fieldsref->{date}   = $date;
    $fieldsref->{status} = 'active';

    # decimals used, values stored in 'pence'
    $fieldsref->{price} = 100 * $fieldsref->{price}
      if ( $configuration{usedecimals} eq 'yes' );

    # parse the option field
    (
        $fieldsref->{'category'},
        $fieldsref->{'parent'},
        $fieldsref->{'keywords'}
    ) = $fieldsref->{'classification'} =~ /(\d{4})\s(\d{4})(.*)/;

    # put new tags into category table. if free-form tags are in use
    if ( $configuration{'usetags'} eq 'yes' ) {
        my @tags = split( /\s+/, $fieldsref->{'yellowtags'} );

        foreach my $tag (@tags) {

            $tag = lc($tag);    # make canonical lower case...

            # free form tags are category 9999
            my $sql = get_check_tag_sql($tag);
            my ( $registryerror, $categoryref ) =
              sqlraw( 'local', $db, $sql, '', '' );

            # if it exists already, skip...
            next if ( length( $categoryref->{'description'} ) );

            my $newref;

            #FIXME: hack to make all keywords 9999
            $newref->{'category'}    = '9999';
            $newref->{'status'}      = 'active';
            $newref->{'description'} = $tag;

            add_database_record( $class, $db, 'om_categories', $newref,
                $token );

        }

        #FIXME: this isn't a great way of storing tags
        #       move tags to keywords field...
        $fieldsref->{'keywords'} = $fieldsref->{'yellowtags'};
        $fieldsref->{'category'} = '9999';
        undef $fieldsref->{'yellowtags'};

    }

    my ( $refresh, $error, $html, $cookies ) =
      add_database_record( $class, $db, $table, $fieldsref, $token );
    return ( 1, $fieldsref->{home}, $error, $messages{directorypageadded},
        "result.html", "" );
}

=head3 show_yellow

Join the specific yellow pages record with the user
record to display telephone number and email etc.

Run show balance and volume to show balance and volume at 
bottom of ad. This is a pretty heavy operation and perhaps
should be done as a nightly batch to generate static html

This also contains SQL at present, goodbye n-tier purity!

=cut

sub show_yellow {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;

    my $x;

    # DATE_FORMAT('2003-10-03',GET_FORMAT(DATE,'EUR'));

    my $sqlstring = <<EOT;
  SELECT DISTINCT u.userEmail, u.userStatus,  y.id, date_format(y.date,get_format(date,'eur')) as dt, y.subject, 
                  y.type, y.keywords, y.unit, y.tradeCurrency, y.price, y.truelets,
                  y.description, u.userMobile, u.userTelephone, y.fromuserid
  FROM om_yellowpages y, om_users u
  WHERE (
  y.fromuserid = u.userLogin AND y.id = '$fieldsref->{id}')
EOT

    # get equi-joined table
    my ( $error, $hash_ref ) = sqlraw( $class, $db, $sqlstring, 'id', $token );
    my %report;
    my $html;
    my $record_ref;
    foreach my $hash_key ( keys %$hash_ref ) {

        # decimal display, if configured
        $hash_ref->{$hash_key}->{'price'} = sprintf "%.2f",
          ( $hash_ref->{$hash_key}->{'price'} / 100 )
          if ( $configuration{usedecimals} eq 'yes' );

        # my $parent = "$hash_ref->{$hash_key}->{parent}" ;
        $record_ref = $hash_ref->{$hash_key};
    }

    my ( $r, $m, $error, $balvol, $templ, $c ) =
      show_balance_and_volume( $class, $db, $record_ref->{'fromuserid'},
        $fieldsref, $token );
    $record_ref->{'balanceandvolume'} = $balvol;

    $html = "<table>$html</table>";

# part of the 'new deal' html returned as default but lots of other possibilities
    if ( $fieldsref->{'mode'} eq 'html' || !length( $fieldsref->{'mode'} ) ) {

        #FIXME: result template used if result not supplied, should always be...
        my $template = $fieldsref->{'resulttemplate'} || "result.html";
        return ( "", "", "", $html, $template, $record_ref );
    } elsif ( $fieldsref->{'mode'} eq 'print' ) {

    }

}

=head3 show_yellow_dir1

Show yellow pages directory by category description, based on the work done by Mary Fee
for Camden. Should work with any scheme that has categories and parent categories
only nested once, otherwise needs re-writing to be recursive

Shows all lower level description in a big craiglist like table, will make a big
page when there lots of ads. 

Also this is a lot simpler than the first one with its expanding and contracting
display etc. 06/2007

sql etc. moved to Cclitedb in 05/2010

FIXME: Of course this is still very html-bound...

=cut

sub show_yellow_dir1 {

    my ( $class, $db, $sqlstring, $fieldsref, $token, $offset, $limit ) = @_;

    my $interval    = 1;        # one week for displaying items as new...
    my $html        = "<tr>";
    my $width_count = 1;
    my $max_depth = $fieldsref->{maxdepth}
      || 3;                     # four cells wide as default if not specified
    my $item_count;

    # changed $fieldsref->{'getdetail'} to 0, should be just category
    my ( $new_items_hash_ref, $yellowdirectory_hash_ref ) =
      get_yellowpages_directory_data( $class, $db, $interval, 0, $token );

    foreach my $key ( sort keys %$yellowdirectory_hash_ref ) {

        my $type =
          $yellowdirectory_hash_ref->{$key}->{'type'}
          ;                     #just for convenience to shorten it

        $yellowdirectory_hash_ref->{$key}->{'type'} =
          $messages{$type};   # replace offered/wanted with multilingual message

  # if there's recent ads in this category add a small 'New' flag in the listing
        if ( exists $new_items_hash_ref->{$key}->{'description'} ) {
            $yellowdirectory_hash_ref->{$key}->{'literal'} =
              $yellowdirectory_hash_ref->{$key}->{'description'}
              . "<sup class=\"spaced\">$messages{'new'}<\/sup>";
        } else {
            $yellowdirectory_hash_ref->{$key}->{'literal'} =
              $yellowdirectory_hash_ref->{$key}->{'description'};
        }

        # make a url out of the description field...
        $yellowdirectory_hash_ref->{$key}->{'url'} = <<EOT;
         <a title="get listing by category" href="/cgi-bin/cclite.cgi?action=showyellowbycat&string1=$yellowdirectory_hash_ref->{$key}->{'description'}">
         $yellowdirectory_hash_ref->{$key}->{'literal'}
         </a>
EOT

        my $row = <<EOT;
        <td class="$type">$yellowdirectory_hash_ref->{$key}->{'url'}</td><td>&nbsp;</td><td class="$type">$yellowdirectory_hash_ref->{$key}->{'majorcount'}</td><td>&nbsp;</td>
EOT

        # start a new row, if at max width, else just add on
        if ( $width_count == $max_depth ) {
            $html .= "$row</tr>\n<tr>";
            $width_count = 1;

        } else {
            $html .= $row;
            $width_count++;
        }

    }

    # pad and row-terminate the end of the table, if necessary
    my $endtable =
      "<td></td>" x ( ( $max_depth - $width_count ) * $item_count );
    $html .= "$endtable</tr>" if ( $html !~ /<tr>$/ );

    $html = "<table><tbody class=\"stripy\">$html</tbody></table>";

    if ( $fieldsref->{'mode'} eq 'html' || !length( $fieldsref->{'mode'} ) ) {
        return ( 0, '', '', $html, "result.html", '', '', $token );
    } elsif ( $fieldsref->{'mode'} eq 'print' ) {
        return ( 0, '', '', $html, "result.html", '', '', $token );
    }
}

=head3 show_tag_cloud


This produces the free form tag cloud enabled by usetags. Main idea
is to make the yellow pages more flexible and multilingual.

Same signatures as the other yellow pages functions, for simplicity

FIXME: Of course this is still very html-bound...

=cut

sub show_tag_cloud {

    my ( $class, $db, $fieldsref, $token ) = @_;

    my ( %keyword_index, %keyword_count, %keyword_type )
      ;    # type is offer/wanted/match

    my $interval = 1;    # one week for displaying items as new...
    my $registry_error;
    my $width_count = 1;
    my $status;          # blank entry used for delivering json
    my $max_depth = $fieldsref->{maxdepth}
      || 5;
    my $max_entries = 100;
    my $total_count = 0;

    my ( $registry_error, $hash_ref ) =
      get_yellowpages_tag_cloud_data( $class, $db, $interval, 0, $token );

    # phase 1 collect

    foreach my $key ( sort keys %$hash_ref ) {
        my @tags = split( /\s+/, $hash_ref->{$key}->{'keywords'} );

        # make unique...legacy problems
        @tags = map lc,
          @tags;    # deal with legacy problems between upper and lower....
        my %hash = map { $_, 1 } @tags;
        @tags = keys %hash;

        foreach my $tag (@tags) {
            $keyword_index{$tag} .=
              "$key,";    # list of ids that this keyword references
            $keyword_count{$tag}++;    # add one to the count for this tag
            $total_count++;            # and to the total

            if ( $keyword_type{$tag} ne $hash_ref->{$key}->{'type'} ) {
                $keyword_type{$tag} = 'matched';
            } elsif ( $keyword_type{$tag} ne 'matched' ) {
                $keyword_type{$tag} = $hash_ref->{$key}->{'type'};
            }
        }

    }

    # json raw cloud
    if ( $fieldsref->{'mode'} eq 'json' ) {
        my ($json) = deliver_remote_data( $db, 'om_categories', $registry_error,
            \%keyword_index, $status, $token );
        return $json;
    }

    # html cloud for right-hand-side
    my $depth = 1;
    my $cloud;

    foreach my $tag ( sort keys %keyword_index ) {

        $tag =~ s/\s+$//g;
        $keyword_index{$tag} =~ s/\,$//;

        my $size = int( $keyword_count{$tag} / $total_count * 10 );
        ### print "$keyword_count{$tag} $total_count $size<br/>" ;
        $size = 50 if ( $size < 50 );
        $cloud .= <<EOT;
    <span class="$keyword_type{$tag}" style="font-size:$size"><a title="get listing by category: $messages{'count'} $keyword_count{$tag}: $messages{$keyword_type{$tag}}" href="/cgi-bin/cclite.cgi?action=showyellowbycat&string1=$tag">
         $tag</a></span> 
EOT

        if ( $depth == $max_depth ) {
            $cloud .= "<br/>";
            $depth = 1;
        } else {
            $depth++;
        }

    }

    return ( $registry_error, $cloud );

}

1;

