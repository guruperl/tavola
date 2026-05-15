CREATE PROCEDURE proc_jenny_a (
IN i_login VARCHAR(255), IN i_passwd VARCHAR(255), IN i_ip INT unsigned,
OUT out_id INT unsigned, OUT out_login VARCHAR(255),
OUT out_firstname varchar(255), OUT out_lastname VARCHAR(255))
BEGIN
  DECLARE c1 INT;
  DECLARE c2 INT;
  SELECT COUNT(*) INTO c1 FROM tavola_login_a_tavola_ip WHERE ret='fail' AND ip=i_ip AND login=i_login AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-3600));
  SELECT COUNT(*) INTO c2 FROM tavola_login_a_tavola_ip WHERE ret='fail' AND ip=i_ip AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-24*3600));
  IF (c1<=5 AND c2<=20) THEN
    SELECT a_id, email, firstname, lastname INTO out_id, out_login, out_firstname, out_lastname
    FROM tavola_login_a
    WHERE status IN ("Yes")
AND email =i_login
AND passwd=SHA1(concat(i_login, i_passwd));

    IF ISNULL(out_id) THEN
      INSERT INTO tavola_login_a_tavola_ip (ip,login,ret) VALUES (i_ip,i_login,'fail');
    ELSE
      DELETE FROM tavola_login_a_tavola_ip WHERE ret='fail' AND ip=i_ip AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-24*3600));
      INSERT INTO tavola_login_a_tavola_ip (ip,login,ret) VALUES (i_ip,i_login,'success');
    END IF;
  ELSE
    SELECT '1030' INTO out_id;
  END IF;
END
