-- SME App placeholder schema
-- Run against the sme_app database created by cloud-init.txt

USE sme_app;

CREATE TABLE IF NOT EXISTS inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO inventory (item_name, quantity) VALUES
    ('Sample Widget', 12),
    ('Sample Gadget', 4);
