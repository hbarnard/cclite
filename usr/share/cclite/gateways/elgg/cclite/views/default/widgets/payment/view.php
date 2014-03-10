
<script type="text/javascript">

$(document).ready(function() { 
    var options = { 
        target:        '#output1',   // target element(s) to be updated with server response 
        beforeSubmit:  showRequest,  // pre-submit callback 
        success:       showResponse  // post-submit callback 
 
        // other available options: 
         url:         <?php echo "{$CONFIG->url}action/cclite/pay" ?>           // override for form's 'action' attribute 
        //type:      type        // 'get' or 'post', override for form's 'method' attribute 
        //dataType:  null        // 'xml', 'script', or 'json' (expected server response type) 
        //clearForm: true        // clear all form fields after successful submit 
        //resetForm: true        // reset the form after successful submit 
 
        // $.ajax options can be used here too, for example: 
        //timeout:   3000 
    }; 
 
    // bind form using 'ajaxForm' 
    $('#payment').ajaxForm(options); 
}); 
 
// pre-submit callback 
function showRequest(formData, jqForm, options) { 
    // formData is an array; here we use $.param to convert it to a string to display it 
    // but the form plugin does this for you automatically when it submits the data 
    var queryString = $.param(formData); 
 
    // jqForm is a jQuery object encapsulating the form element.  To access the 
    // DOM element for the form do this: 
    // var formElement = jqForm[0]; 
 
    alert('About to submit: \n\n' + queryString); 
 
    // here we could return false to prevent the form from being submitted; 
    // returning anything other than false will allow the form submit to continue 
    return true; 
} 
 
// post-submit callback 
function showResponse(responseText, statusText, xhr, $form)  { 
    // for normal html responses, the first argument to the success callback 
    // is the XMLHttpRequest object's responseText property 
 
    // if the ajaxForm method was passed an Options Object with the dataType 
    // property set to 'xml' then the first argument to the success callback 
    // is the XMLHttpRequest object's responseXML property 
 
    // if the ajaxForm method was passed an Options Object with the dataType 
    // property set to 'json' then the first argument to the success callback 
    // is the json data object returned by the server 
 
    alert('status: ' + statusText + '\n\nresponseText: \n' + responseText + 
        '\n\nThe output div should have already been updated with the responseText.'); 
} 
</script>

<div id="output1"></div>

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
 
echo elgg_view('input/form', array('body' => $form_body, 'id'=> 'payment', 'action' => "{$CONFIG->url}action/cclite/pay"));


?>

