#!/usr/bin/perl 

$test = 1 ;
if ($test) {
print STDOUT "Content-type: text/html\n\n";
my $data = join( '', <DATA> );
eval $data;
if ($@) {
    print $@;
    exit 1;
}
}

__END__


=head1 graph.pl

Simple graphing for cclite

---------------------------------------------------------------------------
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
---------------------------------------------------------------------------

these batch scripts are kept as eval <whole-of-script>, if they fail they print their problems
onto the status web page

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a simple graph of transaction size an volumes for a given
registry, it is run as a time job within the admin menu



=head1 COPYRIGHT

Copyright 2005 -2011 Hugh Barnard.

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 1.2 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

=head3 save_chart

Writes the file, should die and complain on the
management page, if something goes wrong

=cut


sub save_chart
{
	my ($chart,$name,$ext) = @_ ;
	
	local(*OUT);
	open(OUT, ">$name.$ext") or 
		die "Cannot open $name.$ext for write: $!";
	binmode OUT;
	print OUT $chart->$ext();;
	close OUT;
}


=head3 make_graph


width
height
title
x_label
y_label
draw_grid
draw_border
draw_tic_labels
draw_data_labels
transparent
grid_on_top
binary
data_label_style
thickness
skip_undefined
boxwidth



=cut


sub make_graph {

  my ($x_label,$array_ref, $y_label,$xskip) = @_ ;
  my $timestamp = sql_timestamp() ;
  my $graph ;
  my $title = "Last updated at $timestamp" ;
  
  my $ch = Chart::Strip->new(
                 title   => $title,
                 'x_label' => $x_label,
                 'y_label' => $y_label,
                 'skip_undefined' => $xskip,
                 'transparent' => 0,
             );

    $ch->add_data( $array_ref, { style => 'line',
                                  color => '000000',
                                  label => '' } );

    return $ch ;
}

#=============================================================================================
# Main part of script....this will need  which chart strip uses GD
#=============================================================================================

use strict ;
use lib '../../../lib';

use Cccookie ;
use Ccu ;
use Ccconfiguration ;
				
use strict ;
use Cclitedb;

use Log::Log4perl;
use Chart::Strip;

our %configuration = readconfiguration();

Log::Log4perl->init($configuration{'loggerconfig'});
our $log = Log::Log4perl->get_logger("graph");

my $cookieref = get_cookie();
my %fields    = cgiparse();

# message language now decided by decide_language 08/2011
our %messages = readmessages();

# you'll have to hardwire this, if running from cron
my $registry = $cookieref->{registry} || 'dalston' ;

# charts are kept per registry in public html....
my $chartdir = "$configuration{htmlpath}/images/charts/$registry" ;

if (-e $chartdir && -w $chartdir) {
} else {
  print "$chartdir does not exist or is not writable\n";
  exit 1 ;
}

# name is chart name
my $name  ;
# value before token is how many hours back to go...
my $hours_back = 24 ; # how many hours back to go
# type is minutes, hours, days.
my $type = 'hours' ;

 my $averages_array_ref = get_raw_stats_data ( 'local', $registry, $hours_back, 'average', $type, '' );
 my $volumes_array_ref = get_raw_stats_data ( 'local', $registry, $hours_back, 'volume', $type, '' );
 
 $name = "$chartdir/transactions" ; 
 my $chart = make_graph  ('time',$averages_array_ref, 'average transaction value',1) ;
 save_chart ($chart,$name,'png');
 $name = "$chartdir/volumes" ;
 my $chart = make_graph  ('time',$volumes_array_ref, 'trade volume',1) ;
 save_chart ($chart,$name,'png');

my $updated = sql_timestamp() ;
#print "$messages{statsupdate} $updated" ;
exit 0 ;




