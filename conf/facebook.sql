DROP TABLE IF EXISTS m_facebook;
CREATE TABLE m_facebook (
  memberid  int not null,
  email     varchar(255) NOT NULL,
  firstname varchar(255) DEFAULT NULL,
  lastname  varchar(255) DEFAULT NULL,
  
  access_token  text,
  expires_in    varchar(255) DEFAULT NULL,
  id            varchar(255) DEFAULT NULL,
  status enum('Yes','No') DEFAULT 'Yes',
  created datetime default null,
  primary  key (memberid),
  index (email(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP PROCEDURE IF EXISTS proc_m_facebook;
DELIMITER ~
CREATE PROCEDURE proc_m_facebook (
IN in_email        VARCHAR(255),
IN in_first_name   VARCHAR(255),
IN in_last_name    VARCHAR(255),
IN in_access_token TEXT,
IN in_expires_in   INT,
in in_id           VARCHAR(255),

OUT out_id        INT UNSIGNED,
OUT out_login     varchar(255),
OUT out_firstname varchar(255),
OUT out_lastname  varchar(255))
BEGIN

DECLARE s VARCHAR(10);
SELECT memberid, email, firstname, lastname, status INTO out_id, out_login, out_firstname, out_lastname, s WHERE email = in_email;

IF (out_id && s='No') THEN
	SELECT '1030' INTO out_id;
ELSEIF (out_id) THEN
	UPDATE m_facebook SET firstname=in_first_name, lastname=in_last_name, access_token=in_access_token, expires_in=in_expires_in;
ELSE
	INSERT INTO m_facebook VALUES (FLOOR(RAND()*4294967296), in_email, in_first_name, in_last_name, in_access_token, in_expires_in, in_id, 'Yes', NOW());
	SELECT memberid, email, firstname, lastname INTO out_id, out_login, out_firstname, out_lastname WHERE email = in_email;
END IF;

END~
DELIMITER ;
