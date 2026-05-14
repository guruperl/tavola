DROP TABLE IF EXISTS mem_github;
CREATE TABLE mem_github (
  memberid    int unsigned not null,
  `id` int unsigned not null,
  `login` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `bio`  varchar(255) DEFAULT NULL,
  `company`  varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `repos_url` varchar(255) DEFAULT NULL,
  `html_url` varchar(255) DEFAULT NULL,
  `access_token` text,
  moment timestamp,
  primary  key (`memberid`),
  unique key (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP PROCEDURE IF EXISTS proc_github_member;
DELIMITER ~
CREATE PROCEDURE proc_github_member (
IN in_id int unsigned,
IN in_gitlogin VARCHAR(255), IN in_name VARCHAR(255),
IN in_bio VARCHAR(255),
IN in_company VARCHAR(255), IN in_url VARCHAR(255),
IN in_repos_url VARCHAR(255), IN in_html_url VARCHAR(255),
IN in_firstname VARCHAR(255), IN in_lastname  VARCHAR(255),
IN in_email     VARCHAR(255), IN in_access_token VARCHAR(255),

OUT login varchar(255),
OUT out_memberid INT unsigned, OUT m_active VARCHAR(255),
OUT m_type VARCHAR(255), OUT m_subscription VARCHAR(255),
OUT m_email  VARCHAR(255), OUT m_lang VARCHAR(255),
OUT m_firstname VARCHAR(255) CHARSET utf8, OUT m_lastname VARCHAR(255) CHARSET utf8,
OUT m_groupid INT unsigned, OUT m_isgroup TINYINT)
BEGIN
-- login 
    SELECT m.login, m.memberid, m.email, t.lang, m.active, t.typeid, m.firstname, m.lastname, m.groupid, IF(m.groupid=m.memberid,1,0), IF(subscription_type!='', subscription_type, 'NONE')
    INTO login, out_memberid, m_email, m_lang, m_active, m_type, m_firstname, m_lastname, m_groupid, m_isgroup, m_subscription
    FROM mem_github g
	INNER JOIN member m USING (memberid)
    INNER JOIN def_type t USING (typeid)
    WHERE m.active IN ("Yes","First") AND g.id=in_id;
	IF (out_memberid) THEN
		UPDATE mem_github SET name=in_name, bio=in_bio, company=in_company, url=in_url, repos_url=in_repos_url, html_url=in_html_url, email=in_email, access_token=in_access_token WHERE memberid=out_memberid;
		UPDATE member SET email=in_email, firstname=in_firstname, lastname=in_lastname WHERE memberid=out_memberid;
	END IF;
END~
DELIMITER ;

DROP PROCEDURE IF EXISTS proc_github;
DELIMITER ~
CREATE PROCEDURE proc_github (
IN in_memberid  int unsigned, IN in_typeid    tinyint unsigned,
IN in_login     varchar(255), IN in_id int unsigned,
IN in_gitlogin VARCHAR(255), IN in_name VARCHAR(255),
IN in_bio VARCHAR(255),
IN in_company VARCHAR(255), IN in_url VARCHAR(255),
IN in_repos_url VARCHAR(255), IN in_html_url VARCHAR(255),
IN in_firstname VARCHAR(255), IN in_lastname  VARCHAR(255),
IN in_email     VARCHAR(255), IN in_access_token VARCHAR(255),

OUT login varchar(255),
OUT out_memberid INT unsigned, OUT m_active VARCHAR(255),
OUT m_type VARCHAR(255), OUT m_subscription VARCHAR(255),
OUT m_email  VARCHAR(255), OUT m_lang VARCHAR(255),
OUT m_firstname VARCHAR(255) CHARSET utf8, OUT m_lastname VARCHAR(255) CHARSET utf8,
OUT m_groupid INT unsigned, OUT m_isgroup TINYINT)
BEGIN
-- login  --- never used because of in_mmeber can't be null
	IF (ISNULL(in_memberid) && ISNULL(in_login)) THEN
    	SELECT m.login, m.memberid, m.email, t.lang, m.active, t.typeid, m.firstname, m.lastname, m.groupid, IF(m.groupid=m.memberid,1,0), IF(subscription_type!='', subscription_type, 'NONE')
    	INTO login, out_memberid, m_email, m_lang, m_active, m_type, m_firstname, m_lastname, m_groupid, m_isgroup, m_subscription
    	FROM mem_github g
		INNER JOIN member m USING (memberid)
    	INNER JOIN def_type t USING (typeid)
    	WHERE m.active IN ("Yes","First")
    	AND g.id=in_id;
		IF (out_memberid) THEN
			REPLACE INTO mem_github (memberid, id, login, name, bio, company, url, repos_url, html_url, email, access_token) VALUES (out_memberid, in_id, in_gitlogin, in_name, in_bio, in_company, in_url, in_repos_url, in_html_url, in_email, in_access_token);
			UPDATE member SET email=in_email, firstname=in_firstname, lastname=in_lastname WHERE memberid=out_memberid;
		END IF;
	ELSE
-- get memberid from cookie, still login, check
    	SELECT m.login, m.memberid, m.email, t.lang, m.active, t.typeid, m.firstname, m.lastname, m.groupid, IF(m.groupid=m.memberid,1,0), IF(subscription_type!='', subscription_type, 'NONE')
    	INTO login, out_memberid, m_email, m_lang, m_active, m_type, m_firstname, m_lastname, m_groupid, m_isgroup, m_subscription
    	FROM member m
    	INNER JOIN def_type t USING (typeid)
    	WHERE m.active IN ("Yes","First")
    	AND m.memberid=in_memberid;

-- no memberid, registration
		IF (ISNULL(out_memberid)) THEN
			INSERT INTO mem_github (memberid, id, login, name, bio, company, url, repos_url, html_url, email, access_token) VALUES (in_memberid, in_id, in_gitlogin, in_name, in_bio, in_company, in_url, in_repos_url, in_html_url, in_email, in_access_token);
			INSERT INTO member (memberid, login, active, typeid, groupid, email, firstname, lastname, created) VALUES (in_memberid, in_login, 'Yes', in_typeid, in_memberid, in_email, in_firstname, in_lastname, NOW());
    		SELECT m.login, m.memberid, m.email, t.lang, m.active, t.typeid, m.firstname, m.lastname, m.groupid, IF(m.groupid=m.memberid,1,0), IF(subscription_type!='', subscription_type, 'NONE')
    		INTO login, out_memberid, m_email, m_lang, m_active, m_type, m_firstname, m_lastname, m_groupid, m_isgroup, m_subscription
    		FROM member m
    		INNER JOIN def_type t USING (typeid)
    		WHERE m.active IN ("Yes","First")
    		AND m.memberid=in_memberid;
		END IF;
   END IF;
END~
DELIMITER ;
