-- 管理用データベースの作成
CREATE DATABASE IF NOT EXISTS admin_tmpuser;
USE admin_tmpuser;

DROP TABLE IF EXISTS leases;
CREATE TABLE IF NOT EXISTS leases (
  username   VARCHAR(32)  NOT NULL,
  hostname   VARCHAR(255) NOT NULL,
  rolename   VARCHAR(32)  NOT NULL,
  expires_at DATETIME     NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (username, hostname),
  KEY ix_expires (expires_at)
);
