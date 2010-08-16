ALTER TABLE `om_users` CHANGE `userPublickey` `userPublickeyid` VARCHAR( 20 ) NULL DEFAULT NULL ;
ALTER TABLE `om_registry` CHANGE `public_key` `public_key_id` VARCHAR( 20 ) NULL DEFAULT NULL ; 
ALTER TABLE `om_users` ADD `userSmsreceipt` BOOL NOT NULL DEFAULT '0';
