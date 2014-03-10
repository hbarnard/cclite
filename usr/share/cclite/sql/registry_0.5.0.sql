-- phpMyAdmin SQL Dump
-- version 2.6.0-pl2
-- http://www.phpmyadmin.net
-- 
-- Host: localhost
-- Generation Time: Jul 02, 2007 at 09:19 AM
-- Server version: 5.0.13
-- PHP Version: 4.2.2
-- 
-- Database: `chelsea`
-- 

-- --------------------------------------------------------

-- 
-- Table structure for table `om_categories`
-- 

DROP TABLE IF EXISTS `om_categories`;
CREATE TABLE IF NOT EXISTS `om_categories` (
  `id` mediumint(11) NOT NULL auto_increment,
  `category` varchar(4) NOT NULL default '',
  `parent` varchar(4) NOT NULL default '',
  `status` enum('active','inactive') NOT NULL default 'active',
  `description` varchar(80) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `alpha` (`parent`,`description`)
) ENGINE=MyISAM AUTO_INCREMENT=150 ;

-- 
-- Dumping data for table `om_categories`
-- 

INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (1, '1000', '', 'inactive', 'ADMINISTRATION');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (14, '1010', '', 'inactive', 'ADVICE');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (28, '1020', '', 'inactive', 'ARTS & CRAFTS');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (38, '1030', '', 'inactive', 'BODY CARE');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (52, '1040', '', 'inactive', 'BOOKS & MAGAZINES');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (57, '1050', '', 'inactive', 'CHILDREN');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (62, '1060', '', 'inactive', 'COMPANIONSHIP');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (69, '1070', '', 'inactive', 'FOOD & DRINK');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (76, '1080', '', 'inactive', 'GARDENING');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (81, '1090', '', 'inactive', 'HOUSEHOLD');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (86, '1110', '', 'inactive', 'DIY');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (93, '1120', '', 'inactive', 'LANGUAGES');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (103, '1130', '', 'inactive', 'MISCELLANEOUS');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (105, '1140', '', 'inactive', 'PETS');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (108, '1150', '', 'inactive', 'TUITION');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (125, '1160', '', 'inactive', 'TRANSPORT');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (130, '1170', '', 'inactive', 'USE OF FACILITIES');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (139, '1180', '', 'inactive', 'FOR SALE');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (2, '1001', '1000', 'active', 'General Admin');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (3, '1002', '1000', 'active', 'Computer trouble shooting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (4, '1003', '1000', 'active', 'Copywriting (short)');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (5, '1004', '1000', 'active', 'Form filling');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (6, '1005', '1000', 'active', 'Fundraising');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (7, '1006', '1000', 'active', 'Leaflet design');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (8, '1007', '1000', 'active', 'Leaflet distribution');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (9, '1008', '1000', 'active', 'Online research');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (10, '1009', '1000', 'active', 'Proofing & Editing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (11, '1010', '1000', 'active', 'Research');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (12, '1011', '1000', 'active', 'Typing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (13, '1012', '1000', 'active', 'Writing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (147, '1013', '1000', 'active', 'test new admin category');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (148, '1014', '1000', 'active', 'Brand new admin category');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (15, '1001', '1010', 'active', 'Architectural building');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (16, '1002', '1010', 'active', 'Colour coordination');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (17, '1003', '1010', 'active', 'Counselling');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (18, '1004', '1010', 'active', 'CV - interview');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (19, '1005', '1010', 'active', 'Dress Design');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (20, '1006', '1010', 'active', 'General');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (21, '1006', '1010', 'active', 'Health');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (22, '1008', '1010', 'active', 'Legal');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (23, '1009', '1010', 'active', 'Marketing/PR');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (24, '1010', '1010', 'active', 'Nutritional');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (25, '1011', '1010', 'active', 'Problem solving & fun');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (26, '1012', '1010', 'active', 'Predictions');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (27, '1013', '1010', 'active', 'Psychic');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (29, '1001', '1020', 'active', 'Architectural drawings');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (30, '1002', '1020', 'active', 'Artwork');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (31, '1003', '1020', 'active', 'Crochet');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (32, '1004', '1020', 'active', 'Digital photography');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (33, '1005', '1020', 'active', 'Fashion illustrations');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (34, '1006', '1020', 'active', 'Fire Swinging');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (35, '1007', '1020', 'active', 'Framing - advice on');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (36, '1008', '1020', 'active', 'Knitting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (37, '1009', '1020', 'active', 'Interior Design');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (39, '1001', '1030', 'active', 'Aromatherapy');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (40, '1002', '1030', 'active', 'Massage');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (41, '1003', '1030', 'active', 'Indian Head Massage');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (42, '1004', '1030', 'active', 'Hairdressing/cutting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (43, '1005', '1030', 'active', 'Homoeopathy');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (44, '1006', '1030', 'active', 'Cranial-Sacral Therapy');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (45, '1007', '1030', 'active', 'Physiotherapy');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (46, '1008', '1030', 'active', 'Reflexology');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (47, '1009', '1030', 'active', 'Reiki');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (48, '1010', '1030', 'active', 'Japanese Foot Massage');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (49, '1011', '1030', 'active', 'Exercise Support');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (50, '1012', '1030', 'active', 'Mineral testing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (51, '1013', '1030', 'active', 'Therapies - other');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (53, '1001', '1040', 'active', 'Discount Books');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (54, '1002', '1040', 'active', 'Holistic Science Mag');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (55, '1003', '1040', 'active', 'Returning library books');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (56, '1004', '1040', 'active', 'Subscription to Pathways');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (58, '1001', '1050', 'active', 'Child-minding');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (59, '1002', '1050', 'active', 'Babysitting / Help');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (60, '1003', '1050', 'active', 'Helping with Kids Parties');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (61, '1004', '1050', 'active', 'Music for children');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (63, '1001', '1060', 'active', 'Bedside Visiting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (64, '1002', '1060', 'active', 'Companionship');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (65, '1003', '1060', 'active', 'Caring for People');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (66, '1004', '1060', 'active', 'Listening');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (67, '1005', '1060', 'active', 'Wheelchair Outings');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (68, '1006', '1060', 'active', 'Reading aloud');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (70, '1001', '1070', 'active', 'Baking');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (71, '1002', '1070', 'active', 'Bread');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (72, '1003', '1070', 'active', 'Dinner Party Help');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (73, '1004', '1070', 'active', 'Jam & marmalade');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (74, '1005', '1070', 'active', 'Party planning');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (75, '1006', '1070', 'active', 'Vegetarian Cooking');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (77, '1001', '1080', 'active', 'Allotment Share');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (78, '1002', '1080', 'active', 'Gardening');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (79, '1003', '1080', 'active', 'Hedge & tree cutting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (80, '1004', '1080', 'active', 'Landscaping');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (82, '1001', '1090', 'active', 'Cleaning');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (83, '1002', '1090', 'active', 'Clearing clutter');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (84, '1003', '1090', 'active', 'Curtain making');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (85, '1004', '1090', 'active', 'Decorating');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (87, '1001', '1110', 'active', 'Fixing household goods');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (88, '1002', '1110', 'active', 'House minding');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (89, '1003', '1110', 'active', 'Plant care');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (90, '1004', '1110', 'active', 'Sewing /Mending /Alterations');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (91, '1005', '1110', 'active', 'Waiting in for Trades');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (92, '1006', '1110', 'active', 'Window Cleaning');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (94, '1001', '1120', 'active', 'Dutch');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (95, '1002', '1120', 'active', 'English');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (96, '1003', '1120', 'active', 'German');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (97, '1004', '1120', 'active', 'French');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (98, '1005', '1120', 'active', 'Hebrew');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (99, '1006', '1120', 'active', 'Japanese');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (100, '1007', '1120', 'active', 'Latin');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (101, '1008', '1120', 'active', 'Russian');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (102, '1009', '1120', 'active', 'Spanish');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (104, '1001', '1130', 'active', 'Nature reserves in Camden');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (106, '1001', '1140', 'active', 'Pet Care');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (107, '1002', '1140', 'active', 'Dog training');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (109, '1001', '1150', 'active', 'Acting');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (110, '1002', '1150', 'active', 'Alexander Technique');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (111, '1003', '1150', 'active', 'Ballet');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (112, '1004', '1150', 'active', 'Bates Method');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (113, '1005', '1150', 'active', 'Belly Dancing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (114, '1006', '1150', 'active', 'Bread making');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (115, '1008', '1150', 'active', 'Gardening lessons');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (116, '1009', '1150', 'active', 'Computing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (117, '1011', '1150', 'active', 'Maths');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (118, '1012', '1150', 'active', 'Mosaic design');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (119, '1013', '1150', 'active', 'Singing');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (120, '1014', '1150', 'active', 'Stretch class');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (121, '1015', '1150', 'active', 'Swimming');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (122, '1016', '1150', 'active', 'Tennis');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (123, '1017', '1150', 'active', 'Voice');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (124, '1018', '1150', 'active', 'Yoga');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (126, '1001', '1160', 'active', 'Bicycle repair');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (127, '1002', '1160', 'active', 'Driving & Lifts');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (128, '1003', '1160', 'active', 'Shopping');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (129, '1004', '1160', 'active', 'Driving skills');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (131, '1001', '1170', 'active', 'Accommodation');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (132, '1002', '1170', 'active', 'Clothes rail for hire');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (133, '1003', '1170', 'active', 'Internet access');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (134, '1004', '1170', 'active', 'Meeting Space');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (135, '1005', '1170', 'active', 'Publicity');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (136, '1006', '1170', 'active', 'CD copying - Scanning');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (137, '1007', '1170', 'active', 'Tool hire');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (138, '1008', '1170', 'active', 'Use of Washing Machine');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (140, '1001', '1180', 'active', 'Children''s bikes');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (141, '1002', '1180', 'active', 'Harmonium');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (142, '1003', '1180', 'active', 'Indoor plants');
INSERT INTO `om_categories` (`id`, `category`, `parent`, `status`, `description`) VALUES (149, '', '1070', 'active', 'Garden Party');

-- --------------------------------------------------------

-- 
-- Table structure for table `om_currencies`
-- 

DROP TABLE IF EXISTS `om_currencies`;
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
) ENGINE=MyISAM ;



-- 
-- Table structure for table `om_groups`
-- 

DROP TABLE IF EXISTS `om_groups`;
CREATE TABLE IF NOT EXISTS `om_groups` (
  `groupId` int(8) NOT NULL auto_increment,
  `groupName` varchar(255) NOT NULL default '',
  `groupDescription` text,
  PRIMARY KEY  (`groupId`),
  UNIQUE KEY `groupName` (`groupName`)
) ENGINE=MyISAM  ;

-- 
-- Dumping data for table `om_groups`
-- 


-- --------------------------------------------------------

-- 
-- Table structure for table `om_log`
-- 

DROP TABLE IF EXISTS `om_log`;
CREATE TABLE IF NOT EXISTS `om_log` (
  `id` int(11) NOT NULL auto_increment,
  `type` varchar(20) NOT NULL default '',
  `userLogin` varchar(30) NOT NULL default '',
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `ip` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  ;

-- 
-- Dumping data for table `om_log`
-- 


-- --------------------------------------------------------

-- 
-- Table structure for table `om_partners`
-- 

DROP TABLE IF EXISTS `om_partners`;
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
) ENGINE=MyISAM ;

-- 
-- Table structure for table `om_prefs`
-- 

DROP TABLE IF EXISTS `om_prefs`;
CREATE TABLE IF NOT EXISTS `om_prefs` (
  `prefName` varchar(64) NOT NULL default '',
  `prefUser` int(8) NOT NULL default '0',
  `prefValue` text,
  PRIMARY KEY  (`prefName`)
) ENGINE=MyISAM ;

-- 
-- Dumping data for table `om_prefs`
-- 


-- --------------------------------------------------------

-- 
-- Table structure for table `om_registry`
-- 

DROP TABLE IF EXISTS `om_registry`;
CREATE TABLE IF NOT EXISTS `om_registry` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(30) NOT NULL default '',
  `description` varchar(250) NOT NULL default '',
  `admemail` varchar(50) default NULL,
  `postemail` varchar(50) default NULL,
  `chargetype` enum('equaltime','market') NOT NULL default 'equaltime',
  `commission` enum('yes','no') NOT NULL default 'yes',
  `geographic` enum('yes','no') NOT NULL default 'yes',
  `postcodes` varchar(80) NOT NULL default '',
  `subscription` enum('yes','no') NOT NULL default 'yes',
  `commitlimit` varchar(10) NOT NULL default '',
  `public_key` blob,
  `merchant_key` varchar(255) default NULL,
  `allow_ip_list` varchar(60) NOT NULL,
  `latest_news` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM ;


-- 
-- Table structure for table `om_rules`
-- 

DROP TABLE IF EXISTS `om_rules`;
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
) ENGINE=MyISAM ;


-- 
-- Table structure for table `om_summary`
-- 

DROP TABLE IF EXISTS `om_summary`;
CREATE TABLE IF NOT EXISTS `om_summary` (
  `id` int(11) NOT NULL auto_increment,
  `userLogin` int(11) NOT NULL default '0',
  `tradeCurrency` int(11) NOT NULL default '0',
  `tradeBalance` bigint(20) NOT NULL default '0',
  `tradeVolume` bigint(20) NOT NULL default '0',
  `reputation` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM ;


-- Table structure for table `om_trades`
-- 

DROP TABLE IF EXISTS `om_trades`;
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
  `tradeItem` enum('goods','services','other') NOT NULL default 'goods',
  `tradeTaxflag` char(2) default '0',
  `tradeHash` varchar(128) default NULL,
  PRIMARY KEY  (`tradeId`),
  KEY `tradeCurrency` (`tradeCurrency`),
  KEY `tradeDate` (`tradeDate`),
  KEY `tradeSource` (`tradeSource`),
  KEY `tradeDestination` (`tradeDestination`)
) ENGINE=InnoDB  ;


-- 
-- Table structure for table `om_users`
-- 

DROP TABLE IF EXISTS `om_users`;
CREATE TABLE IF NOT EXISTS `om_users` (
  `userId` int(11) NOT NULL auto_increment,
  `userLogin` varchar(30) NOT NULL default '',
  `userLang` enum('en','fr','de') NOT NULL default 'en',
  `userPassword` varchar(128) NOT NULL default '',
  `userPublickey` text,
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
  `userLevel` enum('user','admin','sysaccount','other') default 'user',
  `userStatus` enum('active','unconfirmed','suspended','predelete','holiday') default 'active',
  `userJoindate` date NOT NULL default '0000-00-00',
  `userLastLogin` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `userRegistration` int(11) NOT NULL default '0',
  PRIMARY KEY  (`userId`),
  KEY `userLogin` (`userLogin`)
) ENGINE=MyISAM ;

-- 
-- Dumping data for table `om_users`
-- 

INSERT INTO `om_users` (`userId`, `userLogin`, `userLang`, `userPassword`, `userPublickey`, `userEmail`, `userTelephone`, `userMobile`, `userName`, `userNameornumber`, `userStreet`, `userTown`, `userArea`, `userPostcode`, `userDescription`, `userUrl`, `userLevel`, `userStatus`, `userJoindate`, `userLastLogin`, `userRegistration`) VALUES (1, 'manager', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, 'yourmail@yourdomain.com', '', '', 'Registry Manager', '', '', '', '', '', '', '', 'admin', 'active', 0x303030302d30302d3030, 0x323030372d30372d30322030373a32333a3539, 0);
INSERT INTO `om_users` (`userId`, `userLogin`, `userLang`, `userPassword`, `userPublickey`, `userEmail`, `userTelephone`, `userMobile`, `userName`, `userNameornumber`, `userStreet`, `userTown`, `userArea`, `userPostcode`, `userDescription`, `userUrl`, `userLevel`, `userStatus`, `userJoindate`, `userLastLogin`, `userRegistration`) VALUES (2, 'sysaccount', 'en', 'X8LKbwhZGfL3dibx4oD6ucyStO3J7cU6xu7j9yxcUI6GnunWepbWOYbRTBwrgsNf9fMUlL6oMQFUJPWclv/2ZA', NULL, 'yourmail@yourdomain.com', '', '', 'System Account', '', '', '', '', '', '', '', 'sysaccount', 'active', 0x303030302d30302d3030, 0x323030372d30372d30312031313a32363a3038, 0);

-- 
-- Table structure for table `om_users_groups`
-- 

DROP TABLE IF EXISTS `om_users_groups`;
CREATE TABLE IF NOT EXISTS `om_users_groups` (
  `ugGroupId` int(8) NOT NULL default '0',
  `ugUserId` int(8) NOT NULL default '0',
  PRIMARY KEY  (`ugGroupId`,`ugUserId`)
) ENGINE=MyISAM ;

-- 
-- Table structure for table `om_yellowpages`
-- 

DROP TABLE IF EXISTS `om_yellowpages`;
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
) ENGINE=MyISAM ;
