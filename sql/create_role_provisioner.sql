CREATE ROLE `role_provisioner`;
GRANT ALL ON `subscription`.* TO `role_provisioner` WITH GRANT OPTION;
GRANT PROCESS, CREATE USER ON *.* TO `role_provisioner`;
GRANT EXECUTE ON PROCEDURE `mysql`.`rds_kill` TO `role_provisioner`;