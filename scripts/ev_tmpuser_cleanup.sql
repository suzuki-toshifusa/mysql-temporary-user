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

    -- 一時ユーザー削除プロシージャを呼び出し
    CALL admin_tmpuser.drop_temporary_user(v_username, v_hostname);

  END LOOP;
  CLOSE cur;
END $$
DELIMITER ;
