-- 読み取り用ロール作成スクリプト
DROP ROLE IF EXISTS role_test_read_data;
CREATE ROLE IF NOT EXISTS role_test_read_data;
GRANT SELECT, SHOW VIEW ON test.* TO role_test_read_data;

-- 読み書き用ロール作成スクリプト
DROP ROLE IF EXISTS role_test_read_write_data;
CREATE ROLE IF NOT EXISTS role_test_read_write_data;
GRANT SELECT, SHOW VIEW, INSERT, UPDATE, DELETE ON test.* TO role_test_read_write_data;

-- DB所有者用ロール作成スクリプト
DROP ROLE IF EXISTS role_test_owner;
CREATE ROLE IF NOT EXISTS role_test_owner;
GRANT ALL ON test.* TO role_test_owner;