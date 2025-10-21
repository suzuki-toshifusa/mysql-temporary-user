USE admin_tmpuser;

DELIMITER $$

DROP PROCEDURE IF EXISTS create_temporary_user $$
CREATE PROCEDURE create_temporary_user(
    IN  p_username VARCHAR(32),
    IN  p_hostname VARCHAR(255),
    IN  p_rolename VARCHAR(32),
    IN  p_hours    INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_password     VARCHAR(128);
    DECLARE v_userhost_lit VARCHAR(300);
    DECLARE v_role_quoted  VARCHAR(100);
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

    -- 入力値検証
    IF p_hours < 1 OR p_hours > 99 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Please specify the usage hours between 1 and 99 hours.';
    END IF;

    -- 同一ユーザーの存在チェック
    IF EXISTS (
        SELECT 1 FROM admin_tmpuser.leases
        WHERE username = p_username
          AND hostname = p_hostname
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified username and hostname combination already exist.';
    END IF;

    -- ロールの存在チェック
    IF NOT EXISTS (
        SELECT 1 FROM mysql.user
        WHERE user = p_rolename
          AND host = '%'
          AND account_locked = 'Y'
          AND authentication_string = ''
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified role does not exist.';
    END IF;

    -- トランザクション開始
    START TRANSACTION;

    -- "'user'@'host'" を安全に構築
    SET v_userhost_lit = CONCAT(QUOTE(p_username), '@', QUOTE(p_hostname));
    -- ロール名は識別子クオート
    SET v_role_quoted  = CONCAT('`', REPLACE(p_rolename,'`','``'), '`');

    -- 強度十分な乱数パスワード（Base64から/=を除去）
    SET v_password = REPLACE(REPLACE(TO_BASE64(RANDOM_BYTES(24)), '/', ''), '=', '');
    
    -- CREATE USER
    SET @sql = CONCAT('CREATE USER IF NOT EXISTS ', v_userhost_lit, ' IDENTIFIED BY ', QUOTE(v_password));
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    -- GRANT
    SET @sql = CONCAT('GRANT ', v_role_quoted, ' TO ', v_userhost_lit);
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    -- DEFAULT ROLE ALL
    SET @sql = CONCAT('SET DEFAULT ROLE ALL TO ', v_userhost_lit);
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    INSERT INTO admin_tmpuser.leases (username, hostname, rolename, expires_at)
    VALUES (p_username, p_hostname, p_rolename, NOW() + INTERVAL p_hours HOUR);

    -- トランザクションコミット
    COMMIT;

    -- 戻り値
    SELECT p_username AS username,
           p_hostname AS hostname,
           v_password AS password,
           p_hours    AS available_hours,
           (SELECT expires_at FROM admin_tmpuser.leases
            WHERE username = p_username AND hostname = p_hostname) AS expires_at;
END $$
DELIMITER ;
