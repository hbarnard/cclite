<?php

	/**
	 * Elgg cclite plugin
	 * 
	 * @package Elgg-cclite
	 * @license http://www.gnu.org/licenses/old-licenses/gpl-2.0.html GNU Public License version 2
	 * @author Hugh Barnard
	 * @copyright Hugh Barnard
	 * @link http://www.hughbarnard.org
         * Provides a passthrough to the cclite alternative currency package

	 */

	/**
	 * cclite initialisation
	 *
	 * These parameters are required for the event API, but we won't use them:
	 * 
	 * @param unknown_type $event
	 * @param unknown_type $object_type
	 * @param unknown_type $object
	 */
	
 
		function cclite_init() {
			
			// Load system configuration
				global $CONFIG;
			
			
			// Set up menu for logged in users
				if (isloggedin()) {
    				
					add_menu(elgg_echo('cclite'), $CONFIG->wwwroot . "pg/cclite/" . $_SESSION['user']->username);
					
			// And for logged out users
				} else {
					add_menu(elgg_echo('cclite'), $CONFIG->wwwroot . "mod/cclite/everyone.php",array(
					));
				}
				
			// Extend system CSS with our own styles, which are defined in the cclite/css view
				extend_view('css','cclite/css');
				
			// Extend hover-over menu	
				extend_view('profile/menu/links','cclite/menu');
				
			// Register a page handler, so we can have nice URLs
				register_page_handler('cclite','cclite_page_handler');
			
 

	
			// Register a URL handler for cclite posts
				register_entity_url_handler('cclite_url','object','cclite');
				
			// Register this plugin's object for sending pingbacks
				register_plugin_hook('pingback:object:subtypes', 'object', 'cclite_pingback_subtypes');

			// Register granular notification for this type
			if (is_callable('register_notification_object'))
				register_notification_object('object', 'cclite', elgg_echo('cclite:newpost'));

			// Listen to notification events and supply a more useful message
			register_plugin_hook('notify:entity:message', 'object', 'cclite_notify_message');

				
			// Listen for new pingbacks
				register_elgg_event_handler('create', 'object', 'cclite_incoming_ping');
				
			// Register entity type
				register_entity_type('object','cclite');
				
				
			// widget created data is metadata, mainly to be posted to remote cclite instance
		        // this is a little ugly but I haven't found better...
		        register_elgg_event_handler('create','metadata','cclite_post_data', 1000);
			
			register_elgg_event_handler('create', 'user', 'post_create_update_handler', 501);
		}
		
		function cclite_pagesetup() {
			
			global $CONFIG;

			//add submenu options
				if (get_context() == "cclite") {
					
				}
			
		}
		
		/**
		 * cclite page handler; allows the use of fancy URLs
		 *
		 * @param array $page From the page_handler function
		 * @return true|false Depending on success
		 */
		function cclite_page_handler($page) {
			
			
		}

		/**
		 * Returns a more meaningful message
		 *
		 * @param unknown_type $hook
		 * @param unknown_type $entity_type
		 * @param unknown_type $returnvalue
		 * @param unknown_type $params
		 */
		function cclite_notify_message($hook, $entity_type, $returnvalue, $params)
		{
			$entity = $params['entity'];
			$to_entity = $params['to_entity'];
			$method = $params['method'];
			if (($entity instanceof ElggEntity) && ($entity->getSubtype() == 'cclite'))
			{
				$descr = $entity->description;
				$title = $entity->title;
				if ($method == 'sms') {
					$owner = $entity->getOwnerEntity();
					return $owner->username . ' via cclite: ' . $title;
				}
				if ($method == 'email') {
					$owner = $entity->getOwnerEntity();
					return $owner->username . ' via cclite: ' . $title . "\n\n" . $descr . "\n\n" . $entity->getURL();
				}
			}
			return null;
		}



		
		/**
		 * This function adds 'cclite' to the list of objects which will be looked for pingback urls.
		 *
		 * @param unknown_type $hook
		 * @param unknown_type $entity_type
		 * @param unknown_type $returnvalue
		 * @param unknown_type $params
		 * @return unknown
		 */
		function cclite_pingback_subtypes($hook, $entity_type, $returnvalue, $params)
		{
			$returnvalue[] = 'cclite';
			return $returnvalue;
		}
		
		/**
		 * Listen to incoming pings, this parses an incoming target url - sees if its for me, and then
		 * either passes it back or prevents it from being created and attaches it as an annotation to a given
		 *
		 * @param unknown_type $event
		 * @param unknown_type $object_type
		 * @param unknown_type $object
		 */
		function cclite_incoming_ping($event, $object_type, $object)
		{
			// TODO: Get incoming ping object, see if its a ping on a cclite and if so attach it as a comment
		}

		
	        function post_create_update_handler($event, $object_type, $object) {

			$user = $object;
			$username = $user->username;
			global $CONFIG;
                        include ($CONFIG->wwwroot."/mod/cclite/cclite-common.php") ;
            // do any followup operations on successfull login
			
			// ensure "admin" is a friend for all users ... if you want
			// any other user just use it below
		//	if ( ($username != "admin") && ($admin = get_user_by_username ("admin")) ) {
		//          $block_content = cclite_contents('adduser',$username) ;
		//         system_message ( "trying to create cclite user $block_content");
			

		//	}
            
			// put out a greeting message ... this could be customized
			// depending on user's profile, etc. 
		//	system_message ( "Welcome " . $user->name . " to " . $CONFIG->wwwroot );
	}

	//register plugin initialization handler
	register_elgg_event_handler('init', 'system', 'post_create_update_init');
		
	// Make sure the cclite initialisation function is called on initialisation
		register_elgg_event_handler('init','system','cclite_init');
		register_elgg_event_handler('pagesetup','system','cclite_pagesetup');
                register_elgg_event_handler('create', 'user', 'post_login_update_handler', 501);
		add_widget_type('summary',elgg_echo("Trading Summary"),elgg_echo("Trading Summary"));
                add_widget_type('transactions',elgg_echo("Recent Transactions"),elgg_echo("Recent Transactions"));
                add_widget_type('payment',elgg_echo("Payment"),elgg_echo("Payment"));
	// Register actions
		global $CONFIG;
		register_action("cclite/pay",false,$CONFIG->pluginspath . "cclite/actions/pay.php");
		
?>
