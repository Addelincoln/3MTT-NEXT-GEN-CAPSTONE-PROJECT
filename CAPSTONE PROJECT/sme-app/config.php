<?php
// Database connection settings.
// This app connects over TCP as a dedicated MySQL user (not root, not azureuser),
// created separately since MySQL's default root account only allows local
// socket auth and azureuser has no MySQL privileges.

define('DB_HOST', '127.0.0.1');
define('DB_NAME', 'sme_app');
define('DB_USER', 'sme_app_user');
define('DB_PASS', 'ChangeMe123!'); // Replace with a real secret before any real deployment

function get_db_connection(): PDO {
    $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4';
    return new PDO($dsn, DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
}
