# mysql-temporary-user

MySQLで一時的なユーザーアカウントを作成・管理するためのスクリプト集です。指定した有効期限付きでユーザーを作成し、期限切れのアカウントを自動的にクリーンアップします。

## 機能

- **一時ユーザーの作成**: 有効期限とロールを指定してユーザーを作成
- **期限延長・ロール追加**: 既存ユーザーの有効期限延長や別のロールの付与
- **ユーザー削除**: 手動での一時ユーザー削除
- **自動クリーンアップ**: 1分間隔で期限切れユーザーを自動削除

## 前提条件

- MySQL 8.0 以上
- Aurora MySQL 3 以上
- `event_scheduler`が有効であること（自動クリーンアップに必要）

```sql
-- イベントスケジューラの確認
SHOW VARIABLES LIKE 'event_scheduler';

-- 有効化（必要な場合）
SET GLOBAL event_scheduler = ON;
```
## 注意点

MySQLの仕様上、GRANTやDROP USERを行っても、既にログイン中のセッションには反映されません。
このため、クリーンアップ処理の中でユーザーセッションをKILLしています。

この動作が不要な場合は、drop_temporary_user プロシージャーを改修してください。

## 環境設定

### 環境変数ファイルの準備

Dockerを利用してスクリプトの動作確認をする際は、環境変数ファイルを設定してください。

```bash
# .env.exampleをコピーして.envを作成
cp .env.example .env

# .envファイルを編集してパスワードなどを設定
```

`.env`ファイルの設定例：

```env
MYSQL_VERSION=8.0
CONTAINER_NAME=mysql_db
HOSTNAME=mysql-db
ROOT_PASS=secure_root_password_here
DB_NAME=test
DB_USER=test
DB_PASS=secure_db_password_here
DB_PORT=3306
TZ=Asia/Tokyo
```

## セットアップ手順

以下の順序でスクリプトを実行してください。

### 1. ロールの作成（必須）

**重要**: 一時ユーザーを作成する前に、付与するロールを事前に作成する必要があります。

```bash
mysql -u root -p < scripts/create_role.sql
```

このスクリプトで以下のロールが作成されます：

- `role_test_read_data`: 読み取り専用（SELECT, SHOW VIEW）
- `role_test_read_write_data`: 読み書き可能（SELECT, SHOW VIEW, INSERT, UPDATE, DELETE）
- `role_test_owner`: 全権限（ALL）

#### ロールの設計

ロールの考え方は次の二種類があります。

1. ロールを組み合わせて利用する
1. 複数の権限を統合したロールを利用する

このスクリプトではロール付与を簡便化するため、複数の権限を統合したロールを作成しています。
読み書きを行いたい場合、読み取り専用権限と書き込み専用権限を用意して両方を付与するのではなく、読み書き権限を付与します。
また、DDLを実行したい場合は、データベースに関する全権限を付与したロールを付与します。

#### ロールのスコープ

大まかに次のスコープがあります。

1. サーバー全体 
1. 特定データベース

このスクリプトのロールは、特定データベースに対するロールになっています。
`test.*` の部分を、適用するデータベース名に変更して利用してください。
サーバー全体の権限を付与したい場合は、 `*.*` に変更して下さい。


```SQL
GRANT SELECT, SHOW VIEW ON test.* TO role_test_read_data;
```

#### ロールのネーミングルール

このスクリプトでは、次のようなネーミングルールにしています。  
MySQLではロールは `mysql.user` に格納され、ユーザーとロールの区別がつきにくいです。  
このため接頭辞を付けることを推奨します。

```
<接頭辞（role）>_<データベース名>_<ロール名>
```

### 2. 管理データベースと管理テーブルの作成

```bash
mysql -h 127.0.0.1 -u root -p < scripts/admin_temp_user_leases.sql
```

`admin_tmpuser` データベースと、一時ユーザーのリース情報を管理する `leases` テーブルを作成します。

### 3. ストアドプロシージャのインストール

```bash
# ユーザー作成プロシージャ
mysql -h 127.0.0.1 -u root -p < scripts/create_temporary_user.sql

# ユーザー更新プロシージャ
mysql -h 127.0.0.1 -u root -p < cripts/alter_temporary_user.sql

# ユーザー削除プロシージャ
mysql -h 127.0.0.1 -u root -p < scripts/drop_temporary_user.sql
```

### 4. 自動クリーンアップイベントのインストール

```bash
mysql -h 127.0.0.1 -u root -p < scripts/ev_tmpuser_cleanup.sql
```

期限切れユーザーを1分ごとに自動削除するイベントを作成します。

## 使用方法

### 一時ユーザーの作成

```sql
CALL create_temporary_user('username', 'hostname', 'rolename', hours);
```

**パラメータ**:
- `username`: ユーザー名（VARCHAR(32)）
- `hostname`: ホスト名（VARCHAR(255)、例: '%', 'localhost', '192.168.1.%'）
- `rolename`: 付与するロール名（事前作成が必要）
- `hours`: 有効時間（0〜99時間）

**例**:
```sql
-- 1時間有効な読み取り専用ユーザーを作成
CALL create_temporary_user('suzukito', '%', 'role_test_read_data', 1);

-- 返り値にはユーザー名、ホスト名、パスワード、有効時間が含まれます
```

### 期限延長・ロール追加

```sql
CALL alter_temporary_user('username', 'hostname', 'rolename', hours);
```

**機能**:
- 既存ユーザーの有効期限を延長
- 新しいロールを追加（既存のロールは維持）
- DEFAULT ROLE ALLを設定（すべてのロールを有効化）

**例**:
```sql
-- 有効期限を1時間延長
CALL alter_temporary_user('suzukito', '%', 'role_test_read_data', 1);

-- 書き込みロールを追加（有効期限の延長はしない）
CALL alter_temporary_user('suzukito', '%', 'role_test_write_data', 0);
```

### ユーザー削除

```sql
CALL drop_temporary_user('username', 'hostname');
```

**例**:
```sql
-- ユーザーを手動で削除
CALL drop_temporary_user('suzukito', '%');
```

### リース情報の確認

```sql
-- 全ての一時ユーザーを確認
SELECT * FROM admin_tmpuser.admin_temp_user_leases;

-- 特定ユーザーの権限を確認
SHOW GRANTS FOR 'username'@'hostname';
```

## テスト手順

`test.sql`を使用して、各機能の動作確認ができます。

**テスト内容**:

1. **create_temporary_user のテスト**:
   - 時間範囲外のエラー（100時間、0時間）
   - 存在しないロールのエラー
   - 正常なユーザー作成
   - 重複エラー
   - 期限切れ後の自動削除確認

2. **alter_temporary_user のテスト**:
   - 期限延長
   - ロール追加

3. **drop_temporary_user のテスト**:
   - 存在しないユーザーの削除エラー
   - 正常な削除

## データベーステーブル

### admin_temp_user_leases

一時ユーザーのリース情報を管理するテーブル。

| カラム名 | 型 | 説明 |
|---------|-----|------|
| username | VARCHAR(32) | ユーザー名（主キー） |
| hostname | VARCHAR(255) | ホスト名（主キー） |
| rolename | VARCHAR(32) | 付与されているロール名 |
| expires_at | DATETIME | 有効期限 |
| created_at | DATETIME | 作成日時 |
| updated_at | DATETIME | 更新日時 |

## セキュリティと注意事項

### セキュリティ

- **パスワード生成**: 24バイトのランダムなバイトをBase64エンコードして生成（強度十分）
- **SQLインジェクション対策**: すべての動的SQLでプリペアドステートメントを使用
- **トランザクション管理**: 各操作はトランザクション内で実行され、エラー時は自動ロールバック
- **SQL SECURITY DEFINER**: プロシージャは定義者権限で実行
- **管理データの分離**: 
  - 管理テーブル (`admin_temp_user_leases`) は専用データベース (`admin_tmpuser`) に格納
  - 一時ユーザーは `admin_tmpuser` データベースにアクセスできないため、自分の有効期限やリース情報を改ざんできない
  - 一時ユーザーは ロールで指定されたデータベースのみにアクセス可能

### 運用上の注意

1. **ロールの事前作成必須**: `create_temporary_user`を実行する前に、付与するロールを作成してください
2. **event_scheduler**: 自動クリーンアップには`event_scheduler = ON`が必要です
3. **有効時間の範囲**: 1〜99時間の範囲で指定してください
4. **クリーンアップ頻度**: イベントは1分ごとに実行されます（調整可能）
5. **ロールの変更**: `alter_temporary_user`はロールを追加しますが、既存のロールは削除しません

### エラーハンドリング

各プロシージャは以下のケースでエラーを返します：

- **create_temporary_user**:
  - 有効時間が1〜99時間の範囲外
  - 同じユーザー名とホスト名の組み合わせが既に存在
  - 指定されたロールが存在しない

- **alter_temporary_user**:
  - 有効時間が0〜99時間の範囲外
  - 指定されたユーザーが存在しない
  - 指定されたロールが存在しない

- **drop_temporary_user**:
  - 指定されたユーザーが存在しない
