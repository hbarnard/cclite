
=head1 NAME

 Ccrss.pm

=head1 SYNOPSIS

 Sketchy RSS module for Cclite

=head1 DESCRIPTION

 This is a sketchy RSS module for Cclite..the idea is to publish 
 and aggregate offer and demand London-wide, for example.

 Ccrss.pm is based on:
 rss.pl -- lightweight CGI-based RSS aggregator
 Copyright (C) 2004 Mark L. Irons

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 Yes, I'm aware that this is embarrassing Perl 4 code. Improve it! 
 Have done so, I hope...HB 2005 -- MLI

 Note that there's tons of dead code from the original project in here.
 It's left in in case the current module is extended in that direction.

=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO

rss.pl -- lightweight CGI-based RSS aggregator
Copyright (C) 2004 Mark L. Irons

=head1 COPYRIGHT

Copyright (C) 2004 Mark L. Irons
(c) Hugh Barnard 2005 GPL Licenced 

=cut

package Ccrss;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Cclitedb;
use Ccu;
###use Ccsecure;    # at least for get_server_details()
use XML::RSS;    # generate registries channel, ads channel
use XML::Simple;
use LWP::Simple;

my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(create_rss_feed);

our %messages    = readmessages();
our $messagesref = \%messages;

=head3 create_rss_feed

 this is the real feed creator and storer. It needs to be more
 parameterised, for example, where it stores its created files etc.
 It's designed to run as one cron for multiple registries running
 in one domain on one webserver (if that makes sense..)

=cut

sub create_rss_feed {
    my ( $class, $home, $description, $email, $db, $table, $fieldsref, $token )
      = @_;

    my $rss = new XML::RSS( version => '1.0' );
    my ( $sqlstring, $title );

    if ( $fieldsref->{'type'} eq 'all' ) {
        $title     = "$db $messages{'all'}";
        $sqlstring = "type = \'offered\' or type = \'wanted\'";
    } elsif ( $fieldsref->{'type'} eq 'offered'
        || $fieldsref->{'type'} eq 'wanted' )
    {
        $title     = "$db $messages{$fieldsref->{'type'}}";
        $sqlstring = "type = \'$fieldsref->{'type'}\'";

    } elsif ( $fieldsref->{'type'} eq 'match' ) {
        $title     = "$db $messages{'matched'}";
        $sqlstring = <<EOT;
SELECT * FROM om_yellowpages o, om_yellowpages w where (
(o.id != w.id) and o.type != w.type and o.category = w.category and o.parent = w.parent  ) 
EOT

    } else {
        log_entry("unknown feed type:$$fieldsref{'type'}");
    }

    my ( $registryerror, $ad_hash_ref );

    if ( $$fieldsref{type} ne 'match' ) {
        ( $registryerror, $ad_hash_ref ) = sqlfind(
            $class, $db,   $table, $fieldsref, '*', $sqlstring,
            undef,  undef, undef
        );
    } else {
        ( $registryerror, $ad_hash_ref ) =
          sqlraw( $class, $db, $sqlstring, 'id', $token );
    }

    # empty query result, return
    return if ( ( !length($ad_hash_ref) ) || $registryerror );

    foreach my $key ( keys %$ad_hash_ref ) {

        $rss->add_item(
            title =>
"$ad_hash_ref->{$key}->{'type'}:$ad_hash_ref->{$key}->{'subject'}",
            link =>
"$home?subaction=om_yellowpages&userLogin=$ad_hash_ref->{$key}->{'fromuserid'}&action=showuser",
            description => $ad_hash_ref->{$key}->{'description'},
            dc          => {
                subject => $ad_hash_ref->{$key}->{'subject'},
                creator => "$ad_hash_ref->{$key}->{'fromuserid'} at $db",
            },
            taxo => [
                'http://dmoz.org/Society/Organizations/Local_Currency_Systems/',
'http://dmoz.org/Society/Organizations/Local_Currency_Systems/LETS/'
            ]
        );
    }    # end of foreach row

    # header information for the rss channel

    $rss->channel(
        title       => "$title",
        link        => $home,
        description => $description,
        dc          => {
            date      => '2000-08-23T07:00+00:00',
            subject   => "Goods and Services Offers at $db",
            creator   => $email,
            publisher => $email,
            rights    => 'Copyright 2010, Cclite',
            language  => $fieldsref->{'language'},
        },
        syn => {
            updatePeriod    => "hourly",
            updateFrequency => "1",
            updateBase      => "1901-01-01T00:00+00:00",
        },
        taxo => [
            'http://dmoz.org/Society/Organizations/Local_Currency_Systems/',
            'http://dmoz.org/Society/Organizations/Local_Currency_Systems/LETS/'
        ]
    );

    $rss->image(
        title => $title,
        url   => "$home/image",
        link  => $home,
        dc    => { creator => "anon", },
    );

    $rss->textinput(
        title       => "quick finder",
        description => "Use the input below to search this registry",
        name        => "query",
        link        => "$home",
    );

    #rss path is now /var/www/cclite/public_html/rss/dogtown/en for example
    my $rss_directory =
      join( '/', $fieldsref->{'rsspath'}, $db, $fieldsref->{'language'} );

    if ( -e $rss_directory ) {
    } else {

        #FIXME: won't work for Windows though...
        `mkdir -p $rss_directory`;
    }

    my $feed_file_name = "$fieldsref->{'type'}\.rdf";
    my $full_name      = "$rss_directory\/$feed_file_name";
    if ( !( -w $full_name ) ) {
        log_entry("cannot write to rss feed file:$feed_file_name");
    }
    $rss->save($full_name)
      if ( length($db) );    # ugly but removes empty file bug
    return;
}

1;

