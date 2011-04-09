#!/usr/bin/perl
use strict;
use LWP::Simple;
use SVG;
use CGI qw(:standard);

my $counter;
my ( @dates, @adj_closes, @volumes );
my ( $min,   $max,        $maxvol );

#form parameters
my $symbol = param('symbol');
my $full   = param('full');

#my $symbol = 'MSFT';

#-------------------------------------------------------------------------------------------------------------
#PROCESS THE CSV FILE
#-------------------------------------------------------------------------------------------------------------
my ( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];
my $url =
    "http://ichart.yahoo.com/table.csv?"
  . "ignore=.csv&s="
  . $symbol . "&a="
  . $month . "&b="
  . $day . "&c="
  . ( $year + 1899 ) . "&d="
  . $month . "&e="
  . $day . "&f="
  . ( $year + 1900 );

#print $url . "\n";
#get the file from yahoo
my $content = get($url);

#split the rows
my @lines = split( /\n/, $content );

#go through each line
foreach my $row (@lines) {
    if ( $row =~ /[0-9]{1,2}\-/ ) {
        my ( $date, $open, $high, $low, $close, $volume, $adj_close ) =
          split( /,/, $row );

        $dates[$counter]      = $date;
        $adj_closes[$counter] = $adj_close;
        $volumes[$counter]    = $volume;

        if ( $counter == 0 ) {
            $min    = $adj_close;
            $max    = $adj_close;
            $maxvol = $volume;
        } else {
            if ( $adj_closes[$min] > $adj_close ) { $min    = $counter; }
            if ( $adj_closes[$max] < $adj_close ) { $max    = $counter; }
            if ( $volumes[$maxvol] < $volume )    { $maxvol = $counter; }

        }

        $counter++;
    }
}

#-------------------------------------------------------------------------------------------------------------
#Calculations
#-------------------------------------------------------------------------------------------------------------
my ( $txsize, $tysize, $xsize, $ysize, $xpos, $ypos );
my ( $step, $smallfontsize, $bigfontsize, $lastmove, $color );

#total sparkline size
if ( param('xsize') == '' ) {
    $txsize = 220;
} else {
    $txsize = param('xsize');
}
if ( param('ysize') == '' ) {
    $tysize = 50;
} else {
    $tysize = param('ysize');
}

#font size for small labels
$smallfontsize = $tysize / 5;
if ( $smallfontsize < 7 ) { $smallfontsize = 7; }

#font size for big labels
$bigfontsize = $tysize / 2.5;

#initial x and y position of the path
$xpos = $bigfontsize * 2;
$ypos = $tysize - $smallfontsize;

#total size of the path
$xsize = $txsize - $xpos * 2.5;
$ysize = $tysize - $ypos / 1.3;

#step
$step = $xsize / --$counter;

#last move
$lastmove = $adj_closes[0] - $adj_closes[1];

if ( $lastmove > 0 ) {
    $color = 'blue';
} else {
    $color = 'red';
}

#-------------------------------------------------------------------------------------------------------------
#SVG Creation & Output
#-------------------------------------------------------------------------------------------------------------
print("Content-Type: image/svg+xml\n\n");

# create an SVG object
my $svg = SVG->new( width => $txsize, height => $tysize );

#create path
my $path;

#vÕ(i) = (v(i) -  minA)/(maxA - minA)* (new_maxA)

$path =
    "M " 
  . $xpos . " "
  . ( $ypos -
      ( $adj_closes[$counter] - $adj_closes[$min] ) /
      ( $adj_closes[$max] - $adj_closes[$min] ) *
      $ysize )
  . " ";

for ( my $i = $counter - 1 ; $i > 0 ; $i-- ) {
    $path =
        $path . " L "
      . ( $xpos + ( $counter - $i ) * $step ) . " "
      . ( $ypos -
          ( $adj_closes[$i] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize )
      . " ";

    if ( $full eq 'true' ) {
        $svg->line(
            x1 => ( $xpos + ( $counter - $i ) * $step ),
            x2 => ( $xpos + ( $counter - $i ) * $step ),
            y1 => $tysize - 1,
            y2 => $tysize -
              $volumes[ $counter - $i ] * ( $tysize / 1.3 ) / $volumes[$maxvol],
            'opacity'      => .3,
            'fill'         => '#000000',
            'stroke-width' => $step
        );
    }
}

$svg->path( d => $path, 'fill' => 'none', stroke => '#909090' );

#--------------------------------
#create min,max and last points
#--------------------------------

#min
$svg->circle(
    cx => $xpos + ( $counter - $min ) * $step,
    cy => (
        $ypos -
          ( $adj_closes[$min] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize
    ),
    'stroke' => 'none',
    'fill'   => 'red',
    'r'      => 1.5
);

#max
$svg->circle(
    cx => $xpos + ( $counter - $max ) * $step,
    cy => (
        $ypos -
          ( $adj_closes[$max] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize
    ),
    'stroke' => 'none',
    'fill'   => 'green',
    'r'      => 1.5
);

#last
$svg->circle(
    cx => $xpos + ( $counter - 1 ) * $step,
    cy => (
        $ypos -
          ( $adj_closes[0] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize
    ),
    'stroke' => 'none',
    'fill'   => 'blue',
    'r'      => 1.5
);

#--------------------------------
#create last and symbol labels
#--------------------------------
#last
$svg->text(
    x => $xpos + ( $counter - 1 ) * $step + $smallfontsize / 2,
    y => $tysize / 1.6,
    'font-size'   => $bigfontsize . 'px',
    'font-family' => 'Trebuchet MS',
    'fill'        => $color
)->cdata( $adj_closes[0] );

#symbol label
$svg->text(
    x             => 3,
    y             => $tysize / 1.6,
    'font-size'   => $bigfontsize . 'px',
    'font-family' => 'Trebuchet MS',
    'fill'        => '#666666'
)->cdata($symbol);

#--------------------------------
#create min and max labels
#--------------------------------
#min
$svg->text(
    x => $xpos + ( $counter - $min ) * $step,
    y => (
        $ypos -
          ( $adj_closes[$min] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize
      ) + $smallfontsize,
    'fill'        => 'red',
    'text-anchor' => 'middle',
    'font-size'   => $smallfontsize . 'px',
    'font-family' => 'Lucida Grande,Verdana',
    'opacity'     => '0.6'
)->cdata( $adj_closes[$min] );

#max
$svg->text(
    x => $xpos + ( $counter - $max ) * $step,
    y => (
        $ypos -
          ( $adj_closes[$max] - $adj_closes[$min] ) /
          ( $adj_closes[$max] - $adj_closes[$min] ) *
          $ysize
      ) - $smallfontsize / 2,
    'fill'        => 'green',
    'text-anchor' => 'middle',
    'font-size'   => $smallfontsize . 'px',
    'font-family' => 'Lucida Grande,Verdana',
    'opacity'     => '0.6'
)->cdata( $adj_closes[$max] );

#----------------------------------
#create full chart
#----------------------------------
if ( $full eq 'true' ) {

    #change label
    $svg->text(
        x             => $txsize - $smallfontsize * 4,
        y             => $smallfontsize + 1,
        'fill'        => $color,
        'text-anchor' => 'start',
        'font-size'   => $smallfontsize + 1 . 'px',
        'font-family' => 'Lucida Grande,Verdana',
        'opacity'     => '0.6'
      )
      ->cdata(
        sprintf( "%.2f", ( $adj_closes[0] / $adj_closes[1] - 1 ) * 100 )
          . "%" );

    #volume
    $svg->text(
        x             => $txsize - $smallfontsize * 3,
        y             => $tysize - $smallfontsize / 2.5,
        'fill'        => '#666666',
        'text-anchor' => 'start',
        'font-size'   => $smallfontsize . 'px',
        'font-family' => 'Lucida Grande,Verdana',
        'opacity'     => '0.6'
    )->cdata( sprintf( "%.1f", $volumes[0] / 1000000 ) . "M" );
}

#dates
#$svg->text(x=>$xpos,
# 			y=>$smallfontsize +1,
# 			'font-size'=> $smallfontsize . 'px',
# 			'font-family'=>'Trebuchet MS',
# 			'text-anchor'=>'middle',
# 			'fill'=>'#999999'
# 			)->cdata($dates[$counter]);

#$svg->text(x=>$xpos + ($counter-1) * $step,
# 			y=>$smallfontsize +1,
# 			'font-size'=> $smallfontsize . 'px',
# 			'font-family'=>'Trebuchet MS',
# 			'fill'=>'#999999'
# 			)->cdata($dates[0]);

my $out = $svg->xmlify;
print $out;

exit 0;
