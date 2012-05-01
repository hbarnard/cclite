#!/usr/bin/perl



use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More "no_plan";
use Test::Exception;
use Getopt::Long;
use Data::Dumper;

# generate random transaction amount

our %control_total ;

sub readconfiguration {

    my $configfile = 'test.cf';
    my %configuration ;
    
    if ( -e $configfile ) {
        open( CONFIG, $configfile );
        while (<CONFIG>) {
            s/\s$//g;
            next if /^#/;
            my ( $key, $value ) = split( /\=/, $_ );
            if ($value) {
                $key =~ lc($key);    #- make key canonic, all lower
                $configuration{$key} = $value if ( length($value) );
            }
            $key   = "";
            $value = "";
        }
    } elsif ( !-e $configfile && $0 =~ /ccinstall/ ) {
        return;
    } else {

        die 'test.cf not found' ;
    }
    return %configuration;
}


sub generate_random_amount {
 
my $x  =   sprintf( "%.2f", rand(100) );   
#if ($usedecimals ne 'yes') {    
#$x = int($x) ;
#} 
 
return $x    

}    

# generate random sleep time
sub generate_random_sleep {
 
my $x  =   int(rand(600));
return $x        

}    


sub test_volume_ng {

my ($sel, $iteration) = @_ ;

my @users = qw(test2 test3) ;
my @currencies = qw(Lime Dally Tpound) ;

my $x = 1 ; 

my ($amount, $currency, $user) ;

while ($x <= $iteration) {
foreach $user (@users) {

 
 # ugly...
 my $destination ;
 ($user eq 'test2') ? ($destination = 'test3') : ($destination = 'test2') ;
   
 foreach $currency (@currencies) {  
  $amount = generate_random_amount() ;  
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", 'dalston');
$sel->type_ok("userLogin", $user);
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("tradeDestination", $destination);
$sel->select_ok("toregistry", "label=Dalston");
$sel->select_ok("tradeCurrency", "label=$currency");
$sel->type_ok("tradeAmount", $amount);
$sel->type_ok("tradeTitle", "random continuous: send 10 dallies to test3");
$sel->type_ok("tradeDescription", "random continuous testing");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");    
    

my $sleep = generate_random_sleep() ;    
sleep  $sleep ; 

 $control_total{$user}{$currency} += $amount ;
    
 } #end foreach currencies
 
 
 
} # end foreach users


$x++ ;

} #endwhile
 
return ;   
 
}    


sub test_volume {
# logon test1 to dalston, send 10 dallies to test2
# and logoff
 my ($usedecimals,$iteration, $sel, $type, $sleep, $registry1) = @_ ;

my $x = 1 ; 

while ($x <= $iteration) {
    
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test2");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("tradeDestination", "test3");
$sel->select_ok("toregistry", "label=\u$registry1") ;
$sel->select_ok("tradeCurrency", "label=Dally");

if ($usedecimals eq 'yes') {
# ugly hack to use iteration as 'pennies' f decimals turned on...
 $sel->type_ok("tradeAmount", "10\.$x");
} else {
 $sel->type_ok("tradeAmount", "10");
}


$sel->type_ok("tradeTitle", "$x of $iteration: send 10 dallies to test3");
$sel->type_ok("tradeDescription", "testing");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");


    
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test3");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("tradeDestination", "test2");
$sel->select_ok("toregistry", "label=\u$registry1") ;
$sel->select_ok("tradeCurrency", "label=Dally");

if ($usedecimals eq 'yes') {
# ugly hack to use iteration as 'pennies' f decimals turned on...
 $sel->type_ok("tradeAmount", "5\.$x");
} else {
 $sel->type_ok("tradeAmount", "5");
}


$sel->type_ok("tradeTitle", "$x of $iteration: send 5 dallies to test2");
$sel->type_ok("tradeDescription", "testing");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);    
$control_total{'test3'}{'dally'} += 5 ;       
$x++ ;    
    
}
 return ;

}

#====================================================================================================

# values first of all come from test.cf and then overridden by command line options
our %configuration = readconfiguration() ;

# setup all defaults values, trunk testing is default
my $type     		= $configuration{'type'} ;
# english language default
my $language      	= $configuration{'language'} ;
# test scope = all, all tests can be just volume, to test graphs, for example
my $scope 			= $configuration{'scope'} ;
#  no snapshots
my $snapshots 		= $configuration{'snapshots'} ;
#  sleep
my $sleep 			= $configuration{'sleep'} ;
# test for pretty names in cpanel...
our $cpanelprefix 	= $configuration{'cpanelprefix'} ;
# use decimal point currencies
our $usedecimals    = $configuration{'usedecimals'} ;
# local logging file
our $logg 			= $configuration{'logg'} ;
# two registry names 
my $registry1 		= $configuration{'registry1'} ;
my $registry2 		= $configuration{'registry2'} ;
# dbuser and password
my $dbuser 			= $configuration{'dbuser'} ;
my $dbpassword      = $configuration{'dbpassword'} ;
# path for saving images
my $image_path 		= $configuration{'image_path'} ;
my $image_key       = $configuration{'image_key'} ;
# mailboxes
my $admemail 		= $configuration{'admemail'} ;
my $admpass 		= $configuration{'admpass'};
my $postemail 		= $configuration{'postemail'};
my $postpass 		= $configuration{'postpass'};

my $url ;  # decided by test below
#======================================================================================================== 

# these options can override the configured options

GetOptions(
    'type=s'            => \$type,
    'language=s'        => \$language,
    'scope=s'           => \$scope,
    'snapshots=s'       => \$snapshots,
    'sleep=i'           => \$sleep,
    'usedecimals=s'     => \$usedecimals,
    'log=s'				=> \$logg,
    'registry1=s'		=> \$registry1,
    'registry1=s'		=> \$registry2,
    'dbuser=s'			=> \$dbuser,
    'dbpassword=s'		=> \$dbpassword,
    'usedecimals=s'		=> \$usedecimals,
    'cpanelprefix=s'	=> \$cpanelprefix,
    'url=s'				=> \$url,
    
) or die "Incorrect usage!\n";


if ( $type !~ /cpanel|fedora|deb|trunk|xp/ ) {
    print "unknown type must be one of: cpanel fedora deb trunk xp\n" ;
    exit 0 ;
}

if ( $scope !~ /all|volume|random/ ) {
    print "unknown scope must be all, volume or random\n" ;
    exit 0 ;
}

if ($type eq 'trunk') {
    $url 			= $configuration{'trunkurl'} ;
} elsif ($type eq 'deb') {
    $url 			= $configuration{'deburl'} ;
} elsif ($type eq 'cpanel') { 
# amended for pretty-print databases and open system testing area...    
    $dbuser 		= $configuration{'cpaneldbuser'} ;
    $dbpassword     = $configuration{'cpaneldbpassword'} ;
    $url 			= $configuration{'cpanelurl'} ;
} elsif ($type eq 'fedora') {
   $url 			= $configuration{'fedoraurl'} ;   
} elsif ($type eq 'xp') {
    $url 			= $configuration{'xpurl'} ;
    # use standard remote mailboxes
    $admemail = "hbarnard\@cclite.xp.server" ;
    $admpass = 'bryana1' ;
    $postemail = "hbarnard\@cclite.xp.server" ;
    $postpass = 'bryana1' ;
}    


if ($logg eq 'yes') {
	
open(LOG,">test.log");

*STDERR = *LOG;
*STDOUT = *LOG;

}

my $sel = Test::WWW::Selenium->new( host => $configuration{'host'}, 
                                    port => $configuration{'port'}, 
                                    browser => $configuration{'browser'}, 
                                    browser_url =>  $url );



#  just test volume of transactions and exit...
if ($scope eq 'random') {
test_volume_ng ($sel,$configuration{'randomcount'})  ;
 exit 0 ; 
}

#  just test volume of transactions and exit...
if ($scope eq 'volume') {
test_volume ($usedecimals, $configuration{'volumecount'}, $sel, $type, $sleep, $registry1)  ;
 exit 0 ; 
}

# print control total structure, doesn't work really
open ( my $ctl,'>>','control_totals.txt') ;
print "after volume and random\n" ;
print $ctl Dumper %control_total ;
close $ctl ;

#check that the install checker is on-line
$sel->open_ok("/cgi-bin/protected/ccinstall.cgi");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=installcheck");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep);

# check that installer is online, open up for all options,
# change users to active, so that they can be testedout with emails..

$sel->open_ok("/cgi-bin/protected/ccinstall.cgi");
$sel->select_ok("id=install_type", "label=All Options");
$sel->type_ok("initialuserstatus", "active");

# cpanel expected install with no extra modules...
if ($type ne 'cpanel') {
$sel->type_ok("multiregistry", "yes");
}


$sel->type_ok("dbuser", $dbuser);
$sel->type_ok("dbpassword", $dbpassword);
$sel->type_ok("cpanelprefix", $cpanelprefix) if (length($cpanelprefix)) ;
$sel->type_ok("usedecimals", $usedecimals) if (length($usedecimals))  ;
$sel->submit("form") ;

# take a picture
`import -window root  $image_path/${image_key}.png`  if ($snapshots) ;
$image_key++ ;

sleep($sleep);

$sel->click_ok("link=Update Configuration");

sleep($sleep);

if ($type ne 'cpanel') {
    
#create dalston registry
$sel->open_ok("/cgi-bin/protected/ccinstall.cgi?action=showregistries");
$sel->click_ok("link=Create New Registry");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("//input[\@name='newregistry']", $registry1);
$sel->type_ok("//input[\@name='description']", "$registry1 Registry");
$sel->type_ok("admemail", $admemail);
$sel->type_ok("admpass", $admpass);
$sel->type_ok("postemail", $postemail);
$sel->type_ok("postpass", $postpass);
$sel->type_ok("commitlimit", "10000");
$sel->type_ok("merchant_key", "1234");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

} else {

# modify existing dalston registry for cpanel    
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

$sel->click_ok("link=Modify $registry1");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("//input[\@name='description']", "\u$registry1 Registry");
$sel->type_ok("admemail", "cclite.dalston\@cclite.cclite.k-hosting.co.uk");
$sel->type_ok("admpass", "caca");
$sel->type_ok("postemail", "cclite.dalston\@cclite.cclite.k-hosting.co.uk");
$sel->type_ok("postpass", "caca");
$sel->type_ok("commitlimit", "1000000");
$sel->type_ok("merchant_key", "123456");
$sel->type_ok("latest_news", "news from $registry1");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("id=logoff");
               
}


#exit 0;

sleep($sleep);

# logon at dalston
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form");
$sel->wait_for_page_to_load_ok("30000");


`import -window root  $image_path/${image_key}.png` if ($snapshots) ;
$image_key++ ;

# create dally at dalston
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Dally");
$sel->type_ok("code", "DAL");
$sel->type_ok("//input[\@name='description']", "\u$registry1 Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form");
$sel->wait_for_page_to_load_ok("30000");

# create lime at dalston
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Lime");
$sel->type_ok("code", "LIM");
$sel->type_ok("//input[\@name='description']", "\u$registry2 Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form");
$sel->wait_for_page_to_load_ok("30000");

# create totnes pound at dalston
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Tpound");
$sel->type_ok("code", "TPD") ;
$sel->type_ok("//input[\@name='description']", "Totnes Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("id=logoff");

sleep($sleep) ;

`import -window root  $image_path/${image_key}.png`if ($snapshots)  ;
$image_key++ ;


#create limehouse registry
if ($type ne 'cpanel') {
    
$sel->open_ok("/cgi-bin/protected/ccinstall.cgi?action=showregistries");
$sel->click_ok("link=Create New Registry");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("//input[\@name='newregistry']", $registry2);
$sel->type_ok("//input[\@name='description']", "\u$registry2 Registry");
$sel->type_ok("admemail", $admemail);
$sel->type_ok("admpass", $admpass);
$sel->type_ok("postemail", $postemail);
$sel->type_ok("postpass", $postpass);
$sel->type_ok("commitlimit", "10000");
$sel->type_ok("merchant_key", "1234");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

} else {

# modify existing limehouse registry for cpanel    
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry2);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

$sel->click_ok("link=Modify $registry2");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("//input[\@name='description']", "$registry2 Registry");
$sel->type_ok("admemail", "cclite.limehouse\@cclite.cclite.k-hosting.co.uk");
$sel->type_ok("admpass", "caca");
$sel->type_ok("postemail", "cclite.limehouse\@cclite.cclite.k-hosting.co.uk");
$sel->type_ok("postpass", "caca");
$sel->type_ok("commitlimit", "1000000");
$sel->type_ok("merchant_key", "123456");
$sel->type_ok("latest_news", "news from $registry1");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("id=logoff");

sleep($sleep);
    
}


# create limehouse as a local partner for dalston
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Create Registry Partner");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=dname", $registry2);
$sel->type_ok("name=email", "hugh.barnard\@gmail.com");
$sel->select_ok("name=type", "local");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("id=logoff");

sleep($sleep);

# logon at limehouse
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry2);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

# create dally at limehouse
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Dally");
$sel->type_ok("code", "DAL");
$sel->type_ok("//input[\@name='description']", "Dalston Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

# create lime at limehouse
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Lime");
$sel->type_ok("code", "LIM");
$sel->type_ok("//input[\@name='description']", "Limehouse Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

# create totnes pound at limehouse
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=currency.html");
$sel->type_ok("cname", "Tpound");
$sel->type_ok("code", "TPD") ;
$sel->type_ok("//input[\@name='description']", "Totnes Local");
$sel->type_ok("mail", "hugh.barnard\@googlemail.com");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("id=logoff");

sleep($sleep) ;

# create dalston as a local partner for limehouse
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry2);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Create Registry Partner");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=dname", $registry1);
$sel->type_ok("name=email", "hugh.barnard\@gmail.com");
$sel->select_ok("name=type", "local");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");


sleep($sleep);

# try to create non existent as a local partner for limehouse, should fail
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi?action=template&name=partners.html");
$sel->type_ok("dname", "fugggghl");
$sel->type_ok("email", "hugh.barnard\@googlemail.com");
$sel->select_ok("type", "label=local");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

# logoff from limehouse

$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep);


# test change language: not logged in

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->open_ok("/cgi-bin/cclite.cgi?action=lang&language=zh");
$sel->wait_for_page_to_load_ok("30000");
$sel->open_ok("/cgi-bin/cclite.cgi?action=lang&language=el");
$sel->wait_for_page_to_load_ok("30000");
$sel->open_ok("/cgi-bin/cclite.cgi?action=lang&language=es");
$sel->wait_for_page_to_load_ok("30000");
$sel->open_ok("/cgi-bin/cclite.cgi?action=lang&language=en");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

# test1 account for dalston
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry1);
$sel->type_ok("nuserLogin", "test1");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hugh.barnard\@googlemail.com");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "447779159451");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
# public key id
$sel->type_ok("userPublickeyid", "51E7D8C9");
$sel->type_ok("userName", "Number One");
$sel->submit("form") ;

sleep($sleep);

#test 2 account for dalston

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry1);
$sel->type_ok("nuserLogin", "test2");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hughbarnardlists\@yahoo.co.uk");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "447779159452");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
# public key id
$sel->type_ok("userPublickeyid", "51E7D8C9");
$sel->type_ok("userName", "Number Two");
$sel->submit("form") ;

sleep($sleep);

#test 3 account for dalston
# invalid email

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry1);
$sel->type_ok("nuserLogin", "test3");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hugh.barnard\@laposte.net");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "447779159453");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
$sel->type_ok("cuserPin", "2323");
# public key id
$sel->type_ok("userPublickeyid", "51E7D8C9");
$sel->type_ok("userName", "A N Other");
$sel->submit("form") ;

sleep($sleep);

#test 7 account for dalston
# email for receiving jabber payments

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry1);
$sel->type_ok("nuserLogin", "test7");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hughbar\@jabber.org.uk");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "447779159457");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
# public key id
$sel->type_ok("userPublickeyid", "51E7D8C9");
$sel->type_ok("userName", "Number Seven");
$sel->submit("form") ;

sleep($sleep);

#test accounts for limehouse
# same emails as dalston throughout
# mobile number is 5 = 5555 55555555 etc.

# test4 account for limehouse
# has incorrect phone changed to 4444 444444 later in test
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry2);
$sel->type_ok("nuserLogin", "test4");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hughbarnardlists\@yahoo.co.uk");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "1234 123456");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
$sel->type_ok("userName", "Hugh Barnard");
$sel->submit("form") ;

sleep($sleep);

#test 5 account for limehouse
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry2);
$sel->type_ok("nuserLogin", "test5");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "hugh.barnard\@googlemail.com");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "5555 555555");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
$sel->type_ok("userName", "Hugh Barnard");
$sel->submit("form") ;

sleep($sleep);

#test 6 account for limehouse
# invalid email

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("link=New Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("chooseregistry", $registry2);
$sel->type_ok("nuserLogin", "test6");
$sel->type_ok("userPassword", "password");
$sel->type_ok("cuserPassword", "password");
$sel->type_ok("userEmail", "no.one\@googlemail.com");
$sel->type_ok("userNameornumber", "23");
$sel->type_ok("userStreet", "Kiln Court Newell Street");
$sel->type_ok("userTown", "L");
$sel->type_ok("userTown", "London");
$sel->type_ok("userArea", "London");
$sel->type_ok("userPostcode", "E14 7JP");
$sel->type_ok("userTelephone", "0207 005 0957");
$sel->type_ok("userMobile", "6666 666666");
$sel->type_ok("userPin", "2323");
$sel->type_ok("cuserPin", "2323");
$sel->type_ok("userName", "Hugh Barnard");
$sel->submit("form") ;

sleep($sleep);

# logon test1 to dalston, send 10 dallies to test2
# and logoff

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test1");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("tradeDestination", "test2");
$sel->select_ok("toregistry", "label=\u$registry1") ;
$sel->select_ok("tradeCurrency", "label=Dally");
$sel->type_ok("tradeAmount", "10");
$sel->type_ok("tradeTitle", "send 10 dallies to test2");
$sel->type_ok("tradeDescription", "testing");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

#change language, if mentioned
#
if (length($language)) {
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->select_ok("id=language_value", "label=$language");
sleep($sleep);
}
#
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);


# logon to test1 and change password, log off, logon with new password and change
# back

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test1");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;

$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("userPassword", "newpassword");
$sel->type_ok("confirmPassword", "newpassword");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");

sleep($sleep);

# logon with new password
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test1");
$sel->type_ok("userPassword", "newpassword");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

# change back newpassword to password
print "change test1 password back to old value" ;

$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("userPassword", "password");
$sel->type_ok("confirmPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("logoff");
sleep($sleep);


# change sms receipt for test2 on 
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test2");
$sel->type_ok("userPassword", "password");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("userSmsreceipt");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");

#change language, if mentioned
#
if (length($language)) {
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->select_ok("id=language_value", "label=$language");
sleep($sleep);
}
#


=item cut
# turn sms receipts for test2 off
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("userSmsreceipt");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");
=cut

$sel->click_ok("logoff");
sleep($sleep);

#login to manager and change password and back again

=item cut

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form") ;

$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("userPassword", "password");
$sel->type_ok("confirmPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");

#
sleep($sleep);

# logon with new password
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

# change back newpassword to password
print "change test1 password back to old value" ;

$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("userPassword", "amanger");
$sel->type_ok("confirmPassword", "manager");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("logoff");
sleep($sleep);

=cut


# logon test2 and accept waiting transaction 
# from test1

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test2");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Transactions");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("//input[\@name='go' and \@value='Ok']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");

sleep($sleep);

# Yay, OpenId manipulation..
# logon to test2 and add two valid openids, list them,
# delete one, list again...

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test2");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep);

$sel->click_ok("link=Add Openid");
$sel->type_ok("name=openId", "https://me.yahoo.com/a/s.04E3wakMfN_Px.mQAqkddxjLM.kp0KwrREmXs-");
$sel->type_ok("name=openIdDesc", "yahoo");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");


$sel->click_ok("link=Add Openid");
$sel->type_ok("name=openId", "https://hughbarnard.myopenid.com/");
$sel->type_ok("name=openIdDesc", "myopenid");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=List Openids");
$sel->wait_for_page_to_load_ok("30000");

# list delete and re-create openids 
$sel->click_ok("link=List Openids");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("//input[\@name='go' and \@value='Delete']");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=List Openids");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=Add Openid");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=openId", "https://hughbarnard.myopenid.com/");
$sel->type_ok("name=openIdDesc", "myopenid");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=List Openids");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("logoff");

sleep($sleep);


# send 10 dallies from test1 at dalston to test4
# at limehouse, then logon and accept them by test4
# use of local partner registry therefore...problematic for cpanel?!
    
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "test1");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");


$sel->type_ok("tradeDestination", "test4");
$sel->select_ok("toregistry", "label=\u$registry2");
$sel->select_ok("tradeCurrency", "label=Dally");
$sel->type_ok("tradeAmount", "42");
$sel->type_ok("tradeTitle", "test1 to test4");
$sel->type_ok("tradeDescription", "cross registry test");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");


sleep($sleep);

# logon as test4 and accept transaction from test1
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry2);
$sel->type_ok("userLogin", "test4");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
#
$sel->click_ok("link=Transactions");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("//input[\@name='go' and \@value='Ok']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");



sleep($sleep);

# test volume of transactions, also provides multiple page links

test_volume ($usedecimals, 30, $sel, $type, $sleep, $registry1)  ;

#logon to dalston test2 and place two ads, one wanted and one offered

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("name=registry", $registry1);
$sel->type_ok("name=userLogin", "test2");
$sel->type_ok("name=userPassword", "password");
$sel->click_ok("css=td > input[type=submit]");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=yellowtags", "baking");
$sel->type_ok("name=subject", "bake some more bread");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per hour");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("name=type", "label=Wanted");
$sel->type_ok("id=yellowtags", "computer");
$sel->type_ok("name=subject", "please help me with my compute");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per day");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");

# login test 3 and place a couple of ads with test tags

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("name=registry", $registry1);
$sel->type_ok("name=userLogin", "test2");
$sel->type_ok("name=userPassword", "password");
$sel->click_ok("css=td > input[type=submit]");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=yellowtags", "baking");
$sel->type_ok("name=subject", "bake some more bread");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per hour");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");

$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("name=type", "label=Wanted");
$sel->type_ok("id=yellowtags", "computer");
$sel->type_ok("name=subject", "please help me with my compute");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per day");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;

# logon to dalston test3 and place the same ads but wanted for computing
# should match test2

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("name=registry", $registry1);
$sel->type_ok("name=userLogin", "test3");
$sel->type_ok("name=userPassword", "password");
$sel->click_ok("css=td > input[type=submit]");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("name=type", "label=Wanted");
$sel->type_ok("id=yellowtags", "computer");
$sel->type_ok("name=subject", "please help me with my compute");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per day");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;

# logon to limehouse and place an ad, just to have some rdf

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("name=registry", $registry2);
$sel->type_ok("name=userLogin", "test4");
$sel->type_ok("name=userPassword", "password");
$sel->click_ok("css=td > input[type=submit]");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=yellowtags", "baking");
$sel->type_ok("name=subject", "bake some more bread: limehouse");
$sel->type_ok("css=textarea[name=description]", "test ad");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per hour");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Place Ad");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("name=type", "label=Wanted");
$sel->type_ok("id=yellowtags", "computer");
$sel->type_ok("name=subject", "help me with my compute");
$sel->type_ok("css=textarea[name=description]", "test ad:limehouse");
# new test for decimal prices
if (length($usedecimals)) {
 $sel->type_ok("id=price", "10.12");
} else {
 $sel->type_ok("id=price", "10");
}
$sel->select_ok("name=tradeCurrency", "label=Tpound");
$sel->select_ok("name=unit", "label=per day");
$sel->click_ok("name=saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;

# split transaction at dalston
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", "$registry1");
$sel->type_ok("userLogin", "test3");
$sel->type_ok("userPassword", "password");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Split Payment");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("tradeDestination", "test2");
$sel->select_ok("toregistry", "label=\u$registry1");
$sel->select_ok("tradeCurrency", "label=Dally");
$sel->type_ok("tradeAmount", "10");
$sel->select_ok("stradeCurrency", "label=Tpound");
$sel->click_ok("stradeAmount");
$sel->type_ok("stradeAmount", "12");
$sel->click_ok("tradeTitle");
$sel->type_ok("tradeTitle", "split transaction test");
$sel->type_ok("tradeDescription", "split transaction test");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;

# print control total structure
open ($ctl,'>>','control_totals.txt') ;
print "after split\n" ;
print $ctl Dumper %control_total ;

close $ctl ;


# modify currency dally 

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("registry");
$sel->type_ok("registry", $registry1);
$sel->click_ok("userLogin");
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
#$sel->click_ok("id=adminlinkhref");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Show Currencies");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("//input[\@name='go' and \@value='Modify']");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("mail", "hugh.barnard1\@caca.com");
$sel->click_ok("saveadd");

$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;

# and show modifications to currency

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", "");
$sel->type_ok("registry", "$registry1");
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
#$sel->click_ok("id=adminlinkhref");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Show Currencies");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("go");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");

sleep($sleep) ;

# modify limehouse partner at dalston and show the record
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
#$sel->click_ok("id=adminlinkhref");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Partners");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("//input[\@name='go' and \@value='Modify']");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("email", "hugh.barnard\@gmail.com");
$sel->select_ok("type", "label=local");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Partners");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("go");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");




#self contained search tests, doesn't include good test for transaction as present
# autosuggest comment clicks are commented don't work well currently
# new oness as of 30/10/2011

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("name=registry", $registry1);
$sel->type_ok("name=userLogin", "test1");
$sel->type_ok("name=userLogin", "test2");
$sel->type_ok("name=userPassword", "password");
$sel->click_ok("css=td > input[type=submit]");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=search_string", "10");
#$sel->click_ok("css=li.ac_even");
$sel->click_ok("css=input.small");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("id=search_type", "label=Users");
$sel->type_ok("id=search_string", "t");
#$sel->click_ok("css=li.ac_odd");
$sel->click_ok("css=input.small");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("id=search_type", "label=Adverts");
$sel->type_ok("id=search_string", "bak");
#$sel->click_ok("css=li.ac_odd > strong");
$sel->click_ok("css=input.small");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("id=logoff");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;
# end of search tests
# put control panel tests here....




# logon to limehouse test4 and modify user record, Mr Test4 + correct phone

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry2);
$sel->type_ok("userLogin", "test4");
$sel->type_ok("userPassword", "password");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify Account");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("userMobile", "4444 444444");
$sel->type_ok("userName", "Mr Test 4");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;

# forgotten password test for googlemail

$sel->open_ok("/cgi-bin/cclite.cgi?action=template&name=forgotpass.html");
$sel->click_ok("link=exact:Forgotten Password?");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userEmail", "hugh.barnard\@googlemail.com");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;

# forgotten password test invalid registry

$sel->open_ok("/cgi-bin/cclite.cgi?action=template&name=forgotpass.html");
$sel->click_ok("link=exact:Forgotten Password?");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("registry", 'dddeet');
$sel->type_ok("userEmail", "hugh.barnard\@googlemail.com");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;

# forgotten password test invalid email

$sel->open_ok("/cgi-bin/cclite.cgi?action=template&name=forgotpass.html");
$sel->click_ok("link=exact:Forgotten Password?");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userEmail", "mr.jekyll\@hyde.com");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;


# test file upload facility

=item upload, security problem in javascript with this, test by hand
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form") ;
sleep(3) ;
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi");
$sel->click_ok("link=Upload Batch Files");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("batch", "/home/hbarnard/cclite-support-files/test-suite/credits.csv");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");
sleep($sleep) ;
=cut

# cash pay in at counter to test3

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=User Menu");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("tradeCurrency", "label=Dally");
$sel->select_ok("toregistry", "label=\u$registry1");
$sel->select_ok("tradeItem", "label=Cash In");
$sel->type_ok("tradeDestination", "test3");
$sel->type_ok("tradeSource", "cash");
$sel->type_ok("tradeAmount", "100");
$sel->type_ok("tradeTitle", "test counter pay in by test3");
$sel->type_ok("tradeDescription", "test");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;


# cash pay out at counter to test3

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=User Menu");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("toregistry", "label=\u$registry1");
$sel->select_ok("tradeCurrency", "label=Dally");
$sel->select_ok("tradeItem", "label=Cash Out");
$sel->type_ok("tradeSource", "test3");
$sel->type_ok("tradeTitle", "cash out over counter");
$sel->type_ok("tradeDescription", "test");
$sel->type_ok("tradeTitle", "cash out over counter");
$sel->type_ok("tradeAmount", "24");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");


sleep($sleep) ;

#try to login for cash and fail

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "cash");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=not allowed for system accounts");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;


# create news at dalston and let test1 view it
#
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form") ;

sleep($sleep) ;

# put some news in strap
$sel->open_ok("/cgi-bin/protected/ccadmin.cgi");
$sel->click_ok("link=Modify $registry1");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("latest_news", "This is some news");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");


sleep($sleep) ;

#remove news from strap
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");

$sel->open_ok("/cgi-bin/protected/ccadmin.cgi");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Modify $registry1");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("latest_news", "");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

sleep($sleep) ;

# click the batch buttons and see
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->submit("form") ;
$sel->wait_for_page_to_load_ok("30000");

# click on batch buttons to start
$sel->select_ok("id=stats_value", "label=Every 5min");
$sel->select_ok("id=mail_value", "label=Every 5min");
$sel->select_ok("id=rss_value", "label=Every 5min");
$sel->select_ok("id=gammu_value", "label=Every 5min");



sleep ($sleep) ;

# click on batch buttons to stop
$sel->select_ok("id=stats_value", "label=Stop Stats");
$sel->select_ok("id=mail_value", "label=Stop Mail");
$sel->select_ok("id=rss_value", "label=Stop Rss");
$sel->select_ok("id=gammu_value", "label=Stop SMS");
# click on month in statement download
$sel->select_ok("name=month", "label=11");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");


# service charge test: new may 2010
$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->click_ok("registry");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
#$sel->click_ok("id=adminlinkhref");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Apply Service Charge");
$sel->wait_for_page_to_load_ok("30000");
$sel->select_ok("tradeCurrency", "label=Dally");

# decimal style service charge...
if (length($usedecimals)) {
 $sel->type_ok("value", "2.34");
} else {
 $sel->type_ok("value", "2");
}


$sel->type_ok("//input[\@name='title']", "service charge test");
$sel->type_ok("//input[\@name='description']", "service charge test description");
$sel->click_ok("saveadd");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");


sleep ($sleep) ;

# attempt to create batch directories at dalston...

$sel->open_ok("/cgi-bin/cclite.cgi");
$sel->type_ok("registry", $registry1);
$sel->type_ok("userLogin", "manager");
$sel->type_ok("userPassword", "manager");
$sel->click_ok("//input[\@value='Logon']");
$sel->wait_for_page_to_load_ok("30000");
#$sel->click_ok("id=adminlinkhref");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Create Batch Dirs");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("logoff");
$sel->wait_for_page_to_load_ok("30000");

# REST interface

=head3 usage


java -jar selenium-server-standalone-2.20.0.jar to start selenium

set up test.cf from test.cf.example

./test-cclite-ng.pl -type=xp -log=yes > test.txt for example to test a windows installation


=cut


