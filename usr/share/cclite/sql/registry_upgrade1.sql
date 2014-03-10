#These are the changes to upgrade to Cclite 0.5.0

ALTER TABLE `om_registry` ADD `allow_ip_list` VARCHAR( 60 ) NOT NULL AFTER `merchant_key` ;
ALTER TABLE `om_users` CHANGE `userPin` `userPublickey` TEXT DEFAULT NULL ;
ALTER TABLE `om_registry` ADD `latest_news` TEXT NOT NULL ;

# this swaps source and destination back to the correct columns for credit transactions
update om_trades set tradeDestination=(@TEMP:=tradeDestination), tradeDestination=tradeSource, tradeSource=@TEMP where tradeType = 'credit' ;


