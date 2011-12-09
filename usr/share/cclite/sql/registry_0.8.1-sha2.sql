-- phpMyAdmin SQL Dump
-- version 2.11.8.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 22, 2009 at 09:11 AM
-- Server version: 5.0.27
-- PHP Version: 5.1.6

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: ``
--

-- --------------------------------------------------------

--
-- Table structure for table `om_categories`
--

CREATE TABLE IF NOT EXISTS `om_categories` (
  `id` mediumint(11) NOT NULL auto_increment,
  `category` varchar(4) NOT NULL default '',
  `parent` varchar(4) NOT NULL default '',
  `status` enum('active','inactive') NOT NULL default 'active',
  `description` varchar(80) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `alpha` (`parent`,`description`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ;

--
-- Dumping data for table `om_categories`
--

INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES
(1, '1000', '', 'inactive', 'ADMINISTRATION'),
(14, '1010', '', 'inactive', 'ADVICE'),
(28, '1020', '', 'inactive', 'ARTS & CRAFTS'),
(38, '1030', '', 'inactive', 'BODY CARE'),
(52, '1040', '', 'inactive', 'BOOKS & MAGAZINES'),
(57, '1050', '', 'inactive', 'CHILDREN'),
(62, '1060', '', 'inactive', 'COMPANIONSHIP'),
(69, '1070', '', 'inactive', 'FOOD & DRINK'),
(76, '1080', '', 'inactive', 'GARDENING'),
(81, '1090', '', 'inactive', 'HOUSEHOLD'),
(86, '1110', '', 'inactive', 'DIY'),
(93, '1120', '', 'inactive', 'LANGUAGES'),
(103, '1130', '', 'inactive', 'MISCELLANEOUS'),
(105, '1140', '', 'inactive', 'PETS'),
(108, '1150', '', 'inactive', 'TUITION'),
(125, '1160', '', 'inactive', 'TRANSPORT'),
(130, '1170', '', 'inactive', 'USE OF FACILITIES'),
(139, '1180', '', 'inactive', 'FOR SALE'),
(2, '1001', '1000', 'active', 'General Admin'),
(3, '1002', '1000', 'active', 'Computer trouble shooting'),
(4, '1003', '1000', 'active', 'Copywriting (short)'),
(5, '1004', '1000', 'active', 'Form filling'),
(6, '1005', '1000', 'active', 'Fundraising'),
(7, '1006', '1000', 'active', 'Leaflet design'),
(8, '1007', '1000', 'active', 'Leaflet distribution'),
(9, '1008', '1000', 'active', 'Online research'),
(10, '1009', '1000', 'active', 'Proofing & Editing'),
(11, '1010', '1000', 'active', 'Research'),
(12, '1011', '1000', 'active', 'Typing'),
(13, '1012', '1000', 'active', 'Writing'),
(147, '1013', '1000', 'active', 'test new admin category'),
(148, '1014', '1000', 'active', 'Brand new admin category'),
(15, '1001', '1010', 'active', 'Architectural building'),
(16, '1002', '1010', 'active', 'Colour coordination'),
(17, '1003', '1010', 'active', 'Counselling'),
(18, '1004', '1010', 'active', 'CV - interview'),
(19, '1005', '1010', 'active', 'Dress Design'),
(20, '1006', '1010', 'active', 'General'),
(21, '1006', '1010', 'active', 'Health'),
(22, '1008', '1010', 'active', 'Legal'),
(23, '1009', '1010', 'active', 'Marketing/PR'),
(24, '1010', '1010', 'active', 'Nutritional'),
(25, '1011', '1010', 'active', 'Problem solving & fun'),
(26, '1012', '1010', 'active', 'Predictions'),
(27, '1013', '1010', 'active', 'Psychic'),
(29, '1001', '1020', 'active', 'Architectural drawings'),
(30, '1002', '1020', 'active', 'Artwork'),
(31, '1003', '1020', 'active', 'Crochet'),
(32, '1004', '1020', 'active', 'Digital photography'),
(33, '1005', '1020', 'active', 'Fashion illustrations'),
(34, '1006', '1020', 'active', 'Fire Swinging'),
(35, '1007', '1020', 'active', 'Framing - advice on'),
(36, '1008', '1020', 'active', 'Knitting'),
(37, '1009', '1020', 'active', 'Interior Design'),
(39, '1001', '1030', 'active', 'Aromatherapy'),
(40, '1002', '1030', 'active', 'Massage'),
(41, '1003', '1030', 'active', 'Indian Head Massage'),
(42, '1004', '1030', 'active', 'Hairdressing/cutting'),
(43, '1005', '1030', 'active', 'Homoeopathy'),
(44, '1006', '1030', 'active', 'Cranial-Sacral Therapy'),
(45, '1007', '1030', 'active', 'Physiotherapy'),
(46, '1008', '1030', 'active', 'Reflexology'),
(47, '1009', '1030', 'active', 'Reiki'),
(48, '1010', '1030', 'active', 'Japanese Foot Massage'),
(49, '1011', '1030', 'active', 'Exercise Support'),
(50, '1012', '1030', 'active', 'Mineral testing'),
(51, '1013', '1030', 'active', 'Therapies - other'),
(53, '1001', '1040', 'active', 'Discount Books'),
(54, '1002', '1040', 'active', 'Holistic Science Mag'),
(55, '1003', '1040', 'active', 'Returning library books'),
(56, '1004', '1040', 'active', 'Subscription to Pathways'),
(58, '1001', '1050', 'active', 'Child-minding'),
(59, '1002', '1050', 'active', 'Babysitting / Help'),
(60, '1003', '1050', 'active', 'Helping with Kids Parties'),
(61, '1004', '1050', 'active', 'Music for children'),
(63, '1001', '1060', 'active', 'Bedside Visiting'),
(64, '1002', '1060', 'active', 'Companionship'),
(65, '1003', '1060', 'active', 'Caring for People'),
(66, '1004', '1060', 'active', 'Listening'),
(67, '1005', '1060', 'active', 'Wheelchair Outings'),
(68, '1006', '1060', 'active', 'Reading aloud'),
(70, '1001', '1070', 'active', 'Baking'),
(71, '1002', '1070', 'active', 'Bread'),
(72, '1003', '1070', 'active', 'Dinner Party Help'),
(73, '1004', '1070', 'active', 'Jam & marmalade'),
(74, '1005', '1070', 'active', 'Party planning'),
(75, '1006', '1070', 'active', 'Vegetarian Cooking'),
(77, '1001', '1080', 'active', 'Allotment Share'),
(78, '1002', '1080', 'active', 'Gardening'),
(79, '1003', '1080', 'active', 'Hedge & tree cutting'),
(80, '1004', '1080', 'active', 'Landscaping'),
(82, '1001', '1090', 'active', 'Cleaning'),
(83, '1002', '1090', 'active', 'Clearing clutter'),
(84, '1003', '1090', 'active', 'Curtain making'),
(85, '1004', '1090', 'active', 'Decorating'),
(87, '1001', '1110', 'active', 'Fixing household goods'),
(88, '1002', '1110', 'active', 'House minding'),
(89, '1003', '1110', 'active', 'Plant care'),
(90, '1004', '1110', 'active', 'Sewing /Mending /Alterations'),
(91, '1005', '1110', 'active', 'Waiting in for Trades'),
(92, '1006', '1110', 'active', 'Window Cleaning'),
(94, '1001', '1120', 'active', 'Dutch'),
(95, '1002', '1120', 'active', 'English'),
(96, '1003', '1120', 'active', 'German'),
(97, '1004', '1120', 'active', 'French'),
(98, '1005', '1120', 'active', 'Hebrew'),
(99, '1006', '1120', 'active', 'Japanese'),
(100, '1007', '1120', 'active', 'Latin'),
(101, '1008', '1120', 'active', 'Russian'),
(102, '1009', '1120', 'active', 'Spanish'),
(104, '1001', '1130', 'active', 'Nature reserves in Camden'),
(106, '1001', '1140', 'active', 'Pet Care'),
(107, '1002', '1140', 'active', 'Dog training'),
(109, '1001', '1150', 'active', 'Acting'),
(110, '1002', '1150', 'active', 'Alexander Technique'),
(111, '1003', '1150', 'active', 'Ballet'),
(112, '1004', '1150', 'active', 'Bates Method'),
(113, '1005', '1150', 'active', 'Belly Dancing'),
(114, '1006', '1150', 'active', 'Bread making'),
(115, '1008', '1150', 'active', 'Gardening lessons'),
(116, '1009', '1150', 'active', 'Computing'),
(117, '1011', '1150', 'active', 'Maths'),
(118, '1012', '1150', 'active', 'Mosaic design'),
(119, '1013', '1150', 'active', 'Singing'),
(120, '1014', '1150', 'active', 'Stretch class'),
(121, '1015', '1150', 'active', 'Swimming'),
(122, '1016', '1150', 'active', 'Tennis'),
(123, '1017', '1150', 'active', 'Voice'),
(124, '1018', '1150', 'active', 'Yoga'),
(126, '1001', '1160', 'active', 'Bicycle repair'),
(127, '1002', '1160', 'active', 'Driving & Lifts'),
(128, '1003', '1160', 'active', 'Shopping'),
(129, '1004', '1160', 'active', 'Driving skills'),
(131, '1001', '1170', 'active', 'Accommodation'),
(132, '1002', '1170', 'active', 'Clothes rail for hire'),
(133, '1003', '1170', 'active', 'Internet access'),
(134, '1004', '1170', 'active', 'Meeting Space'),
(135, '1005', '1170', 'active', 'Publicity'),
(136, '1006', '1170', 'active', 'CD copying - Scanning'),
(137, '1007', '1170', 'active', 'Tool hire'),
(138, '1008', '1170', 'active', 'Use of Washing Machine'),
(140, '1001', '1180', 'active', 'Children''s bikes'),
(141, '1002', '1180', 'active', 'Harmonium'),
(142, '1003', '1180', 'active', 'Indoor plants'),
(149, '', '1070', 'active', 'Garden Party');

-- --------------------------------------------------------

--
-- Table structure for table `om_currencies`
--

CREATE TABLE IF NOT EXISTS `om_currencies` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(30) NOT NULL default '',
  `code` char(3) NOT NULL,
  `description` varchar(30) NOT NULL default '',
  `status` enum('active','suspended','predelete') NOT NULL default 'active',
  `mail` varchar(30) NOT NULL default '',
  `membership` enum('open','closed','other') NOT NULL default 'open',
  `type` enum('lets','hours','reputation','demurrage','other') NOT NULL default 'lets',
  `public_key` blob,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ;

INSERT INTO `om_currencies` (
`id` ,
`name` ,
`code` ,
`description` ,
`status` ,
`mail` ,
`membership` ,
`type`
)
VALUES (
NULL , 'sms', 'SMS', 'sms debit currency', 'active', 'your-mail-here', 'closed', 'other'
);

--
-- Dumping data for table `om_currencies`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_groups`
--

CREATE TABLE IF NOT EXISTS `om_groups` (
  `groupId` int(8) NOT NULL auto_increment,
  `groupName` varchar(255) NOT NULL default '',
  `groupDescription` text,
  PRIMARY KEY  (`groupId`),
  UNIQUE KEY `groupName` (`groupName`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ;

--
-- Dumping data for table `om_groups`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_log`
--

CREATE TABLE IF NOT EXISTS `om_log` (
  `id` int(11) NOT NULL auto_increment,
  `type` varchar(20) NOT NULL default '',
  `userLogin` varchar(30) NOT NULL default '',
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `ip` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_log`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_partners`
--

CREATE TABLE IF NOT EXISTS `om_partners` (
  `id` int(11) NOT NULL auto_increment,
  `date` date default NULL,
  `name` varchar(30) default NULL,
  `uri` varchar(80) default NULL,
  `proxy` varchar(80) default NULL,
  `email` varchar(50) default NULL,
  `type` enum('local','proxy') default NULL,
  `status` enum('active','suspend','down') default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ;

--
-- Dumping data for table `om_partners`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_prefs`
--

CREATE TABLE IF NOT EXISTS `om_prefs` (
  `prefName` varchar(64) NOT NULL default '',
  `prefUser` int(8) NOT NULL default '0',
  `prefValue` text,
  PRIMARY KEY  (`prefName`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `om_prefs`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_registry`
--

CREATE TABLE IF NOT EXISTS `om_registry` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(30) NOT NULL default '',
  `description` varchar(250) NOT NULL default '',
  `admemail` varchar(60) default NULL,
  `admpass` varchar(20) NOT NULL,
  `postemail` varchar(60) default NULL,
  `postpass` varchar(20) NOT NULL,
  `chargetype` enum('equaltime','market') NOT NULL default 'equaltime',
  `commission` enum('yes','no') NOT NULL default 'yes',
  `geographic` enum('yes','no') NOT NULL default 'yes',
  `postcodes` varchar(80) NOT NULL default '',
  `subscription` enum('yes','no') NOT NULL default 'yes',
  `commitlimit` int(11) default NULL,
  `public_key_id` varchar(20),
  `merchant_key` varchar(255) default NULL,
  `allow_ip_list` varchar(60) NOT NULL,
  `latest_news` text NOT NULL,
  `status` enum('open','closed','closing','down') default 'open',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 ;



INSERT INTO `om_registry` (
`id` ,
`name` ,
`description` ,
`admemail` ,
`admpass` ,
`postemail` ,
`postpass` ,
`chargetype` ,
`commission` ,
`geographic` ,
`postcodes` ,
`subscription` ,
`commitlimit` ,
`merchant_key` ,
`allow_ip_list` ,
`latest_news` ,
`status`
)
VALUES (
NULL , '', '', NULL , '', NULL , '', 'equaltime', 'yes', 'yes', '', 'yes', NULL , NULL , '', '', 'open'
);
--
-- Dumping data for table `om_registry`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_rules`
--

CREATE TABLE IF NOT EXISTS `om_rules` (
  `id` int(11) NOT NULL auto_increment,
  `event` enum('pretransaction','posttransaction','subscription','custom','creditlimit') default 'pretransaction',
  `currencyid` int(11) default NULL,
  `userid` int(11) NOT NULL default '0',
  `langtype` enum('perl','sql','ruby') default 'perl',
  `rulevalue` varchar(250) default NULL,
  `description` varchar(40) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `id_2` (`id`),
  KEY `id` (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_rules`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_summary`
--

CREATE TABLE IF NOT EXISTS `om_summary` (
  `id` int(11) NOT NULL auto_increment,
  `userLogin` int(11) NOT NULL default '0',
  `tradeCurrency` int(11) NOT NULL default '0',
  `tradeBalance` bigint(20) NOT NULL default '0',
  `tradeVolume` bigint(20) NOT NULL default '0',
  `reputation` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_summary`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_trades`
--

CREATE TABLE IF NOT EXISTS `om_trades` (
  `tradeId` int(11) NOT NULL auto_increment,
  `tradeStatus` enum('waiting','rejected','timedout','accepted','cleared','declined','cancelled') NOT NULL,
  `tradeDate` date NOT NULL default '0000-00-00',
  `tradeStamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `tradeSource` varchar(30) NOT NULL default '0',
  `tradeDestination` varchar(30) NOT NULL default '0',
  `tradeMirror` varchar(30) NOT NULL default '0',
  `tradeCurrency` varchar(30) NOT NULL default '0',
  `tradeType` enum('debit','credit','adj','open','balance','reputon') default NULL,
  `tradeAmount` int(11) NOT NULL default '0',
  `tradeTitle` varchar(80) default NULL,
  `tradeDescription` text,
  `tradeItem` enum('goods','services','other','cash') NOT NULL default 'goods',
  `tradeTaxflag` char(2) default '0',
  `tradeHash` varchar(128) default NULL,
  PRIMARY KEY  (`tradeId`),
  KEY `tradeCurrency` (`tradeCurrency`),
  KEY `tradeDate` (`tradeDate`),
  KEY `tradeSource` (`tradeSource`),
  KEY `tradeDestination` (`tradeDestination`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_trades`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_users`
--

CREATE TABLE IF NOT EXISTS `om_users` (
  `userId` int(11) NOT NULL auto_increment,
  `userLogin` varchar(30) NOT NULL default '',
  `userLang` enum('en','ar','zh','de','nl','fr','es','it','el','ja','pt','ru','th') NOT NULL default 'en',
  `userPassword` varchar(128) NOT NULL default '',
  `userPublickeyid` varchar(20),
  `userEmail` varchar(120) NOT NULL default '',
  `userTelephone` varchar(20) NOT NULL default '',
  `userMobile` varchar(20) default NULL,
  `userName` varchar(30) NOT NULL default '',
  `userNameornumber` varchar(20) NOT NULL,
  `userStreet` varchar(40) NOT NULL,
  `userTown` varchar(40) NOT NULL,
  `userArea` varchar(40) NOT NULL,
  `userPostcode` varchar(10) NOT NULL default '',
  `userDescription` varchar(250) NOT NULL default '',
  `userUrl` varchar(50) NOT NULL default '',
  `userLevel` enum('user','admin','sysaccount','issuer','other') default 'user',
  `userStatus` enum('active','unconfirmed','suspended','predelete','holiday') default 'active',
  `userJoindate` date NOT NULL default '0000-00-00',
  `userLastLogin` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `userRegistration` int(11) NOT NULL default '0',
  `userPin` varchar(128) NOT NULL,
  `userPinStatus` enum('active','waiting','locked','change') NOT NULL,
  `userPinTries` int(1) NOT NULL,
  `userPinChanged` date NOT NULL,
  `userPasswordStatus` enum('active','waiting','locked','change') NOT NULL,
  `userPasswordTries` int(1) NOT NULL,
  `userPasswordChanged` date NOT NULL,
  `userSmsreceipt` BOOL NOT NULL DEFAULT '0',
  `userLoggedin` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY  (`userId`),
  KEY `userLogin` (`userLogin`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_users`
--

INSERT INTO `om_users` (`userId`, `userLogin`, `userLang`, `userPassword`, `userPublickeyid`, `userEmail`, `userTelephone`, `userMobile`, `userName`, `userNameornumber`, `userStreet`, `userTown`, `userArea`, `userPostcode`, `userDescription`, `userUrl`, `userLevel`, `userStatus`, `userJoindate`, `userLastLogin`, `userRegistration`, `userPin`, `userPinStatus`, `userPinTries`, `userPinChanged`, `userPasswordStatus`, `userPasswordTries`, `userPasswordChanged`) VALUES
(1, 'manager', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, 'yourmail@yourdomain.com', '', '', 'Registry Manager', '', '', '', '', '', '', '', 'admin', 'active', '0000-00-00', '2009-03-06 08:24:18', 0, '0', 'waiting', 0, '0000-00-00', 'active', 3, '0000-00-00'),
(2, 'sysaccount', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, 'yourmail@yourdomain.com', '', '', 'System Account', '', '', '', '', '', '', '', 'sysaccount', 'active', '0000-00-00', '2008-12-23 09:50:18', 0, '0', 'waiting', 0, '0000-00-00', 'active', 0, '0000-00-00'),
(3, 'cash', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, '', '', NULL, 'Cash Account', '', '', '', '', '', '', '', 'sysaccount', 'active', '0000-00-00', '2008-12-23 06:16:34', 0, '', 'active', 0, '0000-00-00', 'active', 0, '0000-00-00'),
(4, 'liquidity', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, '', '', NULL, 'Liquidity Adjustment', '', '', '', '', '', '', '', 'sysaccount', 'active', '0000-00-00', '2008-12-23 13:01:03', 0, '', 'active', 0, '0000-00-00', 'active', 0, '0000-00-00');

-- --------------------------------------------------------

--
-- Table structure for table `om_users_groups`
--

CREATE TABLE IF NOT EXISTS `om_users_groups` (
  `ugGroupId` int(8) NOT NULL default '0',
  `ugUserId` int(8) NOT NULL default '0',
  PRIMARY KEY  (`ugGroupId`,`ugUserId`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `om_users_groups`
--


-- --------------------------------------------------------

--
-- Table structure for table `om_yellowpages`
--

CREATE TABLE IF NOT EXISTS `om_yellowpages` (
  `id` int(11) NOT NULL auto_increment,
  `status` enum('active','suspended','predelete') NOT NULL default 'active',
  `date` date NOT NULL default '0000-00-00',
  `type` enum('offered','wanted','event','other') NOT NULL default 'offered',
  `majorclass` enum('goods','services','other') NOT NULL default 'goods',
  `fromuserid` varchar(30) NOT NULL default '0',
  `category` varchar(4) NOT NULL default '',
  `parent` varchar(4) NOT NULL default '',
  `keywords` varchar(80) NOT NULL default '',
  `sic` varchar(10) NOT NULL default '',
  `subject` varchar(30) NOT NULL default '',
  `description` varchar(250) NOT NULL default '',
  `url` varchar(60) default NULL,
  `image` varchar(60) default NULL,
  `price` mediumint(10) NOT NULL default '0',
  `unit` enum('hour','day','week','month','other') NOT NULL default 'hour',
  `tradeCurrency` varchar(10) NOT NULL default '',
  `eventdate` date NOT NULL default '0000-00-00',
  `truelets` enum('yes','no') NOT NULL default 'yes',
  PRIMARY KEY  (`id`),
  KEY `id` (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1  ;

--
-- Dumping data for table `om_yellowpages`
--

 CREATE TABLE IF NOT EXISTS `om_openid` (
`userId` INT( 11 ) NOT NULL ,
`userLogin` VARCHAR( 60 ) NOT NULL ,
`openId` VARCHAR( 120 ) NOT NULL ,
`openIdDesc` VARCHAR( 120 ) NOT NULL ,
PRIMARY KEY ( `openId` ) ,
INDEX ( `userLogin` )
) ENGINE = MYISAM ;
