<?php
// Smoke-test probe: echoes request facts the test script asserts on.
// Also the rewrite target: /pretty-url rewrites to index.php.
header('Content-Type: text/plain');
echo "PHP_VERSION=" . PHP_VERSION . "\n";
echo "HTTPS=" . ($_SERVER['HTTPS'] ?? '') . "\n";
echo "REMOTE_ADDR=" . ($_SERVER['REMOTE_ADDR'] ?? '') . "\n";
echo "XFF=" . ($_SERVER['HTTP_X_FORWARDED_FOR'] ?? '') . "\n";
echo "XFP=" . ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') . "\n";
echo "PATH=" . ($_SERVER['REQUEST_URI'] ?? '') . "\n";
