<?php

include_once ($_SERVER['DOCUMENT_ROOT']."/mod/cclite/cclite-common.php") ; 

// Make sure we're logged in (send us to the front page if not)
gatekeeper();

// Make sure action is secure
action_gatekeeper();

		$touser = get_input('touser');
		$currency = get_input('currency');
                $quantity = get_input('quantity');
		$description = get_input('description');

$input = array('pay',$touser,$quantity,$currency) ; // parameters supplied as array 
$cclite = cclite_contents($input) ;
system_message("$cclite");

//forward($_SERVER['HTTP_REFERER']);
//forward($_SERVER['HTTP_REFERER']);
//$result = forward("http://thhw.cclite.k-hosting.co.uk/pg/profile/test2");
//$location = "http://thhw.cclite.k-hosting.co.uk/pg/profile/test2" ;
//header("Location: {$location}");


?>

