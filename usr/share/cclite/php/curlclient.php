<?php

/* this is a quick and messy example for a private gateway from a php application
to cclite, the transaction will return a transaction reference and a transaction
accepted message, if the payment is recorded 

It does the payment transaction but doesn't exit properly at the moment.

Change the configuration to get this working. It's clear that this is
a lot more secure if you use https, up to to you...

Two things you can improve:
1. Process the return message from the transaction
2. Make it return to its home application


Read the curl documentation for php...!

*/

/* logon and store the logon cookies */

/* configuration variables */
$domain = "cclite.cclite.k-hosting.co.uk/" ;
$cookiefile = "/tmp/cclitecookies" ;
$user = "test2" ;
$registry = "ccliekh_dalston" ;
$password = "password" ;
$currency = "dally" ;
$amount = "2" ;
$payto = "test1" ;

$ch = curl_init();
//$fp = fopen("example.html", "w");
curl_setopt($ch, CURLOPT_COOKIEJAR, $cookiefile);
curl_setopt($ch,CURLOPT_URL,"http://$domain/logon/$user/$registry/$password");
curl_setopt($ch, CURLOPT_VERBOSE, 1);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION,1) ;
//curl_setopt($ch,CURLOPT_RETURNTRANSFER,1);
//curl_setopt($ch, CURLOPT_FILE, $fp);
curl_setopt($ch, CURLOPT_HEADER, 0);

$pg = curl_exec($ch);
//fclose($fp);
unset($ch);

/* use the logon cookies and pay someone */
$ch = curl_init();
//$fp = fopen("example1.html", "w");
curl_setopt($ch, CURLOPT_HEADER, 0);
curl_setopt($ch, CURLOPT_COOKIEFILE, $cookiefile);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION,1) ;
curl_setopt($ch,CURLOPT_URL,"http://$domain/pay/$payto/$registry/$amount/$currency");
//curl_setopt($ch,CURLOPT_RETURNTRANSFER,1);
curl_setopt($ch, CURLOPT_VERBOSE, 1);
//curl_setopt($ch, CURLOPT_FILE, $fp1);
$pg = curl_exec($ch);
curl_close($ch);
//fclose($fp);
unset($ch);


/*now logoff which 'should' zeroize the cookies*/
$ch = curl_init();
//$fp = fopen("example1.html", "w");
curl_setopt($ch, CURLOPT_HEADER, 0);
curl_setopt($ch, CURLOPT_COOKIEFILE, $cookiefile);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION,1) ;
curl_setopt($ch,CURLOPT_URL,"http://$domain/logoff");
//curl_setopt($ch,CURLOPT_RETURNTRANSFER,1);
curl_setopt($ch, CURLOPT_VERBOSE, 1);
//curl_setopt($ch, CURLOPT_FILE, $fp1);
$pg = curl_exec($ch);
curl_close($ch);
//fclose($fp);
unset($ch);

exit() ;
?> 