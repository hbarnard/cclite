
<?php
// $Id$

// used to transport merchant key hash
include ($_SERVER['DOCUMENT_ROOT']."/mod/cclite/cclite-common.php") ;


/* json structure returned...

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
*/

$today = date("Y-m-d"); 

$input = array('recent.json') ; // now via array 
$cclite = cclite_contents($input) ;

// TRUE puts it into a multidimensional array rather than an object

$t = json_decode($cclite,TRUE) ;

echo "<div style=\"font-size:small;\">" ;
for ($row = 0; $row < 6; $row++)
{
$line = $t['data'][$row]['id'] . " " .$t['data'][$row]['tradeDate'] . " " .  $t['data'][$row]['tradeType'] . " " . $t['data'][$row]['tradeAmount'] . " " . $t['data'][$row]['tradeCurrency'] . " " . "<br/>" ; 

 $t['data'][$row]['tradeType'] == 'debit' ? ($colour = 'red') : ($colour = 'black') ;
 $t['data'][$row]['tradeDate'] == $today ? ($weight = 'bold') : ($weight = 'normal') ;


echo "<div style=\"color:$colour;font-weight:$weight\">$line</div\n" ;

}

echo "</div>" ;
?>



