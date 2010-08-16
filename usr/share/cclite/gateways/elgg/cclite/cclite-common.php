<?php
// $Id$

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

 $user =  get_loggedin_user()->name ;
// hack for the moment
 $domain = get_plugin_setting('cclite_payment_domain','cclite');
 $protocol = get_plugin_setting('cclite_protocol','cclite');
 $apikey = get_plugin_setting('cclite_api_key','cclite');
 $hashing = get_plugin_setting('cclite_hashing_algorithm','cclite');
 $registry = get_plugin_setting('cclite_registry','cclite');
 $limit = 5 ; //for the moment,five records
 
 $values = array('user'=> $user,
                 'limit' => $limit,
                 'domain' => $domain,
                 'protocol'=> $protocol,
                 'apikey'=> $apikey,
                 'hashing'=> $hashing,
                 'registry'=> $registry) ;

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
      $api_hash = urlsafe_b64encode($api_hash);
/*
      $str = "server is" . $_SERVER['SERVER_ADDR']. " ".$params['hashing'] . "". "<br/>" . "user is " .  $user . "<br/>" . "registry is " .   $registry ; 
      echo $str ;
*/

     // construct the payment url from configuration information
        $cclite_base_url =  'http://' . $params['domain'];

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
// default operation is deliver a transaction summary to user
function cclite_contents() { 
 
    $params = get_gateway_variables() ;
    $user = $params['user'] ;
    $registry = $params['registry'] ;
    $limit = $params['limit'] ;

    $arg_list = func_get_args();
    $numargs = count($arg_list);
    $block_content = '';
    $cclite_operation = '';

    //  debug arguments passed
    //$stuff = "|" . implode("-", $arg_list) . "|";

    // construct the payment url from configuration information
    $cclite_base_url =  'http://' . $params['domain'];

    $ch = curl_init();
    
    // try and logon to cclite, return emptyhanded, if nothing...
    if ($arg_list[0] != 'adduser') {
        $logon_result = cclite_remote_logon();
        if (strlen($logon_result[1])) {
            curl_setopt($ch, CURLOPT_COOKIE, $logon_result[1]);
        } else {
             // no need for logon to add user...
        return;
        }
    }
     
  //  log_debug("logon result 1", $logon_result[1]);
    curl_setopt($ch, CURLOPT_AUTOREFERER, TRUE);
    curl_setopt($ch, CURLOPT_COOKIESESSION, TRUE);
    curl_setopt($ch, CURLOPT_FAILONERROR, FALSE);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
    curl_setopt($ch, CURLOPT_FRESH_CONNECT, FALSE);
    curl_setopt($ch, CURLOPT_HEADER, FALSE);
    curl_setopt($ch, CURLOPT_POST, TRUE);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 30);
    // this switch statement needs to map to the Rewrites in the cclite .htaccess file, so if you're
    // doing something custom-made, you need to think about:
    // -here-, .htaccess and various bits of login in the cclite motor
    switch ($arg_list[0]) {
        case 'recent':
            // $block_content = "case recent transactions : $arg_list[0]/$arg_list[1]" ;
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/recent/transactions")/$limit;
        break;
        case 'summary':
            // $block_content = "case summary : $arg_list[0]  $arg_list[1]/$arg_list[2]/$arg_list[3]/$arg_list[4]/$arg_list[5]" ;
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/summary");
        break;

        case 'block':
            // $block_content = "case summary : $arg_list[0]  $arg_list[1]/$arg_list[2]/$arg_list[3]/$arg_list[4]/$arg_list[5]" ;
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/summary");
        break;

        case 'pay':
            // pay/test1/dalston/23/hack(s) using the merchant key
            // accept plural or singular version of currency name
            $pattern = '/(\S+)s/i';
            $replacement = '${1}';
            $arg_list[4] = preg_replace($pattern, $replacement, $arg_list[4]);
            //  $block_content = "case pay : $cclite_base_url/$arg_list[0]/$arg_list[1]/$arg_list[2]/$arg_list[3]/$arg_list[4]" ;
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/pay/$arg_list[1]/$arg_list[2]/$arg_list[3]/$arg_list[4]");
        break;
        case 'adduser':
            // direct/adduser/dalston/test1/email using the merchant key, without using individual logon
            $block_content = "case adduser : $stuff/$key";
        //    log_debug("in adduser ", "$cclite_base_url/direct/adduser/$arg_list[1]/$arg_list[2]/$arg_list[3]");
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/direct/adduser/$registry/$arg_list[1]/email");
        break;
        case 'modifyuser':
            // direct/modifyuser/dalston/test1/email using the merchant key, without using individual logon
            // non-working at present...
            $block_content = "case modifyuser : $stuff/$key";
        //    log_debug("in modifyuser ", "$cclite_base_url/direct/modifyuser/$arg_list[1]/$arg_list[2]/$arg_list[3]");
            curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/direct/modifyuser/$arg_list[1]/$arg_list[2]/$arg_list[3]");
        break;
        // nothing to display in 
        // elgg specific show summary in spotlight
        default:
             curl_setopt($ch, CURLOPT_URL, "$cclite_base_url/summary");
    }
    $block_content = curl_exec($ch);
    curl_close($ch);

    return $block_content;


}
?>


