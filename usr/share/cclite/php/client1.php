<?php
//
// +----------------------------------------------------------------------+
// | PHP Version 4                                                        |
// +----------------------------------------------------------------------+
// | Copyright (c) 1997-2003 The PHP Group                                |
// +----------------------------------------------------------------------+
// | This source file is subject to version 2.02 of the PHP license,      |
// | that is bundled with this package in the file LICENSE, and is        |
// | available at through the world-wide-web at                           |
// | http://www.php.net/license/2_02.txt.                                 |
// | If you did not receive a copy of the PHP license and are unable to   |
// | obtain it through the world-wide-web, please send a note to          |
// | license@php.net so we can mail you a copy immediately.               |
// +----------------------------------------------------------------------+
// | Authors: Shane Caraveo <Shane@Caraveo.com>                           |
// +----------------------------------------------------------------------+
//
// $Id: client.php,v 1.1 2005/08/15 16:29:31 colson Exp $
//

require_once 'SOAP/Client.php';

/**
 * this client runs against the example server in SOAP/example/server.php
 * it does not use WSDL to run these requests, but that can be changed easily by simply
 * adding '?wsdl' to the end of the url.
 */
$soapclient = new SOAP_Client("http://cclite.caca-cola.com:83/cgi-bin/ccserver.cgi");

//$soapclient = new SOAP_Client(null, array('location' => "http://cclite.caca-cola.com:83/cgi-bin/ccserver.cgi",
//                                     'uri'      => "http://cclite.caca-cola.com:83/Cclite"));

// this namespace is the same as declared in server.php

 $options = array('namespace' => 'urn:Cclite',
                 'trace' => 5);

   $token = 'test' ;
   $transaction = array() ;
// convert to standard transaction input format, fields etc.
// fromregistry : chelsea
   $transaction['fromregistry'] 		= 'chelsea' ;
// home : http://cclite.caca-cola.com:83/cgi-bin/cclite.cgi, for example
   $transaction['home']	      		= "" ; # no home, not a web transaction 
// subaction : om_trades
   $transaction['subaction']     		= 'om_trades' ;
// toregistry : dalston
   $transaction['toregistry']   		= 'chelsea' ;
// tradeAmount : 23
   $transaction['tradeAmount']  		= 23 ;
// tradeCurrency : ducket
   $transaction['tradeCurrency']  		= 'ducket' ;
// tradeDate : this is date of reception and processing, in fact
   $transaction['tradeDate'] 			= '2006-01-01' ;
// tradeTitle : added by this routine
   $transaction['tradeTitle']  			= "PHP transaction: see description" ;
// tradeDescription 
   $transaction['tradeDescription']  		= 'test' ;
// tradeDestination : ddawg
   $transaction['tradeDestination']  		= 'ddawg' ;
// tradeItem : test to see variables
// tradeSource : manager 
   $transaction['tradeSource']  		= 'manager' ;
//
// call ordinary transaction


// check_user_and_add_trade ($transaction['toregistry'],'om_trades',&$transaction,$token)  ;

// $ret = $soapclient->call("echoStringSimple",
//                         $params = array("inputStringSimple"=>"this is a test string"),
//                         $options);

$ret = $soapclient->call("wrapper_for_check_user_and_add_trade",
                          $params = 'chelsea',			
                                    'om_trades', 
                            array(                           
			   'fromregistry' 		=> 'chelsea', 
   			   'home'	      		=> '',  
   			   'subaction'     		=> 'om_trades', 
   			   'toregistry'   		=> 'chelsea', 
   			   'tradeAmount'  		=> '23', 
   			   'tradeCurrency'  		=> 'ducket', 
   			   'tradeDate' 			=> '2006-01-01', 
   			   'tradeTitle'  		=> "PHP transaction: see description", 
   			   'tradeDescription' 		=> 'test', 
   			   'tradeDestination'  		=> 'ddawg', 
   			   'tradeSource'  		=> 'manager'),
     			    $token,
                            $options,null);


/* $ret = $soapclient->call("Cclite#wrapper_for_check_user_and_add_trade",
                          $params = 'chelsea','om_trades',
			   'fromregistry',
			   'chelsea', 
   			   'home',
 			   ' ',  
   			   'subaction', 
                           'om_trades', 
   			   'toregistry', 
			   'chelsea', 
   			   'tradeAmount',
			    '23', 
   			   'tradeCurrency', 
                           'ducket', 
   			   'tradeDate', 
			   '2006-01-01', 
   			   'tradeTitle', 
			   'PHP transaction: see description', 
   			   'tradeDescription', 
                           'test', 
   			   'tradeDestination', 
                           'ddawg', 
   			   'tradeSource',
                           'manager',
     			    $token,
                            $options);

*/

#print $soapclient->__get_wire();
print_r($ret);echo "<br>\n";


