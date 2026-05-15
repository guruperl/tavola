CREATE TABLE IF NOT EXISTS tavola_login_a (
  a_id int unsigned not null auto_increment,
  email varchar(32) NOT NULL DEFAULT '',
  passwd varchar(40) NOT NULL DEFAULT '',
  firstname varchar(255) DEFAULT NULL,
  lastname varchar(255) DEFAULT NULL,
  status enum('Yes','No') DEFAULT 'Yes',
  created datetime DEFAULT NULL,
  PRIMARY KEY (a_id),
  UNIQUE KEY email (email(16))
) ENGINE=InnoDB DEFAULT CHARSET=utf8
