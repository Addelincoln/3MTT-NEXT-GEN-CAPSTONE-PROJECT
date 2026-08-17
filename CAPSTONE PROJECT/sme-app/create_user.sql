CREATE USER 'sme_app_user'@'localhost' IDENTIFIED BY 'ChangeMe123!';
GRANT ALL PRIVILEGES ON sme_app.* TO 'sme_app_user'@'localhost';
FLUSH PRIVILEGES;
