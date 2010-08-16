#!/usr/bin/perl 

#---------------------------------------------------------------------------
#THE cclite SOFTWARE IS PROVIDED TO YOU "AS IS," AND WE MAKE NO EXPRESS
#OR IMPLIED WARRANTIES WHATSOEVER WITH RESPECT TO ITS FUNCTIONALITY,
#OPERABILITY, OR USE, INCLUDING, WITHOUT LIMITATION,
#ANY IMPLIED WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE, OR INFRINGEMENT.
#WE EXPRESSLY DISCLAIM ANY LIABILITY WHATSOEVER FOR ANY DIRECT,
#INDIRECT, CONSEQUENTIAL, INCIDENTAL OR SPECIAL DAMAGES,
#INCLUDING, WITHOUT LIMITATION, LOST REVENUES, LOST PROFITS,
#LOSSES RESULTING FROM BUSINESS INTERRUPTION OR LOSS OF DATA,
#REGARDLESS OF THE FORM OF ACTION OR LEGAL THEORY UNDER
#WHICH THE LIABILITY MAY BE ASSERTED,
#EVEN IF ADVISED OF THE POSSIBILITY OR LIKELIHOOD OF SUCH DAMAGES.
#---------------------------------------------------------------------------
#
# these batch scripts are kept as eval, if they fail they print their problems
# onto the status web page

print STDOUT "Content-type: text/html\n\n";
my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}
__END__


=head3 readconfiguration


Read the configuration data and return a hash, this routine
also exists in ccserver.cgi

Skip comments marked with #
cgi parameters will override configuration file
information, always!

Included here, needs to be executed within BEGIN


=cut


sub readconfiguration {

    my $os = $^O;
    my $dir;
    my $default_config;

    # if it's windows use cd to find the directory
    if ( $os =~ /^ms/i ) {
        $dir = `cd`;
    } else {
        $dir = `pwd`;
    }

    # make an informed guess at the config file not explictly supplied
    $dir =~ s/\bcgi-bin.*//;
    $default_config = "${dir}config/cclite.cf";
    $default_config =~ s/\s//g;

     ###print "default config is $default_config" ;

    # either supply it explicitly with full path or it will guess..
    my $configfile = $_[0] || $default_config;

    my %configuration;
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
    } else {
        error(
            "Cannot find configuration file file: $configfile may be missing?");
    }
    return %configuration;
}



=head3 get_volumes


Get trade volumes and deliver to make a GD Graph chart
This probably also gets delivered into cut down temporary
tables too...

1970-01-01 00:00:01'

tradeStamp(15,2) is minutes
tradeStamp(12,2) is hours
tradeStamp(9,2) is days
tradeStamp(6,2) is month

=cut

sub get_volumes {

    my ( $class, $db, $from_x_hours_back, $type, $token ) = @_;
    my @times;
    my @volumes;
    my $movement = 0 ; # flag that indicates whether there is a volume for this period
    my $seconds = $from_x_hours_back * 60 * 60 ;
    my %types = ('minutes','15,2','hours','12,2','days','9,2','month','6,2' )  ;
    my $slice = $types{$type} ;
    my $sqlstring = <<EOT;
SELECT substr(tradeStamp,12,5), count(*) FROM om_trades o  
   where unix_timestamp(tradeStamp) >= (unix_timestamp()-$seconds) 
   group by substr(tradeStamp,$slice) ORDER BY substr(tradeStamp,12,5) ;
EOT

    my $max_quantity = undef;    # used to scale the graph
    my ( $registry_error, $array_ref ) =
      sqlraw_return_array( $class, $db, $sqlstring, undef, $token );

    foreach my $row (@$array_ref)  {
      # this is because there is a debit and credit for each movement, so that the system balances
      # therefore transaction volume equals sum of entries/2
      my $this_volume = $$row[1]/2 ;
      $max_quantity = $this_volume
          if ($this_volume  > $max_quantity );
          
        push @times,   $$row[0];
        push @volumes, $this_volume ;
        $movement = 1 if ($$row[1] > 0) ; # if there's a movement in the period
    }

    return \@times, \@volumes, $max_quantity, $movement;
}


=head3 get_average_transaction_size

Get trade volumes and deliver to make a GD Graph chart
This probably also gets delivered into cut down temporary
tables too...

1970-01-01 00:00:01'

tradeStamp(15,2) is minutes
tradeStamp(12,2) is hours
tradeStamp(9,2) is days
tradeStamp(6,2) is month

=cut

sub get_average_transaction_size {

    my ( $class, $db, $from_x_hours_back, $type, $token ) = @_;
    my @times;
    my @averages;
    my $movement = 0 ; # indicate whether there are any values for the period
    my $seconds = $from_x_hours_back * 60 * 60 ;
    my %types = ('minutes','15,2','hours','12,2','days','9,2','month','6,2' )  ;
    my $slice = $types{$type} ;
    my $sqlstring = <<EOT;
SELECT substr(tradeStamp,12,5), avg(tradeAmount) FROM om_trades o  
   where unix_timestamp(tradeStamp) >= (unix_timestamp()-$seconds) 
   group by substr(tradeStamp,$slice) ORDER BY substr(tradeStamp,12,5) ;
EOT

    my $max_quantity = undef;    # used to scale the graph
    my ( $registry_error, $array_ref ) =
      sqlraw_return_array( $class, $db, $sqlstring, undef, $token );

    foreach my $row (@$array_ref)  {
      $max_quantity = $$row[1]
          if ($$row[1]  > $max_quantity );
        push @times,   $$row[0];
        push @averages, $$row[1];
        $movement = 1 if ($$row[1] != 0) ; # if there's a non-zero average in the period
    }

    return \@times, \@averages, $max_quantity, $movement;
}


=head3 render_chart

This just makes the chart and calls save_chart to
write the file

=cut


sub render_chart {

my ($times_ref,$data_ref,$graph,$name) = @_ ;

my @data = ( 
    [ @$times_ref ],
    [ @$data_ref],
);

$graph->plot(\@data);
save_chart($graph,$name);
return ;
}


=head3 save_chart

Writes the file, should die and complain on the
management page, if something goes wrong

=cut


sub save_chart
{
	my ($chart,$name) = @_ ;
	local(*OUT);

	my $ext = $chart->export_format;
        ### print "save at $name.$ext\n" ;
	open(OUT, ">$name.$ext") or 
		die "Cannot open $name.$ext for write: $!";
	binmode OUT;
	print OUT $chart->gd->$ext();
	close OUT;
}


=head3 make_graph

Main set setuo for the graph object, if sparklines doesn't work
set it back to lines (or bats). This is alll fairly experimental.

Sparklines graphs are pretty unlabelled and used in small format,
to make them small use imagemagick convert otherwise they are
really ugly...

=cut


sub make_graph {

  my ($format, $xlabel,$ylabel,$xskip,$max_quantity) = @_ ;
  my $timestamp = sql_timestamp() ;
  my $graph ;
  my $title = "Last updated at $timestamp" ;
  if ($format eq 'sparklines') {
   $title = "" ;
   $graph = new GD::Graph::sparklines(300,180);
  } else {
   $graph = new GD::Graph::lines(300,180);
  }
   $graph = new GD::Graph::sparklines(300,180);
  ####my $graph = new GD::Graph::bars(400,240);
 $graph->set( 
#	x_label => $xlabel,
	y_label => $ylabel,
	title => $title,
        x_label_skip => $xskip,
        x_labels_vertical => 1,
	y_max_value => $max_quantity,
	y_min_value => 0,
	y_tick_number => 10,
	y_label_skip => 2,
	box_axis => 0,
	line_width => 3,

	transparent => 1,
);
 return $graph ;
}


=head3 blank_graph

Prints a 'no movement' graphic when there's nothing
happening. A little crude at present

=cut

sub blank_graph {

   my ($chart_name,$literal,$width,$height) = @_ ;   
# create a new image
my $im = new GD::Image($width,$height);

# allocate some colors
my $white = $im->colorAllocate(255,255,255);
my $black = $im->colorAllocate(0,0,0);       
my $red = $im->colorAllocate(255,0,0);      
my $blue = $im->colorAllocate(0,0,255);

# make the background transparent and interlaced
$im->transparent($white);

 # Put a black frame around the picture
 $im->rectangle(0,0,$width,$height,$black);

###$im->string(gdSmallFont,50,50,$literal,$black);
# And fill it with red
$im->fill(0,0,$red);

open (BLANK, ">$chart_name\.gif") ;
print BLANK $im->gif;
close BLANK ;   
   
   
}


# Main part of script....

my %configuration;

use lib '../../../lib';

use Log::Log4perl;

use Ccadmin ;
use Cccookie ;
use Ccu ;
use Ccconfiguration ;
				
use strict ;
use GD ;
use Cclitedb;

###use GD::Graph::bars;

my $format = 'sparklines' ;
eval {
   use GD::Graph::sparklines;
} ;
# no sparklines...
if(@$) {
   $format = 'lines' ;
   use GD::Graph::lines;
}

use GD::Text;
%configuration = readconfiguration();

Log::Log4perl->init($configuration{'loggerconfig'});
our $log = Log::Log4perl->get_logger("graph");

my $cookieref = get_cookie();
my %fields    = cgiparse();
our %messages = readmessages("en");

# you'll have to hardwire this, if running from cron
my $registry = $$cookieref{registry} ;

my ($times_ref,$data_ref,$max_quantity,$movement, $name, $graph, $token, $type, $hours_back) ;


# charts are kept per registry in public html....
my $chartdir = "$configuration{htmlpath}/images/charts/$registry" ;


if (-e $chartdir && -w $chartdir) {
} else {
  print "$chartdir does not exist or is not writable\n";
  exit 1 ;
}

# 
  $name = "$chartdir/volumes" ;
  $token = "" ;

# value before token is how many hours back to go...
  $type = 'minutes' ;
  $hours_back = 1 ; # how many hours back to go

# movement is a flag that shows whether there's movement in the period
($times_ref,$data_ref,$max_quantity,$movement) = get_volumes('local',$registry,$hours_back,$type,$token) ;
 $graph = make_graph($format,$type,'transaction volume',5,$max_quantity) ;

if ($movement) {
render_chart ($times_ref,$data_ref,$graph,$name) ;
} else {
 # bad idea, just leave the old one in place  
 ###  blank_graph ($name,'no movement',400,200) ; 
   
}

   $name = "$chartdir/transaction" ;
   $token = "" ;

# value before token is how many hours back to go...
  $type = 'minutes' ;
  $hours_back = 1 ; # how many hours back to go

 ($times_ref,$data_ref,$max_quantity,$movement) = get_average_transaction_size('local',$registry,$hours_back,$type,$token) ;
  $graph = make_graph($format,$type,'average transaction size',5,$max_quantity) ;

if ($movement) {
render_chart ($times_ref,$data_ref,$graph,$name) ;
} else {
 # bad idea, just leave the old one in place 
 ### blank_graph ($name,'no movement',400,200) ; 
   
}

my $updated = sql_timestamp() ;
print "$messages{statsupdate} $updated" ;
exit 0 ;

=head2 data_example

example of data needed for graph construction....
@data = ( 
    [ qw( Jan Feb Mar Apr May Jun Jul Aug Sep ) ],
    [ reverse(4, 3, 5, 6, 3,  1.5, -1, -3, -4)],
);

=cut


