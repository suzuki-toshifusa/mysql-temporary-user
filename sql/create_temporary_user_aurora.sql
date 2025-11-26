-- ロールも作らず、ユーザー作成、権限付与、イベント作成もシンプルに行うSQL
-- 修正箇所：ユーザー名、イベント名

-- ユーザー作成
CREATE USER IF NOT EXISTS 'suzukito'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';

-- 権限付与
GRANT ALL ON test.* TO 'suzukito'@'%';

-- イベント作成
DELIMITER $$

CREATE EVENT `ev_tmpuser_expire_suzukito`
  ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 5 MINUTE
  ON COMPLETION NOT PRESERVE
  DO
  BEGIN
    DECLARE v_process_id BIGINT;
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE cur_processes CURSOR FOR 
        SELECT id FROM information_schema.processlist 
        WHERE user = 'suzukito';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- アクティブセッションを終了
    OPEN cur_processes;
    kill_loop: LOOP
        FETCH cur_processes INTO v_process_id;
        IF v_done THEN
            LEAVE kill_loop;
        END IF;
        
        -- エラーが出ても続行
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;
            CALL mysql.rds_kill(v_process_id);
        END;
    END LOOP;
    CLOSE cur_processes;

    -- 全セッション終了後にユーザー削除
    DROP USER IF EXISTS 'suzukito'@'%';
  END
$$
DELIMITER ;

-- イベントの確認
SELECT * FROM information_schema.events\G