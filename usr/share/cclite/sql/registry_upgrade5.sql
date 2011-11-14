-- update languages allowed for rough templates and update registry status to allow closing....
ALTER TABLE `om_users` CHANGE `userLang` `userLang` ENUM('en','fr','de','ar','zh','nl','es','it','el','ja','pt','ru','th','ko','bn') CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL DEFAULT 'en' ;
ALTER TABLE `om_registry` CHANGE `status` `status` ENUM( 'open', 'closed', 'down', 'closing' ) DEFAULT 'open' ;

