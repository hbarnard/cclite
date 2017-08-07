
=head1 NAME

Ccadmin.pm

=head1 SYNOPSIS

Administration actions package

=head1 DESCRIPTION

Administrative actions
Actions on currencies and registries may need to be moved to a secure package
that is not present in the public space!!  This package should possibly
be used and then removed.

WARNING

These are powerful administrative operations, this module
should often be removed from the server once sufficient
registries/currency systems are set up

=head1 AUTHOR

Hugh Barnard


=head1 SEE ALSO

Cclitedb.pm
Ccvalidate.pm
Ccu.pm

=head1 COPYRIGHT

(c) Hugh Barnard 2005 GPL Licenced
 
=cut

package Ccadmin;

use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
use Cclitedb;
use Ccvalidate;
use Ccu;
use Data::Dumper;

# should be a core module both *nix and Windows
# given the problems with this and, from the microsoft doc:

# When you enable command extensions (that is, the default), you can use a single mkdir command to create intermediate directories in a specified
# path. For more information about enabling and disabling command extensions, see cmd in Related Topics.

# use File::Path qw(make_path remove_tree);

my $VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(add_currency
  update_config1
  update_config2
  unlock_user
  add_category
  do_modify_currency
  do_delete_currency
  add_registry
  add_partner
  get_installer_link
  get_locked
  get_logged_in_count
  get_set_batch_files
  go_offline
  go_online
  show_registries
  do_modify_registry
  do_delete_registry
  apply_service_charge
);

=head3 messagehash

this is the provisional solution to the multilingual message fragments
later, it will go somewhere neater
to change these, just substitute a translated hash 

=cut

our %messages    = readmessages();
our $messagesref = \%messages;

=head3 _guess_main_config_values

present fairly sensible configuration values
for a new installation, the current software version is 'guessed' here...

Called guess_main etc. now because there will also be a guess_sms_config etc.
very shortly.

=cut

sub _guess_main_config_values {

    my ( $home, $domain, $hash_type, $currdir ) = @_;
    ###print "root is $ENV{DOCUMENT_ROOT}" ;

    #FIXME: this is ugly, called in main script and called here...
    my ( $os, $distribution, $package_type ) = get_os_and_distribution();

    my %configuration;
    $configuration{multiregistry}          = "no";
    $configuration{domain}                 = $domain;
    $configuration{language}               = "en";
    $configuration{menustyle}              = "notused";
    $configuration{defaultaction}          = "showyellowdir";
    $configuration{linesperpage}           = 15;
    $configuration{initialuserstatus}      = "unconfirmed";
    $configuration{initialpaymentstatus}   = "waiting";
    $configuration{systemmailaddress}      = "cclite\@$domain";
    $configuration{systemmailpassword}     = "not-used";
    $configuration{systemmailreplyaddress} = "cclite\056noreply\@$domain";
    $configuration{templates}              = "${currdir}/templates/html";
    $configuration{net_smtp}               = 1;
    $configuration{ping_interval}          = "notused";
    $configuration{secure}                 = "no";
    $configuration{smtp}                   = $domain;
    $configuration{htmlpath}               = $ENV{DOCUMENT_ROOT};
    $configuration{literalspath}           = "${currdir}/literals";
    $configuration{librarypath}            = "${currdir}lib";
    $configuration{mailpath}               = "\/var\/spool\/mail";
    $configuration{supportmail}            = "support\@$domain";
    $configuration{dbuser}                 = "change-me-please";
    $configuration{dbpassword}             = "change-me-please";
    $configuration{registrypublickey}      = "notused";
    $configuration{userss}                 = "no";
    $configuration{usedecimals}            = "yes";
    $configuration{usetags}                = "yes";
    $configuration{version}                = "0.9.4.1";
    $configuration{servicechargelimit}     = "notused";
    $configuration{smslocal}               = "1";

    # Log4perl configuration file path: modified for // 08/2011
    $configuration{loggerconfig} = "${currdir}config/logging.cf";

    #FIXME: eliminate double separators, check_path?
    $configuration{literalspath} =~ s/\/\//\//;
    $configuration{templates}    =~ s/\/\//\//;

    $configuration{hash_type} = $hash_type;

# base for where to find csv batch files, if $curr contains public_html cpanel assumed
#
    if ( $currdir !~ /public_html/ && $os ne 'windows' ) {
        $configuration{csvpath} = "/var/cclite/batch";

        # cpanel
    } elsif ( $currdir =~ /public_html/ && $os ne 'windows' ) {
        $configuration{csvpath} = "$ENV{DOCUMENT_ROOT}/var/cclite/batch";

        # windows
    } elsif ( $os eq 'windows' ) {

        my $base_directory = $ENV{DOCUMENT_ROOT};

        # strip back to var, from document root, stay with c:\cclite..etc..
        # C:/cclite-0.9.4.1-xp/var/www/cclite/public_html
        # print "base directory is $base_directory\n" ;
        $base_directory =~ s/\/www\/cclite\/public_html//;
        $configuration{csvpath} = "$base_directory/cclite/batch";
    }

    $configuration{csvout} = "$ENV{DOCUMENT_ROOT}/out/csv";

    # base for where to put the registry activity charts
    $configuration{chartdir} = "$ENV{DOCUMENT_ROOT}/images/charts";

    # base for where to put printed output, generated by open office
    $configuration{printdir} = "$ENV{DOCUMENT_ROOT}/out/printed";

    $configuration{smsout} = "$ENV{DOCUMENT_ROOT}/out/sms";

    # default is that gammu processing is with the rest of setup
    $configuration{smslocal} = 1;

    # base rss path, registry and language is added, everything now under 'out'
    $configuration{rsspath} = "$ENV{DOCUMENT_ROOT}/out/rss";

    $home =~ s!protected/ccinstall.cgi!cclite.cgi!;
    $configuration{uhome} = $home;
    return \%configuration;
}

sub _guess_gammu_config_values {

    my ( $home, $domain, $hash_type, $currdir ) = @_;

    my $sms_configuration = {};

    $sms_configuration->{'sponsor4'}       = '';
    $sms_configuration->{'sms_debug_file'} = '/var/cclite/log/sms_debug.txt';
    $sms_configuration->{'registry'}       = '';
    $sms_configuration->{'userpinstatus'}  = 'active';
    $sms_configuration->{'smslocal'}       = 1;
    $sms_configuration->{'smsinpath'}      = '/var/cclite/sms/inbox';
    $sms_configuration->{'smsoutpath'}     = '/var/cclite/sms/outbox';
    $sms_configuration->{'sponsor5'}       = '';
    $sms_configuration->{'sms_prefix'}     = '';
    $sms_configuration->{'os'}             = 'linux';
    $sms_configuration->{'currency'}       = '';
    $sms_configuration->{'domain'}         = '';
    $sms_configuration->{'sponsor3'}       = '';
    $sms_configuration->{'debug'}          = 0;
    $sms_configuration->{'userstatus'}     = 'active';
    $sms_configuration->{'home'}           = $home;
    $sms_configuration->{'smserrorpath'}   = '/var/cclite/sms/error';
    $sms_configuration->{'initialpaymentstatus'}   = 'accepted';
    $sms_configuration->{'sponsor1'}               = '';
    $sms_configuration->{'language'}               = 'en';
    $sms_configuration->{'version'}                = '';
    $sms_configuration->{'distribution'}           = '';
    $sms_configuration->{'sponsor2'}               = '';
    $sms_configuration->{'sponsor_message_status'} = '';
    $sms_configuration->{'smssentpath'}            = '/var/cclite/sms/sent';
    $sms_configuration->{'smssleep'}               = 120;
    $sms_configuration->{'userpasswordstatus'}     = 'active';
    $sms_configuration->{'package_type'}           = '';
    $sms_configuration->{'send_key'}               = 'pay';
    $sms_configuration->{'join_key'}               = 'join';
    $sms_configuration->{'suspend_key'}            = 'suspend';
    $sms_configuration->{'balance_key'}            = 'balance';
    $sms_configuration->{'confirm_key'}            = 'confirm';
    $sms_configuration->{'pinchange_key'}          = 'change';
    $sms_configuration->{'language_key'}           = 'lang';

    return $sms_configuration;
}

=head3 update_configuration


First part of configuration update, guess values and display
All the html has been moved into installvalues.html now, as of 11/2008

FIXME: Tests depend on hardcoded file names, this is fragile, will
break if the config file names are rationalised
 
=cut

sub update_config1 {
    my ( $new_main_install, $new_sms_install, $configuration,
        $sms_configuration, $fields_ref, $dir )
      = @_;
    my ( $title, $template );
    my $type = $fields_ref->{'type'};

    # guess values, if new install otherwise read existing
    if ( $new_main_install && $type eq 'main' ) {
        $fields_ref = _guess_main_config_values(
            $fields_ref->{'home'},
            $fields_ref->{'domain'},
            $fields_ref->{'hash_type'}, $dir
        );
        $fields_ref->{'updatemessage'} .= $messages{newinstall};

    } elsif ( $new_sms_install && $type eq 'gammu' ) {

        $fields_ref = _guess_gammu_config_values(
            $fields_ref->{'home'},
            $fields_ref->{'domain'},
            $fields_ref->{'hash_type'}, $dir
        );
        $fields_ref->{'updatemessage'} .= 'new sms install';

    } else {
        my %fields;
        if ( $type eq 'main' ) {
            %fields = &main::readconfiguration($configuration);
        } else {
            %fields = &main::readconfiguration($sms_configuration);
        }
        $fields_ref = \%fields;
        $fields_ref->{'uhome'} = $fields_ref->{'home'};

        # FIXME: ugly new condition based on 'type'

        print;

        if ( !( -w $configuration ) ) {
            $fields_ref->{'updatemessage'} .=
              "$configuration $messages{cannotbewritten}";
            if ( $configuration =~ /cclite.cf/ ) {
                return ( 0, "", "", $fields_ref, "installvalues.html", "" );
            } elsif ( $configuration =~ /readsms.cf/ ) {
                return ( 0, "", "", $fields_ref, "installgammu.html", "" );
            }
        }
    }

    #FIXME: this is ugly, called in main script and called here...
    (
        $fields_ref->{'os'},
        $fields_ref->{'distribution'},
        $fields_ref->{'package_type'}
    ) = get_os_and_distribution();

    # grey out sendmail path in installer, if windows...
    $fields_ref->{'disablesendmail'} = "disabled=\"disabled\""
      if ( $fields_ref->{'os'} eq 'windows' );

    # complain about hash only for new installs, otherwise too late
    if (   $fields_ref->{'hash_type'} eq "sha1"
        && $new_main_install
        && $configuration =~ /cclite.cf/ )
    {
        $fields_ref->{'updatemessage'} .= "<br/>$messages{sha1warning}";
    }

 # for memory: $refresh, $metarefresh, $error, $fieldsref, $pagename, $cookies )

    if ( $type eq 'main' ) {
        return ( 0, '', '', $fields_ref, "installvalues.html", "" );
    } elsif ( $type eq 'gammu' ) {
        return ( 0, '', '', $fields_ref, "installgammu.html", "" );
    }

}

=head3 update_configuration2

create configuration file, if writable, otherwise display

=cut

sub update_config2 {
    my ( $configuration, $fieldsref ) = @_;

    my %fields = %$fieldsref;
    my ( $html, $token, @registries );

    # write the new configuration to screen with a message
    # if it can't be written directly into the configuration file

    my $configuration_string;    # this holds a cumulated set of text values
                                 # so that people can cut and paste if necessary

    ###print "in config2  $fieldsref->{'type'}\n" ;

    foreach my $key ( sort keys %fields ) {

        next if ( $key =~ /action|saveadd|environment/i );

        #FIXME: kludge to deal with name collision between
        # discovering the installer and what's needed as home
        $fields{$key} =~ s!protected/ccinstall.cgi!cclite.cgi!
          if ( $key eq 'home' );
        $configuration_string .= "$key=$fields{$key}<br/>\n";

    }

    # define something copiable for a cclite.cf that can't be written to...
    # right click copy gives some guidance 10/2009
    $configuration_string = <<EOT;
<br/>
<div id="copydiv">
#============
<br/>
$configuration_string
#============
</div>
<br/>

EOT

    # complain if config is not writable
    if ( -e $configuration && !( -w $configuration ) ) {

        # attempt to change to writable
        system("chmod a+w $configuration");
        if ( !( -w $configuration ) ) {

            my $error =
"<span class=\"failedcheck\">attempted update: $configuration $messages{cannotbewritten}</span>";
            return ( 0, "", $error, \%fields, $configuration_string,
                "result.html", "" );
        }
    }

    # checking for gammu setup, does nominated registry exist, for example
    if ( $fieldsref->{'type'} eq 'gammu' ) {
        @registries =
          show_registries( 'local', $fields{registry}, '', $fieldsref,
            'values', $token );
        my $found = 0;
        foreach my $registry (@registries) {
            if ( $registry eq $fields{'registry'} ) {
                $found = 1;
            }
        }

        # no registry by that name
        if ( !$found ) {
            my $error =
"<span class=\"failedcheck\">attempted update: $configuration $messages{'unknownregistry'}</span>";
            return ( 0, "", $error, \%fields, $configuration_string,
                "result.html", "" );
        }

        # no currency by that name in the given registry
        if (
            !sqlcount(
                'local',         $fields{'registry'},
                'om_currencies', undef,
                'name',          $fields{'currency'},
                $token
            )
          )
        {
            my $error =
"<span class=\"failedcheck\">attempted update: $configuration $messages{'invalidcurrency'}</span>";
            return ( 0, "", $error, \%fields, $configuration_string,
                "result.html", "" );
        }
    }
    eval {
        open( CONFIG, ">$configuration" ) or die $@;
        foreach my $key ( keys %fields ) {

            next if ( $key =~ /action|saveadd|environment/i );

            #FIXME: kludge to deal with name collision between
            # discovering the installer and what's needed as home
            $fields{$key} =~ s!protected/ccinstall.cgi!cclite.cgi!
              if ( $key eq 'home' );

            $fields{$key} =~ s!\s$!!g
              if ( $key =~ /sponsor\d+$/ );

            print CONFIG "$key\=$fields{$key}\n";

        }
        close(CONFIG);

        # attempt to remove  writable
        system("chmod a-w $configuration");

        # but restore for current user: apache
        system("chmod u+w $configuration");
    };
    ###print "error is $@";
    if ($@) {
        die "problem $@ $! trying to write $configuration";
        return ( 0, "", "", "$@ <br/> $!", "result.html", "" );

    } else {

=pod


        my $dberror = check_db_and_version($token);

        if ( length($dberror) ) {
            if ( $dberror =~ /access denied/i ) {
                return ( 0, "", "", \%fields,
                    "$messages{dbpasswordorser} $dberror",
                    "result.html", "" );
            } elsif ( $dberror =~ /can\'t connect/i ) {
                return ( 0, "", "", \%fields,
                    "$messages{mysqlnotrunning} $dberror",
                    "result.html", "" );
            } elsif ( $dberror =~ /innodb/i ) {
                return ( 0, "", "", \%fields,
                    "$messages{wrongdbversion} $dberror",
                    "result.html", "" );
            } else {
                return ( 0, "", "", \%fields, $dberror, "result.html", "" );
            }

            # no db error
        } else {

=cut

        # FIXME: Works but ugly and clumsy condition
        if ( !length( $fields{installer2} )
            && $fields{'action'} ne 'updategammuconfig' )
        {

            return ( 0, "", "", \%fields,
                "$messages{configurationupdated} $configuration",
                "result.html", "" );
        } elsif ( $fields{'action'} eq 'updategammuconfig' ) {
            $fields{'action'} = '';
            return ( 0, undef, undef, \%fields,
                "$messages{configurationupdated} $configuration",
                'result.html', undef );
        } else {

            my $installer_url =
"http://$fields{domain}/cgi-bin/protected/ccinstall.cgi?action=template&name=registry.html";

            return ( 1, $installer_url, "", \%fields,
                $messages{configurationupdated},
                "result.html", "" );
        }

        my (
            $refresh,  $metarefresh, $error,   $html, $pages,
            $pagename, $fieldsref,   $cookies, $token
        ) = @_;

        #       }

    }
}

=head3 add_currency

Create a currency. A currency belongs to a 
a specific registry within the root, this means
that each registry will have a currency record
for currencies that it handles, i.e. duplication

This needs some serious validation in Ccvalidate, no duplicate
currencies, no strange names etc.

=cut

sub add_currency {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my @status;
    $class = "Ccadmin";
    my ( $offset, $limit );    # not used here
                               # check whether currency exists already
                               # currencies are always lower case
                               # currencies are always canonical lower case
    $fieldsref->{name} =
      lc( $fieldsref->{cname} );    # hack to deal with name collision

    my ( $status, $currencyref ) =
      get_where( $class, $db, "om_currencies", '*', "name", $fieldsref->{name},
        $token, $offset, $limit );
    if ( length( $$currencyref{name} ) ) {
        push @status, $messages{currencyrejected};
    }

    my @validate =
      validate_currency( $class, $db, $fieldsref, $messagesref, $token, $offset,
        $limit );
    @status = ( @status, @validate );

    if ( scalar(@status) ) {
        $fieldsref->{errors} = join( "<br/>", @status );
        return ( "1", $fieldsref->{home}, "", $messages{currencyrejected},
            "currency.html", "" );
    }
    $fieldsref->{code} = uc( $fieldsref->{code} );    # codes always uc
    add_database_record( $class, $db, $table, $fieldsref, $token );

    # if not a success, force the major status to cause of failure
    return ( "1", $fieldsref->{home}, "", $messages{currencycreated},
        "result.html", "" );
}

=head3 add_category

Create a yellow pages category 
This is new and flakey at present

Slightly improved as of 07/2007

=cut

sub add_category {

    my ( $class, $db, $table, $fieldsref, $token, $offset, $limit ) = @_;
    my @status;
    $class = "Ccadmin";
    my ( $status, $categoryref ) =
      get_where( $class, $db, "om_categories", '*', "name", $fieldsref->{name},
        $token, $offset, $limit );
    ###print "in create category" ;
    if ( length( $$categoryref{name} ) ) {
        return ( "1", $fieldsref->{home}, "", $messages{categorynameexists},
            "result.html", "" );
    }

    #FIXME: hack to make sure that there's a category number, needs fixing
    $fieldsref->{category} = '1099';

    add_database_record( $class, $db, $table, $fieldsref, $token );

    # if not a success, force the major status to cause of failure
    return ( "1", $fieldsref->{home}, "", $messages{categorycreated},
        "result.html", "" );
}

=head3 do_modify_currency

Modify a currency. A currency belongs to a 
a specific registry within the root, this means
that each registry will have a currency record
for currencies that it handles, i.e. duplication

This needs some serious validation in Ccvalidate, no duplicate
currencies, no strange names etc.

Now operative as of 07/2007 but form is pretty restrictive

=cut

sub do_modify_currency {
    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my @status;
    $class = "Ccadmin";
    my ( $metarefresh, $home, $error, $html, $page, $fieldsref ) =
      update_database_record( $class, $db, $table, 1, $fieldsref,
        $fieldsref->{language}, $token );
    return ( $metarefresh, $home, $error, $html, $page, $fieldsref );

}

=head3 do_delete_currency

Delete a currency from a specific registry.
Means that trading concerning this currency has
stopped in this registry. This may not be a good
idea, has quite a few consequences

=cut

sub do_delete_currency {
    return;
}

=head3 add_registry

Create a registry which will contain user directories. The user directories
contain a record describing the user and a transaction directory which contains
transaction records

Currency must be added after registry creation, currently there's
a default creation of duckets and stars in the registry.sql

Augmented to create fields for remote processing. This registry
record is used to check whether the registry is local. It's
a matter of opinion whether there should be two different processes
one for local, one for remote..messier but more efficient?

Also need to deal with registry merge problem.

=cut

sub add_registry {

    # note, no database name, that's in $fieldsref ;
    # odbc must be defined afterwards for Windows
    # this builds the internal table structure etc.
    # --new approach to this, connection to server only
    # --followed by dbh->do 3/2005

    my ( $class, $db, $table, $configref, $cookieref, $fieldsref, $token ) = @_;

    if ( length( $configref->{'cpanelprefix'} ) ) {
        $fieldsref->{'newregistry'} =
          $configref->{'cpanelprefix'} . '_' . $fieldsref->{'newregistry'};
    }

    my ( $structure, @status );

    my @vstatus =
      validate_registry( $class, $db, $fieldsref, $messagesref, $token, undef,
        undef );    # validate registry fields
     #my $dbh=DBI->connect('dbi:mysql:','username','password', {RaiseError=>1}) or die "Couldn't connect:".DBI->errstr();

    # first try and connect to proposed db to see whether it exists here
    my ( $registryerror, $dbh ) =
      Cclitedb::_registry_connect( $fieldsref->{'newregistry'}, $token );

    # return signature: $refresh,$metarefresh,$error,$html,$pagename,$cookies
    # access denied so wrong password

    if ( $registryerror =~ /access denied/i ) {
        push @status, "$messages{usepassword} <br/> $registryerror";
    }

# new way of finding 'real' registries 8/2010: case insenstive don't want Dalston dalston DalstoN etc...
    my @registries =
      show_registries( $class, '', '', $fieldsref, 'values', $token );

    # won't allow duplicates, will allow dalston1, dalston2 etc.
    my $regex = join( '|', @registries );
    $regex = "\^\($regex\)\$";

    if ( $fieldsref->{'newregistry'} =~ /$regex/i ) {
        push @status, $messages{registryexists};

    }

    # registry connect is not generally exposed...
    # connect to server and create db
    my ( $registryerror, $dbh ) = Cclitedb::_registry_connect( $db, $token );

    # access denied so wrong password
    if ( $registryerror =~ /access denied/i ) {
        push @status, $messages{usepassword};

        # highlight configuraton update
        $fieldsref->{'script'} = <<EOT;
<script>
\$\(\'#updateconfig\').css('color', 'red'); ;
</script>
EOT
    }
    @status = ( @vstatus, @status );
    if ( scalar(@status) ) {

        $fieldsref->{errors} =
          join( "</div><div class=\"failedcheck\">", @status );
        $fieldsref->{errors} =
          "<div class=\"failedcheck\">$fieldsref->{errors}</div>";

        return ( "0", '', "$fieldsref->{errors} ", "", "registry.html", "" );
    }

    # eval block for this 7/2010
    eval {
        if ( length($dbh) )
        {
            $dbh->do("create database if not exists $fieldsref->{newregistry}");
            $dbh->disconnect();
        }
    };
    die "ccinstall: $@" if length($@);

    # connect to db, let Cclitedb, take over prefix handling now...
    $fieldsref->{'newregistry'} =~ s/$configref->{'cpanelprefix'}_//;

    my ( $registryerror, $dbh ) =
      Cclitedb::_registry_connect( $fieldsref->{newregistry}, $token );

    # sql creation is now versioned according to the software version
    # and hash type which decides the hashes for the initial passwords
    my $sqlfile;

    # these just simplify the file path...
    my $hash_type = $configref->{'hash_type'};
    my $version   = $fieldsref->{'version'};

    if (   $hash_type eq 'sha1'
        || $hash_type eq 'sha2' )
    {
        $sqlfile = "../../sql/registry_${version}-${hash_type}.sql";

        # added April 2014 to cover version mismatch
        if ( !-e $sqlfile ) {
            die
"ccinstall: non existent sql file for registry creation: $sqlfile";
        }

    } else {
        die
"ccinstall: bad hash type, must be sha1 or sha2, or perhaps module is missing";
    }

    # and create structure of the new registry database
    if ( length($dbh) ) {
        open( SQL, $sqlfile );

        # break into individual statements
        my @sql = <SQL>;
        my $sql = join( "", @sql );
        @sql = split( /;/, $sql );

        foreach my $statement (@sql) {
            my $sth = $dbh->prepare($statement);
            my $rv  = $sth->execute();
        }
    }

    # add the detailed registry description in om_registry, there now (11/2009)
    # a record in om_registy waiting, deals with cpanel paradox, db created but
    # 'empty' om_registry table...hence stuckage...
    # useid is 1 for using the id field..

    $fieldsref->{name} = $fieldsref->{newregistry};    # for the moment

    # like the highlander, there can only be one (the first record), we hope...
    # watch out for auto-increment when dumping db structures too
    $fieldsref->{id} = 1;

    my (
        $package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
    ) = caller(1);

    # added turn commit limit into pennies if decimal currency 3/2012
    my %configuration = main::readconfiguration();
    $fieldsref->{'commitlimit'} = $fieldsref->{'commitlimit'} * 100
      if ( $configuration{usedecimals} eq 'yes' );

    update_database_record( $class, $fieldsref->{newregistry},
        'om_registry', 1, $fieldsref, 'en', $token );

    # set up directories for all batch processes

    my ( $error, $report_ref, $file_ref ) =
      get_set_batch_files( 'set', $configref, $fieldsref, $cookieref );
    my $display_files = join( "<br/>\n", %$file_ref );

    my $message = <<EOT;
    \u$fieldsref->{newregistry} $messages{registrycreated} <br/>
    <a href="/cgi-bin/cclite.cgi">$messages{nowlogonandcreate}</a>
EOT

    return ( 0, '', $error, $message, 'result.html', '' );

#----------------------------------------------------------------------------------
}

=head3 show_registries

Deduce databases that are probably registries and show them.
This is a heavy and somewhat clumsy operation.

FIXME: $table is used in a confusing way/two declarations...

=cut

sub show_registries {

    # note, no database name, that's in $fieldsref ;
    # odbc must be defined afterwards for Windows
    # looks in all the dbs to find ones with om_ currency table

    my ( $class, $db, $table, $fieldsref, $mode, $token ) = @_;
    my $structure;
    my @registries;
    my $return_url     = $fieldsref->{home};    # that is ccinstall.cgi
    my $registry_count = 0;

    my $message = "$messages{noregistriesfound}";

    # need this for cpanelprefix manipulation
    my %configuration = &main::readconfiguration();

    # registry connect is not generally exposed...
    # connect to server and create db
    my ( $registry_error, $db_array ) =
      sqlraw_return_array( $class, $db, "show databases", "", $token );

    if ( length($registry_error) ) {
        $table = $registry_error;
    } else {
        foreach my $db_rec (@$db_array) {

            #FIXME: remove cpanel prefix added twice, if it exists
            $db_rec->[0] =~ s/$configuration{'cpanelprefix'}\_//;
            my ( $registry_error, $table_array ) =
              sqlraw_return_array( $class, $db_rec->[0], "show tables", "",
                $token );

            foreach my $table_rec (@$table_array) {
                if ( $table_rec->[0] =~ /om_currencies/ ) {
                    $registry_count++;
                    push @registries, $db_rec->[0];
                    last;
                }
            }
        }
    }

    if ( $mode eq 'html' ) {
        my $table;
        if ( $registry_count > 0 ) {

            # make a table for the registries

            foreach my $registry (@registries) {

                $table .= <<EOT;
<tr><td><a title="logon to $registry" href="/cgi-bin/cclite.cgi">$registry</a></td></tr>
EOT

            }

            $message =
"$messages{followingregistries}<br/><br/><table border>$table</table>";

        }

        return ( 0, '', "", $message, "result.html", "" );

    } elsif ( $mode eq 'values' ) {
        return @registries;
    } else {
        carp('unkown mode for registry display');
    }

#----------------------------------------------------------------------------------
}

=head3 add_partner

Add a partner to the partner table
$class added to some routines for cclite web services access

FIXME: no test on existence of local partner or remote partner...

=cut

sub add_partner {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( $refresh, $error, $html, $cookies, $offset, $limit );
    my $class = "Cclitedb";
    my @status;
    my $hash       = "";                 # for the moment, needs sha1 afterwards
    my $return_url = $fieldsref->{home};
    @status =
      validate_partner( $class, $db, $fieldsref, $messagesref, $token, "", "" );

    # test for duplicate registry name
    my ( $status, $partnerref ) =
      get_where( $class, $db, "om_partners", '*', "name", $fieldsref->{dname},
        $token, $offset, $limit );
    push @status, $$messagesref{partnerexists} if ( length($partnerref) );
    if ( scalar(@status) ) {
        $fieldsref->{errors} = join( "<br/>", @status );
        return ( "0", '', "", $html, "partners.html", "" );
    }
    my ( $date, $time ) = getdateandtime();
    $fieldsref->{date} = $date;

    # dname in form to avoid name collision
    $fieldsref->{name} = $fieldsref->{dname};

    #
    # add to the  database
    my ( $rc, $rv, $record_id ) =
      add_database_record( $class, $db, $table, $fieldsref, $token );

    return ( "0", '', $error, $messages{partneradded}, "result.html", "" );
}

=head3 process_batch_transactions

Take batch transactions, mainly out of emailed csv records
and move them into a local registry, as 'waiting'. For the moment
they'll need approval afterwards

this will only accept transactions within a single registry and
currency at present

Development is stalled on this bit as of 8/8/2005, for example

=cut

sub process_batch_transactions {
    my ( $class, $db, $table, $filename, $token ) = @_;

    # open file and strip off mail fields
    # get columns from om_trades and form hash with the table

    # update om_trades records as waiting

    return;
}

=head3 do_delete_registry

Delete a registry
Means that trading concerning this all currencies has
and users has stopped. This may not be a good
idea, has quite a few consequences

To be implemented as a move to an invalid database name, perhaps

=cut

sub do_delete_registry {
    return;
}

=head3 apply_service_charge

Apply the given amount, in the given currency
to all accounts except the sysaccount. This will generate an individual line
in the sysaccount at present

=cut

sub apply_service_charge {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;
    my ( @status, %transaction, $html );
    @status =
      validate_service_charge( $class, $db, $fieldsref, $messagesref, $token,
        undef, undef );

    if ( scalar(@status) ) {
        $fieldsref->{errors} = join( "<br/>", @status );
        return ( "0", $fieldsref->{home}, undef, $html, "servicechg.html",
            $fieldsref, undef );
    }

    # look for sysaccount, return if not found
    my ( $status, $userref ) = get_where(
        $class,      $db,          "om_users", '*',
        "userLevel", "sysaccount", $token,     undef,
        undef
    );

    # no sysaccount found or database problem

    if ( !length( $$userref{userId} ) || length($status) ) {
        $fieldsref->{errors} = "$messages{nosysaccount}  or $status";
        return ( "0", $fieldsref->{home}, undef, "", "servicechg.html",
            $fieldsref, undef );
    }

    my $sysaccount = $$userref{userLogin};

    # set up transaction
    # these are all the fixed fields for a service charge
    #fromregistry : chelsea
    $transaction{fromregistry} = $db;

    $transaction{home}      = "";            # no home, not a web transaction
                                             #subaction : om_trades
    $transaction{subaction} = 'om_trades';

    #toregistry : chelsea
    $transaction{toregistry} = $db;

#tradeAmount : 23, note conversion to 'pennies' done in the transaction itself, if using decimals...
    $transaction{tradeAmount} = $fieldsref->{value};

    #tradeCurrency : ducket
    $transaction{tradeCurrency} = $fieldsref->{tradeCurrency};

    #tradeDate : this is date of reception and processing, in fact
    my ( $date, $time ) = Ccu::getdateandtime( time() );
    $transaction{tradeDate} = $date;

    #tradeTitle : added by this routine
    $transaction{tradeTitle} = $fieldsref->{title};

    #tradeDescription
    $transaction{tradeDescription} = $fieldsref->{description};

    #tradeDestination : ddawg
    $transaction{tradeDestination} = $sysaccount;

    #tradeDestination :
    $transaction{tradeType} = 'debit';

    #tradeDestination :
    $transaction{tradeStatus} = 'accepted';

    #tradeDestination : not a true trade
    $transaction{tradeItem} = 'other';

    # end of setup

    my ( $registry_error, $user_hash_ref ) = get_where_multiple(
        $class, $db,   'om_users', '*', 'userLevel', 'user',
        $token, undef, undef
    );
    my $colspan;
    my $count = scalar( ( keys %$user_hash_ref ) ); # count the records returned
    my $maxi;

    # apply transaction to each user level user, not sysaccount or admin
    foreach my $key ( keys %$user_hash_ref ) {

        #tradeItem : test to see variables
        #tradeSource : current user
        $transaction{tradeSource} = $user_hash_ref->{$key}->{'userLogin'};

        # call ordinary transaction
        my $transaction_ref = \%transaction;

        # do a service charge transaction on each non-admin non-sysaccount user
        my ( $metarefresh, $home, $error, $output_message, $page, $c ) =
          Cclite::transaction( 'service', $transaction{fromregistry},
            'om_trades', $transaction_ref, undef, $token );
        ### print "error is $error $output_message <br/>" ;

    }

    $html =
"$$messagesref{servicechargeapplied} $fieldsref->{value} $fieldsref->{tradeCurrency} : $db";

    return ( "1", $fieldsref->{home}, undef, $html, "result.html" );

    # now condense system account records into one record if required

}

=head3 get_set_batch_files

For the moment, just get a list of all the assumptions
about batch files. Next iteration get statuses, exists, readable etc.

# Now with make_path should work for most OSes 12/2009: backed out 10/2010

=cut

sub get_set_batch_files {

    my ( $operation, $configref, $fieldsref, $cookieref ) = @_;

    my $error;

# FIXME: this is not quite right, get should use cookies, set newregistry, probably
    my $registry = $cookieref->{'registry'} || $fieldsref->{newregistry};
    my $language = $cookieref->{'language'} || $configref->{'language'} || 'en';

    my %configuration = %$configref;

    #FIXME: hack for database prefix in cpanel,
    # we want pretty directory names for the paths...
    if ( length( $configuration{'cpanelprefix'} ) ) {
        $registry =~ s/$configuration{'cpanelprefix'}\_//;
    }

    my ( %file, %report, $html );

    # make a subdirectory for graphs etc...
    $file{chartdir} = "$configuration{chartdir}/$registry";

    # make a subdirectory for rss feeds of form
    $file{rssdir} = "$configuration{rsspath}/$registry/$language";

    # make a subdirectory for printed documents, small ads, member lists
    $file{printdir} = "$configuration{printdir}/$registry/$language";

    # make a subdirectory for batch in and results out
    $file{csvdir} = "$configuration{csvpath}/$registry";
    $file{csvout} = "$configuration{csvout}/$registry";

    # make a subdirectory for gammu and results out
    $file{smsdir} = "$configuration{smspath}/$registry";
    $file{smsout} = "$configuration{smsout}/$registry";

#FIXME: due to backed out file path, this is reintroduced, move to top of module
# may have to deal with Windows backslash below too..
    my ( $os, $distribution, $package_type ) = get_os_and_distribution();

    my $err_list;

    if ( $operation eq 'set' ) {
        eval {
            foreach my $key ( sort keys %file )
            {
                if ( $os ne 'windows' ) {
                    `mkdir -p $file{$key}`;
                } else {
                    `mkdir $file{$key}`;
                }
            }
        };
        if ($@) {
            $error = "$@ $!";
        }
    }

    # report whether get or set, modified 12/2009

    my $first_pass = 1;
    foreach my $key ( sort keys %file ) {
        $report{$key} = "$messages{doesnotexist}, " if ( !-e $file{$key} );
        $report{$key} .= $messages{cannotbewritten} if ( !-w $file{$key} );

        ###if ( length( $report{$key} ) && $operation eq 'get' ) {
        if ( length( $report{$key} ) ) {
            my $start_literal = "$messages{batchfileproblems} $err_list <br/>"
              if ($first_pass);
            $first_pass = 0;

# mark with red and explanation when reporting, if it doesn't exist or is not writable
            $report{$key} = <<EOT;
<span title="$file{$key} $report{$key}" class="errors">$start_literal $key</span>
EOT

        }
    }

    return ( $error, \%report, \%file );

}

=head2 get_logged_in 

Get the count and names of those logged in
for preparing to put registry offline

=cut

sub get_logged_in_count {

    my ( $class, $db, $table, $fieldsref, $token ) = @_;

    # get count and list of whos online
    my ( $count, $login_array_ref ) = whos_online( $class, $db, $token );

    # -1 because admin is logged in to be able to do this!
    return ( $count - 1 );
}

=head2 go_offline

Bring down one registry, move registry record into state 'down'
FIXME: needs to deliver errors and this is a weakness in update_database_record

=cut

sub go_offline {
    my ( $class, $db, $table, $useid, $fieldsref, $language, $token ) = @_;

    $fieldsref = { 'id' => '1', 'status' => 'closing' };

    ###debug_message('in go offline routine') ;

    # get count and list of whos online
    my ( $count, $login_array_ref ) = whos_online( $class, $db, $token );

    update_database_record( 'local', $db, 'om_registry', 1, $fieldsref,
        $language, $token );

    return ( "0", '', '', $messages{'registryclosing'}, "result.html", undef );
}

=head2 go_online

Bring up one registry, move registry record into state 'open'
FIXME: needs to deliver errors and this is a weakness in update_database_record

=cut

sub go_online {
    my ( $class, $db, $table, $useid, $fieldsref, $language, $token ) = @_;

    $fieldsref = { 'id' => '1', 'status' => 'open' };
    update_database_record( 'local', $db, 'om_registry', 1, $fieldsref,
        $language, $token );

    return ( "0", '', '', $messages{'registryopen'}, "result.html", undef );
}

=head2 get_installer_link

Get the menu link for the installer, for ccadmin.cgi, not displayed if not present

=cut

sub get_installer_link {

    my $link = <<EOT;
<a class="bodytext" title="Registry and Configuration Installer" href="/cgi-bin/protected/ccinstall.cgi">Installer</a>
EOT

    return $link;
}

=head3 display_gammu_config

FIXME: This is an ugly hack to deal with the increasing complexity
of setting up gammu:

1. All gammu values moved to readsms.cf
2. Displayed and updatable here in the same way as main config

=cut

sub display_gammu_config {

    my $parameter_html_line = <<EOT;
<tr><td title="" class="menu">dbuser</td><td class="pme-key-1">
    <input id="dbuser" data-simple="yes" type="text" class="required" name="dbuser" size="60" value="">
</td></tr>

EOT

    return;

}

=head3 get_locked

Get users where the pin and/or password is locked
display as table to unlock

FIXME: html and literals etc. in here, this is first
cut as of February 2014

=cut

sub get_locked {

    my ( $class, $registry, $fields_ref, $token ) = @_;

    #print "$class, $registry, $fields_ref, $token" ;
    #print Dumper $fields_ref ;
    my $html;
    my $header =
"<tr><td>$messages{'unlockall'}</td><td>userPinStatus</td><td>userPasswordStatus</td><td>userStatus</td></tr>";

    my ( $registry_error, $hash_ref ) = sqlraw(
        $class,
        $registry,
'select userId,userPinStatus,userPasswordStatus,userLogin, userStatus from om_users where (userPinStatus = \'locked\' or userPasswordStatus = \'locked\' or userStatus = \'suspended\')',
        'userId',
        $token
    );

    if ( !$registry_error ) {

        if ( $fields_ref->{'mode'} eq 'json' ) {

        } elsif ( $fields_ref->{'mode'} eq 'html' ) {

            foreach my $key ( sort keys %$hash_ref ) {
                my $line .= <<EOT;
<tr><td><a title="Unlock All" href="/cgi-bin/protected/ccadmin.cgi?action=unlockuser&type=all&userId=$hash_ref->{$key}->{'userId'}&mode=html">$hash_ref->{$key}->{'userLogin'}</a></td>
    <td><a title="Unlock SMS Pin" href="/cgi-bin/protected/ccadmin.cgi?action=unlockuser&type=pin&userId=$hash_ref->{$key}->{'userId'}&mode=html">$hash_ref->{$key}->{'userPinStatus'}</a></td>
    <td><a title="Unlock Password" href="/cgi-bin/protected/ccadmin.cgi?action=unlockuser&type=password&userId=$hash_ref->{$key}->{'userId'}&mode=html">$hash_ref->{$key}->{'userPasswordStatus'}</a></td>
    <td><a title="Undo Suspend" href="/cgi-bin/protected/ccadmin.cgi?action=unlockuser&type=userstatus&userId=$hash_ref->{$key}->{'userId'}&mode=html">$hash_ref->{$key}->{'userStatus'}</a></td>
</tr>
EOT

                $html .= $line;

            }

        } elsif ( $fields_ref->{'mode'} eq 'values' ) {

            # FIXME: not implemented currently, mabye not useful

        }

    } else {
        return "nok: $registry_error";
    }

    return ( undef, undef, undef,
        "<table id=\"transtable\">$header<tbody>$html</tbody></table>",
        'result.html', undef );
}

=head3 unlock_user

Unlock locked pins, passwords and suspended users

=cut

sub unlock_user {

    my ( $class, $registry, $fields_ref, $token ) = @_;

    ###print Dumper $fields_ref ;

    $fields_ref->{'userPasswordStatus'} = 'active'
      if ( $fields_ref->{'type'} eq 'all'
        || $fields_ref->{'type'} eq 'password' );
    $fields_ref->{'userPinStatus'} = 'active'
      if ( $fields_ref->{'type'} eq 'all' || $fields_ref->{'type'} eq 'pin' );
    $fields_ref->{'userStatus'} = 'active'
      if ( $fields_ref->{'type'} eq 'all'
        || $fields_ref->{'type'} eq 'userstatus' );

    my ( $a, $b, $c, $d ) =
      update_database_record( 'local', $registry, "om_users", 1, $fields_ref,
        undef, $token );

    return get_locked( $class, $registry, $fields_ref, $token );
}

1;

