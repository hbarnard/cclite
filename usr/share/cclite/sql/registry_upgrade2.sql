/* add issuer role, as in Thomas Greco's multiple (but not universal, as in LETS) issuers within a system */

ALTER TABLE `om_users` CHANGE `userLevel` `userLevel` ENUM( 'user', 'admin', 'sysaccount', 'issuer', 'other' ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT 'user' ;

/* add password to admin email in registry table so that smtp and pop can be used */

ALTER TABLE `om_registry` ADD `admpass` VARCHAR( 29 ) NOT NULL AFTER `admemail` ;

/* add password to batch email in registry so that smtp and pop can be used */

ALTER TABLE `om_registry` ADD `postpass` VARCHAR( 20 ) NOT NULL AFTER `postemail` ;

/*  registry current status field, used later to signal maintenance etc */

ALTER TABLE `om_registry`  ADD `status` enum('open','closed','down') default 'open' ;
