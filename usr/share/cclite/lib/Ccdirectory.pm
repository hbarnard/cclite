
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
);

# read messages from literals file, this isn't fully multilingual yet
our $log      = Log::Log4perl->get_logger("Ccdirectory");
our %messages = readmessages("en");

=head3 add_yellow

add a yellow page, promoted from raw add_database_record to
do specific validations etc. needs fleshing out...
now added, parse of option fields so that the category, parent
category and keywords work out

=cut

sub add_yellow {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $$fieldsref{date}   = $date;
    $$fieldsref{status} = 'active';

    # parse the option field
    (
        $fieldsref->{'category'},
        $fieldsref->{'parent'},
        $fieldsref->{'keywords'}
    ) = $fieldsref->{'classification'} =~ /(\d{4})\s(\d{4})(.*)/;

    ###$log->debug("string: $fieldsref->{'category'}, $fieldsref->{'parent'}, $fieldsref->{'keywords'}  = $fieldsref->{'classification'}") ;
    #
    my ( $refresh, $error, $html, $cookies ) =
      add_database_record( $class, $db, $table, $fieldsref, $token );
    return ( 1, $$fieldsref{home}, $error, $messages{directorypageadded},
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
  SELECT DISTINCT u.userEmail, u.userStatus,  y.id, date_format(y.date,get_format(date,'eur')) as dt, y.subject, y.type, y.keywords, y.unit, y.tradeCurrency, y.price, y.truelets,
                  y.description, u.userMobile, u.userTelephone, y.fromuserid
  FROM om_yellowpages y, om_users u
  WHERE (
  y.fromuserid = u.userLogin AND y.id = '$$fieldsref{id}')
EOT

    ###$log->debug("sqlstring is $sqlstring") ;
    # get equi-joined table
    my ( $error, $hash_ref ) = sqlraw( $class, $db, $sqlstring, 'id', $token );
    my %report;
    my $html;
    my $record_ref;
    foreach my $hash_key ( keys %$hash_ref ) {

        # my $parent = "$hash_ref->{$hash_key}->{parent}" ;
        $record_ref = $hash_ref->{$hash_key};
    }

    my ( $r, $m, $error, $balvol, $templ, $c ) =
      show_balance_and_volume( $class, $db, $record_ref->{'fromuserid'},
        'html', $token );
    $record_ref->{'balanceandvolume'} = $balvol;

    $html = "<table>$html</table>";



    # part of the 'new deal' html returned as default but lots of other possibilities
    if ($fieldsref->{'mode'} eq 'html' || ! length($fieldsref->{'mode'}) ) {
      #FIXME: result template used if result not supplied, should always be...
       my $template = $fieldsref->{'resulttemplate'} || "result.html";
      return ( "", "", "", $html, $template, $record_ref );
    } elsif ($fieldsref->{'mode'} eq 'print') {

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
    my $max_depth = $$fieldsref{maxdepth}
      || 3;                     # four cells wide as default if not specified
    my $item_count;

    # changed $fieldsref->{'getdetail'} to 0, should be just category
    my ( $new_items_hash_ref, $yellowdirectory_hash_ref ) =
      get_yellowpages_directory_data( $class, $db, $interval, 0, $token );

    foreach my $key ( sort keys %$yellowdirectory_hash_ref ) {

        my $type =
          $yellowdirectory_hash_ref->{$key}
          ->{'type'};           #just for convenience to shorten it

        ###$log->debug("key is $key type is $type") ;

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

   if ($fieldsref->{'mode'} eq 'html' || ! length($fieldsref->{'mode'})) {
    return ( 0, '', '', $html, "result.html", '', '', $token );
   } elsif ($fieldsref->{'mode'} eq 'print' ) {
     return ( 0, '', '', $html, "result.html", '', '', $token );
   }
}







1;

