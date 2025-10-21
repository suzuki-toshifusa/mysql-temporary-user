/*
  admin_tmpuser.create_temporary_user テスト用SQL
*/
USE admin_tmpuser;

-- 時間が範囲外
CALL admin_tmpuser.create_temporary_user('suzukito', '%', 'role_test_read_data', 100);
CALL admin_tmpuser.create_temporary_user('suzukito', '%', 'role_test_read_data', 0);

-- 存在しないロール
CALL admin_tmpuser.create_temporary_user('suzukito', '%', 'role_not_exists', 1);

-- 正常登録
CALL admin_tmpuser.create_temporary_user('suzukito', '%', 'role_test_read_data', 1);

-- 登録確認
SELECT * FROM admin_tmpuser.leases;
show grants for suzukito@'%';

-- 重複エラー
CALL admin_tmpuser.create_temporary_user('suzukito', '%', 'role_test_read_data', 1);

-- 登録確認
SELECT * FROM admin_tmpuser.leases;

-- 期限切れに変更
UPDATE admin_tmpuser.leases
  SET expires_at = NOW() - INTERVAL 1 MINUTE
WHERE username='suzukito';

-- 数分後、イベントによりREVOKE + DROP USERが実施される
SELECT * FROM admin_tmpuser.leases WHERE username='suzukito';

/* 
  admin_tmpuser.alter_temporary_user テスト用SQL
*/ 

-- 期限延長
SELECT * FROM admin_tmpuser.leases;
CALL admin_tmpuser.alter_temporary_user('suzukito', '%', 'role_test_read_data', 1);
SELECT * FROM admin_tmpuser.leases;
show grants for suzukito@'%';

-- 権限追加付与（期限延長はしない）
SELECT * FROM admin_tmpuser.leases;
CALL admin_tmpuser.alter_temporary_user('suzukito', '%', 'role_test_read_write_data', 0);
SELECT * FROM admin_tmpuser.leases;

/* 
  admin_tmpuser.drop_temporary_user テスト用SQL
*/ 

-- 存在しないユーザー削除
CALL admin_tmpuser.drop_temporary_user('test_user', '%');
SELECT * FROM admin_tmpuser.leases;

-- ユーザー削除
CALL admin_tmpuser.drop_temporary_user('suzukito', '%');
SELECT * FROM admin_tmpuser.leases;
