
=head1 NAME

Cclite.pm

=head1 SYNOPSIS

Cclite main model

=head1 DESCRIPTION

This is the second prototype perl web services version of the CClite package for use
with soap lite/c#/dotnet etc.

The design philosophy is as follows:

  - simplicity, small number of lines of code
  - use SHA2 based hashing to preserve integrity
  - use MySql for storage, first version used filestore
  - many validation checks, especially on transactions
  - everything should return at least a status, passed up the return chain
 
Nearly everything that is not Mysql is a hash, 

Integrity individual SHA2 fingerprints on the transactions and for the
SMS messages. Secure transmission is proposed via https which will
also work for SOAP (a large to-be-done).

This Cclite package should contain anything/everything that is to be exposed
as an external web service. This is not true now and needs tidying
up.

These functions assume that all the local data has been validated
Probably this is done via Ccvalidate.pm. 
There are extra actions for remote registry checks already

=head1 AUTHOR

Hugh Barnard


=head1 COPYRIGHT

(c) Hugh Barnard 2004-2007 GPL Licenced 

=cut

package Cclite;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Cclitedb;
use Cccookie;
use Ccvalidate;
use Ccsecure;
use Ccconfiguration;
use Ccu;

# used for new style notify, set net_smtp to zero and comment, if not needed
use Net::SMTP;

# notify by mail is exported now, to allow sms/email notifies

my $VERSION = 1.00;
@ISA    = qw(Exporter);
@EXPORT = qw(add_user
  add_openid
  modify_user
  show_user
  confirm_user
  change_language
  logon_user
  do_login
  logoff_user
  collect_items
  get_user
  get_news
  get_trades
  delete_trade
  find_and_delete_trade
  modify_trade
  notify_by_mail
  find_and_modify_trade
  forgotten_password
  find_records
  show_balance_and_volume
  show_balance_and_volume1
  sms_transaction
  get_next_user
  get_items
  get_many_items
  delete_user
  split_transaction
  directpay
  transaction
  check_user_and_add_trade
  wrapper_for_check_user_and_add_trade
);

=head3 messages

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash
 
=cut

our %messages    = readmessages();
our $messagesref = \%messages;

our $log         = Log::Log4perl->get_logger("Cclite");

# used in several places now, moved up here 4/2011
our %configuration = readconfiguration() if ( $0 !~ /ccinstall/ );

=head3 get_basic_credentials

SOAP basic endpoint authentication: needs configuration file parameters and
general beefing up. This example will authenticate a user 'transport'
with a password of 'test'

One potential problem is managing the user/password values in this

=cut

sub SOAP::Transport::HTTP::Client::get_basic_credentials {
    return 'transport' => 'test';
}

=head3 add_openid

Add an openid to the openid table..

=cut

sub add_openid {

    my ( $class, $db, $table, $fieldsref, $cookieref, $token ) = @_;

    $fieldsref->{'userId'} = $cookieref->{'userId'};

    add_database_record( $class, $db, $table, $fieldsref, $token );
    return ( "1", $fieldsref->{home}, "", "open id added", "result.html", "" );

}

=head3 add_user

Add a user to the user table
$class added to some routines for cclite web services access

Normally a user is validated via email and becomes active at that
point. See manual for how to switch this off

A stub user via the drupal (and soon Elgg) passthrough  can also be added
here, in this case, validation is skipped. August 2009

=cut

sub add_user {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $refresh, $error, $html, $cookies );

    my @status;
    my $hash       = "";                 # for the moment, needs sha1 afterwards
    my $return_url = $fieldsref->{home};

    # need nuserLogin field to make the autosuggest work in ccsuggest.cgi
    # but must put correct field into the database

    # lower case only screen names, as of 11/2008
    $fieldsref->{nuserLogin} =~ s/\s+$//;
    $fieldsref->{userLogin} = lc( $fieldsref->{nuserLogin} );

    # api user creation gives non-validated stub records
    if ( $fieldsref->{logontype} ne 'api' ) {
        @status =
          validate_user( $class, $db, $fieldsref, $messagesref, $token, "",
            "" );
        if ( $status[0] == -1 ) {
            shift @status;
            $fieldsref->{errors} = join( "<br/>", @status );
            return ( "0", "", "", $html, "newuser.html", "" );
        }
    }

    # new users are set to initial status defined in cclite.cgi
    $fieldsref->{userStatus} = $fieldsref->{initialUserStatus};

#FIXME: boolean userSmsreceipt update, probably unnecessary but test, if removed
    length( $fieldsref->{'userSmsreceipt'} )
      ? ( $fieldsref->{'userSmsreceipt'} = 1 )
      : ( $fieldsref->{'userSmsreceipt'} = 0 );
    ###$log->debug("sms receipt is $fieldsref->{'userSmsreceipt'}") ;

    # FIXME: These should not be hardcoded, 3 tries, not test yet + active
    $fieldsref->{userPasswordTries}  = 3;
    $fieldsref->{userPasswordStatus} = 'active';

    #
    my ( $date, $time ) = getdateandtime( time() );
    $fieldsref->{userJoindate} = $date;

    #
    $fieldsref->{userLevel}    = 'user';
    $fieldsref->{userPassword} = $fieldsref->{userHash};

# mobile pin number is stored as hashed, status waiting, phone number reformatted
# pin status is always waiting until a confirm sms, 3 tries then locked
# FIXME: Most of these should not be hardcoded
    $fieldsref->{userPin}       = text_to_hash( $fieldsref->{userPin} );
    $fieldsref->{userPinStatus} = 'waiting';
    $fieldsref->{userPinTries}  = 3;

    #FIXME: don't assume that all mobiles are UK based, drop  this..
    $fieldsref->{userMobile} =
      format_for_standard_mobile( $fieldsref->{userMobile} );

    # add the user to the registry database
    my ( $rc, $rv, $record_id ) =
      add_database_record( $class, $db, $table, $fieldsref, $token );

    #
    delete $fieldsref->{saveadd};
    delete $fieldsref->{userPassword};

    #
    $fieldsref->{action}     = "confirmuser";
    $fieldsref->{userStatus} = "active";
    $fieldsref->{Send}       = "$messages{confirm} $fieldsref->{userName}";

# make a hyperlink: many people will receive text-only email, therefore no buttons
    my $urlstring = <<EOT;
$return_url?registry=$fieldsref->{registry}&subaction=om_users&userLogin=$fieldsref->{userLogin}&userStatus=active&action=confirmuser
EOT

    # type 1 notification for new user
    # modified 11/2008, give a return from the attempt to send mail
    # won't send email if user is intially active as default, saves an email!
    my $mail_return;

    if ( $fieldsref->{initialUserStatus} ne 'active' ) {
        $mail_return = notify_by_mail(
            $class,
            $db,
            $fieldsref->{userName},
            $fieldsref->{userEmail},
            $fieldsref->{systemMailAddress},
            $fieldsref->{systemMailReplyAddress},
            $fieldsref->{userLogin},
            $fieldsref->{smtp},
            $urlstring,
            undef,
            1,
            $hash
        );
    }

    return ( "1", $return_url, $error,
        "$messages{useradded} <br/> $mail_return",
        "result.html", "" );
}

# make a user active in the database usually via reception
# of an email, move to here to provide a little feedback

sub confirm_user {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    update_database_record( $class, $db, $table, 2, $fieldsref,
        $fieldsref->{language}, $token );
    return ( "1", $fieldsref->{home}, "",
        "$fieldsref->{userLogin} $messages{isnowactive}",
        "result.html", $fieldsref, "" );
}

=head3 logon_user

Logon a remote web user

no remote access for this, put somewhere else? Ccsecure?
by this I mean, doesn't need/want exposure as web service...
need to check whether user is already logged on: new field
need to check whether the user is confirmed, otherwise: no login
need to log failures: new table om_log and log_violation in Ccsecure
need to cumulate cascading return codes

Extended for api key style logon, compares key and then gives same
set of tokens etc. as for the individual user

Ugliness at the bottom of this, for moving the user to the correct
start page via print Location. 10/2009

=cut

sub logon_user {

    my ( $class, $db, $table, $fieldsref, $cookieref, $registry_private_value )
      = @_;
    my ( $limit, $offset );                                   # unused here ;
    my ( $refresh, $error, $html, %cookie, $cookieheader );
    my $fail = 0;    # set to 1 if logon failure, for better refresh experience
         # get the user record from the database, depending on login type
    my ( $status, $userref );

    # merchant key delivered as cookie
    my $cookieref = get_cookie();

    # user delivered via REST, same as form....
    if ( $fieldsref->{logontype} eq 'form' || $fieldsref->{logontype} eq 'api' )
    {
        ( $status, $userref ) = get_where(
            $class, $fieldsref->{registry},
            "om_users", '*', "userLogin", $fieldsref->{userLogin},
            $registry_private_value, $offset, $limit
        );

# test and branch to deal with bad db user and non-existent database, used  to 500
        if ( length($status) ) {
###            $log->warn(
###"logon database problem: s:$status u:$fieldsref->{userLogin} r:$fieldsref->{registry}"
###            );
            $html =
"$messages{loginfailedfor} $fieldsref->{userLogin} $messages{at} $fieldsref->{registry}: $status <a href=\"$fieldsref->{home}\">$messages{tryagain}</a>";
            return ( "0", '', $error, $html, "result.html", $fieldsref,
                $cookieheader );
        }
    } elsif ( $fieldsref->{logontype} eq 'remote' ) {
        ( $status, $userref ) = get_where( $class, $fieldsref->{registry},
            "om_users", '*', "userLogin", $ENV{REMOTE_USER},
            $registry_private_value, $offset, $limit );
    }

    # cash, liquidity and sysaccount may not logon
    if ( $userref->{userLevel} eq 'sysaccount' ) {
        $html =
"$messages{loginfailedfor} $fieldsref->{userLogin} $messages{at} $fieldsref->{registry}: $status <a href=\"$fieldsref->{home}\"> $messages{notallowedsysaccount}";

        return ( "0", '', $error, $html, "result.html", $fieldsref,
            $cookieheader );

    }

    # login failed here...need some industrial processing to deal with this
    # no user found
    if ( !length( $userref->{userId} ) ) {
        $log->warn(
"$messages{loginfailedfor} $fieldsref->{userLogin} $messages{at} $fieldsref->{registry} : user not found"
        );
        $html =
"$messages{loginfailedfor} $fieldsref->{userLogin} $messages{at} $fieldsref->{registry}: $status <a href=\"$fieldsref->{home}\">$messages{tryagain}</a>";
        return ( "0", '', $error, $html, "result.html", $fieldsref,
            $cookieheader );

    } elsif

      # compares password from form or api key from initial cookie
      # FIXME: api_key method should be replace by OAuth, real-soon-now 07/2011
      (
        !_compare_password_or_api_key(
            $fieldsref, $cookieref, $userref, $registry_private_value
        )
      )

    {
        $log->warn(
"$messages{loginfailedfor} $fieldsref->{userLogin} $messages{at} $fieldsref->{registry} : password failed"
        );

#FIXME: The locking mechanism is in place but nothing for resetting and testing, bigger job...
        $userref->{userPasswordTries}--;
        if ( $userref->{'userPasswordTries'} <= 1 ) {
            $userref->{'userPasswordStatus'} = 'locked';
            $userref->{userPasswordTries} = 0;
        }

        undef $userref
          ->{userPassword}; # remove this otherwise it's rehashed and re-updated
        my ( $a, $b, $c, $d ) =
          update_database_record( 'local', $db, "om_users", 2, $userref,
            $userref->{language}, $cookie{token} );

        $html =
"$messages{passwordfailedfor} $fieldsref->{userLogin} $messages{at} $db <a href=\"$fieldsref->{home}\">$messages{tryagain}</a>";

        return ( "0", '', $error, $html, "result.html", $fieldsref,
            $cookieheader );

        # user not active
    } elsif ( $userref->{userStatus} ne 'active' ) {
        $html =
"$fieldsref->{userLogin} $messages{at} $db $messages{isnotactive} <a href=\"$fieldsref->{home}\">$messages{tryagain}</a>";
        return ( "0", '', $error, $html, "result.html", $fieldsref,
            $cookieheader );
    } else {

        # login success, fill in cookie fields
        my $path = "/";   
        my $domain = $fieldsref->{domain};

        my $ip_address = $ENV{REMOTE_ADDR};

        # cookie is produced this time, not checked
        ( $cookie{'token'}, $cookie{'token1'} ) =
          calculate_token( $registry_private_value,
            $fieldsref, undef, $ip_address );

        # make cookie fields from the user table
        $cookie{userLogin} = $userref->{userLogin};
        $cookie{userId} =
          $userref->{userId};    # not used yet, to replace userLogin
          
        # language taken from cookie first, then user record
        #FIXME: duplicates decide_language, pretty much, fold in
        $cookie{language} = $cookieref->{'language'} || $userref->{userLang} || $configuration{language} || 'en' ;

        # avoid cumulation of registry cookie values, this is a browser problem though
        $cookie{registry} ||= $fieldsref->{registry};
        $cookie{userLevel} = $userref->{userLevel};

        # make a cookie header, valid for session
        #FIXME: language cookie should have long expiry
        $cookieheader =
          return_cookie_header( "-1", $domain, $path, "", %cookie );

        # calculate date and time stamp for om_users table
        # get date and timestamp
        my ( $date, $time ) = getdateandtime( time() );
        
        # just supply necessary fields, not the whole records, restore password tries on success, 08/2011
        # language updated just in case changed without logging in...
        my %update =  ('userId', $userref->{'userId'},
                       'userLastLogin', "$date$time", 
                       'userPasswordTries', 3,
                       'userLang', $cookie{'language'} ) ;
        
        undef $userref
          ->{'userPassword'};  # remove this otherwise it's rehashed and re-update
                             # mode 2 is where userLogin = value ;
            # use userref to update record, should strip all other fields...
            # throw away return codes for the present
        my ( $a, $b, $c, $d ) =
          update_database_record( 'local', $db, "om_users", 1, \%update,
            $userref->{'language'}, $cookie{'token'} );

        print $cookieheader ;
        print "Location:$fieldsref->{home}\n\n";
        ### print "Location:$ENV{SCRIPT_PATH}\n\n";
        exit 0;

    }
}

=head3 _do_login

Internal function to enable openid, widget etc. Possible
security hole here...language comes only from user record
no facility for changing it here...

=cut

sub do_login {

    my ( $fieldsref, $registry, $userref, $registry_private_value ) = @_;
    
    my %cookie;
    
    $cookie{language} = $userref->{userLang};
    
    # cookie is produced this time, not checked
    ( $cookie{'token'}, $cookie{'token1'} ) =
      calculate_token( $registry_private_value, $fieldsref, undef,
        $ENV{REMOTE_ADDR} );

    # make cookie fields from the user table
    $cookie{userLogin} = $userref->{userLogin};
    $cookie{userId} = $userref->{userId};   # not used yet, to replace userLogin
    
  # avoid cumulation of registry cookie values, this is a browser problem though
    $cookie{registry} = $registry || $fieldsref->{registry};

    $cookie{userLevel} = $userref->{userLevel};

    # make a cookie header, valid for session
    my $cookieheader =
      return_cookie_header( "-1", $fieldsref->{domain}, '/', "", %cookie );

    # calculate date and time stamp for om_users table
    # get date and timestamp
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    $userref->{userLastLogin} = "$date$time";
    undef $userref
      ->{userPassword};    # remove this otherwise it's rehashed and re-update
                           # mode 2 is where userLogin = value ;
        # use userref to update record, should strip all other fields...
        # throw away return codes for the present
    my ( $a, $b, $c, $d ) =
      update_database_record( 'local', $cookie{registry}, "om_users", 2,
        $userref, $userref->{language}, $cookie{token} );

    print $cookieheader ;
    print "Location:$fieldsref->{home}\n\n";
    exit 0;

}

=head3 _compare_password_or_api_key

Offload the gradually more complex logic for password checking

=cut

sub _compare_password_or_api_key {

    my ( $fieldsref, $cookieref, $userref, $registry_private_value ) = @_;
    my $passed           = 0;
    my $compare_password = 0;
    my $compare_api_key  = 0;

    if ( $fieldsref->{'logontype'} eq 'form' ) {

        $compare_password = compare_password(
            $fieldsref->{'userHash'},
            $fieldsref->{'userPassword'},
            $userref->{userPassword}
        );

    }

    # password failed and it comes from the api key hash
    # first cut drupal and elgg etc. connections 08/2009
    # FIXME: Replace with OAuth, real-soon-now 07/2011
    if ( $fieldsref->{'logontype'} eq 'api' ) {

        $compare_api_key = compare_api_key(
            $fieldsref->{'registry'},
            $cookieref->{'merchant_key_hash'},
            $registry_private_value
        );

    }

    $passed = 1 if ( $compare_password || $compare_api_key );
    return $passed;
}

=head3 logoff_user

Logoff a web user
Again this should probably be moved away from Cclite

=cut

sub logoff_user {

    my ( $class, $db, $table, $pages, $cookieref, $fieldsref,
        $registry_private_value )
      = @_;

    my $goodbye = "$messages{goodbye} $cookieref->{userLogin}";

    $fieldsref->{'youare'} = "";
    $fieldsref->{'at'}     = "";
    $fieldsref->{'action'} = "";

    foreach my $key ( keys %$cookieref ) {
        $cookieref->{$key} = undef if ($key ne 'language');
    }

    my $cookieheader =
      return_cookie_header( "-1", $fieldsref->{'domain'}, '/', "",
        %$cookieref );

    display_template(
        "1",    $fieldsref->{'home'}, "",         $goodbye,
        $pages, "result.html",        $fieldsref, $cookieheader,
        ""
    );
    exit 0;
}

=head3 get_news

Get news from registry table in database
There's only one record which contains a news field

=cut

sub get_news {
    my ( $class, $db, $token ) = @_;

    # get the first (and only..) record within the registry table

    my ( $status, $registryref ) =
      get_where( $class, $db, 'om_registry', '*', 'name', $db, $token, 0, 1 );

    # this is messy but don't want the box, if empty
    return $registryref->{latest_news};

}

=head3 find_records

Find database records
provides a list as return

create a large 'or' for textual fields and then find
cookieref processed to get logon field
specific for finding trades at present

04/2005 this was moved from Cclitedb and the database
part was split and moved into the database part

05/2007 somewhat re-written to be slightly less messy,
some way to go though...

=cut

sub find_records {
    my (
        $class,     $db,    $table,  $fieldsref, $fieldslist,
        $cookieref, $token, $offset, $limit
    ) = @_;
    my ( $html, @row, $home );
    my $allow_changes = 0;    # used only to avoid repeating a complex test

    # these come from Ajax search boxes
    $fieldsref->{'string'} =
         $fieldsref->{'string1'}
      || $fieldsref->{'string2'}
      || $fieldsref->{'string3'};

    # no * after $fieldsref, forces use of the allowed fields list
    my ( $error, $count, $column_array_ref, $hash_ref ) = find_database_records(
        $class,     $db,    $table,  $fieldsref, $fieldslist,
        $cookieref, $token, $offset, $limit
    );

    my $i;
    my @columns;
    my $paging_html =
      make_page_links( $count, $offset, $limit );    # make links for all pages
    my $colspan        = 0;
    my $record_counter = 1;
    my $tablefields    = get_table_fields( $table, ' ' );

    foreach my $key ( keys( %{$hash_ref} ) ) {

        # unhappily the id field used in each table is inconsistent
        my $id = get_id_name($table);

        my $display_button = "&nbsp;";
        my $delete_button  = "&nbsp;";
        my $modify_button  = "&nbsp;";

        # there's always a display button
        # display is this crudest default, the others are more tailored...
        my %display_actions = qw(om_yellowpages showyellow om_users showuser);
        my $display_action = $display_actions{$table} || 'display';

        $display_button =
          makebutton( $messages{show}, '', $display_action, $db, $table,
            $hash_ref->{$key}, $fieldsref, $token );

        # add a modify and delete button if a yellow pages record belongs to
        # the logged on user or the user is an administrator

        if (
            $$cookieref{userLevel} eq "admin"
            || (
                ( $table eq "om_yellowpages" )
                && ( $hash_ref->{$key}->{'fromuserid'} eq
                    $fieldsref->{userLogin} )
            )
          )
        {

            $allow_changes = 1;

            if ( $table ne "om_trades" ) {
                $delete_button =
                  makebutton( $messages{delete}, '', "delete", $db, $table,
                    $hash_ref->{$key}, $fieldsref, $token );

            } else {

                # if the record is a trade, then the delete operation becomes
                # 'modify the status to cancel'

                $delete_button =
                  makebutton( $messages{cancel}, '', "canceltrade", $db, $table,
                    $hash_ref->{$key}, $fieldsref, $token );

            }

            $modify_button =
              makebutton( $messages{modify}, '', "template", $db, $table,
                $hash_ref->{$key}, $fieldsref, $token );

        }

        my $buttons = <<EOT;
          <td class="pme-key-1">$display_button</td>
          <td class="pme-key-1">$modify_button</td>
          <td class="pme-key-1">$delete_button</td>
EOT

        my $row_contents =
          make_html_row_contents( $record_counter, $buttons, $tablefields,
            $hash_ref->{$key} );

        $html .= $row_contents;
        $record_counter++;

    }    # end of loop for found records

    my $col_titles;
    my $header;

    # if there are results, use multilingual table title..
    my $table_title = $messages{$table};

    if ( $count > 0 ) {

        my $fields_list = get_table_fields( $table, ' ' );
        @columns = split( /,/, $fields_list );

        # make the column heading for buttons uppercase
        unshift @columns,
          (
            "\u$messages{display}", "\u$messages{modify}", "\u$messages{delete}"
          );

        my $row;
        foreach my $entry (@columns) {
            $entry = $messages{$entry} || $entry;
            $row .= "<td class=\"pme-key-title\">\u$entry</td>"
              if ( length($entry) );
        }

        $row = "<tr class=\"smallgreytext\">$row</tr>\n";
        $col_titles .= $row;

        $col_titles = "<tr>$col_titles</tr>\n";

        $header .= <<EOT;
      <tr>
         <td class="pme-key-title" colspan="$colspan">$paging_html $messages{found} $count $messages{recordswith} "$fieldsref->{'string'}" $messages{in} $table_title</td>
     </tr>
EOT
    } else {

        $header .= <<EOT;
      <tr>
         <td class="pme-key-1" colspan="$colspan">$messages{found} $count $messages{recordswith} "$fieldsref->{string}" $messages{in} $table_title</td>
         <td class="pme-key-1"></td>
     </tr>
EOT

    }

    $html =
"<table><tbody class=\"stripy\">$header $col_titles $html</tbody></table>";
    return ( 0, '', $error, $html, "result.html", '', '', $token );
}

=head3 show_user

show user profile including balance and volume and stubs
of each advert for a given user, near equivalent of
show_yellow for users

Also probably a candidate for batch processing
html needs removing or internationalizing

=cut

sub show_user {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;

    my %report;
    my ( $html, $offset, $limit );

    my ( $error1, $user_hash_ref ) =
      get_where( $class, $db, 'om_users', '*', 'userLogin',
        $fieldsref->{'duserLogin'},
        $token, $offset, $limit );

    #reformat mobile to read more easily
    $user_hash_ref->{'userMobile'} =~ s/^(\d{2})(\d{4})(.*)/$1 $2 $3/;

    my $userhtml .= <<EOT;
   <tr><td class="wanted" colspan="3"><h2>$messages{userinfofor} $fieldsref->{duserLogin}</h2></td></tr>    
   <tr><td valign="top" class="pme-key-title">$user_hash_ref->{userName} $messages{is} \u$user_hash_ref->{userStatus}</td>
       <td valign="top" colspan="2" class="pme-key-title"><a href="mailto:$user_hash_ref->{userEmail}?subject=$db">$user_hash_ref->{userEmail}</a></td>
       <td class="pme-key-1"></td>
   </tr>

   <tr><td valign="top" class="pme-key-1">$messages{postcode}</td>
       <td valign="top" class="pme-key-1">$user_hash_ref->{userPostcode}</td>
       <td class="pme-key-1"></td>
   </tr>
   <tr><td valign="top" class="pme-key-1">$messages{telephone}</td>
       <td valign="top" class="pme-key-1">$user_hash_ref->{userTelephone} &nbsp; |&nbsp;  </td>
       <td class="pme-key-1">$user_hash_ref->{userMobile}</td>
   </tr>
      <tr><td colspan="3" ><hr/><br/></td>
    </tr>
   <tr><td valign="top" colspan="3" class="pme-key-1">bal</td>
       <td valign="top" class="pme-key-1"></td>
       <td class="pme-key-1"></td>
   </tr>

EOT

    # get the user data, joined with their yellow pages ads
    my ( $error2, $ad_hash_ref ) =
      get_user_display_data( $class, $db, $fieldsref->{'duserLogin'}, $token );

    # get balance and volume for user to show in table ;
    my ( $refresh, $metarefresh, $error1, $balv, $page, $c ) =
      show_balance_and_volume( $class, $db, $fieldsref->{'duserLogin'},
        "", $token );

    my $first_pass = 1;
    my $counter    = 0;    # used for counting what goes on left and right
    my $userimage;

    foreach my $hash_key ( keys %$ad_hash_ref ) {

        #FIXME: must be revisited, parasitic call because of fetchall_hashref!
        my ( $error3, $hash_ref1 ) =
          get_where( $class, $db, 'om_yellowpages', '*', 'id', $hash_key,
            $token, $offset, $limit );
        my $record_ref = $ad_hash_ref->{$hash_key};
        my $save_subject;

        foreach my $key ( sort keys %$record_ref ) {
            if ( $ad_hash_ref->{$hash_key}->{subject} ne $save_subject ) {

                # colour code the advert summaries by changing the display class
                # truelets is something that's paid at 100% in LETS
                #
                my $dclass = "pme-key-1";    # default case
                $dclass = "pme-key-green"
                  if ( $$hash_ref1{truelets} eq "yes"
                    && $$hash_ref1{type} eq "offered" );
                $dclass = "pme-key-1"
                  if ( $$hash_ref1{truelets} ne "yes"
                    && $$hash_ref1{type} eq "offered" );
                $dclass = "pme-key-debit" if ( $$hash_ref1{type} eq "wanted" );

                # show 'per unit' price if unit is valid
                my $per_unit = "$messages{per} $$hash_ref1{unit}"
                  if ( length( $$hash_ref1{unit} )
                    && $$hash_ref1{unit} ne 'other' );

                $html .= <<EOT;
   <tr><td class="pme-key-title">$ad_hash_ref->{$hash_key}->{subject}</td>
       <td class=""></td>
       <td class=""></td> 
       </tr>
   <tr><td colspan="2" class="pme-key-title">$ad_hash_ref->{$hash_key}->{description}</td>
       <td class="$dclass">$ad_hash_ref->{$hash_key}->{price} $ad_hash_ref->{$hash_key}->{tradeCurrency}s $per_unit</td>
       </tr>
   <tr><td colspan="3"></td>
       </tr>
   <tr><td colspan="3"></td>
       </tr>
EOT

                $save_subject = $ad_hash_ref->{$hash_key}->{subject};
            }

        }    # this record
        $first_pass = 0;
        $counter++;
    }    # all records
    $userhtml =~ s/bal/$balv/;

    $html = "<table>$userhtml<tr><td colspan=\"3\"></td></tr>$html</table>";
    return ( "", '', "", $html, "result.html", $fieldsref );
}

=head3 change_language

Change the user language for the web interface
never tested recently as of 4/2005, waiting until
html is somewhat complete and in another language...

Now in testing as of August 2011...modified to update
om_users and send only language cookie with expiry of around six months

=cut


sub change_language {
    my ($class, $db, $template_dir, $fieldsref, $cookieref, $token ) = @_;
    my $domain    = $configuration{'domain'};
    my $path      = "/";
    
    ### my $cookieref = get_cookie();
    my %cookie    ;    
    $cookie{language} = $fieldsref->{language};
    my $expires = 15552000 + time() ; # six month expiry for language cookie
    my $cookies = return_cookie_header( $expires, $domain, $path, "", %cookie );
    
    my $pages =
      new HTML::SimpleTemplate("$template_dir/$fieldsref->{language}");
       
    # update om_users for language change for this user, if someone is logged on
    if (length($db)) {   
      my %new_language = ('userId', $cookieref->{'userId'}, 'userLang', $fieldsref->{'language'}) ;
      my $x = join ('|',%new_language) ;
      $log->debug("update is $x") ;
      update_database_record( $class, $db, 'om_users', 1, \%new_language, undef, $token );
    }
    
    return ( "1", $fieldsref->{home}, "", $messages{languagechanged},
        $pages, "result.html", $fieldsref, $cookies );
}

=head3 modify_user

Modify an existing user, needs implementing to replace
raw update: update_database_record

Also needs extension so that, for example an administrator
can modify credit limit fields etc.

=cut

sub modify_user {
    my ( $class, $db, $table, $userlogin, $fieldsref, $pages, $token ) = @_;
    my ( $refresh, $error, $html );
    my @status;
    my $hash       = "";
    my $return_url = $fieldsref->{home};

    @status =
      validate_user( $class, $db, $fieldsref, $messagesref, $token, "", "" );
    if ( $status[0] == -1 ) {
        shift @status;
        $html = join( "<br/>", @status );
        return (
            "0",        $return_url, "",
            $html,      $pages,      "result.html",
            $fieldsref, "",          $token
        );
    }

    # mobile pin number is stored as hashed
    $fieldsref->{userPin} = text_to_hash( $fieldsref->{userPin} );

    my (
        $refresh,  $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
      )
      = modify_database_record2(
        'local',     $db,        'om_users', $userlogin,
        'userLogin', $fieldsref, $pages,     'users.html',
        $token
      );
    return (
        0,         $metarefresh, $error,   $html, $pages,
        $pagename, $fieldsref,   $cookies, $token
    );
}

=head3 delete_user

Delete a user, physically, all accounts need to be closed first
Not done in current version

=cut

sub delete_user {
    return;
}

=head3 make_uri_and_proxy

Make distant registry uri and proxy from a domain name given in a registry
record. If there is no explicit uri and proxy, this is what happens:

uri   : http://subdomain.domain.tld/Cclite
proxy : http://subdomain.domain.tld/cgi-bin/ccserver.cgi

If there is an explicit domain and proxy in the proxy registry record
these are overridden

=cut

sub make_uri_and_proxy {

    my ($domain) = @_;
    my $uri      = "http://$domain/Cclite";
    my $proxy    = "http://$domain/cgi-bin/ccserver.cgi";

    return ( $uri, $proxy );
}

=head3 wrapper_for_check_user_and_add_trade


this wrapper deals with some php difficulties in
passing array references remotely 2006/01

=cut

sub wrapper_for_check_user_and_add_trade {

    my ( $class, $db, $table, @transaction, $token ) = @_;
    my $transaction_ref = \@transaction;
    my @errors =
      check_user_and_add_trade( $class, $db, $table, $transaction_ref, $token );
    return @errors;
}

=head3 check_user_and_add_trade

Check user validity and add the trade

integrated for remote SOAP access, to avoid two round trips
will return if something wrong with remote user

As of 06/2007 now returns keys for literals, so that messages
can be translated into the initiating user's language with
the transaction function
=cut

sub check_user_and_add_trade {

    my ( $class, $db, $table, $transaction_ref, $token ) = @_;
    my %transaction = %$transaction_ref;
    my ( $offset, $limit, @errors );
    my ( $status, $userref ) = get_where(
        $class, $transaction{toregistry},
        "om_users", '*', "userLogin", $transaction{tradeDestination},
        $token, $offset, $limit
    );

    push @errors, "rdb1: $status" if length($status);

    # destination user doesn't exist
    if ( !length( $userref->{userLogin} ) ) {
        push @errors, 'nonexist';
    }

    # destination user does exist but inactive
    if ( $userref->{userStatus} ne "active" ) {
        push @errors, 'userinactive';
    }

    # see if the currency exists in partner

    my ( $status, $currencyref ) = get_where(
        $class, $transaction{toregistry},
        "om_currencies", '*', "name", $transaction{tradeCurrency},
        $token, $offset, $limit
    );

    push @errors, "rdb2: $status" if length($status);

    # no currency in remote registry
    if ( !length( $$currencyref{name} ) ) {
        push @errors, 'noremotecurrency';
    }

    # currency inactive in remote registry
    if ( $$currencyref{status} ne "active" ) {
        push @errors, 'currencyinactive';
    }
    my ( $adderror, $record_id );
    if ( scalar(@errors) ) {
        return @errors;
    } else {
        ( $adderror, $record_id ) =
          add_database_record( $class, $transaction{toregistry},
            'om_trades', \%transaction, $token );
    }
    push @errors, "rdb3: $adderror" if length($adderror);
    return @errors;
}

=head3 split_transaction

This is a transaction that divides into two elementary transactions,
a primary currency and a secondary currency. Used, for example, for recording items
that are partially paid in national currency.

The hash reference for the transaction is that of the 'primary' transaction part.
This will tie everything together.

Ideally this will need to be a complete atomic database transaction in
a future version.


FIXME: This is weak no error testing on the second bit, not atomic etc..
=cut

sub split_transaction {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;

# this is the primary transaction, we'd like to use this as an engine
# FIXME: terrible confusion around modes and mode field at present, to be made restful
    $transaction_ref->{'mode'} = 'engine';

    ###$log->debug("transaction ref is $transaction_ref") ;

    # comment the transaction as a split
    $transaction_ref->{'tradeTitle'} =
      "$messages{split}: $transaction_ref->{'tradeTitle'}";
    my ($t) = transaction( 'local', $db, $table, $transaction_ref, $token );

    # the transaction hash is now updated to put the secondary currency
    # into the currency and amount fields and a second transaction done

    $transaction_ref->{'tradeCurrency'} = $transaction_ref->{'stradeCurrency'};
    $transaction_ref->{'tradeAmount'}   = $transaction_ref->{'stradeAmount'};
    $transaction_ref->{'mode'}          = 'html';
    $transaction_ref->{'tradeHash'}     = $t->{'tradeHash'};

    my ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
      transaction( 'local', $db, $table, $transaction_ref, $token );

    return ( $refresh, $metarefresh, $error, $html, $pagename, $cookies );
}

=head3 directpay

Transaction from a foreign system, drupal for the moment
Provides limited html in return, dealing with a complete 'foreign'
interface rather than complete cclite templates

=cut

sub directpay {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;
    my ( $refresh, $metarefresh, $error, $html, $pagename, $cookies );

    # merchant key hash compared to calculated before doing anything
    if (
        !compare_api_key(
            $db, $transaction_ref->{'merchant_key_hash'}, $token
        )
      )
    {
        return "invalid merchant key";
    } else {
        ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
          transaction( 'local', $db, $table, $transaction_ref, $token );
    }

}

=head3 transaction

Transaction part of the motor, buyer, seller etc.
The journal part will be done in the future via the db journals


fromid - initiating userid e.g. jsb
from_regy - initiating registry e.g. nw.cov.uk
to_id - receiving id e.g. rik
to_regy - receiving registry e.g. se.cov.uk
system - domain of payment system e.g. b2b.cov.uk
amount - amount of currency tranferred e.g. 23.45
currency is probably always stored as cents and displayed as units/cents
user_date - integer seconds since 12:00:00AM 1/1/1970 GMT user record
            these are readable dates and times in Hugh's version               

system_date - integer seconds since 12:00:00AM 1/1/1970 GMT system record
            these are readable dates and times in Hugh's version

details - string to identify transaction e.g. customer a/c jkl2345987
           this probably has a description in it in Hugh's Version

mms_accept, mss_accept, mas_accept values 'Y' for yes, 'N'
            for no, 'W' for waiting. A payment clears when all 3 are 'Y' or
            is rejected if a single 'N' is recorded.

status values: W - waiting, R - rejected, C - cleared, T - timed out

Return status numbers need sorting out, more possible failure
modes need to be identified

Transaction commit to be sorted, especially some imperfect version
of remote commit: returns hash/compared to local calculation?

When this is invoked the SMS, Mail, CSV is already translated into
standard transaction format in Ccinterfaces.pm and Ccsmsgateway.pm

New since 7/2011, automagic singular for json:
tpounds = tpound
dallies = dally
to avoid most common REST misteak...

FIXME: probably need to store error and other messages as hashes
not as arrays, to ensure 'good' processing/translation from
remote systems

=cut

sub transaction {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;
    my ( $limit, $offset );    # not used here
    my $same_registry =
      0;    # if the same registry, can use a Mysql transaction...
            # if local registries can use two, but not the same effect...

    my %transaction = %$transaction_ref;

    # default separator is for html
    my $separator = "<br/>\n";

    #FIXME: json be a separate case
    $separator = ','
      if ( $transaction{mode} eq 'csv' || $transaction{mode} eq 'json' );

    # make the header like the 'others'
    my $json_header = <<EOT;
     {"registry":"$transaction{fromregistry}","table": "om_trades", "message"
EOT

    # $log->warn("mode:$$transaction_ref{mode} \n ===============" );
    # this is somewhat more rational as of 06/2007
    my @remote_status;    # messages returned from remote registry
    my @local_status;     # messages returned from local registry
        # also local messages are accumulated then returned so that
        # the user can see everything that's wrong, not just the last message

    my ( $refresh, $metarefresh, $error, $html, $pagename, $cookies );

    # multiply by 100 to put into 'pence', if decimal
    $transaction{tradeAmount} = 100 * $transaction{tradeAmount}
      if ( $configuration{usedecimals} eq 'yes' );

#----------------------------------------------------------------------------------
# validate transaction, do everything we can to make sure it's valid
# can't do a transaction with the same person as sender and receiver

    if (   ( $transaction{fromregistry} eq $transaction{toregistry} )
        && ( $transaction{tradeSource} eq $transaction{tradeDestination} ) )
    {
        push @local_status, $messages{sameaccount};
    }

    # no transaction source, can happen from rest interface
    if ( !length( $transaction{tradeSource} ) ) {
        push @local_status, $messages{nosource};
    }

    # cash must be credited to the cash account when issued
    if (   $transaction{tradeItem} eq 'cash'
        && $transaction{tradeDestination} ne 'cash' )
    {
        push @local_status, $messages{'mustgotocash'};
    }

# there's a commitment limit in the registry and this is exceeded by this
# transaction, commitment limit is global, at present, should probably be per-currency

    # now have a look at the commitmentlimit in the registry record
    my ( $status, $registry_ref ) = get_where(
        $class, $transaction{fromregistry},
        "om_registry", '*', "name", $transaction{fromregistry},
        $token, $offset, $limit
    );

    push @local_status, "db1: $status" if length($status);

    # test commitment, this can be zero for an issuance local currency
    # null means no commitlimit
    my $commitment_limit = $$registry_ref{commitlimit};
    if ( defined($commitment_limit) ) {

        # html to return html, values to return raw balances and volumes
        # for each currency
        my ( $balance_ref, $volume_ref ) = show_balance_and_volume(
            'local',
            $transaction{fromregistry},
            $transaction{tradeSource},
            'values', $token,
        );

        # current balance for this particular currency
        my $balance = $$balance_ref{ $transaction{tradeCurrency} };

# balances are negative in the sending side, need to subtract and make absolute
# if more than commitment limit transaction does not proceed
# sysaccount -can- issue value into accounts: should check for 'local' style currency
# corrected commit limit arithmetic 12/2008

        if (
            (
                (
                    ( $balance + $commitment_limit ) - $transaction{tradeAmount}
                ) < 0
            )
            && $transaction{tradeSource} ne 'sysaccount'
          )
        {

            ###$log->debug("exceeded b:$balance c:$commitment_limit  t:$transaction{tradeAmount}") ;
            push @local_status, $messages{transactionlimitexceeded};
        }
    }

    # create mirror transaction here ; this also hashes the transaction and adds
    # the original transaction hash field to both sides

    my $debit_transaction_ref;
    ( $transaction_ref, $debit_transaction_ref ) =
      create_transaction_mirror( $transaction{action}, %transaction );
    %transaction = %$transaction_ref;
    my %debit_transaction = %$debit_transaction_ref;

# do the remote side before the local side..if the remote side fails, neither are done
# the credit transaction can be in a remote registry
# need to get the trading partners description from the originating registry, not the distant one
# modified to deal with the current registry itself: most common type of transaction
# local means on the same system, same_registry is on the same system, within the same registry
# therefore can be carried within a mysql transaction

    my %registry;

    if ( $transaction{fromregistry} eq $transaction{toregistry} ) {
        $registry{type} = "local";
        $same_registry = 1;
    } else {
        my ( $status, $registry_ref ) = get_where(
            $class, $transaction{fromregistry},
            "om_partners", '*', "name", $transaction{toregistry},
            $token, $offset, $limit
        );
        %registry = %$registry_ref;
        push @local_status, "db2: $status" if length($status);
    }

    #   error code here
    my ( $soap, $error, $record_id );

    # it's a registry that lives locally on this currency server
    # therefore this is done directly and not via soap calls

    if ( $registry{type} eq "local" ) {

        # check whether remote registry is still a partner
        # not necessary if partner is the same registry
        #

        unless ( $transaction{fromregistry} eq $transaction{toregistry} ) {

            my ( $status, $partnerref ) = get_where(
                $class, $transaction{toregistry},
                "om_partners",              '*', "name",
                $transaction{fromregistry}, $token,
                $offset,                    $limit

            );
            push @local_status, "db3: $status" if length($status);
            if ( !length( $partnerref->{'name'} ) ) {
                push @local_status, $messages{noremotepartner};
            }

            # destination partner does exist but inactive
            if ( $partnerref->{'status'} ne "active" ) {
                push @local_status, $messages{remotepartnerinactive};
            }
        }

        # check facts about destination user

        my ( $status, $userref ) = get_where(
            $class, $transaction{toregistry},
            "om_users", '*', "userLogin", $transaction{tradeDestination},
            $token, $offset, $limit
        );
        push @local_status, "db4: $status" if length($status);

        # destination user doesn't exist
        if ( !length( $userref->{'userLogin'} ) ) {
            push @local_status, $messages{nonexist};
        }

        # destination user does exist but inactive
        if ( $userref->{'userStatus'} ne "active" ) {
            push @local_status, $messages{userinactive};
        }

        # see if the currency exists in partner
        # 07/2011 make singular, where necessary for REST/json
        if ( $transaction{'mode'} eq 'json' ) {
            $transaction{tradeCurrency} =~ s/ies$/y/i;    # dallies -> dally
            $transaction{tradeCurrency} =~ s/s$//i;       # tpounds -> tpound
        }

        my ( $status, $currencyref ) = get_where(
            $class, $transaction{toregistry},
            "om_currencies", '*', "name", $transaction{tradeCurrency},
            $token, $offset, $limit
        );
        push @local_status, "db5: $status" if length($status);

        # no currency in remote registry
        if ( !length( $currencyref->{'name'} ) ) {
            push @local_status, $messages{noremotecurrency};
        }

        # currency inactive in remote registry
        if ( $currencyref->{'status'} ne "active" ) {
            push @local_status, $messages{currencyinactive};
        }

        # no zero value transactions...
        if ( $transaction{tradeAmount} == 0 ) {
            push @local_status, $messages{zerovaluetransaction};
        }

      # since the remote is about to be rejected, reject the local one
      # since nothing has changed yet in the databases, return with a message...
      # processing changed 1/2009 to avoid storage of many rejected transactions

        if ( length( $local_status[0] ) ) {
            push @local_status, $messages{transactionrejected};
            $transaction{tradeStatus} = "rejected";
            my $output_message = join( $separator, @local_status );
            ###       print "here $error, $output_message $currencyref->{'name'}" ;
            # warn about rejections at this level in log
            ### $log->warn("rejected transaction: $output_message");

            if ( $transaction{'mode'} ne 'json' ) {
                return ( "1", $$transaction_ref{home}, $error, $output_message,
                    "result.html", "" );
            } else {

                # put quotes around the messages for json...
                my @local_status =
                  map { ( my $s = $_ ) =~ s/(.*)/\"$1\"/; $s } @local_status;
                my $output_message = join( $separator, @local_status );
                my $json = <<EOT;
                 $json_header: "NOK", "data": [$output_message ] }
EOT
                return $json;
            }
        }

        # add the transaction to the receiving user...
        ( $error, $record_id ) =
          add_database_record( $class, $transaction{toregistry},
            $transaction{subaction}, \%transaction, $token );
        push @local_status, "db6: $error" if length($error);

    } else {

        # transaction in remote registry, this is one integrated sub-routine
        # reduces round-trip 'costs' and avoid soap hanging problems

        if ( !length( $registry{uri} ) ) {
            ( $registry{uri}, $registry{proxy} ) =
              make_uri_and_proxy( $registry{domain} );
        }

        # check remote user and add transaction to the remote registry
        # done as an integrated call to avoid xml to-and-fro
        #
        my $soap =
          SOAP::Lite->uri( $registry{uri} )->proxy( $registry{proxy} )
          ->check_user_and_add_trade( $transaction{toregistry},
            'om_trades', \%transaction, $token );
        my $s = $soap->faultstring;
        die $soap->faultstring if $soap->fault;

        # get all the messages and pack them up
        @remote_status = $soap->paramsout;
        my $res = $soap->result;
        push @remote_status, $res;
    }

    # remote status is delivered as literal keys and database status messages
    # this translates them where possible, database messages are prepended with
    # rdbn and left as-is, soap status also untranslatable

    my @translated_remote_status;
    foreach my $status (@remote_status) {
        if ( length( $messages{$status} ) ) {
            push @translated_remote_status, $messages{$status};
        } else {
            push @translated_remote_status, $status;
        }
    }

    # the debit transaction is always saved in the local registry
    # but with rejected tradeStatus and the errors packed into the
    # tradeDescription

    if ( length( $local_status[0] ) || length( $remote_status[0] ) ) {
        $debit_transaction{tradeDescription} =
          join( "\r\n", @local_status, @translated_remote_status );
        $debit_transaction{tradeStatus} = "rejected";
    }

    ( $error, $record_id ) =
      add_database_record( $class, $transaction{fromregistry},
        $transaction{subaction}, \%debit_transaction, $token );

    # since this can fail at local database attempt, at least there 'may'
    # be a screen display of this
    push @local_status, "db7: $error" if length($error);
    if ( length( $local_status[0] ) || length( $remote_status[0] ) ) {
        push @local_status, $messages{transactionrejected};
    } elsif ( $transaction_ref->{'mode'} ne 'json' ) {
        push @local_status,
"$messages{transactionaccepted}<br/>Ref:&nbsp;$transaction{tradeHash}";
    } elsif ( $transaction_ref->{'mode'} eq 'json' ) {
        push @local_status,
"\"message\":\"$messages{transactionaccepted}\", \"reference\":\"$transaction{tradeHash}\"";
    }

    my $output_message =
      join( $separator, @local_status, @translated_remote_status );

    if (   $transaction_ref->{'mode'} ne 'engine'
        && $transaction_ref->{'mode'} ne 'json' )
    {
        return (
            "1", "$$transaction_ref{home}?action=showtransnotify_by_mail",
            $error,
            $output_message,

            "result.html", ""
        );

    } elsif ( $transaction_ref->{'mode'} eq 'json' ) {

        # $log->debug("\{$output_message\}");
        return "\{$output_message\}";
    } else {
        return $transaction_ref;
    }

}

=head3 create_transaction_mirror

Creates the 'mirror image' of a transaction to either create or
delete a double entry. This is isolated in one subroutine so that
changes in transaction structure are reflected in one place

Don't mess with the literal values like 'debit' and 'credit'
in here, they are database enums, not message literals

=cut

sub create_transaction_mirror {
    my ( $action, %transaction ) = @_;

    # prepare both sides of the transaction image
    my %debit_transaction = %transaction;

    # get date and timestamp
    my ( $date, $time ) = &Ccu::getdateandtime( time() );
    my $timestamp = "$date$time";

    #
    $transaction{tradeStamp}       = $timestamp if ( $action ne "delete" );
    $debit_transaction{tradeStamp} = $timestamp if ( $action ne "delete" );

# current date is inserted if no date suplied by transaction, batch values supply
# date, for example
    if ( !length( $transaction{tradeDate} ) ) {
        $transaction{tradeDate} = $date;
    }
    $debit_transaction{tradeDate} = $transaction{tradeDate};

    #
    $transaction{tradeType}       = "credit";
    $debit_transaction{tradeType} = "debit";

    # the initial payment status is usually waiting but can be 'accepted'
    # initial status is applied only if there's no current status
    # this deals with batch interfaces slightly better

    $transaction{tradeStatus} = $transaction{tradeStatus}
      || $transaction{initialPaymentStatus};
    $debit_transaction{tradeStatus} = $transaction{tradeStatus};

   # the mirror ties both sides of a transaction to allow distributed registries

    $debit_transaction{tradeMirror} = $transaction{toregistry};
    $transaction{tradeMirror}       = $transaction{fromregistry};

    # add tax flag to both sides
    $debit_transaction{tradeTaxflag} = $transaction{tradeTaxflag};

    # hash transaction and join to both sides of deal
    # the primary trade hash is -imposed-, if it exists, for split trades
    # in order to make a link between the two operations

    if ( !length( $transaction{tradeHash} ) ) {

        # tidied up as of 06/2007, only hashes core information
        # for transaction, not all template fields etc.
        # means that hash can be reproduced if necessary
        # next release should include token value

        my $transaction_as_text = join( "",
            $transaction{tradeStamp},       $transaction{tradeDate},
            $transaction{tradeType},        $transaction{tradeSource},
            $transaction{tradeDestination}, $transaction{tradeMirror},
            $transaction{tradeTaxflag},     $transaction{tradeAmount},
            $transaction{tradeCurrency} );

        #FIXME: Do we want URL Safe trade hashes? These are not they...
        my $hash_value = text_to_hash($transaction_as_text);
        $transaction{tradeHash}       = $hash_value;
        $debit_transaction{tradeHash} = $hash_value;
    } else {
        $debit_transaction{tradeHash} = $transaction{tradeHash};
    }

    return ( \%transaction, \%debit_transaction );
}

=head3 delete_trade

This operation should probably NOT be allowed on an established transaction
 
Needs the timestamp to identify it
Plenty of deleted transactions affect reputation
 
Local one can be deleted directly via id
Remote one needs 'get where fromuser = user and timestamp = timestamp
Left in code, just in case

Perhaps these operations should be removed? ML/MF 04/2005
06/2007 cancel status in om_trades + a new modify trade operation
this is how a trade should be cancelled

=cut

sub delete_trade {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;

    # create transaction mirror
    my ( $debit_transaction_ref, $html );

    # check whether local
    my ( %registry, $offset, $limit );
    if ( $db eq $$transaction_ref{tradeMirror} ) {
        $registry{type} = "local";
    } else {
        my ( $status, $registry_ref ) =
          get_where( $class, $db, "om_partners", '*', "name",
            $$transaction_ref{tradeMirror},
            $token, $offset, $limit );
        %registry = %$registry_ref;
    }

    # if local use direct call
    if ( $registry{type} eq 'local' ) {

        # get where fromuser = user and timestamp = timestamp
        find_and_delete_trade( $class, $$transaction_ref{tradeMirror},
            $table, $transaction_ref, $pages, $token );
    } else {

        # get where fromuser = user and timestamp = timestamp
        # else use web services call
        if ( !length( $registry{uri} ) ) {
            ( $registry{uri}, $registry{proxy} ) =
              make_uri_and_proxy( $registry{domain} );
        }

        # check remote user and add transaction to the remote registry
        # done as an integrated call to avoid xml to-and-fro
        #
        my $soap =
          SOAP::Lite->uri( $registry{uri} )->proxy( $registry{proxy} )
          ->find_and_delete_trade( $$transaction_ref{tradeMirror},
            'om_trades', $transaction_ref, $token );

        die $soap->faultstring if $soap->fault;

        # get all the messages and pack them up
        my @status = $soap->paramsout;
        my $res    = $soap->result;
        push @status, $res;
    }

    # delete local side record
    my ( $refresh, $metarefresh, $error, $h, $pagename, $cookies ) =
      delete_database_record( $class, $db, 'om_trades', $transaction_ref,
        $token );
    return ( 0, $$transaction_ref{home}, "", $html, "result.html", "" );
}

=head3 find_and_delete_trade

This is a delete for the destination trade via timestamp 
and user

get via get_where and delete via delete_database_record
these are packed together to increase web services efficiency
This is a remote trade that cannot be identified via an id
 
Need check here that multiple trades aren't returned for mirror
in which case the whole thing should stop

Perhaps these operations should be removed? ML/MF 04/2005

=cut

sub find_and_delete_trade {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;
    my ( $offset, $limit, $order );
    my $sqlstring =
"tradeStamp = \'$$transaction_ref{tradeStamp}\' and tradeDestination = \'$$transaction_ref{tradeDestination}\'";

    # sqlfind timestamp and corresponding record
    my ( $error, $hash_ref ) = sqlfind( $class, $$transaction_ref{tradeMirror},
        'om_trades', $transaction_ref, '*', $sqlstring, $order, $token, $offset,
        $limit );

#FIXME: put the id into a record hash for delete, if there's more than one returned should die!

    my @keys = keys %$hash_ref;

    # hash is just field name and record id for delete
    my %fields = ( "tradeId", "$hash_ref->{$keys[0]}->{'tradeId'}" )
      ;    # just the id in this hash
    my $fieldsref = \%fields;

    # delete
    my ( $refresh, $metarefresh, $error, $html, $pagename, $cookies ) =
      delete_database_record( $class, $db, 'om_trades', $fieldsref, $token );

    return ( $refresh, $metarefresh, $error, $html, $pagename, $cookies );

}

=head3 modify_trade

These are modification operations allowed on an established transaction
to change the trade state only. Needs filtering to only
allow changes to: tradeStatus

Needs the timestamp to identify it
Plenty of declined and cancelled transactions should affect reputation
Local one can be modified directly via id
Remote one needs 'get where fromuser = user and timestamp = timestamp

This is probably a more reasonable way of doing delete

=cut

sub modify_trade {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;
    my ( $debit_transaction_ref, $html, $pagename );

    # filter anything that doesn't belong to tradeStatus, tradeDestination,
    # tradeSource,tradeMirror, tradeId

    # change status for confirm
    $$transaction_ref{tradeStatus} = "accepted"
      if ( $$transaction_ref{action} eq "confirmtrade" );

    # change status for confirm
    $$transaction_ref{tradeStatus} = "declined"
      if ( $$transaction_ref{action} eq "declinetrade" );

    # change status for delete, does not delete record, only changes
    # status to cancelled 06/2007
    $$transaction_ref{tradeStatus} = "cancelled"
      if ( $$transaction_ref{action} eq "canceltrade" );

    # if it's not any of these then the status is unchanged...

    # filter fields that shouldn't be modified, include home needs this!
    foreach my $key ( keys %$transaction_ref ) {
        if ( $key !~
/tradeStamp|tradeStatus|tradeCurrency|tradeDestination|tradeSource|tradeMirror|tradeId|tradeDestination|home/
          )
        {
            delete $$transaction_ref{$key};
        }
    }

    # check whether local
    my ( %registry, $offset, $limit );
    if ( $db eq $$transaction_ref{tradeMirror} ) {
        $registry{type} = "local";
    } else {
        my ( $status, $registry_ref ) =
          get_where( $class, $db, "om_partners", '*', "name",
            $$transaction_ref{tradeMirror},
            $token, $offset, $limit );
        %registry = %$registry_ref;
    }

    # if local use direct call
    if ( $registry{type} eq 'local' ) {

        # get where fromuser = user and timestamp = timestamp
        find_and_modify_trade( 'local', $$transaction_ref{tradeMirror},
            $table, $transaction_ref, $pages, $token );
    } else {

        # get where fromuser = user and timestamp = timestamp
        # else use web services call
        if ( !length( $registry{uri} ) ) {
            ( $registry{uri}, $registry{proxy} ) =
              make_uri_and_proxy( $registry{domain} );
        }

        # check remote user and add transaction to the remote registry
        # done as an integrated call to avoid xml to-and-fro
        #
        my $soap =
          SOAP::Lite->uri( $registry{uri} )->proxy( $registry{proxy} )
          ->find_and_modify_trade( $$transaction_ref{tradeMirror},
            'om_trades', $transaction_ref, $token );

        die $soap->faultstring if $soap->fault;

        # get all the messages and pack them up
        my @status = $soap->paramsout;
        my $res    = $soap->result;
        push @status, $res;
    }

    # update local side trade
    update_database_record( $class, $db, $table, 1, $transaction_ref, undef,
        $token );
    $html = "$messages{transactionstatusnow} $$transaction_ref{tradeStatus}";

    # return to transaction list
    return ( 1, "$$transaction_ref{home}?action=showtrans",
        "", $html, "result.html", "" );
}

=head3 find_and_modify_trade

This is a modification for the destination trade via timestamp 
and user

get via get_where and delete via delete_database_record
these are packed together to increase web services efficiency
This is a remote trade that cannot be identified via an id
 
Need check here that multiple trades aren't returned for mirror
in which case the whole thing should stop

This should probably be based on id via the hash in the future

=cut

sub find_and_modify_trade {

    my ( $class, $db, $table, $transaction_ref, $pages, $token ) = @_;
    my ( $offset, $limit, $order, $pagename );
    my $sqlstring = <<EOT;
tradeStamp = '$$transaction_ref{tradeStamp}' and
tradeCurrency = '$$transaction_ref{tradeCurrency}' and
tradeSource = '$$transaction_ref{tradeSource}' and
tradeId <> '$$transaction_ref{tradeId}'
EOT

    # sqlfind timestamp and corresponding record
    my ( $error, $hash_ref ) = sqlfind( $class, $$transaction_ref{tradeMirror},
        'om_trades', $transaction_ref, '*', $sqlstring, $order, $token, $offset,
        $limit );

    my @keys = keys %$hash_ref;

    # hash is just id field and status for modify at present
    # only operation allowed is to modify status value of transactions
    my %fields;
    my %fields = (
        'tradeId',     $hash_ref->{ $keys[0] }->{'tradeId'},
        'tradeStatus', "$$transaction_ref{tradeStatus}"
    );    # just the id  and trade status in this hash
    my $fieldsref = \%fields;

    # modify the trade status
    update_database_record( $class, $db, $table, 1, $fieldsref, undef, $token );
    return;
}

=head3 get_many_items

This get_many_items is mainly used for getting transactions at present
But it should become a general purpose lister, for ads,
users, SICs etc

FIXME: Items delivered as hashes, since SOAP is being phased out as of 5/2010
At present mode = html to produce an html type listing

12/2005: This is becoming a bit of a disgrace although it runs pretty well
07/2007: More disgraceful, new code anyone?
xx/2008: get_trades added to start to unscramble...

=cut

sub get_many_items {

    my (
        $class, $db,   $table, $fieldsref, $fieldname,
        $name,  $mode, $token, $offset,    $limit
    ) = @_;
    my (
        $allow_changes, $colspan, $entry, $status, $option_string,
        $error,         $row,     $html,  $home
    );
    my $total_count;

    # for the present deliver all trade types
    my $trade_type = "all";

    # count total in set, as opposed to number delivered by limit
    # note that this is overwritten by get_trades, if finding trades

    if (   $table ne "om_partners"
        && $table ne "om_currencies"
        && $table ne "om_trades" )
    {
        $total_count =
          sqlcount( $class, $db, $table, "", $fieldname, $name, $token );
    } elsif ( $table ne "om_trades" ) {
        $total_count = sqlcount( $class, $db, $table, "1", '', '', $token );
    }
    ;    # count them all
         # get the records
    my ( $registry_error, $hash_ref );
    if ( $table eq "om_trades" ) {
        ( $registry_error, $total_count, $hash_ref ) =
          get_trades( 'local', $db, $fieldsref->{userLogin},
            $trade_type, $token, $offset, $limit );

    } else {
        ( $registry_error, $hash_ref ) = get_where_multiple(
            $class, $db,    $table,  ' ', $fieldname,
            $name,  $token, $offset, $limit
        );
        $total_count = scalar( keys %$hash_ref );   # count the records returned
    }

    my $x              = 1;
    my $record_counter = 1;

    my $tablefields = get_table_fields( $table, ' ' );

    # unhappily the id field used in each table is inconsistent
    my $id = get_id_name($table);

# only refresh is [mis]used to carry json payload if json is being returned 2/2011
    if ( $fieldsref->{'mode'} eq 'json' ) {
        my ($json) =
          deliver_remote_data( $db, $table, $registry_error, $hash_ref,
            $token );
        return $json;
    }

    foreach my $key ( sort { $b <=> $a } keys( %{$hash_ref} ) ) {

        my $modify_button  = "&nbsp;";
        my $delete_button  = "&nbsp;";
        my $display_button = "&nbsp;";
        my $confirm_button = "&nbsp;";
        my $decline_button = "&nbsp;";

        # there's always a display button
        # display is this crudest default, the others are more tailored...
        my %display_actions = qw(om_yellowpages showyellow om_users showuser);
        my $display_action = $display_actions{$table} || 'display';

        $display_button =
          makebutton( $messages{show}, '', $display_action, $db, $table,
            $hash_ref->{$key}, $fieldsref, $token );

#FIXME: this is a weak piece of code, in that , if the script is the admin script
# there'll always be modify and delete, scope of button display needs to
# shouldn't really delete currencies or users, for example,
# current restriction is not to delete trades
# cut down 05/2007

        if (
            (
                (
                    ( $table eq "om_yellowpages" )
                    && ( $hash_ref->{$key}->{'fromuserid'} eq
                        $fieldsref->{userLogin} )
                )
                || ( ( $table ne "om_trades" ) && is_admin() )
                || ( ( $table eq "om_openid" ) )
                || ( ( $table eq "om_categories" ) )

            )
          )
        {

            my $class;
            $allow_changes = 1;

            # if the record is a trade, then the delete operation becomes
            # 'modify the status to cancel'

            if ( $table ne "om_trades" ) {
                $delete_button =
                  makebutton( $messages{delete}, '', "delete", $db, $table,
                    $hash_ref->{$key}, $fieldsref, $token );

            } else {

                # if the record is a trade, then the delete operation becomes
                # 'modify the status to cancel'

                $fieldsref->{tradeStatus} = "cancelled";
                $delete_button =
                  makebutton( $messages{modify}, '', "template", $db, $table,
                    $hash_ref->{$key}, $fieldsref, $token );

            }

            $modify_button =
              makebutton( $messages{modify}, '', "template", $db, $table,
                $hash_ref->{$key}, $fieldsref, $token );

        }    # end of buttons

        # delete button for trades is removed now
        # decline button implemented 12/2005

        if (   $table eq 'om_trades'
            && $hash_ref->{$key}->{'tradeType'}   eq 'credit'
            && $hash_ref->{$key}->{'tradeStatus'} eq "waiting" )
        {
            $confirm_button =
              makebutton( $messages{ok}, '', "confirmtrade", $db, $table,
                $hash_ref->{$key}, $fieldsref, $token );

            $decline_button =
              makebutton( $messages{reject}, '', "declinetrade", $db, $table,
                $hash_ref->{$key}, $fieldsref, $token );
        }    # end of trades buttons

        #FIXME: this is a weakness and should be coded out 05/2007

        $modify_button =
          makebutton( $messages{modify}, '', "template", $db, $table,
            $hash_ref->{$key}, $fieldsref, $token )
          if ( $table eq 'om_currencies' );

        # experimental: show decimal places for trades
        if ( $configuration{usedecimals} eq 'yes' && $table eq 'om_trades' ) {
            $hash_ref->{$key}->{'tradeAmount'} = sprintf "%.2f",
              ( $hash_ref->{$key}->{'tradeAmount'} / 100 );
        }

 # trades have somehwat different buttons to the others
 # everything now has three, but passthrough Drupal or Elgg display doesn't have
 # any buttons currently

        my $buttons;

        if ( $fieldsref->{mode} ne 'csv' ) {
            if ( $table eq "om_trades" ) {
                $buttons = <<EOT;
          <td class="pme-key-1">$display_button</td>
          <td class="pme-key-1">$confirm_button</td>
          <td class="pme-key-1">$decline_button</td>
EOT

            } else {
                $buttons = <<EOT;
          <td class="pme-key-1">$display_button</td>
          <td class="pme-key-1">$modify_button</td>
          <td class="pme-key-1">$delete_button</td>
EOT
            }    # end of unshift for buttons
        }

        my $row_contents =
          make_html_row_contents( $record_counter, $buttons, $tablefields,
            $hash_ref->{$key} );
        $html .= $row_contents;

        # colspan is the row size
        $colspan = scalar( keys %{ $hash_ref->{$key} } );
        $record_counter++;

    }    # end of loop for records

    my $template = "result.html"
      if ( !length( $fieldsref->{resulttemplate} ) );

    # only do all the formatting, if there are some results returned
    my $col_titles;

    # create paging info for top of display
    my $paging_html = make_page_links( $total_count, $offset, $limit );

    # if there are results, use multilingual table title..
    my $table_title = $messages{$table};

    my $table_title = $messages{$table};
    my $thisspan    = $colspan + 1;
    my $header;

    # if there's more than one page and not csv show paging
    if ( length($paging_html) && $fieldsref->{mode} ne 'csv' ) {
        $header .= <<EOT;
   <tr>
         <td class="pme-key-title" colspan="$thisspan">$messages{pages} $paging_html</td>
   </tr>
EOT

    }

    if ( $total_count > 0 ) {

        my @columns = split( /,/, $tablefields );

        # edit the column headings
        # buttons are not the same for trades, can't modify or delete
        # can accept or decline waiting trades. No buttons and no button
        # titles for passthrough to Drupal or Elgg

        if ( $table ne "om_trades" ) {
            unshift @columns,
              ( $messages{display}, $messages{modify}, $messages{delete} );
        } elsif ( $fieldsref->{mode} ne 'csv' ) {
            unshift @columns,
              ( $messages{display}, $messages{ok}, $messages{no} );
        }    # end of unshift column titles

        my $row;
        foreach my $entry (@columns) {
            $entry = $messages{$entry} || $entry;
            $row .= "<td class=\"pme-key-title\">\u$entry</td>"
              if ( length($entry) );
        }    # end of make column titles

        $col_titles .= "<tr>$row</tr>\n";

        my $type_literal;
        $table eq 'om_trades'
          ? ( $type_literal = $messages{$trade_type} )
          : ( $type_literal = '' );

        $header .= <<EOT;
      <tr>
         <td class="pme-key-1" colspan="$colspan">$messages{'found'} $total_count $type_literal $messages{'in'} $table_title</td>
     </tr>
EOT

    }

    $html =
"<table><tbody class=\"stripy\">$header $col_titles $html</tbody></table>";
    return ( 0, "", $error, $html, $template, "" );
}

=head3 get_trades

coded 07/2007

Delivers count of trades and an hash reference
for the retrieved trades.

For admin level users all trades are delivered,
for user level only trades that have tradeDestination 
or tradeSource = user are delivered

This is the first step in descrambling get_many_items

This is the complete enum of statuses:
enum('waiting', 'rejected', 'timedout', 'accepted', 'cleared', 'declined', 'cancelled')

type can be all 		= all transactions
            active 		= waiting and accepted
            accepted 		= accepted (this is the value for arithmetic)
            not_accepted 	= declined and cancelled
            error 		= rejected and timedout

=cut

sub get_trades {

    my ( $class, $db, $user, $type, $token, $offset, $limit ) = @_;
    my $sqlstring;

    # first select base set, only records for user, if not admin
    # debits and opening balances are user sourced, credits are remote sourced
    if ( !is_admin() ) {
        $sqlstring = <<EOT;
((tradeSource = '$user' and (tradeType = 'debit' or tradeType = 'open'))
 or
 (tradeDestination = '$user' and  tradeType = 'credit')
)
EOT

        # then refine for various status types and append to sql statement
        if ( $type eq "active" ) {
            $sqlstring .= <<EOT;
and (tradeStatus = 'waiting' or tradeStatus = 'accepted')
EOT

        } elsif ( $type eq "accepted" ) {
            $sqlstring .= <<EOT;
and (tradeStatus = 'accepted')
EOT

        } elsif ( $type eq "not_accepted" ) {
            $sqlstring .= <<EOT;
and (tradeStatus = 'declined' or tradeStatus = 'cancelled')
EOT

        } elsif ( $type eq "error" ) {
            $sqlstring .= <<EOT;
and (tradeStatus = 'rejected' or tradeStatus = 'timedout')
EOT

        }

    } elsif ( is_admin() && $type eq "all" ) {
        $sqlstring = 1;
    } else {

        # error condition needed here
    }

    my $sqlcount = <<EOT;
$sqlstring 
EOT

    # count the whole set
    my $count = sqlcount( $class, $db, 'om_trades', $sqlcount, '', '', $token );

# sqlfind either records belonging to this account, or all, if an admin is asking

    my ( $error, $trade_hash_ref ) = sqlfind(
        $class,  $db,        'om_trades',    '',
        ' ',     $sqlstring, 'tradeId desc', $token,
        $offset, $limit
    );

    return $error, $count, $trade_hash_ref;

}

=head3 collect_items


FIXME: This has become a problem in that it is invoked, when there's not a
valid user or registry, because it is implicated in display_template..

This is exanded to collect currencies, languages, yellowpage categories
This is a possible flaw, all the currencies have to be collected from the
home registry

Read this registry collect complete list of currencies. 
Check later in transaction for allowed currency combinations. 
This needs to be moved further to the top later

Only select mode works at present Needs to be generalised so that it 
only collects active items via 'status'. 
This is hacked in for yellow page categories, at present.

Amended not to display closed or suspended currencies in 12/2005
Amended in 2010 to use hashes, as with all the other listing functions

=cut

sub collect_items {
    my (
        $class, $db,    $table,  $fieldsref, $field_name,
        $mode,  $token, $offset, $limit
    ) = @_;

    return '' if ( !length($db) );

    # unhappily the id field used in each table is inconsistent
    my $id = get_id_name($table);

    my ( $rc, $record_id, $entry, $option_string, %duplicates );
    my ( $registry_error, $hash_ref );

    # hacked in special sql for categories, keep them in order in the drop down
    # 11/7/2011 9999 category number is for folksonomy tags only....
    if ( $table eq 'om_categories' ) {
        my $sqlstring =
"SELECT * FROM `om_categories` WHERE category != '9999' order by parent,description";
        ( $registry_error, $hash_ref ) =
          sqlraw( $class, $db, $sqlstring, $id, $token );
    } else {
        ( $registry_error, $hash_ref ) =
          get_where_multiple( $class, $db, $table, '*', $id, '*', $token,
            $offset, $limit );
    }

    my $first_pass = 1;
    my $save;

    foreach my $key ( keys( %{$hash_ref} ) ) {

        # only take active items from categories table
        next
          if ( $table eq 'om_categories'
            && $hash_ref->{$key}->{'status'} eq 'inactive'
            && $field_name ne 'parent' );

   # don't display currencies that are declared as closed or suspended/predelete
        next
          if (
            $table eq 'om_currencies'
            && (   $hash_ref->{$key}->{'membership'} eq 'closed'
                || $hash_ref->{$key}->{'status'} eq 'suspended'
                || $hash_ref->{$key}->{'status'} eq 'predelete' )
          );

        #item is hold over from the array code previously...
        my $item = $hash_ref->{$key}->{$field_name};

        my $x = 1;
        my $name;
        my $checked;

        # if it's not already defined and not a current subdirectory
        if ( !defined $duplicates{$item} && $item !~ /\056/ ) {
            if ( $mode eq "select" ) {
                if ( $table eq 'om_categories' ) {
                    if ( $field_name ne 'parent' ) {
                        my ( $error, $hashref ) = get_where(
                            $class,          $db,
                            'om_categories', '*',
                            'category',      $hash_ref->{$key}->{'parent'},
                            $token,          $offset,
                            $limit
                        );

# put the code into the value with the literal: group the categories with optgroup
                        $option_string .=
                          "<optgroup label=\"$$hashref{description}\">"
                          if ( $first_pass
                            || $save ne $hash_ref->{$key}->{'parent'} );
                        $option_string .=
"<option value=\"$hash_ref->{$key}->{'category'}, $hash_ref->{$key}->{'parent'},$item\">\u$item</option>\n";
                        $option_string = "</optgroup>$option_string"
                          if ( $first_pass
                            || $save ne $hash_ref->{$key}->{'parent'} );
                        $save       = $hash_ref->{$key}->{'parent'};
                        $first_pass = 0;
                    } else {
                        my ( $error, $hashref1 ) = get_where(
                            $class,          $db,
                            'om_categories', '*',
                            'category',      $hash_ref->{$key}->{'parent'},
                            $token,          $offset,
                            $limit
                        );
                        $option_string .=
"<option value=\"$hash_ref->{$key}->{'parent'}\">\u$$hashref1{description}</option>\n";
                    }
                } else {
                    $option_string .=
                      "<option value=\"$item\">\u$item</option>\n";
                }
            } elsif ( $mode eq "checkbox" ) {
                $name = "$item$x";
                $checked = "checked" if ( defined $fieldsref->{$name} );
                $option_string .=
"<input type=\"checkbox\" name=\"$name\" $checked value=\"$item\">\u$item &nbsp;";
                undef $checked;
                $x++;
            }
            $duplicates{$item} = "y";
        }
    }
    return $option_string;
}

=head3 notify_by_mail

Give activation URL for new account or new password for account via email. This will only normally work
on Linux based systems. Note that the forged header needs to be changed
and may be a current problem

Modify the display name elegantly to tell them which registry

notification type is  1 for new users
                      2 for forgotten password
		      3 general mailing
		      4 sms gateway messages

smtp is a mail server in addition to localhost

=cut

sub notify_by_mail {

    #
    my (
        $class,       $registry,         $name,
        $email,       $systemfrom,       $return_address,
        $accountname, $smtp,             $urlstring,
        $text,        $notificationtype, $hash
    ) = @_;

    ###$email = quotemeta($email) ;

    # new style configuration read

    my ( $message, $from, $subject );

    if ( $notificationtype == 1 ) {

        $from    = "cclite new account at $registry <$return_address>";
        $subject = "$messages{pleaseactivate}\r\n\r\n";
        $message = <<EOT;
$messages{hi} $name, 
$messages{pleasenote}

$urlstring

$messages{usernameis} $accountname $messages{suppliedwhen}
.

EOT

    }

    # forgotten password

    elsif ( $notificationtype == 2 ) {

        $from    = "cclite $messages{newpassword1}<$return_address>";
        $subject = "$messages{newpassword}\r\n\r\n";
        $message = <<EOT;
$messages{hi} $name, 

$urlstring

$messages{usernameis} $accountname 
.


EOT

        # type 3 is general letters to everyone within a registry
        # not implemented at present

    } elsif ( $notificationtype == 3 ) {

        $from    = "member mailing <$return_address>";
        $subject = "$messages{generalmailing}\r\n\r\n";
        $message = <<EOT;
$messages{hi} $name, 

$text

$messages{usernameis} $accountname 
.


EOT

    }

    # type 4 is for sms confirmations and other sms
    # operations, this is a bit of a mess now...
    elsif ( $notificationtype == 4 ) {

        $from    = "$messages{'smstransactionemailtitle'} <$return_address>";
        $subject = "$messages{'smstransactiontitle'}\r\n\r\n";
        $message = <<EOT;
$messages{hi} $name, 

$text
$messages{usernameis} $accountname 

EOT

    } elsif ( $notificationtype == 5 ) {

 # type 5 is for new style mail confirmations and other mail transaction related
 # operations, this is more of a mess now...

        $from    = "$registry $messages{'mailtransactions'} <$return_address>";
        $subject = "$registry $messages{mailtransactionresult} \r\n\r\n";
        $message = <<EOT;
$messages{hi} $name, 

$text
$messages{usernameis} $accountname 

EOT

    }

    if ( $configuration{net_smtp} ) {
        eval {

            # new style use configuration from Ccconfiguration.pm 11/2009

# read the current registry to pick up per-registry email values
#FIXME: notify and above need to pass the token in, currently blank for this call
            my ( $offset, $limit, $token );

            my ( $error, $registryref ) = get_where(
                $class, $registry, 'om_registry', '*',
                'id',   1,         $offset,       $limit,
                $token
            );
            my $return_address = $registryref->{admemail};
            my $password       = $registryref->{admpass};
            my $host           = $return_address;

            # get the domain part as postbox...
            $host =~ s/^(.*?)\@(.*)$/$2/;

            # set Debug to 1 here, for debugging batch style mail processes...

            my $smtp = Net::SMTP->new(
                $host,
                ###             Timeout => 30,
                Debug => 1,
            ) or die "feedback: net::smtp failed to create object ($!; $@)\n";

            $smtp->auth( "$return_address", $password );

            # from address, the logged in address with override
            $smtp->mail($return_address);

            # to address, need the quotes otherwise Exim, at least, hates it...
            $smtp->to("$email");

            # maildata
            $smtp->data();
            $smtp->datasend("To: $email\n");

            #FIXME: possibly this should be no-reply style address...
            $smtp->datasend("From: $return_address\n");
            $smtp->datasend("Subject: $subject\n");
            $smtp->datasend("\n");
            $smtp->datasend("$message\n");
            $smtp->dataend();
            $smtp->quit;

        };    # end of Net::SMTP eval

    } else {

        eval {

            my %mail = (
                To      => $email,
                From    => $from,
                Subject => $subject,
                Message => $message,
            );

            # older non-preferred way of doing mail
            # cite an additional mailserver if necessary, localhost is default
            my %mailcfg;
            $mailcfg{'smtp'} = [qw(localhost $smtp)] if ( length($smtp) );

            eval { require "Mail::Sendmail qw(sendmail %mailcfg)" };
            sendmail(%mail) or die $Mail::Sendmail::error;

        };

    }

    if ($@) {
        ###  $log->error("mail error is: $@ $message");
    }

    return $@;
}

=head3 forgotten_password

Create and send a password to a person that forgot it
Checks that the email address is in the db and corresponds to an
active user. Generates a new password, sends it, dispays a result
and returns

=cut

sub forgotten_password {

    my ( $class, $db, $table, $fieldsref, $offset, $limit, $token ) = @_;
    my ( $refresh, $error, $html, %cookie, $cookieheader );

    # get the user record from the database, depending on login type
    my ( $status, $userref );
    ( $status, $userref ) = get_where(
        $class,      $fieldsref->{registry},
        "om_users",  '*',
        "userEmail", $fieldsref->{userEmail},
        $token,      $offset,
        $limit
    );

    # no user found for this email
    # FIXME: Fixed bug in return signature, add tests into test suite...
    if ( !length( $userref->{userId} ) ) {
        $html =
"email not found $fieldsref->{userEmail} at $fieldsref->{registry}: $status";
        return ( "1", $fieldsref->{home}, $error, $html, "result.html",
            $cookieheader );
    } elsif ( $userref->{userStatus} ne 'active' ) {
        $html = "user $fieldsref->{userLogin} at $db is not active";
        return ( "1", $fieldsref->{home}, $error, $html, "result.html",
            $cookieheader );
    } else {
        my $password = random_password();    # get a random password

        $userref->{userPassword} =
          $password;                         # don't hash it done at update time

#FIXME: mild kludge to make om_user specific update processing work in Cclitedb/Ccvalidate
        $userref->{action}  = 'update';
        $userref->{userPin} = '';

        my $passwordstring = <<EOT;
 $messages{heresyourpassword} $fieldsref->{registry}, $messages{pleasechangeit}\n\n
  $password
EOT

        my ( $a, $b, $c, $d ) =
          update_database_record( 'local', $fieldsref->{registry},
            "om_users", 2, $userref, $userref->{language}, $token );

        # ....and mail it

        my $mail_return = notify_by_mail(
            $class,
            $db,
            $userref->{userName},
            $userref->{userEmail},
            $fieldsref->{systemMailAddress},
            $fieldsref->{systemMailReplyAddress},
            $userref->{userLogin},
            $fieldsref->{smtp},
            $passwordstring,
            undef,
            2,
            ""
        );

        $html = $messages{passwordsent};
        ###return;
        return ( 1, $fieldsref->{home}, $error, $html, "result.html",
            $cookieheader );
    }
}

=head3 show_balance_and_volume1

Create and display balances. For a given user calculate volume of trade activity
and current balance for each currency for which they participate
 
Necessary anyway for user, also for transaction fees and demurrage, perhaps
Same signature as get many items

This is the old version, will be removed in the next iteration 5/2010



sub show_balance_and_volume1 {
    my (
        $class, $db,   $table, $fieldsref, $fieldname,
        $name,  $mode, $token, $offset,    $limit
    ) = @_;
    

    # find all transactions for a given name
    my ( $error, $html );
    my $type = "active";

    # add up everything if user login
    $type = "all" if ( is_admin() );

    # hack for large limit clause...
    my ( $registry_error, $total_count, $hash_ref ) =
      get_trades( 'local', $db, $fieldsref->{userLogin}, $type, $token, 0,
        99999999 );

    my %balances;    #  hash of balances keyed on currency
    my %volumes;     #  hash of volumes keyed on currency
                     # phase one: accumulate

    my $id = get_id_name($table) ;
    
    
    foreach my $key ( keys (%{$hash_ref}) ) {
      
        my $month = substr( $hash_ref->{$key}->{'tradeDate'}, 5, 2 );   # month 
        my $year  = substr( $hash_ref->{$key}->{'tradeDate'}, 0, 4 );   # year
        
        # now just adds everything in line with LETS received wisdom about volumes
        # but the total balance for each currency is preserved, declined and cancelled are not counted
        # don't count declined, cancelled or error trades in totals

        if ( $hash_ref->{$key}->{'tradeType'} eq 'credit' ) {
            $balances{ $hash_ref->{$key}->{'tradeCurrency'} } += $hash_ref->{$key}->{'tradeAmount'}; # add to the currency accumulator
        } elsif ( $hash_ref->{$key}->{'tradeType'} eq 'debit' ) {
            $balances{ $hash_ref->{$key}->{'tradeDate'} } -=
              $hash_ref->{$key}->{'tradeAmount'};    # subtract from the currency accumulator
        } elsif ( $hash_ref->{$key}->{'tradeType'} eq 'balance' ) {
            $balances{ $hash_ref->{$key}->{'tradeDate'} } +=
              $hash_ref->{$key}->{'tradeAmount'};    # add to the currency accumulator: signed
        }

# cumulate month also, add only, to give 'volume': abs is used because balances are signed
        $balances{"$year-$month-$hash_ref->{$key}->{'tradeCurrency'}"} += abs( $hash_ref->{$key}->{'tradeAmount'} );
        $volumes{ $hash_ref->{$key}->{'tradeCurrency'} }++;
    }

    # phase two accumulate trading history by month and report it
    # these aren't really -all- currencies, they're various hash keys
    # reverse sort, most recent entries first 2005 before 2004 etc.

    # maxreport can be passed in to give a 'little' sidebar display
    my $maxreport = $fieldsref->{maxreport} || 6;

    my %counts;    # count history for each currency

    foreach my $currency ( reverse sort keys %balances ) {
        next if ( $currency !~ /^\d/ );    # not a month balance record, anyway
        $currency =~ /(\d{4})-(\d{2})-(.*)/;  # parse 2005-04-ducket for example
             # count and report only most recent maxreport months reported
        if ( $counts{$3} < $maxreport ) {
            $balances{"history-$3"} .=
              "$balances{$currency} $messages{in} $2/$1 &nbsp;&nbsp;";
            $counts{$3}++;
        }
        delete $balances{$currency};
    }

    # phase three: report
    my $record_counter;
    foreach my $currency ( sort keys %balances ) {
        $currency =~ s/history\-// && next;
        my $line = join(
            "</td><td class=\"pme-key-1\">",
            "\u$currency",       $balances{$currency},
            $volumes{$currency}, $balances{"history-$currency"}
        );

# kludge for debits, only substitute first class because that's the -balance- report
# volumes are, by their nature, unsigned, just add up everything...
# make stripey styles
        my $row_style;
        if ( $record_counter % 2 ) {
            $row_style = "odd";
        } else {
            $row_style = "even";
        }

        $line =~ s/key-1/key-debit/ if ( $balances{$currency} < 0 );
        $html .=
"<tr class=\"$row_style\"><td class=\"pme-key-title\">$line</td></tr>";
        $record_counter++;
    }
    my $title .= <<EOT;

<tr><td class=\"pme-key-title\">$messages{currency}</td>
<td class=\"pme-key-title\">$messages{balance}</td>
<td class=\"pme-key-title\">$messages{trades}</td>
<td class=\"pme-key-title\">$messages{tradevolumes}</td></tr>
EOT

    $html = "<table><tbody class=\"stripy\">$title$html</tbody></table>";

    # default behaviour is to return html
    if ( $mode eq 'html' || !length($mode) ) {
        my $template = "result.html"
          if ( !length( $fieldsref->{resulttemplate} ) );
        return ( 0, '', $error, $html, $template, '' );
    } elsif ( $mode eq 'values' ) {
        return ( \%balances, \%volumes );
    }

}

=cut

=head3 show_balance_and_volume

New version, more heavy lifting done in sql, sql moved to Cclitedb
Some html remains for the moment...

=cut

sub show_balance_and_volume {

    my ( $class, $db, $user, $mode, $token ) = @_;

    #FIXME how many previous months to display, configurable later
    my $months_back = 4;

    my %month_hash;    # contains lines by month only the last x are printed
    my ( $month_titles, $row_style );
    my $month_counter = 0;
    my %total_balance;        # by currency
    my %total_count;          # by currency
    my %total_volume;         # absolute value cumulated trades
    my %total_volume_html;    # absolute value cumulated trades

    my ( $registry_error, $volume_hash_ref, $balance_hash_ref ) =
      get_transaction_totals( $class, $db, $user, $months_back, $token );

    foreach my $key ( keys %$balance_hash_ref ) {

        #FIXME: does this work properly?
        $balance_hash_ref->{$key}->{'sum'} = sprintf "%.2f",
          ( $balance_hash_ref->{$key}->{'sum'} / 100 )
          if ( $configuration{usedecimals} eq 'yes' );

        $total_balance{ $balance_hash_ref->{$key}->{'currency'} } +=
          $balance_hash_ref->{$key}->{'sum'};

        ###$log->debug("currency: $key = $balance_hash_ref->{$key}->{'currency'} ") ;
        ###$log->debug("sum: $key = $balance_hash_ref->{$key}->{'sum'} ") ;
        ###$log->debug("total: $balance_hash_ref->{$key}->{'currency'}  = $total_balance{ $balance_hash_ref->{$key}->{'currency'} } ") ;

        if ( ( $mode eq 'html' || !length($mode) )
            && $month_counter <= $months_back )
        {
        }
    }

    foreach my $key ( sort { $b cmp $a } keys %$volume_hash_ref ) {
        if ( ( $mode eq 'html' || !length($mode) )
            && $month_counter <= $months_back )
        {
            ( $month_counter % 2 )
              ? ( $row_style = "odd" )
              : ( $row_style = "even" );
            $total_volume_html{ $volume_hash_ref->{$key}->{'currency'} } .=
              <<EOT;
     <td class="$row_style"> 
    $volume_hash_ref->{$key}->{'volume'}:$volume_hash_ref->{$key}->{'cnt'} in $volume_hash_ref->{$key}->{'mth'}/$volume_hash_ref->{$key}->{'yr'} 
    </td>
EOT

        }
        $month_counter++;
    }

    # default behaviour is to return html
    if ( $mode eq 'html' || !length($mode) ) {

        # lay currencies by month out in a row
        my $html;
        my $record_counter = 1;
        foreach my $key ( sort keys %total_volume_html ) {
            ( $record_counter % 2 )
              ? ( $row_style = "odd" )
              : ( $row_style = "even" );
            $html .=
"<tr class=\"$row_style\" title=\"volume:transaction count\" ><td>\u$key</td><td> $total_volume_html{$key}</td></tr>";
            $record_counter++;
        }
        my ( $html_totals, $template ) =
          make_html_transaction_totals( \%total_balance, \%total_count, '',
            \%messages );

        my $volume_table = <<EOT;
    <table>
    $html
    </table>
EOT

        return ( 0, '', $registry_error, "$volume_table $html_totals<hr/>",
            $template, '' );
    } elsif ( $mode eq 'values' ) {

        return ( \%total_balance, \%total_count );
    } elsif ( $mode eq 'json' ) {

# only refresh is [mis]used to carry json payload if json is being returned 2/2011
        my $json = deliver_remote_data( $db, 'om_transactions', $registry_error,
            $balance_hash_ref, $token );
        my $json1 .=
          deliver_remote_data( $db, 'om_transactions', $registry_error,
            $volume_hash_ref, $token );
        return "$json|$json1";    # delivers two structures though....
    }

    # }

}

sub _debug_hash_contents {

    my ($fields_ref) = @_;
    my $x;

    foreach my $hash_key ( keys %$fields_ref ) {
        $x .= "$hash_key: $fields_ref->{$hash_key}\n";

    }
    my ( $package, $filename, $line ) = caller;
    $log->debug("pack:$package file:$filename line:$line");

    $log->debug("fields: $x");

    return;
}

1;

