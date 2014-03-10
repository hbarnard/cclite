<?php

/*
This is still pretty rough, but oo use:

1.  supply variables in get_test_variables
2.  supply tests in $api_tests at botton
3.  on command line 
         php cclite-curl-test.php > test.html


*/


 
// used to encode/transport merchant key hash

function urlsafe_b64encode($string) {
    $data = base64_encode($string);
    $data = str_replace(array('+', '/', '='), array('-', '_', ''), $data);
    return $data;
}

function urlsafe_b64decode($string) {
    $data = str_replace(array('-', '_'), array('+', '/'), $string);
    $mod4 = strlen($data) % 4;
    if ($mod4) {
        $data.= substr('====', $mod4);
    }
    return base64_decode($data);
}

/* 

Put testing variables here, sppof server is the IP that the connection
is 'meant' to be coming from, this is a weakness incidentally...

*/

function get_test_variables () {

 $user =   	'testuser' ;				// active test user
 $domain =  	"domain.com";				// cclite domain
 $protocol =  	"http"; 				// should be https
 $apikey =  	'123456'; 				// corresponds to the key in registry
 $hashing =  	'sha1' ;				// sha1 works at present, at least
 $registry =  	'database_name' ;			// registry name
 $limit = 	5 ; //for the moment,five records	// five record limit for recent, does this work properly?
 $spoof_server = '10.0.0.1' ;				// server that one is pretending to be: weakness to be addressed
 $verbose      =  1 ;					// makes curl verbose for deep debugging
 

 $values = array('user'=> $user,
                 'limit' => $limit,
                 'domain' => $domain,
                 'protocol'=> $protocol,
                 'apikey'=> $apikey,
                 'hashing'=> $hashing,
                 'registry'=> $registry,
		 'spoof_server' => $spoof_server,
                 'verbose' => $verbose        
                 ) ;

/*
 $str = "getting variables " . $_SERVER['SERVER_ADDR'] . "<br/>" . "user is " .  $user . "<br/>" . "registry is " .   $registry ; 
 echo $str ;
*/

 return $values ;
}


function cclite_remote_logon() {

    

    $params = get_test_variables() ;
    $user = $params['user'] ;
    $registry = $params['registry'] ;

    // if there's no user name, don't even bother to try...
    if ( strlen($user) ) {

     //   so when you use this, nake sure that the server ip checks against the list in the cclite registry!
      $api_hash = hash ( $params['hashing'], ( $params['apikey'] . $params['spoof_server']), 'true');
      $api_hash = urlsafe_b64encode($api_hash);
/*
      $str = "server is" . $_SERVER['SERVER_ADDR']. " ".$params['hashing'] . "". "<br/>" . "user is " .  $user . "<br/>" . "registry is " .   $registry ; 
      echo $str ;
*/

     // construct the base url from configuration information
        $cclite_base_url =  'http://' . $params['domain'];

        $ch = curl_init();
        if ($params['verbose'])  curl_setopt($ch, CURLOPT_VERBOSE, true); // Display communication with server
        curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
        curl_setopt($ch, CURLOPT_COOKIE, "merchant_key_hash=$api_hash");
        curl_setopt($ch, CURLOPT_COOKIESESSION, TRUE);
        curl_setopt($ch, CURLOPT_FAILONERROR, TRUE);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, FALSE);
        curl_setopt($ch, CURLOPT_FRESH_CONNECT, TRUE);
        curl_setopt($ch, CURLOPT_HEADER, TRUE);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 30);
        curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/logon/$user/$registry");
        $logon = curl_exec($ch);
        curl_close($ch);

      // extract the user style cookies from the logon
        preg_match_all('|Set-Cookie: (.*);|U', $logon, $results);
        $cookies = implode("; ", $results[1]);
        return array($logon, $cookies);
    } else {
        return array('noelgguser', '');
    }
}

/*
Thia is the engine that does cclite operations and delivers content

The default operation is deliver a transaction summary to user

This switch statement inside needs to map to the Rewrites in the cclite .htaccess file, so if you're
doing something custom-made, you need to think about:

-here-, .htaccess and various bits of login in the cclite motor
$url is constructed outside curl_setopt, so it can be debugged more easily...

*/

function cclite_contents($input) { 
 
    $params = get_test_variables() ;
    $user = $params['user'] ;
    $registry = $params['registry'] ;
    $limit = $params['limit'] ;

    $block_content = '';
    $cclite_operation = '';
    $logon_result = '' ;
    $url = '' ;


    // construct the payment url from configuration information
    $cclite_base_url =  'http://' . $params['domain'];

    $ch = curl_init();
    
    // try and logon to cclite, return emptyhanded, if nothing...
    if ($input[0] != 'adduser') {
        $logon_result = cclite_remote_logon();
        if (strlen($logon_result[1])) {
            curl_setopt($ch, CURLOPT_COOKIE, $logon_result[1]);
        } else {
             // no need for logon to add user...
        return;
        }
    }
     
    curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
    curl_setopt($ch, CURLOPT_COOKIESESSION, TRUE);
    curl_setopt($ch, CURLOPT_FAILONERROR, FALSE);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
    curl_setopt($ch, CURLOPT_FRESH_CONNECT, FALSE);
    curl_setopt($ch, CURLOPT_HEADER, FALSE);
    curl_setopt($ch, CURLOPT_POST, TRUE);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 30);

    // switch REST url depending on required cclite operation
    switch ($input[0]) {

        case 'recent':
            // $block_content = "case recent transactions : $input[0]/$input[1]" ;
            $url = "$cclite_base_url/recent/transactions/$limit" ;
            curl_setopt($ch, CURLOPT_URL, $url);
        break;

        case 'summary':
            // $block_content = "case summary : $input[0]  $input[1]/$input[2]/$input[3]/$input[4]/$input[5]" ;
            $url = "$cclite_base_url/recent/transactions/$limit" ;
            curl_setopt($ch, CURLOPT_URL, $url);
         break;

        case 'block':
            // $block_content = "case summary : $input[0]  $input[1]/$input[2]/$input[3]/$input[4]/$input[5]" ;
            // note 'block' is a Drupal thing...
            $url = "$cclite_base_url/recent/transactions/$limit" ;
            curl_setopt($ch, CURLOPT_URL, $url);
         break;

        case 'pay':
            // pay/test1/dalston/23/hack(s) using the merchant key
            // accept plural or singular version of currency name
            $pattern = '/(\S+)s/i';
            $replacement = '${1}';
            $input[4] = preg_replace($pattern, $replacement, $input[4]);
            //  $block_content = "case pay : $cclite_base_url/$input[0]/$input[1]/$input[2]/$input[3]/$input[4]" ;
            $url = "$cclite_base_url/pay/$input[1]/$input[2]/$input[3]/$input[4]" ;
            echo "pay url is $url" ;
            curl_setopt($ch, CURLOPT_URL, $url );
         break;

        case 'direct':
            // direct/adduser/dalston/test1/email using the merchant key, without using individual logon
            // non-working direct modify user
            if ($input[1] == 'adduser') {
            $url = "$cclite_base_url/direct/adduser/$input[2]/$input[3]/$input[4]" ;
            curl_setopt($ch, CURLOPT_URL, $url );
            } elseif ($input[1] == 'modifyuser') {
             // non-working currently
             // $url = "$cclite_base_url/direct/adduser/$input[2]/$input[3]/$input[4]" ;
             // curl_setopt($ch, CURLOPT_URL, $url );           
            }
         break;

        case 'modifyuser':
            // direct/modifyuser/dalston/test1/email using the merchant key, without using individual logon
            // non-working at present...
            $block_content = "case modifyuser : $stuff/$key";
            $url = "$cclite_base_url/direct/modifyuser/$input[1]/$input[2]/$input[3]" ;
            curl_setopt($ch, CURLOPT_URL, $url);
         break;

        // nothing to display in 
        // elgg specific show summary in spotlight, probably should return 'nothing'
        default:
             curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/summary");
    }
    $block_content = curl_exec($ch);

    // this version now logs off, gateway is 'transactional' doesn't stay connected...
    curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/logoff");
    $logoff = curl_exec($ch);
    curl_close($ch);

    // modify this at will to debug...
    if ($params['verbose']) {
         return "u:$url\n b:$block_content \n l:$logoff" ;
    } else {
         return $block_content ;
    }
 
}



// here are the tests, change these to your values...

$api_tests = array('recent'=> "recent",
                 'summary' => "summary",
                 'block' => "block",
                 'pay'  => "pay,test1,ccliekh_dalston,23,dally",
                 'adduser' => 'direct,adduser,ccliekh_dalston,test42,bogus\@bogus.net',
                 ) ;

foreach ($api_tests as $k => $v) {

      
     $call_params = explode(",",$api_tests[$k]) ;
     $contents = cclite_contents($call_params) ;
     echo "\nstart of test $k <br/>\n" ;
     echo $contents ;
     echo "\nend of test $k <br/><br/>\n\n" ;
}  

?>


