 
function stripe() {
     striper('tbody','stripy', 'tr', 'odd,even') ;
}

/* decimal tradeamounts etc. if decimals are switched on  */

function validatedecimals (id,amount) {

 
// see whether we are using decimal point
var usedecimals = $('div#usedecimals').text() ;

if (usedecimals == 'no' && amount == parseInt(amount) ) {
  $(id).css('background-color', 'lightgreen');  
//  alert('value is parseint ' + amount) ; 
} else if (usedecimals == 'yes' && amount == parseFloat(amount) ) {
  $(id).css('background-color', 'lightgreen'); 
//  alert('value is parsefloat ' + amount) ;
} else {
  $(id).css('background-color', '#F08080');
  $(id).focus(); 
//  alert('else ' + amount + ' ' + usedecimals ) ;
}

return ;

}


/* controlling statistics, mail transactions and csv file transactions
  for the system, the intervals must be set here for the moment
*/

stats_interval_id = 0 ;
mail_interval_id = 0 ;
gpg_mail_interval_id = 0 ;
csv_interval_id = 0 ;
rss_interval_id = 0 ;
gammu_interval_id = 0 

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


 function remove_readonly_install (id) {
     
     selector = '#' + eval("id")  ;
     var selected = $(selector + " option:selected");       
  
     if(selected.val() == 'full'){  
       $('#installer2').attr('disabled','1') ;
       $("input").each(function (i) {
      //  alert('! ' + i) ;
      // if ($(this).attr('readonly') == "1") {
         $(this).removeAttr('readonly') ;
        //  $(this).css('background-color', 'red');
     //  } 
      });
     
     } else {
          $('#installer2').removeAttr('disabled') ;
         $("input").each(function (i) {
      //  alert('! ' + i) ;
      
       if ($(this).attr('name') != "dbuser" && $(this).attr('name') != "dbpassword") {
         $(this).attr('readonly','1') ;
        //  $(this).css('background-color', 'red');
      } 
      }); 
          
     }
     
     
 }

 function on_select_change(id){
     // #stats_value, #mail_value etc
     selector = '#' + eval("id") + '_value' ;
     var selected = $(selector + " option:selected");       
     var output = "";  
     if(selected.val() != 0){  
         output = "You Selected " + selected.val();  
     }
     
   control_task (id,selected.val())  ;
 }  

// changes trade destination for cash style transactions, allowed by admin...
// liquidity is initial and current liquidity (printed money) and cash is M1 (no deposits)


function on_trade_change(id){
     
   
     // #stats_value, #mail_value etc
     selector = '#' + eval("id")  ;
     var selected = $(selector + " option:selected");       
     var output = "";  
     if(selected.val() != 0){  
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




/* experimental general input processing, value supplied by select as minutes
changed into milliseconds here */

function control_task (type,minutes) {
    
  // alert((type + ' ' + minutes)) ;
   
   //selector is used to change the status bar selection
   selector = '#' + eval("type") ;
  
   interval = eval("type") + '_interval' ;
   window[interval] = minutes * 60 * 1000  
  
   interval_display = '#' + interval ;
   interval_id = eval("type") + '_interval_id' ;
    
  if (minutes == 0) { 
       clearInterval ( window[interval_id] );
       $(selector).html('Stopped ' + type);
       $(selector).css('background-color', 'red');
       window[type]  = "stopped" ;
  } else if (minutes > 0) {
      try{
       $(selector).html('Starting ' + type );
       // display run interval in seconds
       display_interval =  minutes ;
       window[type] = "started" ;
       $(selector).css('color', 'white');
       $(selector).css('background-color', 'darkorange');  
       
     // window[interval_id] = setInterval( "do_task('type', 'batch_path')", window[interval]) ;
     
     // this ugly thing is something to do with scoping in setInterval, go figure, I can't!
     if (type == 'stats') {
       window[interval_id] = setInterval( "do_task( 'stats', '/cgi-bin/protected/graphs/graph.pl')", window[interval]) ;
      } else if (type == 'rss') {
       window[interval_id] = setInterval( "do_task( 'rss', '/cgi-bin/protected/batch/writerss.pl')", window[interval]) ;
      } else if (type == 'mail') {
        window[interval_id] = setInterval( "do_task( 'mail', '/cgi-bin/protected/batch/read_pop_mail.pl')", window[interval]) ;
      } else if (type == 'gpg_mail') {
        window[interval_id] = setInterval( "do_task( 'gpg_mail', '/cgi-bin/protected/batch/read_pop_mail_gpg.pl')", window[interval]) ;
      } else if (type == 'csv') {
        window[interval_id] = setInterval( "do_task( 'csv', '/cgi-bin/protected/batch/readcsv.pl')", window[interval]) ;
      } else if (type == 'gammu') {
      window[interval_id] = setInterval( "do_task( 'gammu', '/cgi-bin/protected/batch/readsms_from_gammu.pl')", window[interval]) ;               
     }
                            
                 
       //alert('time ' + window[interval] + ' id ' + window[interval_id] + ' ' + interval_id) ;
       } catch(error) { alert('error is ' + error)}
      
  }

}


/* Running appears next to the button  in selector and the data appears below the buttons in status_selector
can be used to transmit errors from the script into the page */


function do_task(type,batch_path)
{
 
     //alert('batch path ' + batch_path) ;
   
     try{
     selector = '#' + eval("type") ;
     status_selector = '#' + eval("type") + '_status' ;
     $(selector).html('Processing ' + type);
     $(selector).css('background-color', 'green');
      $.ajax({
                    method: 'get',
                    url : batch_path,
                    dataType : 'text',
                    success: function (data) { $(selector).html('Running ' + type) ; $(status_selector).html(data);
                    }
                 });
      // reload graphs for stats only
      if (type == 'stats') {
       // why doesn't jquery selection work here? sigh   
       vol = document.getElementById('volumes').src ;
       trans = document.getElementById('transactions').src ;
       document.getElementById('volumes').src = vol + '?' + (new Date()).getTime() ;
       document.getElementById('transactions').src = trans + '?' + (new Date()).getTime() ;
     }
      
      $(selector).html('Waiting ' + type);
     } catch(error) { alert('error is ' + error)}
}

var newwindow;
function poptastic(url)
{
	newwindow=window.open(url,'_blank','');
	if (window.focus) {newwindow.focus()}
}

  

 $(document).ready(function(){


  $("#form").validate();
  // balloon help via qtip plugin, turned off at present
  //  $('input').qtip({ style: { name: 'cream', tip: true } }) ;
    $('#hash_type').css('display:none') ;
 
  // show logoff if logon, show admin link in user, if admin, needs to be multilingual
  if ($.cookie('userLogin')  ) {    
     $('#userlink').html("Cclite User");
     logoff = 'Log off '  + $.cookie('userLogin') ;  
     $("#logoff").html(logoff);     
   }
   
// show admin menu link, if administrator
   if ($.cookie('userLevel') == 'admin') {
      $("#adminlink").html("Admin Menu");
      $("#adminlinknewtab").html("*");
     }
//alert($("#fileproblems").length) ;

  if ($("#fileproblems").length > 1){
     
    $("#fileliteral").html('Batch files or directories below have problems, put mouse over to examine') ;
  }
   

// prompt for cut and paste of configuration if not writable directly
   $("#copydiv").bind('copy', function(e) {
                alert('Now paste this into cclite\.cf');
            });
   
   $('#stats').css('color', 'white');
   $('#mail').css('color', 'white');
   $('#gpg_mail').css('color', 'white');
   $('#csv').css('color', 'white'); 
   $('#rss').css('color', 'white');
   $('#gammu').css('color', 'white');
  



// check smsreceipt box if necessary
  if ( $('[name=userSmsreceipt]').val() == 1 ) {
     $('input[name=userSmsreceipt]').attr('checked', true);
  }


// autocompletes, depending on the field used, the 'type' of lookup is decided and this
// is passed in to ccsuggest.cgi  



 $("#tradeDestination").autocomplete("/cgi-bin/ccsuggest.cgi",
{
   extraParams: {
       type: function() { return 'user' ; }
   }
});
 
 $("#tradeSource").autocomplete("/cgi-bin/ccsuggest.cgi",
{
   extraParams: {
       type: function() { return 'user' ; }
   }
}); 


  $('#yellowtags').tagSuggest({
    url: '/cgi-bin/ccsuggest.cgi' ,
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
 

 $("#string1").autocomplete("/cgi-bin/ccsuggest.cgi",

{
   extraParams: {
       type: function() { return 'user' ; }
   }

});


  $("#nuserLogin").autocomplete("/cgi-bin/ccsuggest.cgi",

{
   selectFirst: false,
   extraParams: {
       type: function() { return 'newuser' ; }
 

   }


});
  
  $("#nuserMobile").autocomplete("/cgi-bin/ccsuggest.cgi",

{
//   selectFirst: false,
   extraParams: {
       type: function() { return 'newusermobile' ; }
 

   }

});
  
  $("#nuserEmail").autocomplete("/cgi-bin/ccsuggest.cgi",

{
//   selectFirst: false,
   extraParams: {
       type: function() { return 'newuseremail' ; }
 

   }

});


  $("#string2").autocomplete("/cgi-bin/ccsuggest.cgi",
{
   extraParams: {
       type: function() { return 'ad' ; }
   }


});
  
  $("#string3").autocomplete("/cgi-bin/ccsuggest.cgi",

{
   extraParams: {
       type: function() { return 'trade' ; }
   }

});


var path = document.location.pathname;
//path = path.replace(/\//gi, "");
//path = path.replace(/%20/gi, " ");
//path = path.replace(/\\/gi, "\/");
//alert (path);
//var path = document.location.pathname;

if ( $('#upload_button').length ) {
// batch file uploader
new AjaxUpload('#upload_button', {
  // Location of the server-side upload script
  // NOTE: You are not allowed to upload files to another domain
  action: '/cgi-bin/protected/ccupload.cgi',
  // File upload name
  name: 'userfile',
  // Additional data to send
  data: {
       serverfilename : 'batch.csv',
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
  onChange: function(file, extension){},
  // Fired before the file is uploaded
  // You can return false to cancel upload
  // @param file basename of uploaded file
  // @param extension of that file
  onSubmit : function(file , ext){
    //  if (! (ext && /^(jpg|png|jpeg|gif)$/.test(ext))){
                if (! (ext && /^(csv)$/.test(ext))){
                        // extension is not allowed
                        alert('Error: must be csv extension file');
                        // cancel upload
                        return false;
                }
                return true ;
        },

  // read the file when it's uploaded
  onComplete: function(file , response){
                alert('uploaded file ' + file + ' started |CSV File input| to process');
                $.ajax({
                    type: "POST",
                    url: "/cgi-bin/protected/batch/readcsv.pl",
                    data: "",
                    success: function(file){
                         alert( 'file processed ' + file );
                                   }
                         });

               // control_task ('csv',1) ;
                return true ;
        },
});


} ;
// end of bath file uploader


 
  });

