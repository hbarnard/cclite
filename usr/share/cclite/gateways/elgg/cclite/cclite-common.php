<?php
// $Id$

// new version of cclite-common.php with oauth for elgg, at least...
// elgg needs the outh plugin and url_getter plugin too with this plugin...


function oauth_processing () {

// create the consumer
$consument = oauth_create_consumer('cclite-test', 'cclite test elgg-oauth consumer', '123123', '123123');
set_plugin_setting('oauthconsumer', $consument->getGUID());

}



// used to transport merchant key hash
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

/* all the application specific code here, 
getting api variables differs from framework to framework

*/

function get_gateway_variables () {

/*
 $user =  get_loggedin_user()->name ;
 $domain = $vars['entity']->cclite_payment_domain ;
 $protocol = $vars['entity']->cclite_transfer_protocol ;
 $apikey = $vars['entity']->cclite_api_key;
 $hashing = $vars['entity']->cclite_hashing_algorithm;
 $registry = $vars['entity']->cclite_registry;
 $limit = $vars['entity']->cclite_api_transaction_display_limit ;
*/ 

 $user =  get_loggedin_user()->name ;
 
 $domain = 	get_plugin_setting( 'cclite_payment_domain', 'cclite') 	 ;
 $protocol = 	get_plugin_setting('cclite_protocol', 'cclite') ;
 $apikey =  	get_plugin_setting('cclite_api_key', 'cclite') ;
 $hashing = 	get_plugin_setting('cclite_hashing_algorithm', 'cclite') ;
 $registry = 	get_plugin_setting('cclite_registry', 'cclite') ;
 $limit = 	get_plugin_setting('cclite_api_transaction_display_limit', 'cclite') ; 


 $values = array('user'=> $user,
                 'limit' => $limit,
                 'domain' => $domain,
                 'protocol'=> $protocol,
                 'apikey'=> $apikey,
                 'hashing'=> $hashing,
                 'registry'=> $registry,
                 'verbose' => 0,
                 ) ;

/*
 $str = "getting variables " . $_SERVER['SERVER_ADDR'] . "<br/>" . "user is " .  $user . "<br/>" . "registry is " .   $registry ; 
 echo $str ;
*/

 return $values ;
}


function cclite_remote_logon() {


    $params = get_gateway_variables() ;
    $user = $params['user'] ;
    $registry = $params['registry'] ;

    // if there's no elgg user, don't even bother to try...

    if ( strlen($user) ) {

     //   so when you use this, nake sure that the server ip checks against the list in the cclite registry!
      $api_hash = hash ( $params['hashing'], ( $params['apikey'] . $_SERVER['SERVER_ADDR']), 'true');
    //  $api_hash = hash ( 'sha1', ( $params['apikey'] . $_SERVER['SERVER_ADDR']), 'true');
      $api_hash = urlsafe_b64encode($api_hash);
/*
      $str = "server is" . $_SERVER['SERVER_ADDR']. " ".$params['hashing'] . "". "<br/>" . "user is " .  $user . "<br/>" . "registry is " .   $registry ; 
      echo $str ;
*/

        // construct the payment url from configuration information
        $cclite_base_url =  $params['protocol'] . "://" . $params['domain'];

        $ch = curl_init();
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
 
    $params = get_gateway_variables() ;
    $user = $params['user'] ;
    $registry = $params['registry'] ;
    $limit = $params['limit'] ;

    $block_content = '';
    $cclite_operation = '';
    $logon_result = '' ;
    $url = '' ;

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
     
    // construct the payment url from configuration information
    $cclite_base_url =  $params['protocol'] . "://" . $params['domain'];


    curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
    curl_setopt($ch, CURLOPT_COOKIESESSION, TRUE);
    curl_setopt($ch, CURLOPT_FAILONERROR, FALSE);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
    curl_setopt($ch, CURLOPT_FRESH_CONNECT, FALSE);
    curl_setopt($ch, CURLOPT_HEADER, FALSE);
    curl_setopt($ch, CURLOPT_POST, FALSE);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 30);

    // switch REST url depending on required cclite operation
    switch ($input[0]) {

        case 'recent':
            // $block_content = "case recent transactions : $input[0]/$input[1]" ;
            
            $url = "$cclite_base_url/recent/transactions/$limit" ;
            curl_setopt($ch, CURLOPT_URL, $url);
        break;

        case 'recent.json':
            // $block_content = "case recent transactions : $input[0]/$input[1]" ;
            // recent transactions delivered as json format, will need post-processing....
            $url = "$cclite_base_url/recent/transactions.json" ;
            curl_setopt($ch, CURLOPT_URL, $url);
        break;


        case 'summary':
            // $block_content = "case summary : $input[0]  $input[1]/$input[2]/$input[3]/$input[4]/$input[5]" ;
            $url = "$cclite_base_url/summary" ;
            curl_setopt($ch, CURLOPT_URL, $url);
         break;

       case 'summary.json':
            // $block_content = "case summary : $input[0]  $input[1]/$input[2]/$input[3]/$input[4]/$input[5]" ;
            $url = "$cclite_base_url/summary.json" ;
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
            $input[3] = preg_replace($pattern, $replacement, $input[3]);
            //  $block_content = "case pay : $cclite_base_url/$input[0]/$input[1]/$input[2]/$input[3]/$input[4]" ;
            $url = "$cclite_base_url/pay/$input[1]/$registry/$input[2]/$input[3]" ;
            // echo "pay url is $url" ;
            curl_setopt($ch, CURLOPT_URL, $url );
         break;

        case 'direct':
            // direct/adduser/dalston/test1/bogus@bogus.net using the merchant key, without using individual logon
            // non-working direct modify user
            if ($input[1] == 'adduser') {
            $url = "$cclite_base_url/direct/adduser/$registry/$input[2]/$input[3]" ;
            curl_setopt($ch, CURLOPT_URL, $url );
            } elseif ($input[1] == 'modifyuser') {
             // non-working currently
             // $url = "$cclite_base_url/direct/adduser/$registry/$input[2]/$input[3]" ;
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

    // this version now logs off, gateway is 'transactional' and stateless doesn't stay connected...
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

// oauth functions

function test_and_get_token() {
 
  $token = oauth_get_token($user, $consumer);

  // not set up for Oauth, take to setup view
  if ($token->AccessToken == NULL && $token->RequestToken == NULL) {

    /* msg: a text message to display to the user. If this is left out, the system will use a generic one.
     * consumer_key: the key for the consumer, used to look up the consumer object downstream
     * user_auth: URL for user authentication for the service you're trying to access
     * request_url: URL for getting request tokens
     * access_url: URL for trading validated request tokens for access tokens
     * return_to: URL to return to once this whole process is complete */


  }

}


?>


