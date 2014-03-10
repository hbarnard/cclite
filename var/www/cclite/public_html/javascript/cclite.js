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


/* switch off direct registry creation if cpanel */

function cpanel_install() {


     // see whether we are using decimal point
     var cp = $('div#distribution').text();
     var patt1 = /cpanel/ ;
     var patt2 = /probably/ ;
     
     // certainly cpanel found in binaries
     if (cp.search(patt1) != -1 && cp.search(patt2) == -1) {
		 $('a#newregistry').css('text-decoration', 'strikethrough'); 
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


 /*   build selects for language choice at top an

do also userLang  in
 correct language, not used currently because of character set display
problems in drop down, chinese, arabic etc.  08/2011  

*/

function build_language_selects (messages) {

// $('#language_value').empty();


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
"greek-el",
"arabic-ar",
"japanese-ja", 
"korean-ko", 
"bengali-bn", 
"vietnamese-vi",
"ukranian-uk",
"indonesian-id",
"hungarian-hu",
"finnish-fi",
"hebrew-he",
"haitian-ht"
) ;

$.each(language_keys, function(index,value)
{   
  
  
     var literal = value.split('-') ;
     // alert ('literal is ' + literal + '' + index) ;
     $('#language_value').
          append($("<option></option>").
          attr("value",literal[1]).
          text(messages.get(literal[0]))); 
    // alert ('literal is ' + literal[0] + ' ' + literal[1] + ' ' + messages.get(literal[0])) ;     
          
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

/* get stats as this is somewhat specialised: deprecated replaced by flot */

function get_stats (batch_path,first_pass) {
	
    //  alert('batch path ' + batch_path) ;
     try {
       if (first_pass > 0 && ($('#transactions').length > 0) ) {  
		   
         processing = messages.get("processing");
         waiting = messages.get("waiting");
        
         $('#stats').html(processing + ' ' + type);
         
        }
        
        $.ajax({
              method: 'get',
              url: batch_path,
              dataType: 'text',
              success: function (data) {
				 
                  $('#stats').html(messages.get("running") + ' ' + 'stats');
                   $('#stats_status').html(data);
             }
          });
       
	     if ($('#volumes_bargraph').length > 0) {
		   $('#stats').css('background-color', 'green');
  	       vol = '/images/charts/' + $.cookie('registry') + '/volumes.png' + '?timestamp=' + new Date().getTime();
           trans = '/images/charts/' +  $.cookie('registry')  + '/transactions.png' + '?timestamp=' + new Date().getTime();
           
           // alert('vol is' + vol) ;
           
            $("#volumes_bargraph").attr("src", vol);
            $("#average_bargraph").attr("src", trans);
         }
  
     } catch (error) {
         alert(messages.get('erroris') + ' ' + error) ;
     }

	
}	


/* get stats as this is somewhat specialised */

function get_stats_json (batch_path,first_pass) {

        $.ajax({
              method: 'get',
              url: batch_path,
              dataType: 'json',
              success: function (data) {
				    
		timestring =   (new Date()).toTimeString().substring(0,12) ;
		  
		if (($("#userbalances").length > 0) && ($.cookie('userLevel') == 'user') ){
			var plotdata = new Array;
			for (var key in data.balances) {
               if (data.balances.hasOwnProperty(key)) {
				  var obj = { data: data.balances[key].sort(), label: key + ' ' + messages.get('balances') + ' ' + timestring};
				  //var txt = JSON.stringify(obj, '');
				  //alert('obj is ' + txt) ;
				   
				  plotdata.push(obj);
				// var txt = JSON.stringify(plotdata, '');
                //  alert('plotdata is ' + txt) ;
               }
            }
           //var txt = JSON.stringify(plotdata, '');
           //alert('plotdata is ' + txt) ;
            
           // only plot if there is data, otherwise display message 
           if (plotdata.length > 0) {
		    _plot_graph_lines('userbalances',plotdata,data.milliseconds_back) ;
		   } else {
			   $('#userbalances').text(messages.get("nobalancedata"));
		   }	   
		    
		} else if ($("#averages").length > 0 ) {	
			 var data1 = [{ data: data.averages.sort(), label: messages.get('vols') + ' ' + timestring }];
             var data2 = [{ data: data.volumes.sort(), label: messages.get('avg') + ' ' +  timestring  }];
            
            // only plot if there is data, otherwise display message 
           if (data1.length > 0) {  
            _plot_graph('averages',data1,data.milliseconds_back,'graphlabel1') ;
           } else {
			   $('#averages').text(messages.get("noaveragesdata"));
		   }	    
            
		    // only plot if there is data, otherwise display message
		   if (data2.length > 0) { 
		    _plot_graph('volumes',data2,data.milliseconds_back,'graphlabel2') ;
		   } else { 
			 $('#volumes').text(messages.get("novolumedata"));
		   }	   
		    
	    }
                  $('#stats').html(messages.get("running") + ' ' + 'stats');
                  $('#stats_status').html(data);
             }
          });
          	
}	


/* generalised inner function for plotting accessed
 * from ajax call */


function _plot_graph (selector,data,milliseconds_back,labelcontainer) {	
		until =   (new Date()).getTime() + 7200000 ; //  two hours into the future
		minimum_x =  until - milliseconds_back ;	
		
		// alert('label '  + labelcontainer) ;
				
        $.plot($('#' + selector), data, {
            xaxis: {
                mode: "time",
              // minTickSize: [1, "minute"],
              min: minimum_x,
              max: until,            
            },
           
            legend:{container: $('#' + labelcontainer)},
            bars: { show: true }           
        });	
return ;		
}	


function _plot_graph_lines (selector,data,milliseconds_back) {	
		until =   (new Date()).getTime() + 7200000 ; //  two hours into the future
		minimum_x =  until - milliseconds_back ;
		
		var txt = JSON.stringify(data, '');
		// alert ('data is ' + txt) ;
				
        $.plot($('#'+selector), data, {
            xaxis: {
                mode: "time",
              // minTickSize: [1, "minute"],
              min: minimum_x,
              max: until,            
            },
            legend:{container: $("#graphlabel")}
           
        });	
return ;		
}	

/*  not being used yet, sparkline formatting for flot data 
function _plot_graph_sparklines (selector,data) {

//	
//var data 
//     = [ [0, 1], [1, 2], [2, 2], [3, 2], [4, 2], [5, 3], [6, 4], 
 //          [7, 2], [8, 2], [9, 3], [10, 5], [11, 5], [12, 4] ];

		
  var options = {
    xaxis: {
	 mode: "time",	
      // extend graph to fit the last point
      max: data[data.length - 1][0] + 1
    },
    grid: {
      show: false
    }
  };

  // main series
  var series = [{
    data: data,
    color: '#000000',
    lines: {
      lineWidth: 0.8
    },
    shadowSize: 0
  }];

  // colour the last point red.
  series.push({
    data: [ data[data.length - 1] ],
    points: {
     show: true,
     radius: 1,
     fillColor: '#ff0000'
    },
    color: '#ff0000'
  });

  // draw the sparkline
  var plot = $.plot('#'+selector, series, options);

return ;

}
*/

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
            
         } else if (selected.val() == 'cashout') {
             $('#tradeDestination').val('cash');
             $('#tradeStatus').val('accepted');
             //    $('#tradeDestination').attr('disabled', 'disabled');
             
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
             
             // One week is default for stats, this is passed right though into the x axis too            
             if (type == 'stats') {
				 batch_path = '/cgi-bin/cclite.cgi?action=getstats' ;
				 if ($('hours_back').val()) {
				  batch_path =	batch_path + '&hours_back=' + $('hours_back').val() ;
				 } else {
			      batch_path =	 batch_path + '&hours_back=168' ;	 
				 }
                 window[interval_id] = setInterval("get_stats_json(batch_path)", window[interval]);
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
             
         } catch (error) {
             alert(messages.get('erroris') + ' ' + error) ;
         }

     }

 }


/* Running appears next to the button  in selector and the data appears below the buttons in status_selector
can be used to transmit errors from the script into the page */


 function do_task(type, batch_path) {

     try {        
         processing = messages.get("processing");
         waiting = messages.get("waiting");

         selector = '#' + eval("type");
         status_selector = '#' + eval("type") + '_status';
         $(selector).html(processing + ' ' + type);
         $(selector).css('background-color', 'green');

          $.ajax({
              method: 'get',
              url: batch_path,
              dataType: 'text',
              success: function (data) {
				   selector = '#' + eval("type");
                    status_selector = '#' + eval("type") + '_status';        
                  $(status_selector).css('background-color', 'green');
                  $(selector).html(messages.get("running") + ' ' + type);
                   $(status_selector).html(data);
             }
          });
       
         $(selector).html(waiting + ' ' + type);
     } catch (error) {
         alert(messages.get('erroris') + ' ' + error) ;
     }
 }


// sort options list, used for languages only at present

$.fn.sort_select_box = function(){
    // Get options from select box
    var my_options = $("#" + this.attr('id') + ' option');
    // sort alphabetically
    my_options.sort(function(a,b) {
        if (a.text > b.text) return 1;
        else if (a.text < b.text) return -1;
        else return 0
    })
   //replace with sorted my_options;
   $(this).empty().append( my_options );

   // clearing any selections
   $("#"+this.attr('id')+" option").attr('selected', false);
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
    
    // cpanel install, grey out registry create if cpanel
    cpanel_install() ;

    // only use datatables where there are some February 2014
    if ($('#transtable').length) {
    
       $('#transtable').dataTable( {"bSort": true});
;   
}
    setInterval('blinktext()',10000) ;
    
    // make the language menu follow the current language
    if ($.cookie('language')) {
     $("#language_value").val($.cookie('language'));
    }
    // searchbox_helper_strings (messages) ;
    // language selects in target language from literals
     build_language_selects(messages) ;
    
    // sort the list of language values, not sure what'll happen with non-western!
     $('#language_value').sort_select_box();

    // hide fields omly if in the installer
    if ($("#install_type").length > 0){
       hide_full_installation_options () ;
    } 

     $("#form").validate();
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
         // do stats as loading
        
     }
     
      get_stats_json('/cgi-bin/cclite.cgi?action=getstats&hours_back=168',1) ;
      
      // user stats for yellow page display only
      // if ( $("#userbalances").length > 0 ) {
      // alert('user is ' + $('#fromuserid').val())
      // get_stats_json('/cgi-bin/cclite.cgi?action=getstats&hours_back=168&stats_user=' $('#fromuserid').val() + ,1) ;
      // }
    
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

     /* autocompletes, depending on the field used, the 'type' of lookup is decided and this
     is passed in to ccsuggest.cgi  
     avoid using userLogin, this is probably the way to generalise all of them...*/
     
    // 'user' is used in preferences.html 
    $("#user").autocomplete("/cgi-bin/ccsuggest.cgi", {
         extraParams: {
             type: function () {
                 return 'user';
             }
         }
     });


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


     $("#muserEmail").autocomplete("/cgi-bin/ccsuggest.cgi",

     {
         //   selectFirst: false,
         extraParams: {
             type: function () {
                 return 'newuseremail';
             }


         }

     });

var path = document.location.pathname;
     
/* only show uploader if positioned on admin page */

  if ($("#file-uploader").length > 0) {

        function createUploader(){            
            var uploader = new qq.FileUploader({
                element: document.getElementById('file-uploader'),
                action: '/cgi-bin/protected/ccupload.cgi',
                
                // additional data to send, name-value pairs
                //params: 
                //{   userfile: 'batch.csv',
                //},
    
               // validation    
               allowedExtensions: ['csv'],        
               // each file size limit in bytes
               // this option isn't supported in all browsers
               sizeLimit: 10000000, // max size   
               minSizeLimit: 0, // min size    
               // set to true to output server response to console
               debug: false,
    
               // events         
               // you can return false to abort submit
                onSubmit: function(id, fileName){},
                onProgress: function(id, file, loaded, total){},
                onComplete: function(id, file, responseJSON ) {
					
                   $.ajax({
                     type: "POST",
                     url: "/cgi-bin/protected/batch/readcsv.pl",
                     serverfilename: 'batch.csv',
                     dataType: 'text',
                     success: function (file,responseJSON) {
						 alert('json is ' + file);
                        // alert(messages.get('fileprocessed') + ' ' + file);
                     },			
					});
 			      return true ;
                //onCancel: function(id, fileName){},
               
            },           
        });        
        // in your app create uploader as soon as the DOM is ready
        // don't wait for the window to load  
    
    };
    
     // end of bath file uploader
       window.onload = createUploader;  
   } // end of cookie level == admin for uploader
     

 });
 


