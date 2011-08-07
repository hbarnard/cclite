<p>
    <?php echo elgg_echo('myplugin:settings:limit'); ?>
 
    <select name="params[limit]">
    <option value="5" <?php if ($vars['entity']->limit == 5) echo " selected=\"yes\" "; ?>>5</option>
    <option value="8" <?php if ((!$vars['entity']->limit) || ($vars['entity']->limit == 8)) echo " selected=\"yes\" "; ?>>8</option>
    <option value="12" <?php if ($vars['entity']->limit == 12) echo " selected=\"yes\" "; ?>>12</option>
    <option value="15" <?php if ($vars['entity']->limit == 15) echo " selected=\"yes\" "; ?>>15</option>
    </select>
</p>

<?php
echo 'begin' ;
if (!$access_key || !$access_secret) {

	// send user off to validate account

	$request_link = cclite_get_authorize_url($vars['url'] . 'pg/cclite/authorize');

	echo '<p>' . sprintf(elgg_echo('cclite:usersettings:request'), $request_link) . '</p>';

} else {

	$url = "{$CONFIG->site->url}pg/cclite/revoke";

	echo '<p class="cclite_anywhere">' . sprintf(elgg_echo('cclite:usersettings:authorized'), $cclite_name, $vars['config']->site->name) . '</p>';

	echo '<p>' . sprintf(elgg_echo('cclite:usersettings:revoke'), $url) . '</p>';
}

echo 'end' ;

?>
