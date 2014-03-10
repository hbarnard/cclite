UPDATE `registry-name`.`om_users` SET `userLastLogin` = NOW( ) ,
`userPasswordTries` = '3' WHERE `om_users`.`userId` =1 LIMIT 1 ;
