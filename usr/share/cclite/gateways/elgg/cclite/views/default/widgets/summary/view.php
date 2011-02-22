<?php

include ($_SERVER['DOCUMENT_ROOT']."/mod/cclite/cclite-common.php") ; 

/*

Balance + and - records for each currency

{"registry":"ccliekh_dalston","table": "om_transactions", "message":"OK",
"data": [
{"id": "1",
 "currency":"dally",
"sum":"20",
"tradeId":"1"
},

{"id": "66",
 "currency":"tpound",
"sum":"12",
"tradeId":"66"
},

{"id": "5",
 "currency":"dally",
"sum":"-739",
"tradeId":"5"
}
]} 

| pipe is used to separate the two json structures  
Total transaction volume for recent months by currency

{"registry":"ccliekh_dalston","table": "om_transactions", "message":"OK",
"data": [
{"id": "tpo20108",
 "currency":"tpound",
"sort":"tpo20108",
"volume":"12",
"yr":"10",
"mth":"August",
"cnt":"1"
},

{"id": "dal20108",
 "currency":"dally",
"sort":"dal20108",
"volume":"322",
"yr":"10",
"mth":"August",
"cnt":"33"
},

{"id": "dal20112",
 "currency":"dally",
"sort":"dal20112",
"volume":"437",
"yr":"11",
"mth":"February",
"cnt":"19"
}
]} 


*/

$input = array('summary.json') ; // parameters supplied as array 
$cclite = cclite_contents($input) ;
$json_array = explode('|',$cclite) ; // separate the two json structures

$balances = json_decode($json_array[0],TRUE) ;
$volumes = json_decode($json_array[1],TRUE) ;

 



?>

<div style="font-size:small;">


<?php 

foreach ($balances['data'] as $record) {
  foreach ($record as $key=> $val) {
   if ($key == 'currency') {
    $keep_currency = $val;
   } elseif ($key == 'sum') {
    $total[$keep_currency] =  $total[$keep_currency] + $val ; 
   }
  }
}
foreach ($total as $key=> $val) {
 $val < 0 ? ($colour = 'red') : ($colour = 'black') ;
 echo "<div style=\"color:$colour;\">Current balance: $key = $val</div>\n" ;
}

echo "<hr/>";

foreach ($volumes['data'] as $record) {
$line = $record['mth'] . " 20" . $record['yr'] . " count:" . $record['cnt'] . " volume:" . $record['volume'] . " " .  $record['currency']  ;
echo "<div>$line</div>" ;

}

 ?> 
</div>
