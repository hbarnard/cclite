
=head1 NAME

Ccu.pm

=head1 SYNOPSIS

Utility routines for Cclite

=head1 DESCRIPTION

This is package of utilities for the Cclite package 
stuff to read configuration files, literals files, lightweight cgi parser
read in and localise web forms etc.

Problem with collect_items, in Cclite currently, should be moved...1/12/2005

=head1 AUTHOR

Hugh Barnard

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced

=cut

package Ccu;

use strict;
use Cccookie;
use Cwd;
use vars qw(@ISA @EXPORT);
use Exporter;

my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(debug
  cgiparse
  readmessages
  debug_soap
  debug_hash_contents
  deliver_remote_data
  display_template
  make_page_links
  make_html_row_contents
  make_html_transaction_totals
  edit_column_display
  getdirectoryentries
  checkstatus
  getdateandtime
  functiondoc
  error
  result
  printhead
  pretty_caller
  sql_timestamp
  get_os_and_distribution
  check_paths
  format_for_uk_mobile
  format_for_standard_mobile);

$ENV{IFS} = '';

our $log = Log::Log4perl->get_logger("Ccu");

=head3 cgiparse

Lightweight cgi parser routine. Can be modified to not accept html,
possible system commands etc. 

=cut

sub cgiparse {
    my $key;
    my $value;
    my %fields;
    my $query;
    my @query;

    if ( $ENV{'REQUEST_METHOD'} eq 'POST' || $ENV{'REQUEST_METHOD'} eq 'post' )
    {
        sysread( STDIN, $query, $ENV{'CONTENT_LENGTH'} );
    } else {
        $query = $ENV{'QUERY_STRING'};
    }
    @query = split( /&/, $query );
    foreach (@query) {
        s/\+/ /g;
        s/%(..)/pack("c",hex($1))/ge;
        ( $key, $value ) = split(/=/);
        $value =~ s/[\<\>\,\;]//g;    # remove command separators etc.
        $fields{$key} = $value;

    }
    return %fields;
}

=head3 debug_soap

Debug SOAP calls. This doesn't seem to work very well?
Why o why!

=cut

sub debug_soap {
    my ($str) = @_;
    open( LOG, ">>../debug/debug.soap" );
    ###if (class($str) eq "HTTP::Request") {
    ### print LOG $str->contents if (length($str));
    ###}
    close LOG;
}

=head3 display_template

display html from template...
uses HTML::Template included with the package
note that the $html variable is badly named, it should be 'message' or something

=cut

sub display_template {

    my (
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    ) = @_;


    my %configuration;
    #FIXME: hack to deal with cpanel database names....
    if ( $0 !~ /ccinstall/ ) {
        
        %configuration = Ccconfiguration::readconfiguration();

        foreach my $key (%$fieldsref) {
            if ( $key =~ /registry/ ) {
                $fieldsref->{$key} =~ s/$configuration{'cpanelprefix'}_//;
            }
        }
    }

# only refresh is [mis]used to carry json payload if json is being returned 2/2011
# prints the cookies, if any, the json and exits..
    if ( $fieldsref->{'mode'} eq 'json' ) {
        print <<EOT;
Content-type: application/json
$cookies
$refresh
EOT

        return;
    }

    if ($refresh) {
        $metarefresh = <<EOT;
<meta http-equiv="refresh" content="2;URL=$metarefresh">
EOT

    }

    # this is to generalise the passing of $fieldsref to the template
    # under many circumstances it'll include all the field data
    # probably need a convention to separate the two name spaces somewhat

    $fieldsref->{'metarefresh'} = $metarefresh;
    $fieldsref->{'error'}       = $error;
    $fieldsref->{'html'}        = $html;

    ###debug_hash_contents($fieldsref) ;

    # display logon registry and language information
    my $cookieref = get_cookie();
    my ( $date, $time ) = getdateandtime( time() );

    # if not logging off, now transferred to cclite
    if ( $fieldsref->{action} ne "logoff" ) {

        $fieldsref->{language} = $cookieref->{language}
          if ( length( $cookieref->{language} ) );

        $fieldsref->{registry} = $cookieref->{registry}
          if ( length( $cookieref->{registry} ) );

        $fieldsref->{date} = $date;
    }

    # display logon if not logged on, otherwise display the trades form
    # needs modification to allow/disallow certain actions
    if ( length($pagename) ) {
        $fieldsref->{pagename} = $pagename;

        # simple gatekeeper against cash trades if not admin
        # FIXME: a little ugly really....
        if (   $fieldsref->{pagename} eq "admintrades.html"
            && $cookieref->{userLevel} ne 'admin' )
        {
            $fieldsref->{pagename} = "trades.html";
        } elsif ( $fieldsref->{pagename} eq "trades.html"
            && $cookieref->{userLevel} eq 'admin' )
        {
            $fieldsref->{pagename} = "admintrades.html";
        }

    } elsif ( !length( $cookieref->{userLogin} ) ) {
        $fieldsref->{pagename} = "logon.html";
    } else {

        # new cash functions etc. for admins (tellers) only
        if ( $cookieref->{userLevel} eq 'admin' ) {
            $fieldsref->{pagename} = "admintrades.html";
        } else {
            $fieldsref->{pagename} = "trades.html";
        }

    }

    my %messages;

    if ( length( $cookieref->{token} ) ) {

        my $login = $cookieref->{userLogin} || $fieldsref->{userLogin};
        %messages                = readmessages( $cookieref->{language} );
        $fieldsref->{youare}     = "$messages{youare} $login";
        $fieldsref->{atregistry} = "$messages{at} $fieldsref->{registry}";
    }

    # collect currencies and partners, if a trade operation
    # always add a blank option as first to prevent unconscious defaults
    # don't do these unless registry defined,
    #

    my $blank_option = "<option value=\"\"></option>";

    # not done for install, blocked 'new' installer 6/4/2011
    if ( $pagename !~ /logon/
        && length( $cookieref->{registry} && $0 !~ /ccinstall/ ) )
    {
        my $option_string =
          Cclite::collect_items( 'local', $fieldsref->{registry},
            'om_currencies', $fieldsref, 'name', 'select', $token );

        # get the latest news field from the registry for front page display
        $fieldsref->{latest_news} =
          Cclite::get_news( 'local', $fieldsref->{'registry'}, $token )
          if ( length( $cookieref->{registry} ) );

        # format it for user level users, admin needs to edit it
        $fieldsref->{latest_news} =
          "<span class=\"news\">$fieldsref->{latest_news}<\/span>"
          if ( $cookieref->{userLevel} ne "admin"
            && length( $fieldsref->{latest_news} ) );

        # this is the primary currency or the 'only' one
        $fieldsref->{selectcurrency} = <<EOT ;
<select class="required" name="tradeCurrency">$blank_option$option_string</select>\n    
EOT

        # this is the secondary currency in a split transaction operation

        $fieldsref->{sselectcurrency} = <<EOT ;
<select class="required" name="stradeCurrency">$blank_option$option_string</select>\n    
EOT

        # collect partners for registry operations, if multiregistry
        # add local registry to option string!
        # otherwise just present local registry as readonly field
        if ( $fieldsref->{multiregistry} eq "yes"
            && length( $cookieref->{registry} ) )
        {
            $option_string =
              Cclite::collect_items( 'local', $fieldsref->{registry},
                'om_partners', $fieldsref, 'name', 'select', $token );
            $option_string .=
"<option value=\"$fieldsref->{registry}\">\u$fieldsref->{registry}</option>";
            $fieldsref->{selectpartners} = <<EOT ;
<select class="required" name="toregistry">$blank_option$option_string</select>    
EOT

        } else {

            $fieldsref->{selectpartners} = <<EOT ;
<input class="grey"
 name="toregistry" class="required" readonly="readonly" size="30" maxlength="255" value="$fieldsref->{registry}" type="text">   
EOT

        }

    }

    # this is now changed to use om_categories, based on Camden LETS
    # rather than the SIC codes. should become 'pluggable' eventually.
    # the codes now have a tree structure, category and parent (category).
    # as of 07/2011 this is switched off, if free form tags are allowed

    if ( $pagename =~ /yellowpages/ && length( $cookieref->{'registry'} ) && $configuration{'usetags'} ne 'yes') {

        # collect categories for yellow pages
        my $option_string =
          Cclite::collect_items( 'local', $fieldsref->{registry},
            'om_categories', $fieldsref, 'description', 'select', $token );
        $fieldsref->{selectclassification} = <<EOT ;
 <select type="required" name="classification">$blank_option$option_string</select>\n    
EOT

    }    else {
    
    $fieldsref->{selectclassification} = $messages{'usetags'} ;
}

    if ( $pagename =~ /category/ && length( $cookieref->{registry} ) ) {

        # collect major, if a category operation
        #
        my $option_string =
          Cclite::collect_items( 'local', $fieldsref->{registry},
            'om_categories', $fieldsref, 'parent', 'select', $token );
        $fieldsref->{selectparent} = <<EOT ;
 <select class="required" name="parent">$blank_option$option_string</select>\n    
EOT

    }

    print <<EOT;
Content-type: text/html
$cookies
EOT

# index is the default template page
# added logic 8/2009 to return untemplated html, for 'foreign' systems
# this is the beginning of 'return for various representations, rss, json, csv etc.

    if ( !length( $fieldsref->{mode} ) || $fieldsref->{mode} eq 'html' ) {
        if ( !length( $fieldsref->{templatename} ) ) {
            $pages->Display( "index.html", $fieldsref );
        } else {
            $pages->Display( $fieldsref->{templatename}, $fieldsref );
        }
    } else {
        print $fieldsref->{html};
    }

    exit 0;
}

=head3 getdateandtime

Return the print formatted date and time of an input time, used by logging
and date stamping subroutines. 

There's a scope or duplicate problem with this currently 08/2005

=cut

sub getdateandtime {
    my ($input_time) = @_;

    # get today from the system and make a yyyymmdd (Y2k compliant!) date
    my ( $sec, $min, $hour, $mday, $lmon, $lyear, $wday, $yday, $isdst ) =
      localtime($input_time);
    my $time = sprintf( "%.2d%.2d%.2d", $hour, $min, $sec );
    $lmon++;
    my $numeric_day =
      sprintf( "%.4d%.2d%.2d", ( $lyear + 1900 ), $lmon, $mday );
    my $literal_date =
      sprintf( "%.2d/%.2d/%.4d", $mday, $lmon, ( $lyear + 1900 ) );
    return ( $numeric_day, $time );
}

=head3 error

Deal with unexpected errors
Should be used with try catch that is eval type constructs

=cut

sub error {

    my ( $language, $description, $support_mail, $support_literal ) = @_;
    my $problem_literal;
    my $mailto;
    my $tellwebmaster_literal;
    my $bgcolour;

    printhead();

    print <<EOT;
  <html>
  <head>
   <title>Problem $description</title>
  </head>
  <body bgcolor=$bgcolour>
   <H2>$description </H2>\n<PRE>
   $@
   </PRE>
   <a href=\"mailto:$support_mail?subject=$_[1]\">$support_literal</a>
  </body>
  </html>
EOT
    exit 0;
}

=head3 make_page_links

Make multi-page links at top of page for 'many' records

=cut

sub make_page_links {

    my ( $count, $offset, $limit ) = @_;

    # routine to make links for each page
    my $true_count = $count / $limit;
    my $page_count = int( $count / $limit );

    # don't paginate single pages..
    $page_count++ if ( ( $count / $limit ) > $page_count );
    return undef if ( $page_count <= 1 );
    my $x      = $count / $limit;
    my $script = "$ENV{SCRIPT_NAME}?$ENV{QUERY_STRING}";
    my $i;
    my $paging_html;

    for ( $i = 0 ; $i < $page_count ; $i++ ) {
        my $new_offset  = $i * $limit;
        my $page_number = $i + 1;
        my $link;
        if ( $new_offset != $offset ) {
            $link = <<EOT;
   &nbsp;<a class=\"pagelink\" href="$script\&offset=$new_offset\&limit=$limit">$page_number</a>
EOT

        } else {
            $link = "<span class=\"currentlink\">$page_number</span>";
        }

        $paging_html .= $link;
        undef $link;
    }

    return $paging_html;
}

=head3 printhead

Just print a content header
This is also probably dead code

=cut

sub printhead {
    print <<EOT;
Content-type: text/html

EOT
    return;
}

=head3 readmessages

Read the messages file for the given language

This has always been somewhat problematic, now finds file,
depending on the package or installation type:

0: linux commodity hosting, home directory
1: windows
2: debian or ubuntu packaged

=cut

sub readmessages {

    my ($language) = @_;

    $language = "en" if ( !length($language) );

    # deals with various directory structures
    my ( $os, $distribution, $package_type ) =
      get_os_and_distribution();    # see package type above
    my ( $error, $dir, $libpath ) =
      check_paths($package_type);    # check libraries exist/make base path

    my ( $package, $filename, $line ) = caller;

    #FIXME: small kludge for debian
    $dir .= '/' if ( $dir !~ /\/$/ );

    my $messfile = "${dir}literals/literals\056$language";
    my %messages;

    if ( -e $messfile ) {
        open( MESS, $messfile );
        while (<MESS>) {
            s/\s$//g;
            next if /^#/;
            my ( $key, $value ) = split( /\=/, $_ );
            if ($value) {
                $key =~ lc($key);    #- make key canonic, all lower
                $messages{$key} = $value if ( length($value) );
            }
            $key   = "";
            $value = "";
        }
    } else {

        error(
            $language,
"Cannot x find messages file:$error $messfile for $language may be missing?",
            "",
            ""
        );
    }
    return %messages;
}

=head3 format_for_uk_mobile

Make sure everything is in a consistent format
for smsgateway, both gateway and database records

Implies 1 country and may need to be changed for non UK...

=cut

sub format_for_uk_mobile {

    my ($input) = @_;

    # numbers are stored in database as 7855 667524 for example, no zero, no 44
    $input =~ s/^44//;
    $input =~ s/^0//;
    $input =~ s/(\d{4})(\d{5})/$1 $2/;
    $input =~ s/\s+$//;
    return $input;

}

=head3 format_for_standard_mobile

Make sure everything is in a consistent format
for smsgateway, both gateway and database records

Numbers are just run together, no spaces, international
format should be used

44 7779 45678 becomes 44777945678, for example

=cut

sub format_for_standard_mobile {

    my ($input) = @_;

    # numbers are stored in database as 447855667524 for example
    $input =~ s/\s+//g;
    $input =~ s/\s+$//;

    return $input

}

=head3 get_os_and_distribution


FIXME: Duplicated in ccinstall.cgi

Now that the package is widening in application
Need a little precision about the platform
This is not infallible, btw...

If the package flag is set, then the supplied default
configuration should work...

package types
0 unpackaged *nix
1 windows
2 debian
3 probable cpanel guessed via public html

=cut

sub get_os_and_distribution {

    my ( $os, $distribution );
    my $checkdir;
    my $package_type = 0;    # 0 is unpackaged *nix, default tarball
    if ( $^O =~ /^ms/i ) {
        $os           = 'windows';
        $package_type = 1;           # 1 is windows
    } elsif ( $^O =~ /^linux/i ) {
        $os = 'linux';
    } elsif ( $^O =~ /^openbsd/i ) {
        $os = 'openbsd';
    } else {
        $os = 'nocurrentsupport';
    }

    # try and find out distribution
    if ( $os eq 'linux' ) {
        my $dist_string = `cat /proc/version`;
        $dist_string =~ m/(fedora|ubuntu|debian|red hat)/i;
        $distribution = lc($1);
    }

    # if ubuntu or debian, test whether packaged by looking
    # in /usr/share/cclite

    if ( $distribution eq 'ubuntu' || $distribution eq 'debian' ) {
        $checkdir = `usr/share/cclite`;
        $package_type = 2 if ( -e $checkdir );    # 2 is debian package
    }

    # guessing at cpanel because the whole thing is under the document root
    my $path = ( getcwd() || `pwd` ) if ( $os eq 'linux' );
    if ( $path =~ /public_html/i && $os eq 'linux' ) {
        $distribution .= ' probably cpanel';
    }
    return ( $os, $distribution, $package_type );
}

=head3 check_paths

Checks that the path to the cclite libraries
exists and is readable. Returns message, if not.

FIXME: libpath is probably not used now...

=cut

sub check_paths {

    my ($package_type) = @_;
    my ( $message, $libpath, $dir );

    my $os = $^O;

    # if it's windows use cd to find the directory
    if ( $os =~ /^ms/i ) {
        $dir = getcwd() || `cd`;
    } else {
        $dir = getcwd() || `pwd`;
    }
    ###print "os is $os dir is $dir" ;
    chomp $dir;
    $dir =~ s/\bcgi-bin.*//;

    # in standard place, so package is -very probably- being used
    if ( $dir =~ /^\/usr/ && $package_type == 2 ) {
        $dir = '/usr/share/cclite';

 # but, if not in standard place, for example in /home, path is preserved 7/2010
    }

    if ( !length($dir) ) {
        $message = <<EOT;
 <h5>Error  in Ccu::check_paths</h5>
 Can't find base dir $dir  does not exist or unreadable?
 Please fix manually
EOT

    }

    return ( $message, $dir, "${dir}lib" );

}

=head3 make_html_row_contents

Factored out of find_record and get many items in Cclite.pm
Another reason for factoring out, gradual separation of html
part

FIXME: This still contains programmatic hacking around of style sheet...

Since there's no guarantee of order when iterating $tablefields is used to 'steer'


=cut

sub make_html_row_contents {

    my ( $record_counter, $buttons, $tablefields, $hash_ref ) = @_;
    my $row_contents;
    my @field_names = split( /,/, $tablefields );

    foreach my $field_name (@field_names) {
        if ( length( $hash_ref->{$field_name} ) ) {
            $row_contents .=
"<td align=\"right\" style=\"padding:5px 5px;\" class=\"pme-key-1\">$hash_ref->{$field_name}</td>";
        }
    }    # end of pack up row contents

    # push the buttons onto the row...
    $row_contents = $buttons . $row_contents;

    # make stripey styles
    my $row_style;
    ( $record_counter % 2 ) ? ( $row_style = "odd" ) : ( $row_style = "even" );

    $row_contents = "<tr class=\"$row_style\">$row_contents</tr>\n";

    # kludge for debits class in row#
    # this is monolingual and needs to be revisited
    $row_contents =~ s/key-1/key-rejected/g
      if ( $row_contents =~ /rejected|declined/ );
    $row_contents =~ s/key-1/key-debit/g if ( $row_contents =~ /debit/ );

    # splits that are not declined in orange
    $row_contents =~ s/key-\w+/key-split/g
      if ( $row_contents =~ /split/ && $row_contents !~ /declined/ );

    return $row_contents

}

=head3 make_html_transaction_totals


=cut

sub make_html_transaction_totals {

    my ( $total_balance_ref, $total_volume_ref, $template, $messages_ref ) = @_;

    my ( $html, $row_style );
    my $record_counter = 1;

    # keys in both these hashes are currency names
    foreach my $key ( keys %$total_balance_ref ) {
        ( $record_counter % 2 )
          ? ( $row_style = "odd" )
          : ( $row_style = "even" );
        $html .= <<EOT;
        <tr class="$row_style"><td align=\"right\" style=\"padding:5px 5px;\" class=\"pme-key-1\">\u$key</td>
            <td align=\"right\" style=\"padding:5px 5px;\" class=\"pme-key-1\">$total_balance_ref->{$key}</td>
        </tr>
EOT
        $record_counter++;

    }

    $html = <<EOT;
    
    <table>
    <tr><td>$messages_ref->{'currency'}</td><td>$messages_ref->{'balance'}</td></tr>
    $html</table>
EOT

    $template ||= "result.html";

    return ( $html, $template );

}

=head3 deliver_remote_data

Since, Cclite.pm 'assumes' in most cases that it is dealing
with the traditional html front end, this is an experimental
palliative to deliver self describing hashes and messages
to remote gateways such as Drupal, Elgg, Joomla and Tiki-Wiki 

It's not a particularly elegant solution but [hopefully] it's
a pragmatic one that preserves some consistency of access and
delivery and doesn't break a lot of fairly useful things in the legacy part...

It does need to distinguish between multdimensional and flat

For example, transactions:

{"registry":"ccliekh_dalston","table": "om_trades", "message":"OK",
"data": [
{"id": "95",
 "tradeSource":"test2",
"tradeDestination":"test1",
"tradeType":"debit",
"tradeDate":"2011-02-20",
"tradeId":"95",
"tradeMirror":"ccliekh_dalston",
"tradeStatus":"waiting",
"tradeCurrency":"dally",
"tradeAmount":"23"
},

{"id": "97",
 "tradeSource":"test2",
"tradeDestination":"test1",
"tradeType":"debit",
"tradeDate":"2011-02-20",
"tradeId":"97",
"tradeMirror":"ccliekh_dalston",
"tradeStatus":"waiting",
"tradeCurrency":"dally",
"tradeAmount":"23"
}]

} 


=cut

sub deliver_remote_data {

    my ( $db, $table, $message, $hash_ref, $token ) = @_;

    $message ||= 'OK';  # used for status messages to remote, $registry_error...
    my $count = 0;      # row counter...

    my $json;           #data delivered to the remote

    my $is_multi_dimensional = 0;

    # find whether it's multidimensional or 'flat'
    for my $value ( values %$hash_ref ) {
        if ( 'HASH' eq ref $value ) {
            $is_multi_dimensional = 1;
            last;
        }
    }

    # pack up as simple json...
    if ($is_multi_dimensional) {

        for my $id ( keys %$hash_ref ) {
            $json .= "\n{\"id\": \"$id\",\n ";
            for my $field_name ( keys %{ $hash_ref->{$id} } ) {
                $json .=
                  "\"$field_name\":\"$hash_ref->{$id}->{$field_name}\",\n";
            }
            $json =~ s/\,$//
              ;    # snip off the last comma in the record, ugly but simple...
            $json .= "},\n";
        }
        $json =~
          s/\,$//;   # snip off the last comma in the record, ugly but simple...
    } else {
        for my $id ( keys %$hash_ref ) {
            # misteak corrected 20.05.2011, was $id, for the value as well
            $json .= "\n{\"id\": \"$hash_ref->{$id}\",\n ";
            $json =~ s/\,$//
              ;      # snip off the last comma in the record, ugly but simple...
            $json .= "},\n";
        }

    }

    $json = <<EOT;
  {\"registry"\:\"$db\",\"table\": \"$table\", \"message":\"$message\",\n\"data\": [$json]} 
EOT

    ###$log->debug("json is: $json") ;

    ###return ( 0, "", $error, $html, $template, "" );
    return $json;

}

=head3 _timestamp

mysql compatible timestamp

=cut

sub sql_timestamp {

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    my $timestamp = sprintf "%4d-%02d-%02d %02d:%02d:%02d\n", $year + 1900,
      $mon + 1, $mday, $hour, $min, $sec;
    return $timestamp;
}

=head3 debug_hash_contents

debug the contents of a hash, with stamp for calling routine

=cut

sub debug_hash_contents {

    my ($fieldsref) = @_;
    my $x;

    foreach my $hash_key ( keys %$fieldsref ) {
        $x .= "$hash_key: $fieldsref->{$hash_key}\n";

    }
    my ( $package, $filename, $line ) = caller;
    $log->debug("pack:$package file:$filename line:$line");
    $log->debug("fields: $x");

    return;
}

sub pretty_caller {

    my ($i) = @_;
    my (
        $package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
    ) = caller($i);

    $log->debug("p:$package l:$line f:$subroutine");
    ###print "p:$package l:$line f:$subroutine";
}

1;

