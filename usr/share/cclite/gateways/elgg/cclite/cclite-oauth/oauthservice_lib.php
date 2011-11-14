<?php
/**
 * Common library of functions used by cclite oauth service
 *
 * This work is heavily based on the work done for linkedin and elgg
 * by Abraham Williams (abraham@abrah.am) http://abrah.am
 * @package cclite
 **/


function cclite_authorize() {
	$token = cclite_get_access_token(get_input('oauth_verifier', NULL));
	if (!isset($token['oauth_token']) || !isset($token['oauth_token_secret'])) {
		register_error(elgg_echo('cclite:authorize:error'));
		forward('pg/settings/plugins');
	}

	// only one user per tokens
	$values = array(
		'plugin:settings:cclite:access_key' => $token['oauth_token'],
		'plugin:settings:cclite:access_secret' => $token['oauth_token_secret'],
	);

	if ($users = get_entities_from_private_setting_multi($values, 'user', '', 0, '', 0)) {
		foreach ($users as $user) {
			// revoke access
			set_plugin_usersetting('access_key', NULL, $user->getGUID());
			set_plugin_usersetting('access_secret', NULL, $user->getGUID());
		}
	}

	// register user's access tokens
	set_plugin_usersetting('access_key', $token['oauth_token']);
	set_plugin_usersetting('access_secret', $token['oauth_token_secret']);

	system_message(elgg_echo('cclite:authorize:success'));
	forward('pg/settings/plugins');
}

function cclite_revoke() {
	// unregister user's access tokens
	set_plugin_usersetting('access_key', NULL);
	set_plugin_usersetting('access_secret', NULL);

	system_message(elgg_echo('cclite:revoke:success'));
	forward('pg/settings/plugins');
}

function cclite_get_authorize_url($callback=NULL) {
	global $SESSION;

	$consumer_key = get_plugin_setting('consumer_key', 'cclite');
	$consumer_secret = get_plugin_setting('consumer_secret', 'cclite');

	// request tokens from cclite
	$cclite = new ccliteOAuth($consumer_key, $consumer_secret);
	$token = $cclite->getRequestToken($callback);
	// save token in session for use after authorization
	$SESSION['cclite'] = array(
		'oauth_token' => $token['oauth_token'],
		'oauth_token_secret' => $token['oauth_token_secret'],
	);
	return $cclite->getAuthorizeURL($token['oauth_token']);
}

function cclite_get_access_token($oauth_verifier=NULL) {
	global $SESSION;

	$consumer_key = get_plugin_setting('consumer_key', 'cclite');
	$consumer_secret = get_plugin_setting('consumer_secret', 'cclite');

	// retrieve stored tokens
	$oauth_token = $SESSION['cclite']['oauth_token'];
	$oauth_token_secret = $SESSION['cclite']['oauth_token_secret'];
	$SESSION->offsetUnset('cclite');

	// fetch an access token
	$api = new ccliteOAuth($consumer_key, $consumer_secret, $oauth_token, $oauth_token_secret);
	return $api->getAccessToken($oauth_verifier);
}

?>
