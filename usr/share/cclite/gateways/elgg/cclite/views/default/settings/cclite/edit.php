<p>
	<?php echo elgg_echo('cclite:cclite_payment_domain'); ?> <?php echo elgg_view('input/text', array('internalname' => 'params[cclite_payment_domain]', 'value' => $vars['entity']->cclite_payment_domain)); ?>

</p>
<p>
	<?php echo elgg_echo('cclite:cclite_api_key'); ?> <?php echo elgg_view('input/text', array('internalname' => 'params[cclite_api_key]', 'value' => $vars['entity']->cclite_api_key)); ?>

</p>
<p></p>
<p>
	<?php echo elgg_echo('cclite transfer protocol'); ?>
	
	<select name="params[cclite_protocol]">
		<option value="http" <?php if ($vars['entity']->cclite_protocol == 'http') echo " selected=\"http\" "; ?>><?php echo elgg_echo('option:http'); ?></option>
		<option value="https" <?php if ($vars['entity']->cclite_protocol != 'https') echo " selected=\"https\" "; ?>><?php echo elgg_echo('option:https'); ?></option>
	</select>
	
</p>
<p></p>
<p>
<?php echo elgg_echo('cclite:cclite_api_password'); ?> <?php echo elgg_view('input/text', array('internalname' => 'params[cclite_api_password]', 'value' => $vars['entity']->cclite_api_password)); ?>
</p>
<p></p>
<p>
	<?php echo elgg_echo('cclite hashing algorithm'); ?>
	
	<select name="params[cclite_hashing_algorithm]">
		<option value="sha256" <?php if ($vars['entity']->cclite_hashing_algorithm == 'sha256') echo " selected=\"sha256\" "; ?>><?php echo elgg_echo('option:sha256'); ?></option>
		<option value="sha512" <?php if ($vars['entity']->cclite_hashing_algorithm != 'sha512') echo " selected=\"sha512\" "; ?>><?php echo elgg_echo('option:sha512'); ?></option>
	</select>
	
</p>
<p></p>
<p>
<?php echo elgg_echo('cclite:cclite_registry'); ?> <?php echo elgg_view('input/text', array('internalname' => 'params[cclite_registry]', 'value' => $vars['entity']->cclite_registry)); ?>
</p>



