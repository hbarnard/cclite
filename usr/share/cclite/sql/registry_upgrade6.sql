--
-- Change table structure for table `om_prefs`
--

DROP INDEX `PRIMARY` ON `om_prefs` ;
ALTER TABLE `om_prefs` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST ;
ALTER TABLE `om_prefs` CHANGE `prefUser` `userId` INT( 11 ) NOT NULL DEFAULT '0';

