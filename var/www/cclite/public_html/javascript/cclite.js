/* 
   Main tailor made javascript for cclite, uses jquery and hashtable. Converted
   to be multilingual and use part [js- prefixed] of the main literals file in 06/2011

   It conttols the following items:
   * statistics
   * mail and csv transactions
   * gammu messages pickup
   * batch upload
   * logon/logoff messages at top
   * various search autocompletes [these are due for upgrade]

  Note that if you use log.console and firebug is switched off the javascript
  will block. So comment out...

  Hugh Barnard August 2011

*/


// window.loadFirebugConsole() ;
 
 stats_interval_id = 0;
 mail_interval_id = 0;
 gpg_mail_interval_id = 0;
 csv_interval_id = 0;
 rss_interval_id = 0;
 gammu_interval_id = 0 ;
 message_data = '' ;
 messages = new Hashtable();
 



/* blink the status message, used for bringing system down */

function blinktext() {                               
                   if  ($('#status_message').css('color') != 'red') {
                       $('#status_message').css('color','red') ;
                       $('#status_message').css('background-color','white') ;
                       
				   } else {
                        $('#status_message').css('color','white') ;
                         $('#status_message').css('background-color','red') ;
              }
              return ;
}

/*  logout users before bringing system down  */

function auto_logout() {
location.href= '/cgi-bin/cclite.cgi?action=logoff' ;	
return ;		
}	
	
function call_auto_logout () {
$('#status_message').text('Registry going off-line now') ;		
var t=setTimeout("auto_logout()",360000);		
}	

function stripe() {
     striper('tbody', 'stripy', 'tr', 'odd,even');
 }

 /* decimal tradeamounts etc. if decimals are switched on  */

function validatedecimals(id, amount) {


     // see whether we are using decimal point
     var usedecimals = $('div#usedecimals').text();

     if (usedecimals == 'no' && amount == parseInt(amount)) {
         $(id).css('background-color', 'lightgreen');
         //  alert('value is parseint ' + amount) ; 
     } else if (usedecimals == 'yes' && amount == parseFloat(amount)) {
         $(id).css('background-color', 'lightgreen');
         //  alert('value is parsefloat ' + amount) ;
     } else {
         $(id).css('background-color', '#F08080');
         $(id).focus();
         //  alert('else ' + amount + ' ' + usedecimals ) ;
     }

     return;

 }



 /* multilingual messages 
 these are js- prefixed messages in the 'normal' literals
 file. Later all this will go into the database....this is async
 because various things were trying to use the message values
 -before- they were loaded...
 */

 function readmessages() {

      $.ajax({
             method: 'get',
             url: '/cgi-bin/cclite.cgi?action=readmessages',
             dataType:'json',
             async: false,
             success: function (data) {
                
                 $.each(data.data, function(i, value) {
                   ;
                   for (var key in value) {
                    var patt = /js/;
                    if ( key.search(patt) == 0 ) {   // found js at start...
                        newkey = key.replace(/^js-/,'')  ;     // strip off js-    
                        messages.put(newkey,value[key]) ;
                       //return( false );
                    } // endif
                   } // end for                   
                 });// end each
           }} //end success function
         ); // end ajax


  return messages ;  

 }



/* 
get statistics for graphs....

 */

var stats ;

function getstats() {


   $.ajax({
             method: 'get',
             url: '/cgi-bin/cclite.cgi?action=getstats',
             dataType:'json',
             async: false,
             success: function (stats) {
                date = new Date() ;
                date_string = date.toLocaleString() ;

                // show the sparklines...
                $('#stats_summary').show() ;

                // clear out the last one
                $('#volumes_bargraph').html('') ;
                $('#average_bargraph').html('') ;
                $('#volumes_sparkbar').html('') ;
                $('#average_sparkline').html('') ;

                // give some height
                $('#volumes_bargraph').height(600) ;
                $('#average_bargraph').height(600) ;

                $('#transaction_vol_title').html('Transaction Volume');
                $('#averages_title').html('Average Transaction Size');

	      
                if (stats.message == 'ok') {
                 new Ico.SparkLine(document.getElementById('average_sparkline'), stats.data[1].avg , { width: 30, height: 14, background_colour: '#ccc' });
                 new Ico.SparkBar(document.getElementById( 'volumes_sparkbar'), stats.data[3].vols, { width: 30, height: 14, background_colour: '#ccc' });
                 new Ico.HorizontalBarGraph(document.getElementById('volumes_bargraph'), stats.data[3].vols, { labels: stats.data[0].vtimes });
                 new Ico.HorizontalBarGraph(document.getElementById('average_bargraph'), stats.data[1].avg, { labels: stats.data[2].stimes });
			   
			   } else {
				$('#volumes_bargraph').html('No data for this period')  ;
				$('#average_bargraph').html('No data for this period')  ;
			   }

               
                 $('#update_date1').html(date_string);
                 $('#update_date2').html(date_string);

           }} //end success function
         ); // end ajax

//new Ico.SparkLine($('sparkline'), [21, 41, 32, 1, 10, 5, 32, 10, 23], { width: 30, height: 14, background_colour: '#ccc' });

// new Ico.SparkBar($('sparkline_2'), [1, 5, 10, 15, 20, 15, 10, 15, 30, 15, 10], { width: 30, height: 14, background_colour: '#ccc' });
//new Ico.SparkLine($('sparkline_3'), [10, 1, 12, 3, 4, 8, 5], { width: 60, height: 14, highlight: { colour: '#ff0000' }, acceptable_range: [5, 9], background_colour: '#ccc' });

/* bargraph for volumes */
//new Ico.BarGraph($('bargraph_6'), [2, 5, 1, 10, 15, 33, 20, 25, 1], { labels: ['label one', 'label two', 'label three', 'label four', 'label five', 'label six', 'label seven', 'label eight', 'label nine'] });

/* line graph for comparative plots */
//new Ico.LineGraph($('linegraph'), { one: [30, 5, 1, 10, 15, 18, 20, 25, 1], two: [10, 9, 3, 30, 1, 10, 5, 33, 33], three: [5, 4, 10, 1, 30, 11, 33, 12, 22]}, { markers: 'circle', colours: { one: '#990000', two: '#009900', three: '#000099'}, labels: ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'], meanline: true, grid: true});

} // end of getstats


 

 /*   build selects for language choice at top an

do also userLang  in
 correct language, not used currently because of character set display
problems in drop down, chinese, arabic etc.  08/2011  

*/

function build_language_selects (messages) {

var language_keys = new Array(
"english-en",
"french-fr",
"german-de",
"dutch-nl",
"russian-ru",
"thai-th",
"chinese-zh",
"portugese-pt",
"italian-it",
"japanese-ja",
"greek-el",
"arabic-ar",
"spanish-es" ) ;

$.each(language_keys, function(index,value)
{   
     var literal = value.split('-') ;
     $('#language_value').
          append($("<option></option>").
          attr("value",literal[1]).
          text(messages.get(literal[0]))); 
 });  


  $.each(language_keys, function(index, value)
 {   
     $('#userLang').
          append($("<option></option>").
          attr("value",value).
          text(messages.get(value))); 
 });

 }


/*
function show_registries () {

  $.ajaxSetup ({  
         cache: false  
     });  
     var ajax_load = "<img src='img/load.gif' alt='loading...' />";  
      
 //  load() functions  
     var loadUrl = "/cgi-bin/protected/ccinstall.cgi?action=showregistries" ;  
     $("#load_basic").click(function(){  
         $("#result").html('').load(loadUrl);  
     });  

 return ;
}
*/


function change_install(id) {

     selector = '#' + eval("id");
     var selected = $('install_type' + " option:selected").index();
    
     if ($("#install_type").val() == 'full') {
         // $('#installer2').attr('disabled', '1');
          
         $("input").each(function (i) {
            
             $(this).removeAttr('readonly');
             $(this).parent().parent().show();
              $(this).css('color', 'black');
             
            
         });

     } else {
        
         $('#installer2').removeAttr('disabled');
         $("input").each(function (i) {
         // custom attribute, firefox OK
           if ($(this).attr('data-simple') != 'yes' ) {
            if ($(this).attr('readonly') == 0) {
               $(this).attr('readonly','1');
               $(this).css('color', 'white');
            } 
           }
         });

     }


}

 /* hide all the complex options, first of all */

 function hide_full_installation_options () {
                 
     if ($("#install_type").val() != 'full') {
        $("input").each(function (i) {
         // custom attribute, firefox OK
           if ($(this).attr('data-simple') != 'yes' ) {
               $(this).attr('readonly','1');
               $(this).css('color', 'white');             
           }
         });
     }
 }


 function on_select_change(id) {
     // #stats_value, #mail_value etc
     selector = '#' + eval("id") + '_value';
     var selected = $(selector + " option:selected");
     var output = "";
     if (selected.val() != 0) {
         output = "You Selected " + selected.val();
     }

     control_task(id, selected.val());
 }

 // changes trade destination for cash style transactions, allowed by admin...
 // liquidity is initial and current liquidity (printed money) and cash is M1 (no deposits)

 function on_trade_change(id) {


     // #stats_value, #mail_value etc
     selector = '#' + eval("id");
     var selected = $(selector + " option:selected");
     var output = "";
     if (selected.val() != 0) {
         //  output = "You Selected " + selected.val();
         if (selected.val() == 'cashin') {
             $('#tradeSource').val('cash');
             $('#tradeStatus').val('accepted');
             //   $('#tradeSource').attr('disabled', 'disabled');
             // alert(output) ;
         } else if (selected.val() == 'cashout') {
             $('#tradeDestination').val('cash');
             $('#tradeStatus').val('accepted');
             //    $('#tradeDestination').attr('disabled', 'disabled');
             //  alert(output) ;
         }
     }


 }


/* change the template language */

 function change_language() {
  var e = document.getElementById("language_value");
  var lang = e.options[e.selectedIndex].value;

  path = '/cgi-bin/cclite.cgi?action=lang&language=' + lang ;
  window.location=path ;
 }


/* experimental general input processing, value supplied by select as minutes
changed into milliseconds here */

 function control_task(type, minutes) {

     
     // alert((type + ' ' + minutes)) ;
     stopped = messages.get("stopped");
     started = messages.get("started");
     //selector is used to change the status bar selection
     selector = '#' + eval("type");

     interval = eval("type") + '_interval';
     window[interval] = minutes * 60 * 1000

     interval_display = '#' + interval;
     interval_id = eval("type") + '_interval_id';

     if (minutes == 0) {
         clearInterval(window[interval_id]);
         $(selector).html(stopped + ' ' + type);
         $(selector).css('background-color', 'red');
         window[type] = "stopped";
     } else if (minutes > 0) {
         try {
             $(selector).html(started + ' ' + type);
             // display run interval in seconds
             display_interval = minutes;
             window[type] = "started";
             $(selector).css('color', 'white');
             $(selector).css('background-color', 'darkorange');

             // window[interval_id] = setInterval( "do_task('type', 'batch_path')", window[interval]) ;
             // this ugly thing is something to do with scoping in setInterval, go figure, I can't!
             if (type == 'stats') {
                 // now changed to the Ico/Javascript based getstats! 09/2011, do stats straight away...
                 getstats() ;
                 window[interval_id] = setInterval("do_task( 'stats', '')", window[interval]);
             } else if (type == 'rss') {
                 window[interval_id] = setInterval("do_task( 'rss', '/cgi-bin/protected/batch/writerss.pl')", window[interval]);
             } else if (type == 'mail') {
                 window[interval_id] = setInterval("do_task( 'mail', '/cgi-bin/protected/batch/read_pop_mail.pl')", window[interval]);
             } else if (type == 'gpg_mail') {
                 window[interval_id] = setInterval("do_task( 'gpg_mail', '/cgi-bin/protected/batch/read_pop_mail_gpg.pl')", window[interval]);
             } else if (type == 'csv') {
                 window[interval_id] = setInterval("do_task( 'csv', '/cgi-bin/protected/batch/readcsv.pl')", window[interval]);
             } else if (type == 'gammu') {
                 window[interval_id] = setInterval("do_task( 'gammu', '/cgi-bin/protected/batch/readsms_from_gammu.pl')", window[interval]);
             }


             //alert('time ' + window[interval] + ' id ' + window[interval_id] + ' ' + interval_id) ;
         } catch (error) {
             alert(messages.get('erroris') + ' ' + error) ;
         }

     }

 }


/* Running appears next to the button  in selector and the data appears below the buttons in status_selector
can be used to transmit errors from the script into the page */


 function do_task(type, batch_path) {

     //alert('batch path ' + batch_path) ;
     try {

         
         processing = messages.get("processing");
         waiting = messages.get("waiting");

         selector = '#' + eval("type");
         status_selector = '#' + eval("type") + '_status';
         $(selector).html(processing + ' ' + type);
         $(selector).css('background-color', 'green');

         // stats has its own function now...
         if (type != 'stats') {
          $.ajax({
              method: 'get',
              url: batch_path,
              dataType: 'text',
              success: function (data) {
                  $(selector).html(messages.get("running") + ' ' + type);
                   $(status_selector).html(data);
             }
          });
         }
         // reload graphs for stats only
         if (type == 'stats') {
             // why doesn't jquery selection work here? sigh   
             /*
             vol = document.getElementById('volumes').src;
             trans = document.getElementById('transactions').src;
             document.getElementById('volumes').src = vol + '?' + (new Date()).getTime();
             document.getElementById('transactions').src = trans + '?' + (new Date()).getTime(); */
             getstats() ;
         }

         $(selector).html(waiting + ' ' + type);
     } catch (error) {
         alert(messages.get('erroris') + ' ' + error) ;
     }
 }

 

 function poptastic(url) {
     newwindow = window.open(url, '_blank', '');
     if (window.focus) {
         newwindow.focus()
     }
 }



 $(document).ready(function () {

    // new style messages from literals.<language-code>
    messages = readmessages();
    
    setInterval('blinktext()',10000) ;
    
    // searchbox_helper_strings (messages) ;
    // language selects in target language from literals
    build_language_selects(messages) ;

    // hide fields omly if in the installer
    if ($("#install_type").length > 0){
       hide_full_installation_options () ;
    } 

     $("#form").validate();
     // balloon help via qtip plugin, turned off at present
     //  $('input').qtip({ style: { name: 'cream', tip: true } }) ;
     $('#hash_type').css('display:none');

     // show logoff if logon, show admin link in user, if admin, needs to be multilingual
     if ($.cookie('userLogin')) {
         $('#userlink').html(messages.get("user"));
         logoff = messages.get("lgoff") + ' ' + $.cookie('userLogin');
         $("#logoff").html(logoff);
     }

     // show admin menu link, if administrator
     if ($.cookie('userLevel') == 'admin') {
         $("#adminlinkhref").html(messages.get("adminmenu"));
         $("#adminlinknewtab").html(messages.get("admintab"));
         $("#adminlink").toggle() ;
         $("#adminlinknewtab").toggle() ;
         $("#adminlinkhref").toggle() ;
         $("#adminlinkhrefnt").toggle() ;
     }
     //alert($("#fileproblems").length) ;
     if ($("#fileproblems").length > 1) {

         $("#fileliteral").html(messages.get('batchfileprobs'));
     }


     // prompt for cut and paste of configuration if not writable directly
     $("#copydiv").bind('copy', function (e) {
         alert('Now paste this into cclite\.cf');
     });

     $('#stats').css('color', 'white');
     $('#mail').css('color', 'white');
     $('#gpg_mail').css('color', 'white');
     $('#csv').css('color', 'white');
     $('#rss').css('color', 'white');
     $('#gammu').css('color', 'white');


     // check smsreceipt box if necessary
     if ($('[name=userSmsreceipt]').val() == 1) {
         $('input[name=userSmsreceipt]').attr('checked', true);
     }

     // autocompletes, depending on the field used, the 'type' of lookup is decided and this
     // is passed in to ccsuggest.cgi  
					





     $("#tradeDestination").autocomplete("/cgi-bin/ccsuggest.cgi", {
         extraParams: {
             type: function () {
                 return 'user';
             }
         }
     });

     $("#tradeSource").autocomplete("/cgi-bin/ccsuggest.cgi", {
         extraParams: {
             type: function () {
                 return 'user';
             }
         }
     });


     $('#yellowtags').tagSuggest({
         url: '/cgi-bin/ccsuggest.cgi',
         delay: 250
     });


/*
 $("#yellowtags").autocomplete("/cgi-bin/ccsuggest.cgi",
{
   extraParams: {
       type: function() { return 'tags' ; }
   }
   

}); 
*/

    $("#search_string").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         extraParams: {
             type: function () {
                 return $("#search_type").val() ;
             }
         }

     });

/*

     $("#string1").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         extraParams: {
             type: function () {
                 return 'user';
             }
         }

     });

*/

     $("#nuserLogin").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         selectFirst: false,
         extraParams: {
             type: function () {
                 return 'newuser';
             }


         }


     });

     $("#nuserMobile").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         //   selectFirst: false,
         extraParams: {
             type: function () {
                 return 'newusermobile';
             }


         }

     });

     $("#nuserEmail").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         //   selectFirst: false,
         extraParams: {
             type: function () {
                 return 'newuseremail';
             }


         }

     });


     var path = document.location.pathname;
     
     if ($('#upload_button').val()) {
         // batch file uploader
        // alert('here') ;
         new AjaxUpload('#upload_button', {
             // Location of the server-side upload script
             // NOTE: You are not allowed to upload files to another domain
             action: '/cgi-bin/protected/ccupload.cgi',
             // File upload name
             name: 'userfile',
             // Additional data to send
             data: {
                 serverfilename: 'batch.csv',
                 //    example_key2 : 'example_value2'
             },
             // Submit file after selection
             autoSubmit: true,
             // The type of data that you're expecting back from the server.
             // HTML (text) and XML are detected automatically.
             // Useful when you are using JSON data as a response, set to "json" in that case.
             // Also set server response type to text/html, otherwise it will not work in IE6
             responseType: false,
             // Fired after the file is selected
             // Useful when autoSubmit is disabled
             // You can return false to cancel upload
             // @param file basename of uploaded file
             // @param extension of that file
             onChange: function (file, extension) {},
             // Fired before the file is uploaded
             // You can return false to cancel upload
             // @param file basename of uploaded file
             // @param extension of that file
             onSubmit: function (file, ext) {
                 //  if (! (ext && /^(jpg|png|jpeg|gif)$/.test(ext))){
                 if (!(ext && /^(csv)$/.test(ext))) {
                     // extension is not allowed
                     alert(messages.get("mustbecsv"));
                     // cancel upload
                     return false;
                 }
                 return true;
             },

             // read the file when it's uploaded
             onComplete: function (file, response) {
                 alert(messages.get('uploadedfile') + ' ' + file + ' started |CSV File input| to process');
                 $.ajax({
                     type: "POST",
                     url: "/cgi-bin/protected/batch/readcsv.pl",
                     data: "",
                     success: function (file) {
                         alert(messages.get('fileprocessed') + ' ' + file);
                     }
                 });

                 // control_task ('csv',1) ;
                 return true;
             },
         });


     };
     // end of bath file uploader


 });


