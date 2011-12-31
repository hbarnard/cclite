
=head1 NAME

Cclitedb.pm

=head1 SYNOPSIS

Database routines for Cclite

=head1 DESCRIPTION

This contains all the database routines and static SQL for cclite and some utility routines
to add a function:
 1.  add a routine to generate SQL here 
 2.  add it to the export list below
 3.  use it in on of the main programs
The token is calculated from session info, remote address and an internal registry
key. It diminishes session hijack risk
November 2004: Limit clauses added to _sqlgetwhere _sqlgetall _sqlfind
=head1 AUTHOR

Hugh Barnard

=head1 BUGS


=head1 SEE ALSO

Cclite.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005-2007 GPL Licenced 
=cut

package Cclitedb;
use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use DBI;
use Ccsecure;
use Ccconfiguration;
use Data::Dumper;

###DBI->trace( 4, '../debug/debug.dbi' );      # Database abstraction
###DBI->trace( 2, '/home/hbarnard/trunk/var/cclite/log/debug.dbi.log' );

use Ccu;    # for paging routine, at least

my $VERSION = 1.00;
@ISA = qw(Exporter);

#---------------------------------------------------------
# note the sql ones almost certainly shouldn't be exported!

@EXPORT = qw(check_db_and_version
  add_database_record
  add_database_record_dbh
  update_database_record
  modify_database_record
  modify_database_record2
  delete_database_record
  find_database_records
  log_entry
  makebutton
  makehome
  sqlget
  sqlgetall
  sqlcount
  get_average_transaction_size
  get_check_tag_sql
  get_id_name
  get_suggest_sql
  get_table_fields
  get_raw_stats_data
  get_where
  get_where_multiple
  get_transaction_totals
  get_yellowpages_tag_cloud_data
  get_yellowpages_directory_data
  get_yellowpages_directory_print
  get_user_display_data
  get_table_columns
  registry_connect
  server_hello
  show_record
  sqlinsert
  sqlupdate
  sqlgetpeople
  sqlfind
  sqlraw
  sqlraw_return_array
  sqldelete
  whos_online
);

=head3 add_database_record

Add a record to the cclite database
now very general should work out which fields to insert via 'describe'

=cut

sub add_database_record {
    my $rc;
    my $record_id;
    my ( $class, $db, $table, $fieldsref, $token ) = @_;

    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $insert = _sqlinsert( $dbh, $table, $fieldsref, $token );
    my $sth    = $dbh->prepare($insert);
    my $rv     = $sth->execute();
    my $error  = $sth->errstr();
    $dbh->disconnect();
    return ( $error, $record_id );
}

=head3 add_database_record_dbh

Add a record to the cclite database
now very general should work out which fields to insert via 'describe'
Version to be used in transactions, connect is outside the routine

=cut

sub add_database_record_dbh {
    my $rc;
    my $record_id;
    my ( $class, $dbh, $table, $fieldsref, $token ) = @_;

    my $insert = _sqlinsert( $dbh, $table, $fieldsref, $token );
    my $sth    = $dbh->prepare($insert);
    my $rv     = $sth->execute();
    my $error  = $sth->errstr();
    $dbh->disconnect();
    return ( $error, $record_id );
}

=head3 show_record

show detail for a database record
very rudimentary at present, packs up record into table
and returns as result

=cut

sub show_record {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;

    my $id = get_id_name($table);
    my ( $status, $returnref ) =
      get_where( $class, $db, $table, '*', $id, $fieldsref->{$id}, $token, '',
        '' );
    my $html;

    foreach my $key ( keys %$returnref ) {

      #FIXME: disambiguate userLogin for display: duserLogin = display userLogin
      # hence this should be used in any display templates
        if ( $key eq 'userLogin' ) {
            $fieldsref->{'duserLogin'} = $returnref->{'userLogin'};
        } else {
            $fieldsref->{$key} = $returnref->{$key};
        }

        $html .= <<EOT;
   <tr><td class="pme-key-1">$key</td><td class="pme-value-1">$returnref->{$key}</td></tr>
EOT

    }
    $html = "<table><tbody class=\"stripy\">$html</tbody></table>";

    # default result.html is used, if no template is supplied
    my $template;
    if ( !length( $fieldsref->{'resulttemplate'} ) ) {
        $template = "result.html";
    } else {
        $template = $fieldsref->{'resulttemplate'};
    }
    return ( "", "", "", $html, $template, $fieldsref );
}

=head3 update_database_record

This is used by registry modification transaction, do not remove

Simplest one, but uses hash exclusively, will it work as a web service?
So far, we have:
update_database_record : raw
modify_database_record : produces form: keep and generalise
modify_database_record2 : where

Need to eliminate one of these!

FIXME: this has a pretty stupid return signature 08/2011

=cut

sub update_database_record {

    # note useid is 1 for using the id field in where
    #               2 for using the user logon

    my ( $class, $db, $table, $useid, $fieldsref, $language, $token ) = @_;
    my ( $html, %messages, $messagesref );

    # deals with no language problem
    #FIXME: In Ccsmsgateway language delivers notused why is this?
    # duplicated language code with Ccu, name collision perhaps 08/2011
    if ( !length($messagesref) ) {
        %messages    = readmessages();
        $messagesref = \%messages;
    }

    if ( $table eq 'om_users' && $$fieldsref{action} eq "update" ) {

        # boolean smsreceipt update
        length( $$fieldsref{'userSmsreceipt'} )
          ? ( $$fieldsref{'userSmsreceipt'} = 1 )
          : ( $$fieldsref{'userSmsreceipt'} = 0 );

        $$fieldsref{registry} = $db;
        my @status =
          Ccvalidate::validate_user( $class, $db, $fieldsref, $messagesref,
            $token, "", "" );

        #FIXME: need to sort out status values throughout
        if ( $status[0] == -1 ) {
            shift @status;
            $html = join( "<br/>", @status );
            return ( "0", '', "", $html, "result.html", $fieldsref );
        }

        # hash password: corrected 18/10/2009 for 0 zero url type
        $$fieldsref{userPassword} =
          Ccsecure::hash_password( 0, $$fieldsref{userPassword} )
          if length( $$fieldsref{userPassword} );

        # unlock the password if administrator and Password changed
        if ( is_admin() && length( $$fieldsref{userPassword} ) ) {
            $$fieldsref{userPasswordTries}  = 3;
            $$fieldsref{userPasswordStatus} = 'active';
        }

        $$fieldsref{userPin} = text_to_hash( $$fieldsref{userPin} )
          if length( $$fieldsref{userPin} );
        $$fieldsref{userMobile} =
          format_for_standard_mobile( $$fieldsref{userMobile} )
          if length( $$fieldsref{userMobile} );

        # unlock the SMS PIN if administrator and PIN changed
        if ( is_admin() && length( $$fieldsref{userPin} ) ) {
            $$fieldsref{userPinTries}  = 3;
            $$fieldsref{userPinStatus} = 'active';
        }

    }

    my ( $rv, $rc, $record_id );
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $update = _sqlupdate( $dbh, $table, $useid, $fieldsref, $token );
    my $sth = $dbh->prepare($update);
    $sth->execute();
    ###debug_message($update) ;
    #FIXME: Some tables still haven't literals
    my $table_literal = $messages{$table} || $table;

    $html = "$table_literal record $$fieldsref{id} $$fieldsref{action}";
    return ( 1, $$fieldsref{home}, "", $html, "result.html", $fieldsref );
}

=head3 delete_database_record

Delete a database record. Compensates for different ids
within tables due to use of tiki schema. Ugly at present
but functioning

=cut

sub delete_database_record {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $error, $html, $record_id );
    my $id;

    #FIXME: compensate for different id names in tables, ugly
    my %translate = qw(om_trades tradeId om_users userId om_openid openId);
    if ( exists $translate{$table} ) {
        $id = $translate{$table};
    } else {
        $id = "id";
    }
    my $delete = _sqldelete( $table, $id, $$fieldsref{$id} );
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $sth = $dbh->prepare($delete);
    $sth->execute();
    my $error = $dbh->errstr();

    # this is not multilingual to be fixed
    $html = "$table record $$fieldsref{$id} deleted" if ( !length($error) );
    return ( "1", $$fieldsref{home}, $error, $html, "result.html", "" );
}

=head3 sqlcount

Count a set of records in the database, either to output
as a guide figure or to make pagination information

Can be done via sqlstring or where

This needs to return an error too

=cut

sub sqlcount {
    my ( $class, $db, $table, $sqlstring, $fieldname, $value, $token ) = @_;
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );

    # count all the transactions belonging to the current user
    my $sqlcount = _sqlcount( $table, $sqlstring, $fieldname, $value, $token );
    my $sth = $dbh->prepare($sqlcount);
    $sth->execute();
    my @row   = $sth->fetchrow_array;
    my $count = $row[0];
    return $count;
}

=head3 sqlraw

Sql raw a given piece of sql. 
Does not allow update or delete used for complex joins etc.
change to hash_ref, self-describing but problematic in soap calls

=cut

sub sqlraw {
    my ( $class, $db, $sqlstring, $id, $token ) = @_;
    my ( $rc, $rv, $hash_ref );

    # remove all modification attempts!
    $sqlstring =~ s/delete|insert|update//gi;
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );
    if ( length($dbh) ) {
        my $sth = $dbh->prepare($sqlstring);
        my $rv  = $sth->execute();
        $hash_ref = $sth->fetchall_hashref($id);
        $sth->finish();
    }

    # --- example of use---------------------------------
    # $hash_ref = $sth->fetchall_hashref('id');
    # print "Name for id 42 is $hash_ref->{42}->{name}\n";
    #----------------------------------------------------
    return ( $registryerror, $hash_ref );
}

=head3 sqlraw_return_array

returns an array, probably useful for web services
otherwise identical to sqlraw, probably should be
renamed to sql_raw_return_hash...

=cut

sub sqlraw_return_array {
    my ( $class, $db, $sqlstring, $id, $token ) = @_;
    my ( $rc, $rv, $array_ref );

    # remove all modification attempts!
    $sqlstring =~ s/delete|insert|update//gi;
      
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );

    # cumulate any detail error with registry error 10/2009
    $registryerror .= $dbh->errstr() if length($dbh);
    if ( length($dbh) ) {
        my $sth = $dbh->prepare($sqlstring);
        my $rv  = $sth->execute();
        $array_ref = $sth->fetchall_arrayref();
        $sth->finish();
    }

    return ( $registryerror, $array_ref );
}

=head3 find_database_records

Find strings within a table
Makes a large OR using LIKE.
Very inefficient but works at present

This will now deliver all transactions into a find
that is done by the manager...be careful

=cut

sub find_database_records {
    my (
        $class,     $db,    $table,  $fieldsref, $fieldslist,
        $cookieref, $token, $offset, $limit
    ) = @_;
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );

    my @columns = get_table_text_columns( $table, $dbh );
    my $column_array_ref = \@columns;

    my ( $count, $row_ref, $like, $string, $hash_ref );

    # make a massive where statement for all textual columns
    foreach my $column (@columns) {
        $column = "$column LIKE \'%$fieldsref->{'string'}%\'";
    }
    $like = join( " or ", @columns );

    # constrain finds on om_trades to just the owner's records
    if ( $table eq "om_trades" && !is_admin() ) {

      # first select base set, only records for user, if not admin
      # debits and opening balances are user sourced, credits are remote sourced

        $like .= <<EOT;
and ((tradeSource = '$$cookieref{userLogin}' and (tradeType = 'debit' or tradeType = 'open'))
 or
 (tradeDestination = '$$cookieref{userLogin}' and  tradeType = 'credit')
)
EOT

    }

    # count all the transactions belonging to the current user
    # if om_trades otherwise count all records
    #
    $count =
      sqlcount( $class, $db, $table, $like, "tradeSource",
        $$cookieref{userLogin}, $token )
      if ( $table eq 'om_trades' );
    $count = sqlcount( $class, $db, $table, $like, "", "", $token )
      if ( $table ne 'om_trades' );

    #FIXME: this should be redundant: get the columns too
    ### my ( $registryerror, $column_array_ref ) =
    ####  sqlraw_return_array( $class, $db, "describe $table", "", $token );

    my $find =
      _sqlfind( $table, $fieldsref, $fieldslist, $like, "", $offset, $limit );

    # unhappily the id field used in each table is inconsistent
    my $id = get_id_name($table);

    my $sth = $dbh->prepare($find);
    $sth->execute();
    $hash_ref = $sth->fetchall_hashref($id);

    $sth->finish();
    my $error = $dbh->errstr();
    return ( $registry_error, $count, $column_array_ref, $hash_ref );
}

=head3 get_transaction_totals

Get credit and debit transation totals for a given user, doesn't deal with admin yet..
Replaces pile of junk code in Cclite::show_balance_and_volume 4/2010


=cut

sub get_transaction_totals {

    my ( $class, $db, $user, $months_back, $token ) = @_;
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $volume_sql = _sql_give_volumes( $user, $months_back, $token );
    my $balance_sql = _sql_get_balance_by_currency( $user, $token );

    my $sth;
    $sth = $dbh->prepare($volume_sql);
    $sth->execute();
    my $volume_hash_ref = $sth->fetchall_hashref('sort');
    $sth = $dbh->prepare($balance_sql);
    $sth->execute();
    my $balance_hash_ref = $sth->fetchall_hashref('tradeId');
    $sth->finish();

    my $error = $dbh->errstr();
    return ( $registry_error, $volume_hash_ref, $balance_hash_ref );

}

=head3 get_suggest_sql

Get the sql statement for the appropriate autosuggest type
All this depends on cclite.js which fires various bits of jquery

=cut

sub get_suggest_sql {

    my ( $level, $userLogin, $type, $query_string ) = @_;
    my $sql;

    # deals with suggesting destination for trade or user search

    if ( $type eq 'user' ) {

        $sql = <<EOT;
SELECT userLogin FROM `om_users` 
 WHERE (userLogin LIKE \'\%$query_string\%\'
        AND userLevel <> \'sysaccount\' 
        AND userLogin <> \'$userLogin\' )
 LIMIT 0 , 10; 
                
EOT

    }

    # suggest yellowpages responding to search

    elsif ( $type eq 'ad' ) {

        $sql = <<EOT;
SELECT subject FROM `om_yellowpages` 
                        WHERE ( type LIKE \'\%$query_string\%\' 
                        OR category LIKE \'\%$query_string\%\' 
                        OR keywords LIKE \'\%$query_string\%\'
                        OR subject LIKE \'\%$query_string\%\' )
LIMIT 0 , 10 ;

EOT

    }

    # suggests replies to trade search

    elsif ( $type eq 'trade' ) {

        # admin can search for any trade
        if ( $level eq 'admin' ) {
            $sql = <<EOT;
SELECT tradeTitle,tradeStatus FROM `om_trades` 
         WHERE (tradeTitle LIKE \'\%$query_string\%\' 
                OR tradeHash LIKE \'\%$query_string\%\' 
                OR tradeStatus LIKE \'\%$query_string\%\') 
LIMIT 0 , 10 ;
 

EOT

            # non admin can search within trades that concern them
        } else {
            $sql = <<EOT;
SELECT tradeTitle,tradeStatus FROM `om_trades` 
         WHERE ((tradeTitle LIKE \'\%$query_string\%\' 
                OR tradeHash LIKE \'\%$query_string\%\' 
                OR tradeStatus LIKE \'\%$query_string\%\') 
                AND (tradeSource = \'$userLogin\' OR tradeDestination = \'$userLogin\'))
LIMIT 0 , 10 ;
 

EOT

        }

        # special case, will produce a reply when new user name is unique

    } elsif ( $type eq 'newuser' ) {
        $sql =
"SELECT userLogin FROM `om_users` WHERE userLogin LIKE \'\%$query_string\%\' LIMIT 0 , 10";

    } elsif ( $type eq 'newuseremail' ) {
        $sql =
"SELECT userLogin FROM `om_users` WHERE userEmail LIKE \'\%$query_string\%\' LIMIT 0 , 10";

    } elsif ( $type eq 'newusermobile' ) {
        $sql =
"SELECT userLogin FROM `om_users` WHERE userMobile LIKE \'\%$query_string\%\' LIMIT 0 , 10";

    } elsif ( $type eq 'tag' ) {
        $sql =
"SELECT description FROM `om_categories` WHERE (description LIKE \'\%$query_string\%\' and category = '9999') LIMIT 0 , 10";

    }

    return $sql;
}

=head3 get_check_tag_sql

Check if free form category tag exists, to avoid
duplicating them. They always have 9999 category codes

=cut

sub get_check_tag_sql {

    my ($tag) = @_;

    my $sql =
"SELECT description FROM `om_categories` WHERE (description = $tag and category = '9999'";
    return $sql;

}

=head3 get_user_display_data

Sql and retrieval for user display page. Moved into here 5/2010
to give better sql/code separation

As of May 2010, hashes are now returned and processed, making everything
less fragile with respect to database changes...

=cut

sub get_user_display_data {
    my ( $class, $db, $user, $token ) = @_;

    my $sqlstring;

    #FIXME: need to remove the simpler version

=item cut-this    
    $sqlstring = <<EOT;
  SELECT  u.userLogin,u.userName, userStatus,
                  u.userPostcode, u.userEmail,u.userMobile,
                  u.userTelephone
  FROM om_users u
  WHERE (
  u.userLogin = '$user')
EOT
=cut

    $sqlstring = <<EOT;
  SELECT DISTINCT u.userLogin,u.userName, userStatus,
                  u.userPostcode, u.userEmail,u.userMobile,
                  u.userTelephone, y.id, y.subject, y.description, 
                  y.fromuserid, y.price, y.unit, y.tradeCurrency
  FROM om_yellowpages y, om_users u
  WHERE (
  y.fromuserid = u.userLogin AND u.userLogin = '$user')
EOT

    # get equi-joined table
    my ( $error, $hash_ref ) = sqlraw( $class, $db, $sqlstring, 'id', $token );

    return ( $error, $hash_ref );
}

=head3 get_yellowpages_directory_data

This moves all the sql and retrieval for the Craigslist style directory
into its correct place, since it contains sql May 2010

As of May 2010, hashes are now returned and processed, making everything
less fragile with respect to database changes...

=cut

sub get_yellowpages_directory_data {

    my ( $class, $db, $interval, $detail, $token ) = @_;

    $interval ||= 1;    # if there are items a week or less in a category
                        # they'll show up as new

    my $sqldetail = <<EOT;

SELECT c.description, count( * ) AS 'majorcount', y.type, y.category
FROM om_yellowpages y, om_categories c
WHERE (
y.category = c.category
AND c.parent = y.parent
)
GROUP BY y.parent,y.category,y.type
ORDER BY c.description ASC
EOT

    # same data set as detail but count 'new' ads

    my $sqltestifnew = <<EOT;

SELECT  c.description, count( * ) AS 'majorcount', y.type, y.category
FROM om_yellowpages y, om_categories c
WHERE datediff(curdate(),y.date) < 2
and
y.category = c.category
AND c.parent = y.parent
GROUP BY y.parent

EOT

    my $sqlmajor = <<EOT;

SELECT  c.description, count( *) AS 'majorcount', y.type, y.category
FROM om_yellowpages y, om_categories c
WHERE (
y.category = c.category
AND c.parent = y.parent
)
GROUP BY y.parent
ORDER BY y.parent ASC
EOT

    my $sqlstring = $sqlmajor;

    # detail is supplied by $fieldsref->{'getdetail'}
    $sqlstring = $sqldetail if ($detail);

    # look up categories which have new ads
    my %newads;

    # get a list of categories which have received ads recently
    # put in a hash
    my ( $registryerror, $new_items_hash_ref ) =
      sqlraw( $class, $db, $sqltestifnew, 'description', $token );

    my ( $registryerror, $yellowdirectory_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'description', $token );

    return ( $new_items_hash_ref, $yellowdirectory_hash_ref );

}

=head3 get_yellowpages_tag_cloud_data

July 2011, same signature as all the other parts of yellowpages
but for tag cloud retrieval. Main idea of this is for the listing
classification to become more flexible and multilingual

9999 category are free form keywords to keep them away from the static
classification scheme.


FIXME: keywords are a string of keywords, they are not properly normalised,
but I don't want millions of little tables

=cut

sub get_yellowpages_tag_cloud_data {

    my ( $class, $db, $interval, $detail, $token ) = @_;

    my $sql = <<EOT;
SELECT  y.id, y.keywords, y.type
FROM om_yellowpages y where category = '9999' order by `date` desc LIMIT 0,1000
EOT

    my $sqltestifnew = <<EOT;
SELECT  y.id, y.keywords, y.type, y.category
FROM om_yellowpages y
WHERE where (category = '9999' and datediff(curdate(),y.date) < 2) order by `date` desc LIMIT 0,1000
EOT

    my ( $registryerror, $yellowdirectory_hash_ref ) =
      sqlraw( $class, $db, $sql, 'id', $token );

    return ( $registryerror, $yellowdirectory_hash_ref );

}

=head3 get_yellowpages_directory_print

This is the version for print format, a work in progress
as of December 2010


=cut

sub get_yellowpages_directory_print {

    my ( $class, $db, $token ) = @_;

    my $sqlstring = <<EOT;

SELECT concat(y.parent,y.category,y.type,y.id) as sortal,
y.category, y.type,y.parent,
u.userId,u.userEmail,u.userMobile,u.userTelephone, y.subject, 
y.price, y.unit, y.tradeCurrency, y.description
FROM om_yellowpages y, om_users u
WHERE
y.fromuserid = u.userLogin
EOT

    my ( $registryerror, $yellowdirectory_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'sortal', $token );

    my $sqlstring = <<EOT;

SELECT concat(y.parent,y.category,y.type,y.id) as sortal,c.description
FROM om_yellowpages y, om_categories c
WHERE
y.parent = c.parent AND y.category = c.category
EOT

    my ( $registryerror, $category_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'sortal', $token );

    return ( $yellowdirectory_hash_ref, $category_hash_ref );

}

=head3 get_statement_print

This is the version for print format, a work in progress
as of December 2010


=cut

sub get_statement_print {

    my ( $class, $db, $token ) = @_;

    my $sqlstring = <<EOT;

SELECT 
FROM om_trades y, om_users u
WHERE
y.trade = u.userLogin

EOT

    my ( $registryerror, $trade_hash_ref ) =
      sqlraw( $class, $db, $sqlstring, 'sortal', $token );

    return ($trade_hash_ref);

}

=head3 get_where

FIXME: This is throwing errors into the apache log
get a record via a single = field condition
should return one record only

=cut

sub get_where {
    my (
        $class, $db,    $table,  $fieldslist, $fieldname,
        $name,  $token, $offset, $limit
    ) = @_;
    my $get =
      _sqlgetwhere( $name, $table, $fieldslist, $fieldname, $token, $offset,
        $limit );

    if ( !length($db) ) {
        my ( $package, $filename, $line ) = caller;

        log_entry($class, $db,
"$class, $db, $table, $fieldname, $name, $token, $offset, $limit g:$get  p:$package, f:$filename, l:$line",
      $token  );
        
        return ( 'blank database', '' );
    }

    my ( $rc, $rv, $hash_ref );
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );

    if ( length($dbh) ) {
        my $sth = $dbh->prepare($get);
        my $rv  = $sth->execute();
        $hash_ref = $sth->fetchrow_hashref;
        $sth->finish();
    }
    return ( $registryerror, $hash_ref );
}

=head3 get_where_multiple

get multiple records via a field condition returns a hash as of 5/2010
this should completely replace get_where after a while
needs limit clause

=cut

sub get_where_multiple {
    my (
        $class, $db,    $table,  $fieldslist, $fieldname,
        $name,  $token, $offset, $limit
    ) = @_;
    ###local, dalston, om_currencies,*, *,  , *, ,
    my $get =
      _sqlgetwhere( $name, $table, $fieldslist, $fieldname, $token, $offset,
        $limit );
    my ( $rc, $rv, $hash_ref );
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );

    # unhappily the id field used in each table is inconsistent
    my $id = get_id_name($table);

    if ( length($dbh) ) {
        my $sth = $dbh->prepare($get);
        my $rv  = $sth->execute();
        $hash_ref = $sth->fetchall_hashref($id);
        $sth->finish();
    }
    return ( $registryerror, $hash_ref );
}

=head3 sqlfind

sql find for a given piece of sql. This is sometimes the motor
for a given application. To some extent, this is a 'tramp' function
as defined in coding complete, but it hides _sqlfind too...

'order' param after $sqlstring isn't filled at present

=cut

sub sqlfind {
    my (
        $class,     $db,    $table, $fieldsref, $fieldslist,
        $sqlstring, $order, $token, $offset,    $limit
    ) = @_;

    my $get =
      _sqlfind( $table, $fieldsref, $fieldslist, $sqlstring, $order, $offset,
        $limit );

    # find id field of the table, not all called id, unhappily
    my $id = get_id_name($table);
    my ( $rc, $rv, $hash_ref );
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );
    if ( length($dbh) ) {
        my $sth = $dbh->prepare($get);
        my $rv  = $sth->execute();
        $hash_ref = $sth->fetchall_hashref($id);
        $sth->finish();
    }
    return ( $registryerror, $hash_ref );
}

=head3 modify_database_record

 Prepares to modify:
  - fetches a record by id
  - transfers fields to fieldsref
  - set up appropriate next action
  - display form if named, default if not
  - hardwired template logic probably needs to be moved

=cut

sub modify_database_record {

    my ( $class, $db, $table, $fieldsref, $cookieref, $pages, $token ) = @_;
    my ( $html, $key, $field, $home, $offset, $limit );

    # work out default template, results.html is not used nowadays
    my $default_template = $table;
    $default_template =~ s/om_//;
    $default_template .= "\056html";
    my $template = $$fieldsref{template} || $default_template;

    # compensate for different id names, needs to be stripped
    my $idname = get_id_name($table);

    my $get;

# FIXME: subtle bug in registry detail retrieve and cpanel create (with empty table), therefore
# get from table by name is safest currently 11/2009
    if ( $table eq 'om_users' ) {
        $get = _sqlgetwhere( $cookieref->{'userId'},
            $table, '*', $idname, $token, $offset, $limit );
    } else {
        $get = _sqlgetwhere( $fieldsref->{$idname},
            $table, '*', $idname, $token, $offset, $limit );
    }

    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $sth = $dbh->prepare($get);
    $sth->execute();
    my $hash_ref = $sth->fetchrow_hashref;
    my $error    = $dbh->errstr();

    return ( 0, '', $error, $html, $pages, $template, $hash_ref, "", $token );
}

=head3 modify_database_record2

Did this never work? Just modified 2/5/2005 to produce
a where condition update.

Needs investigation and possible removal,
FIXME: This is called only once by modify_user im Cclite.pm at about 969

=cut

sub modify_database_record2 {
    my (
        $class,     $db,    $table,    $name, $fieldname,
        $fieldsref, $pages, $pagename, $token
    ) = @_;

    my $html;
    my $field;
    my $offset;    # not used here
    my $limit;     # not used here
                   # this needs to be replaced by fetchrow_hashref...
    my $counter = 0;    # count the rows as they go by!
    my $get =
      _sqlgetwhere( $name, $table, $fieldname, $token, $offset, $limit );
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my $sth = $dbh->prepare($get);
    $sth->execute();
    $fieldsref = $sth->fetchrow_hashref;    # note fieldsref now comes from db
    $sth->finish();
    my $error = $dbh->errstr();
    return ( 0, '', $error, '', $pages, $pagename, $fieldsref, '', $token );
}

=head3 get_table_columns

Gets all the columns within a table via a
table describe. Used to prepare other operations

=cut

sub get_table_columns {
    my ( $table, $dbh ) = @_;
    my ( $sth, @columns, @row );
    my $show = "describe $table;";
    $sth = $dbh->prepare($show);
    my $rv = $sth->execute();
    while ( @row = $sth->fetchrow_array ) {
        push @columns, $row[0];
    }
    $sth->finish();
    my $error = $dbh->errstr();
    return (@columns);
}

=head3 check_db_and_version

checks for database password and no innodb problems
during install/configuration update

alpha quality code, new in December 2005

=cut

sub check_db_and_version {
    my ($token) = @_;

    #---------------------------------------------------------
    my ( $registryerror, $dbh ) = &Cclitedb::_registry_connect( "", $token );

    # return signature: $refresh,$metarefresh,$error,$html,$pagename,$cookies
    # no connection to database, return reason
    if ( length($registryerror) ) {
        return $registryerror;
    }

    # mysql version less than 4, no inno_db, return version
    my $sth = $dbh->prepare("show variables;");
    $sth->execute();
    my $m = 0;
    my @row;
    while ( @row = $sth->fetchrow_array() ) {
        last if ( $row[0] =~ /^have_innodb/i );
    }

    if ( $row[1] !~ /^YES/ ) {
        return "innodb  $row[1]";
    }

    # nothing comes back, ok
    return undef;
}

=head3 get_table_text_columns

gets text type columns via describe
probably refactor this as a mode of get_table_columns?

=cut

sub get_table_text_columns {
    my ( $table, $dbh ) = @_;
    my ( $sth, @columns, @row );
    my $show = "describe $table;";
    $sth = $dbh->prepare($show);
    my $rv = $sth->execute();
    while ( @row = $sth->fetchrow_array ) {
        push @columns, $row[0] if ( $row[1] =~ /varchar|text|enum/ );
    }
    $sth->finish();
    my $error = $dbh->errstr();
    return (@columns);
}

=head3 _registry_connect

connect to database (therefore a registry) or database server 
(with blank $db, to create registries)

Note that all _ prefixed are inner routines, shouldn't be exposed

=cut

sub _registry_connect {

    my ( $db, $token ) = @_;

    my %configuration = readconfiguration();
    our $dbuser     = $configuration{dbuser};
    our $dbpassword = $configuration{dbpassword};

    #FIXME: hack for database prefix in cpanel, registry creation connect
    # has blank database so no prefix should be added...
    if ( length( $configuration{'cpanelprefix'} ) && length($db) ) {
        $db = $configuration{'cpanelprefix'} . '_' . $db;
    }

    #open connection to MySql database
    my $dbh = DBI->connect( "dbi:mysql:$db", $dbuser, $dbpassword );
    my $error = $DBI::errstr;
    return ( $error, $dbh );
}

=head3 registry_connect

FIXME: Exposed version of connect to database (therefore a registry) or database server 
(with blank $db, to create registries)

This is for the future with persistent database handles in mono-registry

=cut

sub registry_connect {

    my %configuration = readconfiguration();
    our $dbuser     = $configuration{dbuser};
    our $dbpassword = $configuration{dbpassword};

    my ( $db, $token ) = @_;

    #FIXME: hack for database prefix in cpanel
    $db = $configuration{'cpanelprefix'} . '_' . $db
      if ( length( $configuration{'cpanelprefix'} ) );

    #open connection to MySql database
    my $dbh = DBI->connect( "dbi:mysql:$db", $dbuser, $dbpassword );
    my $error = $DBI::errstr;
    return ( $error, $dbh );
}

=head3 _sqlfind

find record via string, orders output set
if order parameter is present

=cut

sub _sqlfind {
    my ( $table, $fieldsref, $fieldslist, $sqlstring, $order, $offset, $limit )
      = @_;
    my $sqlfind;
    my $limit_clause;

    # get the tabular display fields for a givem table...
    my $table_fields = get_table_fields( $table, $fieldslist );

   # mild security don't deliver complete tables  unless admin 10.3.2007/06/2007
    return if ( ( $sqlstring == 1 || $sqlstring eq "1=1" ) && !is_admin() );

    if ( length($limit) ) {
        $offset = 0 if ( !length($offset) );
        $limit_clause = "LIMIT $offset,$limit";
    }

    if ( length($order) ) {
        $sqlfind = <<EOT;
   SELECT $table_fields from $table WHERE ($sqlstring) ORDER BY $order $limit_clause
EOT
    } else {
        $sqlfind = <<EOT;
   SELECT $table_fields from $table WHERE ($sqlstring) $limit_clause
EOT
    }

    return $sqlfind;
}

=head3 _sqlgetall

select all the records in a table
uses limit and offset, if present

=cut 

sub _sqlgetall {
    my ( $table, $offset, $limit ) = @_;
    my $limit_clause;

    if ( length($limit) ) {
        $offset = 0 if ( !length($offset) );
        $limit_clause = "LIMIT $offset,$limit";
    }

    my $sqlget = <<EOT;
   SELECT * 
   from $table $limit_clause
EOT

    return $sqlget;
}

=head3 _sqlgetwhere

Used for getting the registry via name, 
can be used for usernames, also
As of 06/2007 now needs tidying up

=cut

sub _sqlgetwhere {
    my ( $name, $table, $fieldlist, $fieldname, $token, $offset, $limit ) = @_;
    my $sqlgetwhere;
    my $limit_clause;

    # get the tabular display fields for a givem table...
    my $table_fields = get_table_fields( $table, $fieldlist );

    if ( length($limit) ) {
        $offset = 0 if ( !length($offset) );
        $limit_clause = "LIMIT $offset,$limit";
    }

    if ( $name ne "*" ) {
        if ( $table ne 'om_trades' ) {
            $sqlgetwhere = <<EOT;
    SELECT $table_fields FROM $table WHERE $fieldname = \'$name\' ORDER BY $fieldname $limit_clause 
EOT

        } else {
            $sqlgetwhere = <<EOT;
    SELECT $table_fields FROM $table WHERE $fieldname = \'$name\' ORDER BY tradeDate DESC $limit_clause 
EOT

        }

    } else {

        #FIXME: These are pretty dangerous...

        if ( $table ne 'om_trades' ) {
            $sqlgetwhere = <<EOT;
    SELECT $table_fields FROM $table WHERE 1 ORDER BY $fieldname $limit_clause
EOT

        } else {

            $sqlgetwhere = <<EOT;
    SELECT $table_fields FROM $table WHERE 1 ORDER BY tradeDate DESC $limit_clause 
EOT

        }

    }
    ### print "where is $sqlgetwhere\n" ;
    return $sqlgetwhere;
}

=head3 _sqldelete

delete record via id only

=cut

sub _sqldelete {
    my ( $table, $fieldname, $id ) = @_;
    my $sqldelete = <<EOT;
   DELETE FROM $table WHERE ($fieldname = '$id')
EOT
    return $sqldelete;
}

=head3 _sqlinsert

Insert a record now made general, will insert into any table, 
column definitions are provided via 'describe table_name' done before this
note please stick to 'id' for an id/primary key, makes life simpler
this is inherited from Mose etc... userId, tradeId hence the complex
regex test below.

FIXME: This only deals with autoincrement...not the case for om_openid, foreign key...
       Therefore test for om_openid but this is ugly..

=cut

sub _sqlinsert {
    my ( $dbh, $tablename, $fieldsref, $token ) = @_;
    my %fields = %$fieldsref;
    my @values;
    my $value_string;
    my @columns = get_table_columns( $tablename, $dbh );
    my $fieldsstring = join( ",\n", @columns );
    foreach my $column_name (@columns) {
        next
          if ( $column_name =~ /^id|^Id|^userId|^tradeId/
            && $tablename ne 'om_openid' );    # don't put id into this
        push @values, "'$fields{$column_name}'";
    }

    # string out the field values for the insert
    $value_string = join( ",\n", @values );
    my $sqlinsert = <<EOT;
   INSERT INTO $tablename (
     $fieldsstring
   ) VALUES (
    NULL,
    $value_string 
   )
EOT
    $sqlinsert =~ s/NULL,// if ( $tablename eq 'om_openid' );
    return $sqlinsert;
}

=head3 _sqlupdate

Update a record
only the fields supplied run into the update, unlike insert
in which ALL the columns are initialised.

=cut

sub _sqlupdate {
    my ( $dbh, $tablename, $useid, $fieldsref, $token ) = @_;
    my %fields = %$fieldsref;
    my $value_string;
    my $id_field;
    my @columns = get_table_columns( $tablename, $dbh );
    my $fieldsstring = join( ",\n", @columns );

    foreach my $column_name (@columns) {
        ( ( $id_field = $column_name ) && next )
          if ( $column_name =~ /^id|^userId|^tradeId|^openId/ && $useid == 1 )
          ;    # don't put id into this

        ( ( $id_field = $column_name ) && next )
          if ( $column_name =~ /userLogin/ && $useid == 2 )
          ;    # don't put id into this

        $value_string .= "$column_name \= \'$fields{$column_name}\',\n"

  #FIXME: ugly hack to zeroise commitlimit field in om_registry if blank 11/2008
          if ( length( $fields{$column_name} )
            || $fields{$column_name} =~ m/commitlimit/ );
    }

 #FIXME: ugly hack to blank latest_news field in om_registry if blank 11/2009
 #       prevented password change etc. badly expressed condition, watch this...
    if ( $tablename eq 'om_registry' ) {
        if ( !length $fields{latest_news} || !defined $fields{latest_news} ) {
            $value_string .= "latest_news \= \'\',\n";
        }
    }

    $value_string =~ s/,$//;    # remove the last comma!

    my $sqlupdate = <<EOT;
   UPDATE $tablename 
   SET
   $value_string 
   WHERE ( $id_field = '$fields{$id_field}')
EOT

    return $sqlupdate;
}

=head3 _sqlcount

This is only tested for the transactions table at present
counts transactions for the logged in user.

=cut

sub _sqlcount {
    my ( $table, $sqlstring, $fieldname, $value, $token ) = @_;
    my $sqlcount;
    if ( !length($sqlstring) ) {

        $sqlcount = <<EOT;
     SELECT COUNT(*) FROM $table
      WHERE $fieldname = '$value'  GROUP BY $fieldname
EOT

    } else {

        $sqlcount = <<EOT;
    SELECT COUNT(*) FROM $table
     WHERE $sqlstring  
EOT

    }

    # removed group by fieldname from second statement
    return $sqlcount;
}

sub _sql_give_volumes {

    my ( $user, $months_back, $token ) = @_;

    # sum by user except for manager, sum all transactions...
    my $user_string;
    ( $user eq 'manager' )
      ? ( $user_string = '' )
      : ( $user_string =
          "(tradeDestination = \'$user\' or tradeSource= \'$user\') and" );

    my $sql = <<EOT;
SELECT  concat(substring(tradeCurrency,1,3),year(tradeDate),month(tradeDate)) as sort,
monthname(tradeDate) as mth, substring(year(tradeDate),3,2) as yr, tradeCurrency as currency,
round(sum(tradeAmount)/2) as volume, round(count(*)/2) as cnt  from om_trades where
$user_string
(tradeStatus = 'waiting' or tradeStatus = 'accepted')
group by currency, yr, mth order by sort
EOT

    return $sql;

}

sub _sql_get_balance_by_currency {

    my ( $user, $token ) = @_;

    # sum by user except for manager, sum all transactions...
    my ( $user_string, $user_string1 );
    ( $user eq 'manager' )
      ? ( $user_string = '' )
      : ( $user_string = "tradeDestination = \'$user\' and" );
    ( $user eq 'manager' )
      ? ( $user_string1 = '' )
      : ( $user_string1 = "tradeSource = \'$user\' and" );

    my $sql = <<EOT;
SELECT tradeId,tradeCurrency as currency, sum(tradeAmount) as sum from om_trades 
where tradeType = 'credit' and
$user_string
( tradeStatus = 'waiting' or tradeStatus = 'accepted' ) and
tradeDestination != 'cash' 
group by currency

union

SELECT tradeId,tradeCurrency as currency, -(sum(tradeAmount)) as sum from om_trades 
where tradeType = 'debit' and
$user_string1
( tradeStatus = 'waiting' or tradeStatus = 'accepted' ) and
tradeDestination != 'cash' 
group by currency
EOT

    return $sql;

}

=head3 makebutton

FIXME: makebutton probably needs to go to Ccu.pm
Values in extras override database values if there's
name collision. It's assumed that the extras are tailor made

label is the label on the push button, action is the name
of the action in the controller.

=cut

sub makebutton {

    my ( $label, $class, $action, $db, $table, $hash_ref, $fieldsref, $token ) =
      @_;

    my ( $formfields, $x, $senddetected );
    my ( $registry_error, $dbh ) = _registry_connect( $db, $token );
    my @fieldnames = get_table_columns( $table, $dbh );
    my $id = get_id_name($table);

    foreach my $field_name (@fieldnames) {

        if ( $field_name !~ /Send|Go/ ) {

#FIXME: only need id info within a delete or display button, should only need id, en principe!
            next
              if ( ( $action eq "delete" || $action =~ /^display|show/ )
                && ( $field_name ne $id && $field_name ne 'userLogin' ) );

            my $hidden_field = <<EOT;
 <input type="hidden" name="$field_name" value="$hash_ref->{$field_name}">
EOT

            #FIXME: name collision, displayed user data and current user...
            $hidden_field =~ s/(name=\")(.*?)(\")/$1duserLogin$3/
              if ( $field_name eq 'userLogin' );

            #FIXME: hack because of 'name' collision in currencies table
            $hidden_field =~ s/(name=\")name(\")/$1cname$2/
              if ( $table eq 'om_currencies' );
            $hidden_field =~ s/(name=\")name(\")/$1dname$2/
              if ( $table eq 'om_partners' );

            $formfields .= $hidden_field;

        } else {
            $formfields .= <<EOT;
 <input  type="submit" name="$field_name" value="$field_name">
EOT
            $senddetected = 1;
        }    # endif

    }    # end foreach

# add a template into resulttemplate, should be display, displayyellow, displayuser etc. etc.
    if ( $action =~ /^display|show/ || $action eq "template" ) {
        my $template = _choosetemplate( ( $action, $db, $table ) );
        $formfields .= $template;
    }

    if ( !$senddetected ) {

        #FIXME: class isn't picked up somewhere in this...

        $class ||= 'small';
        $formfields .= <<EOT;
 <input type="hidden" name="subaction" value="$table">
 <input type="hidden" name="action" value="$action">
 <input class="$class" type="submit" name="go" value="\u$label">
EOT

    }

    #FIXME: correct home for modifcation of partners and currencies
    if ( $action eq 'template'
        && ( $table eq 'om_partners' or $table eq 'om_currencies' ) )
    {
        $fieldsref->{home} =~ s/cclite.cgi/\/protected\/ccadmin.cgi/;
    }

    my $button = <<EOT;
<form id="form" class="pme-form" action="$fieldsref->{home}" method="POST">
$formfields
</form>
EOT

    return $button;
}

=head3 _get_table_fields

Choose fields for tabular style display according to table
Modify this to modify this to modify table display, the fields list must contain
the id field because the retrieval is via a hash since 4/2010

=cut

sub get_table_fields {

    my ( $table, $fieldlist ) = @_;
    my %table_fields = (
        'om_trades' =>
'tradeId,tradeStatus,tradeDate,tradeSource,tradeDestination,tradeMirror,tradeCurrency,tradeType,tradeAmount',
        'om_yellowpages' => 'id,fromuserid,status,date,type,keywords,subject',
        'om_openid'      => 'openId,openIdDesc',
        'om_partners'    => 'id,name,email,type,status',
        'om_currencies'  => 'id,name,code,description,status',
        'om_users'       => 'userId,userLogin,userName,userStatus',

    );

    # for the moment any value will do, other than *
    if ( $fieldlist ne '*' ) {
        return $table_fields{$table};
    } else {
        return '*';
    }
}

=head3 get_id_name

Gets the id field depending on the table name. The should all be the same
but since the database was a mixture of Mose, myself etc. they are not,
don't want to change now, will introduce serious incompatbilities

=cut

sub get_id_name {

    my ($table) = @_;
    my %id_fields = qw(om_trades tradeId om_openid openId om_users userId);

    if ( exists $id_fields{$table} ) {
        return $id_fields{$table};
    } else {
        return 'id';
    }

}

=head3 _choosetemplate

FIXEME: Choose a template for display items when making
buttons. This is ugly, since choice of templates is
hardcoded into the code

=cut

sub _choosetemplate {
    my ( $action, $db, $table ) = @_;
    my %templates;
    my $template;
    if ( $action =~ /^display|show/ ) {    # display, displayyellow etc. etc.
        %templates = qw(om_yellowpages displayyellowpage.html
          om_trades displaytransaction.html
          om_users displayuser.html
        );
        if ( exists $templates{$table} ) {
            $template = <<EOT;
 <input type="hidden" name="resulttemplate" value="$templates{$table}">
EOT
        } else {
            $template = <<EOT;
 <input type="hidden" name="resulttemplate" value="result.html">
EOT

        }

    }

    if ( $action eq "template" ) {
        %templates = qw(om_users users.html
          om_currencies modcurrency.html
          om_trades displaytransaction.html
          om_yellowpages modifyyellowpage.html
          om_partners modpartners.html
        );
        $template = <<EOT;
 <input type="hidden" name="name" value="$templates{$table}">
EOT
    }

    return $template;
}

# stats and graphing transactions

=head3 get_raw_stats_data


Get trade volumes and averages and deliver to make a javascript Graph chart
This probably also gets delivered into cut down temporary
tables too...

1970-01-01 00:00:01'

tradeStamp(15,2) is minutes
tradeStamp(12,2) is hours
tradeStamp(9,2) is days
tradeStamp(6,2) is month

=cut

sub _format_number {
    my ($number) = @_;

    length($number) == 1 ? ( $number = "0$number" ) : ( $number = $number );
    return $number;
}

sub get_raw_stats_data {

    my ( $class, $db, $from_x_hours_back, $graph_type, $type, $token ) = @_;

    my %configuration = readconfiguration();

    # signals whether empty set of values is delivered
    my $are_there_values = 0;    # returned as 0 or 1

    my @times;
    my @values;

    my %types =
      ( 'minutes', '1,16', 'hours', '1,13', 'days', '1,10', 'month', '1,7' );
    my %axis =
      ( 'minutes', '1,16', 'hours', '9,5', 'days', '1,10', 'month', '1,7' );

    my %configuration = readconfiguration();

    # default is previous two days in hourly increments ;
    $from_x_hours_back ||= 48;
    $type              ||= 'hours';

    # fill the 'missing' sql_string variables
    my $slice   = $types{$type};
    my $x_axis  = $axis{$type};
    my $seconds = $from_x_hours_back * 60 * 60;

    my $sql_string;

    if ( $graph_type eq 'average' ) {
        if ( $configuration{'usedecimals'} eq 'yes' ) {
            $sql_string = <<EOT;
 SELECT tradeStamp, unix_timestamp(tradeStamp), format((avg(tradeAmount)/100),2), substr(tradeStamp,$slice) FROM om_trades o  
   where unix_timestamp(tradeStamp) >= (unix_timestamp()-$seconds) 
   group by substr(tradeStamp,$slice) ORDER BY tradeStamp ;
EOT
        } else {
            $sql_string = <<EOT;
 SELECT tradeStamp, unix_timestamp(tradeStamp), format(avg(tradeAmount),2), substr(tradeStamp,$slice) FROM om_trades o  
   where unix_timestamp(tradeStamp) >= (unix_timestamp()-$seconds) 
   group by substr(tradeStamp,$slice) ORDER BY tradeStamp ;
EOT

        }
    } elsif ( $graph_type = 'volume' ) {

        $sql_string = <<EOT;
SELECT tradeStamp, unix_timestamp(tradeStamp), count(*)/2, substr(tradeStamp,$slice) FROM om_trades o  
   where unix_timestamp(tradeStamp) >= (unix_timestamp()-$seconds) 
   group by substr(tradeStamp,$slice) ORDER BY tradeStamp  ;
EOT

    }

###print "type is $type, sqlstring is $sql_string" ;

    my ( $registry_error, $array_ref ) =
      sqlraw_return_array( $class, $db, $sql_string, undef, $token );

    my @chart_array ;

    foreach my $row (@$array_ref) {
				

	    my $hash_ref = {
                        time  => $row->[1],  # must be a unix time_t
                        value => $row->[2],   # the data value
                        color => 'ff0000',   # optional, used for this one point
                       } ;
        
        push @chart_array, $hash_ref ;

=item cut                       
        my $lookahead = shift(@$array_ref)	;
		my $intervals = int	(($row->[1] - $lookahead->[1]) /600 );                
        
        
        my $time = $lookahead->[1] ;
        foreach my $i (1..($intervals - 1)) {
            $time = $time + 600;
            ###print "time is $time<br/>" ;
            my $hash_ref = {
                        time  => $time,  # must be a unix time_t
                        value =>  0 ,   # the data value
                        color => '0000ff',   # optional, used for this one point
           } ;
           push @chart_array, $hash_ref ;
        }

       unshift  @$array_ref,$lookahead ;                      
=cut
       
    }      
    
    return \@chart_array ;
}


=head3 whos_online

Delivers a count and a list of those online
The count is used for closing down the registry

=cut


sub whos_online {
	
    my ($class,$db,$token) = @_;

    my $get = "SELECT userLogin FROM om_users where userLoggedin = '1' " ;
    my ( $rc, $rv, $array_ref );
    my ( $registryerror, $dbh ) = _registry_connect( $db, $token );
    if ( length($dbh) ) {
        my $sth = $dbh->prepare($get);
        my $rv  = $sth->execute();
        $array_ref = $sth->fetchall_arrayref();
        $sth->finish();
    }
    my $count = scalar($array_ref) ;
    return ( $count, $array_ref );	
	
	
	
}	


=head3 log_entry

Log entry into logging table

=cut



sub log_entry {
	
  my ( $class, $db, $message, $token ) = @_ ;
  
  my $timestamp = sql_timestamp() ;
  my $fieldsref = {} ;
  
  $fieldsref->{'message'} = $message ;
  $fieldsref->{'stamp'}   = $timestamp ;
  
  my ( $error, $record_id ) = add_database_record ( $class, $db, 'om_log', $fieldsref, $token );
  	
  return ($error,$record_id) ;
}	

1;

