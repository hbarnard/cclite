<?php

include ($_SERVER['DOCUMENT_ROOT']."/mod/cclite/cclite-common.php") ; 

	// Make sure we're logged in (send us to the front page if not)
		gatekeeper();

        // Make sure action is secure
        action_gatekeeper();

		$touser = get_input('touser');
		$currency = get_input('currency');
                $quantity = get_input('quantity');
		$description = get_input('description');

/*
/pay/$input[1]/$registry/$input[2]/$input[3]
*/

$input = array('pay',$touser,$quantity,$currency) ; // parameters supplied as array 
$cclite = cclite_contents($input) ;

// display return from cclite...
system_message($cclite);
forward("pg/profile/" . $_SESSION['user']->username);
?>
