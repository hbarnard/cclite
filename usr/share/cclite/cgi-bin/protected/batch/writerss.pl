#!/usr/bin/perl

=head1 description

write.rss writing news feeds for cclite adverts

THE cclite SOFTWARE IS PROVIDED TO YOU "AS IS," AND WE MAKE NO EXPRESS
OR IMPLIED WARRANTIES WHATSOEVER WITH RESPECT TO ITS FUNCTIONALITY, 
OPERABILITY, OR USE, INCLUDING, WITHOUT LIMITATION, 
ANY IMPLIED WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE, OR INFRINGEMENT. 
WE EXPRESSLY DISCLAIM ANY LIABILITY WHATSOEVER FOR ANY DIRECT, 
INDIRECT, CONSEQUENTIAL, INCIDENTAL OR SPECIAL DAMAGES, 
INCLUDING, WITHOUT LIMITATION, LOST REVENUES, LOST PROFITS, 
LOSSES RESULTING FROM BUSINESS INTERRUPTION OR LOSS OF DATA, 
REGARDLESS OF THE FORM OF ACTION OR LEGAL THEORY UNDER 
WHICH THE LIABILITY MAY BE ASSERTED, 
EVEN IF ADVISED OF THE POSSIBILITY OR LIKELIHOOD OF SUCH DAMAGES. 

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut

# rough equivalent of fatals to browser, will print anything that goes wrong

print STDOUT "Content-type: text/html\n\n";
my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}

__END__


#
# use sudo apt-get install liferea for example to read the 
# resulting feeds which are at an url like:
# http://cclite.private.server/out/rss/limehouse/en/all.rdf
# for a registry called limehouse, for example

use lib '../../../lib' ;

use Ccu;
use Ccrss ;
use Cccookie ; # to get the registry token from the admin page...
use Ccconfiguration ;

my $token ;

# you'll have to hardcode these, if this is a cron
my $cookieref = get_cookie();
my $registry = $cookieref->{registry} ;
my $language = $cookieref->{language} ;

my  %configuration  = readconfiguration();

# message language now decided by decide_language 08/2011
our %messages = readmessages();

# these are the feed types, all ads, wanted ads, offered ads and matched ads, change this to the feeds that you need
my @types = (all, wanted, offered, match) ;

my %fields ;

# this is the path where the rss files are written
# needs to be writable by the server, rss is now by registry and by language

$fields{'rsspath'}  =   $configuration{'rsspath'} ;
$fields{'language'} =   $language ;

my $email = $configuration{supportmail} ;

# simply loop around each registry creating an rdf file 
# for the type of advert for each one
 my $entry ;
 
foreach $type (@types) {
 
   $fields{type}	= $type ;
   my $fieldsref 	= \%fields ;
 my ($refresh,$metarefresh,$error,$html,$pagename,$cookies) 	= create_rss_feed('local',$configuration{'home'},'desc',$email,$registry,'om_yellowpages',$fieldsref,$token) ;
}

my $updated = sql_timestamp() ;
print "$messages{rdfupdate} $updated" ;

exit 0 ;

