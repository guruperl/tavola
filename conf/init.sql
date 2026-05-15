DROP TABLE IF EXISTS `user_action_public`;
DROP TABLE IF EXISTS `user_action`;
DROP TABLE IF EXISTS `user_component`;
DROP TABLE IF EXISTS `user_role`;
DROP TABLE IF EXISTS `user_procedure`;
DROP TABLE IF EXISTS `user_table_non`;
DROP TABLE IF EXISTS `user_table_unique`;
DROP TABLE IF EXISTS `user_table_fk`;
DROP TABLE IF EXISTS `user_table`;
DROP TABLE IF EXISTS `user_ds`;
DROP TABLE IF EXISTS `user_project`;
DROP TABLE IF EXISTS `member`;
DROP TABLE IF EXISTS `def_type`;

CREATE TABLE IF NOT EXISTS `def_type` (
  `typeid` tinyint(3) unsigned NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  is_vue enum('Yes','No') default 'No',
  is_graph enum('Yes','No') default 'No',
  lang set('PHP','GO','Java','Perl') default 'PHP',
  total_account tinyint unsigned default 1,
  total_role tinyint unsigned default null,
  PRIMARY KEY (`typeid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
INSERT INTO def_type (typeid,name,total_role) VALUES (1,"Personal",3);
INSERT INTO def_type (typeid,name,is_vue,is_graph,lang,total_account) VALUES (2,"Team",'Yes','No','PHP',3);
INSERT INTO def_type (typeid,name,is_vue,is_graph,lang,total_account) VALUES (3,"Enterprise",'Yes','Yes','PHP,GO,Java,Perl',10);

CREATE TABLE IF NOT EXISTS `member` (
  `memberid` int(10) unsigned NOT NULL DEFAULT '0',
  `typeid` tinyint(3) unsigned default 1,
  groupid int(10) unsigned NOT NULL,
  `login` VARCHAR(16) NOT NULL DEFAULT '',
  `passwd` VARCHAR(255) NOT NULL DEFAULT '',
  `active` enum('Yes','No','Wait','First') NOT NULL DEFAULT 'First',
  `subscription_type` varchar(255) default null,
  `subscription_time` datetime default null,
  `email` VARCHAR(255) NOT NULL DEFAULT '',
  `phone` VARCHAR(255) DEFAULT NULL,
  `paycard` enum('Wechat','Alipay','Cash','Other') DEFAULT 'Other',
  `firstname` VARCHAR(255) DEFAULT NULL,
  `lastname` VARCHAR(255) DEFAULT NULL,
  `street` VARCHAR(255) DEFAULT NULL,
  `city` VARCHAR(255) DEFAULT NULL,
  `state` VARCHAR(255) DEFAULT NULL,
  `zip` VARCHAR(255) DEFAULT NULL,
  `country` VARCHAR(255) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `ip` VARCHAR(15) DEFAULT NULL,
  `moment` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`memberid`),
  UNIQUE KEY `login` (`login`),
  foreign key (typeid) references def_type (typeid) on update cascade,
  foreign key (groupid) references member (memberid) on update cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_project` (
  projectid int unsigned not null auto_increment,
  memberid int unsigned not null,
  ds enum('online', 'remote') default 'online',
  Document_root VARCHAR(255) NOT NULL,
  Project VARCHAR(255) NOT NULL,
  Server_url VARCHAR(255) NOT NULL,
  Script VARCHAR(255) NOT NULL,
  Template VARCHAR(255) NOT NULL,
  Uploaddir VARCHAR(255) NOT NULL,
  Pubrole VARCHAR(255) NOT NULL DEFAULT "p",
  def_component varchar(255) DEFAULT NULL,
  def_action varchar(255) DEFAULT "startnew",
  admin_role varchar(255) not null,
  admin_user varchar(255) not null,
  admin_pass varchar(255) not null,
  Log_file VARCHAR(255) NOT NULL,
  config_json JSON DEFAULT NULL,
  filter text DEFAULT NULL,
  model text DEFAULT NULL,
  created datetime,
  primary key (projectid),
  unique key (memberid),
  foreign key (memberid) references member (memberid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_ds` (
  dsid int unsigned not null auto_increment,
  projectid int unsigned not null,
  dbtype enum('MySQL', 'PostgreSQL', 'SQLite', 'Redshift', 'Snowflake') not null default 'MySQL',
  nickname varchar(255) not null, 
  dbname varchar(255) not null, 
  host varchar(255) not null, 
  port varchar(255) not null, 
  dbuser varchar(255) not null, 
  dbpass varchar(255) default null, 
  is_connected enum('Yes','No') default 'No',
  `created` datetime DEFAULT NULL,
  primary key (dsid),
  foreign key (projectid) references user_project (projectid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_table` (
  tableid 	int unsigned not null auto_increment,
  projectid	int unsigned not null,
  table_name	varchar(255) not null,
  current_key   varchar(255) default NULL,
  current_id_auto varchar(255) DEFAULT NULL,
  insert_pars json DEFAULT NULL,
  edit_pars json DEFAULT NULL,
  update_pars json DEFAULT NULL,
  topics_pars json DEFAULT NULL,
  statement text not null,
  is_tabilet tinyint unsigned default 0,
  table_comment varchar(255) default null,
  created datetime, 
  primary key (tableid),
  unique key (projectid, table_name(64)),
  foreign key (projectid) references user_project (projectid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_table_fk` (
  fkid 	int unsigned not null auto_increment,
  tableid	int unsigned not null,
  FKCOLUMN_NAME varchar(255) not null,
  PKTABLE_NAME varchar(255) not null,
  PKCOLUMN_NAME varchar(255) not null,
  primary key (fkid),
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_table_unique` (
  uniqueid 	int unsigned not null auto_increment,
  tableid	int unsigned not null,
  INDEX_NAME varchar(255) not null,
  ORDINAL_POSITION tinyint unsigned not null,
  COLUMN_NAME varchar(255) not null,
  primary key (uniqueid),
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_table_non` (
  nonid 	int unsigned not null auto_increment,
  tableid	int unsigned not null,
  COLUMN_NAME varchar(255) not null,
  primary key (nonid),
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_procedure` (
  procedureid 	int unsigned not null auto_increment,
  projectid	int unsigned not null,
  procedure_name	varchar(255) not null,
  statement text not null,
  tableid int unsigned default null,
  is_tabilet tinyint unsigned default 0,
  created datetime, 
  primary key (procedureid),
  foreign key (projectid) references user_project (projectid) on delete cascade,
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_role` (
  roleid	int unsigned not null auto_increment,
  projectid int unsigned not null,
  name_role varchar(255) not null,
  description varchar(255) not null,
  authen	enum('db','google','facebook','zoom','microsoft') default 'db',
  is_admin tinyint unsigned default 0,
  is_auto tinyint unsigned default 0,
  tableid	int unsigned default null,
  default_component varchar(255) default null,
  default_action varchar(255) default null,
  field_id varchar(255) not null comment "name of role table's id",
  field_login varchar(255) not null,
  field_passwd varchar(255) not null,
  field_firstname varchar(255) default null,
  field_lastname varchar(255) default null,
  restriction varchar(255) not null comment "where restriction for successful login",
  created datetime, 
  primary key (roleid),
  unique key (projectid, name_role(16)),
  foreign key (projectid) references user_project (projectid) on delete cascade,
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_component` (
  componentid 	int unsigned not null auto_increment,
  projectid	int unsigned not null,
  name_component	varchar(255) not null,
  description	varchar(255) not null,
  tableid	int unsigned default null,
  current_key   varchar(255) NOT NULL,
  current_id_auto varchar(255) DEFAULT NULL,
  current_tables json DEFAULT NULL,
  topics_hash json DEFAULT NULL,
  insert_pars json DEFAULT NULL,
  edit_pars json DEFAULT NULL,
  update_pars json DEFAULT NULL,
  topics_pars json DEFAULT NULL,
  component_json  JSON comment "component.json generated, then let customer to adjust",
  filter text comment "the customized filter",
  model  text comment "the customized model",
  created datetime, 
  primary key (componentid),
  unique key (projectid, name_component(16)),
  foreign key (projectid) references user_project (projectid) on delete cascade,
  foreign key (tableid) references user_table (tableid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_action` (
	actionid	int unsigned not null auto_increment,
	componentid   int unsigned not null,
	roleid	int unsigned not null,
	crud	set('startnew','insert','edit','update','delete','topics') default null,
	inkey	varchar(255) default null,
	inmd5	varchar(255) default null,
	outkey	varchar(255) default null,
	outmd5	varchar(255) default null,
	primary key (actionid),
	foreign key (componentid) references user_component (componentid) on delete cascade,
	foreign key (roleid) references user_role (roleid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `user_action_public` (
	apid	int unsigned not null auto_increment,
	componentid   int unsigned not null,
	crud	set('startnew','insert','edit','update','delete','topics') default null,
	primary key (apid),
	foreign key (componentid) references user_component (componentid) on delete cascade
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
