<?php

    /**
	 * Cclite payment page
	 *
	 * @package Cclite
	 * @license http://www.gnu.org/licenses/old-licenses/gpl-2.0.html GNU Public License version 2
	 * @author Hugh Barnard <hugh.barnard@gmail.com>
	 * @copyright Hugh Barnard 2008-2009
	 * @link http://www.hughbarnard.org/
	 */


$form_body = "<p>Payment Form</p>";

$form_body .= elgg_echo('to user');
$form_body .= elgg_view('input/text', array('internalname' => 'touser', 'value' => ''));
$form_body .= elgg_echo('currency');
$form_body .= elgg_view('input/text', array('internalname' => 'currency', 'value' => ''));
$form_body .= elgg_echo('quantity');
$form_body .= elgg_view('input/text', array('internalname' => 'quantity', 'value' => ''));
$form_body .= elgg_echo('description');
$form_body .= elgg_view('input/text', array('internalname' => 'description', 'value' => ''));
$form_body .= elgg_view('input/submit', array('internalname' => 'submit', 'value' => 'Pay'));
$form_body .= elgg_view('input/securitytoken');  

echo elgg_view('input/form', array('body' => $form_body, 'action' => "{$CONFIG->url}mod/cclite/actions/pay.php"));


?>

