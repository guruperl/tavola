CREATE TABLE IF NOT EXISTS tavola_login_a_tavola_ip (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  ip int(10) unsigned NOT NULL,
  login VARCHAR(255) NOT NULL,
  updated timestamp,
  ret enum('fail','success') NOT NULL DEFAULT 'fail',
  PRIMARY KEY (id),
  KEY updated (updated),
  KEY ip (ip)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
