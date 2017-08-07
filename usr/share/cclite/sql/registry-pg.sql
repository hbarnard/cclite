-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Tue Mar  7 15:04:15 2017
-- 
--
-- Table: om_categories.
--
CREATE TABLE "om_categories" (
  "id" serial NOT NULL,
  "category" character varying(4) DEFAULT '' NOT NULL,
  "parent" character varying(4) DEFAULT '' NOT NULL,
  "status" character varying(8) DEFAULT 'active' NOT NULL,
  "description" character varying(80) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "alpha" on "om_categories" ("parent", "description");

--
-- Table: om_currencies.
--
CREATE TABLE "om_currencies" (
  "id" serial NOT NULL,
  "name" character varying(30) DEFAULT '' NOT NULL,
  "code" character(3) NOT NULL,
  "description" character varying(30) DEFAULT '' NOT NULL,
  "status" character varying(9) DEFAULT 'active' NOT NULL,
  "mail" character varying(30) DEFAULT '' NOT NULL,
  "membership" character varying(6) DEFAULT 'open' NOT NULL,
  "type" character varying(10) DEFAULT 'lets' NOT NULL,
  "public_key" bytea,
  PRIMARY KEY ("id")
);

--
-- Table: om_groups.
--
CREATE TABLE "om_groups" (
  "groupId" serial NOT NULL,
  "groupName" character varying(255) DEFAULT '' NOT NULL,
  "groupDescription" text,
  PRIMARY KEY ("groupId"),
  CONSTRAINT "groupName" UNIQUE ("groupName")
);

--
-- Table: om_log.
--
CREATE TABLE "om_log" (
  "id" serial NOT NULL,
  "type" character varying(20) DEFAULT '' NOT NULL,
  "userLogin" character varying(30) DEFAULT '' NOT NULL,
  "stamp" timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "ip" character varying(30) DEFAULT '' NOT NULL,
  "message" character varying(120) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: om_partners.
--
CREATE TABLE "om_partners" (
  "id" serial NOT NULL,
  "date" date DEFAULT NULL,
  "name" character varying(30) DEFAULT NULL,
  "uri" character varying(80) DEFAULT NULL,
  "proxy" character varying(80) DEFAULT NULL,
  "email" character varying(50) DEFAULT NULL,
  "type" character varying(5) DEFAULT NULL,
  "status" character varying(7) DEFAULT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: om_prefs.
--
CREATE TABLE "om_prefs" (
  "id" bigint DEFAULT 0 NOT NULL,
  "prefName" character varying(64) DEFAULT '' NOT NULL,
  "userId" bigint DEFAULT 0 NOT NULL,
  "prefValue" text,
  PRIMARY KEY ("id")
);

--
-- Table: om_registry.
--
CREATE TABLE "om_registry" (
  "id" serial NOT NULL,
  "name" character varying(30) DEFAULT '' NOT NULL,
  "description" character varying(250) DEFAULT '' NOT NULL,
  "admemail" character varying(60) DEFAULT NULL,
  "admpass" character varying(20) NOT NULL,
  "postemail" character varying(60) DEFAULT NULL,
  "postpass" character varying(20) NOT NULL,
  "chargetype" character varying(9) DEFAULT 'equaltime' NOT NULL,
  "commission" character varying(3) DEFAULT 'yes' NOT NULL,
  "geographic" character varying(3) DEFAULT 'yes' NOT NULL,
  "postcodes" character varying(80) DEFAULT '' NOT NULL,
  "subscription" character varying(3) DEFAULT 'yes' NOT NULL,
  "commitlimit" bigint DEFAULT NULL,
  "public_key_id" character varying(20),
  "merchant_key" character varying(255) DEFAULT NULL,
  "allow_ip_list" character varying(60) NOT NULL,
  "latest_news" text NOT NULL,
  "status" character varying(7) DEFAULT 'open',
  PRIMARY KEY ("id")
);

--
-- Table: om_rules.
--
CREATE TABLE "om_rules" (
  "id" serial NOT NULL,
  "event" character varying(15) DEFAULT 'pretransaction',
  "currencyid" bigint DEFAULT NULL,
  "userid" bigint DEFAULT 0 NOT NULL,
  "langtype" character varying(4) DEFAULT 'perl',
  "rulevalue" character varying(250) DEFAULT NULL,
  "description" character varying(40) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "id_2" UNIQUE ("id")
);
CREATE INDEX "id" on "om_rules" ("id");

--
-- Table: om_summary.
--
CREATE TABLE "om_summary" (
  "id" serial NOT NULL,
  "userLogin" bigint DEFAULT 0 NOT NULL,
  "tradeCurrency" bigint DEFAULT 0 NOT NULL,
  "tradeBalance" bigint DEFAULT 0 NOT NULL,
  "tradeVolume" bigint DEFAULT 0 NOT NULL,
  "reputation" character varying(30) DEFAULT '' NOT NULL,
  PRIMARY KEY ("id")
);

--
-- Table: om_trades.
--
CREATE TABLE "om_trades" (
  "tradeId" serial NOT NULL,
  "tradeStatus" character varying(9) NOT NULL,
  "tradeDate" date DEFAULT '0000-00-00' NOT NULL,
  "tradeStamp" timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "tradeSource" character varying(30) DEFAULT '0' NOT NULL,
  "tradeDestination" character varying(30) DEFAULT '0' NOT NULL,
  "tradeMirror" character varying(30) DEFAULT '0' NOT NULL,
  "tradeCurrency" character varying(30) DEFAULT '0' NOT NULL,
  "tradeType" character varying(7) DEFAULT NULL,
  "tradeAmount" bigint DEFAULT 0 NOT NULL,
  "tradeTitle" character varying(80) DEFAULT NULL,
  "tradeDescription" text,
  "tradeItem" character varying(8) DEFAULT 'goods' NOT NULL,
  "tradeTaxflag" character(2) DEFAULT '0',
  "tradeHash" character varying(128) DEFAULT NULL,
  PRIMARY KEY ("tradeId")
);
CREATE INDEX "tradeCurrency" on "om_trades" ("tradeCurrency");
CREATE INDEX "tradeDate" on "om_trades" ("tradeDate");
CREATE INDEX "tradeSource" on "om_trades" ("tradeSource");
CREATE INDEX "tradeDestination" on "om_trades" ("tradeDestination");

--
-- Table: om_users.
--
CREATE TABLE "om_users" (
  "userId" serial NOT NULL,
  "userLogin" character varying(30) DEFAULT '' NOT NULL,
  "userLang" character varying(2) DEFAULT 'en' NOT NULL,
  "userPassword" character varying(128) DEFAULT '' NOT NULL,
  "userPublickeyid" character varying(20),
  "userEmail" character varying(120) DEFAULT '' NOT NULL,
  "userTelephone" character varying(20) DEFAULT '' NOT NULL,
  "userMobile" character varying(20) DEFAULT NULL,
  "userName" character varying(30) DEFAULT '' NOT NULL,
  "userNameornumber" character varying(20) NOT NULL,
  "userStreet" character varying(40) NOT NULL,
  "userTown" character varying(40) NOT NULL,
  "userArea" character varying(40) NOT NULL,
  "userPostcode" character varying(10) DEFAULT '' NOT NULL,
  "userDescription" character varying(250) DEFAULT '' NOT NULL,
  "userUrl" character varying(50) DEFAULT '' NOT NULL,
  "userLevel" character varying(10) DEFAULT 'user',
  "userStatus" character varying(11) DEFAULT 'active',
  "userJoindate" date DEFAULT '0000-00-00' NOT NULL,
  "userLastLogin" timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "userRegistration" bigint DEFAULT 0 NOT NULL,
  "userPin" character varying(128) NOT NULL,
  "userPinStatus" character varying(7) NOT NULL,
  "userPinTries" smallint NOT NULL,
  "userPinChanged" date NOT NULL,
  "userPasswordStatus" character varying(7) NOT NULL,
  "userPasswordTries" smallint NOT NULL,
  "userPasswordChanged" date NOT NULL,
  "userSmsreceipt" bool DEFAULT '0' NOT NULL,
  "userLoggedin" smallint DEFAULT 0 NOT NULL,
  PRIMARY KEY ("userId")
);
CREATE INDEX "userLogin" on "om_users" ("userLogin");

--
-- Table: om_users_groups.
--
CREATE TABLE "om_users_groups" (
  "ugGroupId" integer DEFAULT 0 NOT NULL,
  "ugUserId" integer DEFAULT 0 NOT NULL,
  PRIMARY KEY ("ugGroupId", "ugUserId")
);

--
-- Table: om_yellowpages.
--
CREATE TABLE "om_yellowpages" (
  "id" serial NOT NULL,
  "status" character varying(9) DEFAULT 'active' NOT NULL,
  "date" date DEFAULT '0000-00-00' NOT NULL,
  "type" character varying(7) DEFAULT 'offered' NOT NULL,
  "majorclass" character varying(8) DEFAULT 'goods' NOT NULL,
  "fromuserid" character varying(30) DEFAULT '0' NOT NULL,
  "category" character varying(4) DEFAULT '' NOT NULL,
  "parent" character varying(4) DEFAULT '' NOT NULL,
  "keywords" character varying(80) DEFAULT '' NOT NULL,
  "sic" character varying(10) DEFAULT '' NOT NULL,
  "subject" character varying(30) DEFAULT '' NOT NULL,
  "description" character varying(250) DEFAULT '' NOT NULL,
  "url" character varying(60) DEFAULT NULL,
  "image" character varying(60) DEFAULT NULL,
  "price" integer DEFAULT 0 NOT NULL,
  "unit" character varying(5) DEFAULT 'hour' NOT NULL,
  "tradeCurrency" character varying(10) DEFAULT '' NOT NULL,
  "eventdate" date DEFAULT '0000-00-00' NOT NULL,
  "truelets" character varying(3) DEFAULT 'yes' NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "id" on "om_yellowpages" ("id");

--
-- Table: om_openid.
--
CREATE TABLE "om_openid" (
  "userId" bigint NOT NULL,
  "userLogin" character varying(60) NOT NULL,
  "openId" character varying(120) NOT NULL,
  "openIdDesc" character varying(120) NOT NULL,
  PRIMARY KEY ("openId")
);
CREATE INDEX "om_openid_idx_1" on "om_openid" ("userLogin");

