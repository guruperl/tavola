DROP TABLE IF EXISTS m_google;
CREATE TABLE m_google (
  memberid  int not null,
  email     varchar(255) NOT NULL,
  firstname varchar(255) DEFAULT NULL,
  lastname  varchar(255) DEFAULT NULL,
  
  access_token  text,
  expires_in    varchar(255) DEFAULT NULL,
  id            varchar(255) DEFAULT NULL,
  id_token      text,
  refresh_token text,
  picture       varchar(255) DEFAULT NULL,
  status enum('Yes','No') DEFAULT 'Yes',
  created datetime default null,
  primary  key (memberid),
  index (email(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP PROCEDURE IF EXISTS proc_m_google;
DELIMITER ~
CREATE PROCEDURE proc_m_google (
IN in_email         VARCHAR(255),
IN in_given_name    VARCHAR(255),
IN in_family_name   VARCHAR(255),
IN in_access_token  TEXT,
IN in_expires_in    INT,
in in_id            VARCHAR(255),
IN in_id_token      TEXT,
IN in_refresh_token TEXT,
IN in_picture       TEXT,

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
	UPDATE m_google SET firstname=in_given_name, lastname=in_family_name, access_token=in_access_token, expires_in=in_expires_in, id=in_id, id_token=in_id_token, refresh_token=in_refresh_token, picture=in_picture;
ELSE
	INSERT INTO m_google VALUES (FLOOR(RAND()*4294967296), in_email, in_given_name, in_family_name, in_access_token, in_expires_in, in_id, in_id_token, in_refresh_token, in_picture, 'Yes', NOW());
	SELECT memberid, email, firstname, lastname INTO out_id, out_login, out_firstname, out_lastname WHERE email = in_email;
END IF;

END~
DELIMITER ;
