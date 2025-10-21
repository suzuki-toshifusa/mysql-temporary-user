-- 事前にイベントスケジューラを有効化
-- SET GLOBAL event_scheduler = ON;
USE admin_tmpuser;

DELIMITER $$

DROP EVENT IF EXISTS ev_tmpuser_cleanup $$
CREATE EVENT ev_tmpuser_cleanup
ON SCHEDULE EVERY 1 MINUTE
ON COMPLETION PRESERVE
DO
BEGIN
  DECLARE v_username VARCHAR(32);
  DECLARE v_hostname VARCHAR(255);
  DECLARE v_done BOOL DEFAULT FALSE;

  -- 有効期限切れのユーザーを取得
  DECLARE cur CURSOR FOR
    SELECT username, hostname
      FROM admin_tmpuser.leases
     WHERE expires_at <= NOW();

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_username, v_hostname;
    IF v_done THEN LEAVE read_loop; END IF;

    SET @userhost_lit := CONCAT(QUOTE(v_username), '@', QUOTE(v_hostname));

    -- ユーザーを削除
    SET @sql := CONCAT('DROP USER IF EXISTS ', @userhost_lit);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- leases レコードを削除
    DELETE FROM admin_tmpuser.leases
    WHERE username = v_username AND hostname = v_hostname;

  END LOOP;
  CLOSE cur;
END $$
DELIMITER ;
