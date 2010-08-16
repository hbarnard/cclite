# version 0.3.2

# om-rules is not used som remove these statements if theres a problem upgrading
ALTER TABLE `om_rules`  CHANGE `level` `event` ;
ALTER TABLE `om_rules` CHANGE `event` `event` ENUM( 'pretransaction', 'posttransaction', 'subscription', 'custom', 'creditlimit' ) DEFAULT 'pretransaction' ;
ALTER TABLE `om_rules` CHANGE `type` `langtype` ENUM( 'perl', 'sql', 'ruby' ) DEFAULT 'perl' ;
ALTER TABLE `om_rules` CHANGE `text` `rulevalue` VARCHAR(250) ;
ALTER TABLE `om_rules` ADD `description` VARCHAR( 40 ) NOT NULL ;

ALTER TABLE `om_users` ADD `userNameornumber` VARCHAR( 20 ) NOT NULL AFTER `userName` ,
ADD `userStreet` VARCHAR( 40 ) NOT NULL AFTER `userNameornumber` ,
ADD `userTown` VARCHAR( 40 ) NOT NULL AFTER `userStreet` ,
ADD `userArea` VARCHAR( 40 ) NOT NULL AFTER `userTown` ;
ALTER TABLE `om_users` CHANGE `userLevel` `userLevel` ENUM( 'user', 'admin', 'sysaccount', 'other' )  DEFAULT 'user' ;
ALTER TABLE `om_users` CHANGE `userStatus` `userStatus` ENUM( 'active', 'unconfirmed', 'suspended', 'predelete', 'holiday' ) DEFAULT 'active' ;

ALTER TABLE `om_trades` CHANGE `tradeHash` `tradeHash` VARCHAR(128) ;

# version 0.4.0
# oscommerce gateway + fields for public keys
ALTER TABLE `om_currencies` ADD `code` CHAR( 3 ) NOT NULL AFTER `name` ;

ALTER TABLE `om_trades` CHANGE `tradeDestinationBalance` `tradeTaxflag` CHAR( 2 ) DEFAULT '0' ;

ALTER TABLE `om_currencies` ADD `public_key` BLOB AFTER `type` ;

# changed merchant key to correspond to oscommerce merchant key
ALTER TABLE `om_registry` ADD `public_key` BLOB AFTER `commitlimit` ,
ADD `merchant_key` BLOB AFTER `public_key` ;
ALTER TABLE `om_registry` CHANGE `merchant_key` `merchant_key` VARCHAR( 255 ) DEFAULT NULL ;





