<?php
/*
  cclite.php 
  $Id: cclite.php,v 1.00 2006 hpdl Exp $
  by Hugh Barnard hugh.barnard@hughbarnard.org
  Based on:
  $Id: ohiobarter.php,v 2.00 2004/11/13 hpdl Exp $
  by Jeff Thornton rev@OhioBarter.org
  Revised the link to payment system at http://OhioBarter.org
  based on paypal.php
  osCommerce, Open Source E-Commerce Solutions
  http://www.oscommerce.com

  Copyright (c) 2003 osCommerce

  Released under the GNU General Public License
*/

  class cclite {
    var $code, $title, $description, $enabled;

// class constructor
    function cclite() {
      global $order;
      

      $this->code 		= 'cclite';
      $this->title 		= MODULE_PAYMENT_CCLITE_TEXT_TITLE;
      $this->description 	= MODULE_PAYMENT_CCLITE_TEXT_DESCRIPTION;
      $this->sort_order 	= MODULE_PAYMENT_CCLITE_SORT_ORDER;
      $this->enabled 		= ((MODULE_PAYMENT_CCLITE_STATUS == 'True') ? true : false);

      if ((int)MODULE_PAYMENT_CCLITE_ORDER_STATUS_ID > 0) {
        $this->order_status 	= MODULE_PAYMENT_CCLITE_ORDER_STATUS_ID;
      }

      if (is_object($order)) $this->update_status();
   // GURL = Gateway URL is set in the Cclite payment module configuration
      $this->form_action_url 	= MODULE_PAYMENT_CCLITE_GURL;
    }

// class methods
    function update_status() {
      global $order;

      if ( ($this->enabled == true) && ((int)MODULE_PAYMENT_CCLITE_ZONE > 0) ) {
        $check_flag = false;
        $check_query = tep_db_query("select zone_id from " . TABLE_ZONES_TO_GEO_ZONES . " where geo_zone_id = '" . MODULE_PAYMENT_CCLITE_ZONE . "' and zone_country_id = '" . $order->billing['country']['id'] . "' order by zone_id");
        while ($check = tep_db_fetch_array($check_query)) {
          if ($check['zone_id'] < 1) {
            $check_flag = true;
            break;
          } elseif ($check['zone_id'] == $order->billing['zone_id']) {
            $check_flag = true;
            break;
          }
        }

        if ($check_flag == false) {
          $this->enabled = false;
        }
      }
    }

    function javascript_validation() {
      return false;
    }

    function selection() {
      return array('id' => $this->code,
                   'module' => $this->title);
    }

    function pre_confirmation_check() {
      return false;
    }

    function confirmation() {
      return false;
    }



    function process_button() {




    function split_payments_by_manufacturer($manufacturers,$order) {
      $transaction_totals = array() ;  // holds totals by manufacturer
      $payments = "" ;

      //echo $order->products[0]['id'] ;
      /* gets the manufacturer name for each product line, so that subtotals can be made
       per 'manufacturer' (a community member selling something, for example)
       this can be done with a join but might be big, to be optimised perhaps...
      */

     for ($i=0, $n=sizeof($order->products); $i<$n; $i++) {
      $result 		= tep_db_query("select * from " . TABLE_PRODUCTS . " where products_id =" . $order->products[$i]['id']);
      $prdarray 	= tep_db_fetch_array($result) ;
      $result 		= tep_db_query("select * from " . TABLE_MANUFACTURERS . " where manufacturers_id =" . $prdarray['manufacturers_id']);
      $mfarray 		= tep_db_fetch_array($result) ;

      $transaction_totals[$mfarray['manufacturers_name']] 
           = $transaction_totals[$mfarray['manufacturers_name']] + ($order->products[$i]['qty'] * $order->products[$i]['price']) ;
     }
      reset($transaction_totals);
     foreach ($transaction_totals as $key => $val) {

         $payments = $payments. tep_draw_hidden_field("to:".$key, $val);
      }
      return $payments ;
    }
      global $order, $currencies, $currency;

      /* if (MODULE_PAYMENT_CCLITE_CURRENCY == 'Selected Currency') {
        $my_currency = $currency;
      } else {
        $my_currency = substr(MODULE_PAYMENT_CCLITE_CURRENCY, 5);
      }
      if (!in_array($my_currency, array('CAD', 'EUR', 'GBP', 'JPY', 'USD'))) {

        $my_currency = MODULE_PAYMENT_CCLITE_CURRENCY ;
     
      }       */

   /* these are all the hidden fields passed to cclite, some should be in the module configuration
    later, the transaction type is oscommerce_pay which will allow a complete transaction, if the
    merchant key and the manufacturer (service or goods supplier) and customer (consumer) email 
    addresses are OK and the transaction is valid
   */
     $payments = split_payments_by_manufacturer($manufacturers,$order) ;
   
     $process_button_string =  tep_draw_hidden_field('cmd', '_xclick') .
                               tep_draw_hidden_field('merchantkey', MODULE_PAYMENT_CCLITE_MERCHANTKEY) .
                               tep_draw_hidden_field('action', 'oscommerce_pay') .
                               tep_draw_hidden_field('registry', MODULE_PAYMENT_CCLITE_DEFAULTREG) .
                               tep_draw_hidden_field('onlinestatus', MODULE_PAYMENT_CCLITE_ONLINE) .
                               tep_draw_hidden_field('email', $order->customer['email_address']) .
                               tep_draw_hidden_field('return_url', tep_href_link(FILENAME_CHECKOUT_PROCESS, '', 'SSL', false)) .
                               tep_draw_hidden_field('item_id', STORE_NAME) .
                               tep_draw_hidden_field('version', '1.0') .
                               tep_draw_hidden_field('amount', number_format($order->info['total'] * $currencies->get_value($my_currency), $currencies->get_decimal_places($my_currency))) .
                               tep_draw_hidden_field('shipping', number_format($order->info['shipping_cost'] * $currencies->get_value($my_currency), $currencies->get_decimal_places($my_currency))) .
                               tep_draw_hidden_field('currency_code', MODULE_PAYMENT_CCLITE_CURRENCY) .
                               tep_draw_hidden_field('return_url', tep_href_link(FILENAME_CHECKOUT_PROCESS, '', 'SSL')) .
                               tep_draw_hidden_field('cancel_url', tep_href_link(FILENAME_CHECKOUT_PAYMENT, '', 'SSL')).
                               $payments ;


      return $process_button_string;
    }

    function before_process() {
      return false;
    }

    function after_process() {
      return false;
    }

    function output_error() {
      return false;
    }

    function check() {
      if (!isset($this->_check)) {
        $check_query = tep_db_query("select configuration_value from " . TABLE_CONFIGURATION . " where configuration_key = 'MODULE_PAYMENT_CCLITE_STATUS'");
        $this->_check = tep_db_num_rows($check_query);
      }
      return $this->_check;
    }

    function install() {
      tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, set_function, date_added) values ('Enable CCLITE Module', 'MODULE_PAYMENT_CCLITE_STATUS', 'True', 'Do you want to accept CCLITE payments?', '6', '3', 'tep_cfg_select_option(array(\'True\', \'False\'), ', now())");
//    tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, set_function, date_added) values ('Transaction Currency', 'MODULE_PAYMENT_CCLITE_CURRENCY', 'Selected Currency', 'The currency to use for credit card transactions', '6', '6', 'tep_cfg_select_option(array(\'Selected Currency\',\'Only ducket\',\'Only bucket\',\'Only EUR\',\'Only GBP\',\'Only JPY\'), ', now())");
// cclite configuration fields added
// merchant key to link shop to cclite instance
     tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, date_added) values ('Merchant Key', 'MODULE_PAYMENT_CCLITE_MERCHANTKEY', '1234', 'The Merchant key to use for the CCLITE service Please change this often', '6', '4', now())") ;
// currency to be used
     tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, date_added) values ('Currency Code', 'MODULE_PAYMENT_CCLITE_CURRENCY', 'DCK', 'Currency code for currency', '6', '4', now())") ;
// registry to which payments are applied in cclite
     tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, date_added) values ('Default Registry', 'MODULE_PAYMENT_CCLITE_DEFAULTREG', 'chelsea', 'The default registry that will accept the payments - In this version, only registry per gateway is allowed', '6', '4', now())") ;
// url for cclite instance: usually this should be https!
     tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, date_added) values ('Gateway URL', 'MODULE_PAYMENT_CCLITE_GURL', 'http\:\/\/cclite.caca-cola.com\:83\/cgi-bin\/cclite\.cgi', 'The gateway url to use for the CCLITE service', '6', '4', now())") ;
// whether the gateway mechanism is being tested or payments are being applied
      tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, set_function, date_added) values ('Enable Payments', 'MODULE_PAYMENT_CCLITE_ONLINE', 'test', 'Do you want process CCLITE payments or just test?', '6', '3', 'tep_cfg_select_option(array(\'test\', \'live\'), ', now())");
      tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, date_added) values ('Sort order of display.', 'MODULE_PAYMENT_CCLITE_SORT_ORDER', '0', 'Sort order of display. Lowest is displayed first.', '6', '0', now())");
      tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, use_function, set_function, date_added) values ('Payment Zone', 'MODULE_PAYMENT_CCLITE_ZONE', '0', 'If a zone is selected, only enable this payment method for that zone.', '6', '2', 'tep_get_zone_class_title', 'tep_cfg_pull_down_zone_classes(', now())");
      tep_db_query("insert into " . TABLE_CONFIGURATION . " (configuration_title, configuration_key, configuration_value, configuration_description, configuration_group_id, sort_order, set_function, use_function, date_added) values ('Set Order Status', 'MODULE_PAYMENT_CCLITE_ORDER_STATUS_ID', '0', 'Set the status of orders made with this payment module to this value', '6', '0', 'tep_cfg_pull_down_order_statuses(', 'tep_get_order_status_name', now())");
    }

    function remove() {
      tep_db_query("delete from " . TABLE_CONFIGURATION . " where configuration_key in ('" . implode("', '", $this->keys()) . "')");
    }

    function keys() {
      return array('MODULE_PAYMENT_CCLITE_STATUS', 'MODULE_PAYMENT_CCLITE_CURRENCY', 'MODULE_PAYMENT_CCLITE_ZONE', 'MODULE_PAYMENT_CCLITE_ORDER_STATUS_ID', 'MODULE_PAYMENT_CCLITE_SORT_ORDER','MODULE_PAYMENT_CCLITE_MERCHANTKEY','MODULE_PAYMENT_CCLITE_GURL','MODULE_PAYMENT_CCLITE_DEFAULTREG','MODULE_PAYMENT_CCLITE_ONLINE');
    }
  }
?>
