CREATE USER `provisioner`@`%` IDENTIFIED WITH 'mysql_native_password' BY 'provisioner_password';
GRANT `role_provisioner` TO `provisioner`@`%`;
SET DEFAULT ROLE ALL TO `provisioner`@`%`;
