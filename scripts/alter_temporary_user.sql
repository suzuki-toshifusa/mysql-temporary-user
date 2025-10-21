USE admin_tmpuser;

DELIMITER $$

DROP PROCEDURE IF EXISTS alter_temporary_user $$
CREATE PROCEDURE alter_temporary_user(
    IN  p_username VARCHAR(32),
    IN  p_hostname VARCHAR(255),
    IN  p_rolename VARCHAR(32),
    IN  p_hours    INT
)
SQL SECURITY DEFINER
BEGIN
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
    IF p_hours < 0 OR p_hours > 99 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Please specify the usage hours between 0 and 99 hours.';
    END IF;

    -- 既存ユーザーの存在チェック
    IF NOT EXISTS (
        SELECT 1 FROM admin_tmpuser.leases
        WHERE username = p_username
          AND hostname = p_hostname
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The specified username and host combination does not exist.';
    END IF;

    -- トランザクション開始
    START TRANSACTION;

    -- "'user'@'host'" を安全に構築
    SET v_userhost_lit = CONCAT(QUOTE(p_username), '@', QUOTE(p_hostname));
    -- ロール名は識別子クオート
    SET v_role_quoted  = CONCAT('`', REPLACE(p_rolename,'`','``'), '`');

    -- GRANT（新しいロールを付与）
    SET @sql = CONCAT('GRANT ', v_role_quoted, ' TO ', v_userhost_lit);
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    -- DEFAULT ROLE ALL（すべてのロールを有効化）
    SET @sql = CONCAT('SET DEFAULT ROLE ALL TO ', v_userhost_lit);
    PREPARE stmt FROM @sql;
    SET v_stmt_prepared = TRUE;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET v_stmt_prepared = FALSE;

    -- leases テーブルを更新
    UPDATE admin_tmpuser.leases
    SET rolename = p_rolename,
        expires_at = expires_at + INTERVAL p_hours HOUR,
        updated_at = CURRENT_TIMESTAMP
    WHERE username = p_username
      AND hostname = p_hostname;

    -- トランザクションコミット
    COMMIT;

    -- 戻り値（延長後の有効期限を取得）
    SELECT p_username AS username,
           p_hostname AS hostname,
           p_rolename AS rolename,
           p_hours    AS extended_hours,
           (SELECT expires_at FROM admin_tmpuser.leases
            WHERE username = p_username AND hostname = p_hostname) AS new_expires_at;
END $$
DELIMITER ;
