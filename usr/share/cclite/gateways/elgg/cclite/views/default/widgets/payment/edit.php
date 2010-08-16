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

?>
	<p>
		<?php echo elgg_echo("User"); ?>
		<br/><input type="text" name="params[cclite_username]" value="<?php echo htmlentities($vars['entity']->cclite_username); ?>" />	
		<?php echo elgg_echo("cclite:quantity"); ?>
		<input type="text" name="params[cclite_quantity]" value="<?php echo htmlentities($vars['entity']->cclite_quantity); ?>" />
                <br/><?php echo elgg_echo("cclite:currency"); ?>
		<input type="text" name="params[cclite_currency]" value="<?php echo htmlentities($vars['entity']->cclite_currency); ?>" />	
	
	</p>