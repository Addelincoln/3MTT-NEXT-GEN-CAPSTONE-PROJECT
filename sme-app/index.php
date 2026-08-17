<?php
require __DIR__ . '/config.php';

$error = null;

try {
    $pdo = get_db_connection();

    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['item_name'])) {
        $stmt = $pdo->prepare('INSERT INTO inventory (item_name, quantity) VALUES (?, ?)');
        $stmt->execute([
            trim($_POST['item_name']),
            (int) ($_POST['quantity'] ?? 0),
        ]);
        header('Location: index.php');
        exit;
    }

    $items = $pdo->query('SELECT id, item_name, quantity, updated_at FROM inventory ORDER BY updated_at DESC')->fetchAll();
} catch (PDOException $e) {
    $error = 'Database connection failed: ' . htmlspecialchars($e->getMessage());
    $items = [];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>SME App - Inventory</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 640px; margin: 40px auto; color: #222; }
        h1 { color: #2f5496; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #ddd; }
        th { background: #f2f2f2; }
        form { margin-top: 24px; display: flex; gap: 10px; }
        input[type=text], input[type=number] { padding: 6px 8px; }
        input[type=submit] { background: #2f5496; color: #fff; border: none; padding: 6px 14px; cursor: pointer; }
        .error { background: #fce4d6; padding: 10px; border-radius: 4px; }
        .status { color: #4a4a4a; font-size: 14px; margin-top: 30px; }
    </style>
</head>
<body>
    <h1>SME App &mdash; Inventory</h1>

    <?php if ($error): ?>
        <p class="error"><?= $error ?></p>
    <?php else: ?>
        <table>
            <tr><th>Item</th><th>Quantity</th><th>Last Updated</th></tr>
            <?php foreach ($items as $item): ?>
                <tr>
                    <td><?= htmlspecialchars($item['item_name']) ?></td>
                    <td><?= (int) $item['quantity'] ?></td>
                    <td><?= htmlspecialchars($item['updated_at']) ?></td>
                </tr>
            <?php endforeach; ?>
        </table>

        <form method="post">
            <input type="text" name="item_name" placeholder="Item name" required>
            <input type="number" name="quantity" placeholder="Qty" value="0" min="0">
            <input type="submit" value="Add item">
        </form>
    <?php endif; ?>

    <p class="status">Server: <?= htmlspecialchars($_SERVER['SERVER_ADDR'] ?? 'unknown') ?> &middot; PHP <?= phpversion() ?></p>
</body>
</html>
