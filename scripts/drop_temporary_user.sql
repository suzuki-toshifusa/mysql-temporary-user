USE admin_tmpuser;

DELIMITER $$

DROP PROCEDURE IF EXISTS drop_temporary_user $$
CREATE PROCEDURE drop_temporary_user(
    IN  p_username VARCHAR(32),
    IN  p_hostname VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_userhost_lit VARCHAR(300);
    DECLARE v_stmt_prepared BOOLEAN DEFAULT FALSE;

    -- エラーハンドラ：エラー発生時にロールバックして終了
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- PREPARE文が残っている可能性があるため、安全にクリーンアップ
        IF v_stmt_prepared THEN
            DEALLOCATE PREPARE stmt;
        END IF;
        
        ROLLBACK;
        RESIGNAL;
    END;

    -- 同一ユーザーの存在チェック
    IF NOT EXISTS (
        SELECT 1 FROM admin_tmpuser.leases
        WHERE username = p_username
          AND hostname = p_hostname
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified username and hostname combination does not exist.';
    END IF;

    -- トランザクション開始
    START TRANSACTION;

    -- "'user'@'host'" を安全に構築
    SET v_userhost_lit = CONCAT(QUOTE(p_username), '@', QUOTE(p_hostname));

    -- DROP USER
    SET @sql = CONCAT('DROP USER IF EXISTS ', v_userhost_lit);
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    -- leases テーブルからレコード削除
    DELETE FROM admin_tmpuser.leases
    WHERE username = p_username
      AND hostname = p_hostname;

    -- トランザクションコミット
    COMMIT;

    -- 戻り値
    SELECT p_username AS username,
           p_hostname AS hostname,
           'User deleted successfully' AS message;
END $$
DELIMITER ;
