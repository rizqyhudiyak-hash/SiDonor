<?php
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/../src/Supabase/SupabaseException.php';
require __DIR__ . '/../src/Supabase/SupabaseClient.php';
require __DIR__ . '/../src/Supabase/SupabaseConfig.php';

use SiDonor\Supabase\SupabaseClient;
use SiDonor\Supabase\SupabaseConfig;
use SiDonor\Supabase\SupabaseException;

try {
    $config = SupabaseConfig::load(dirname(__DIR__));
    $client = new SupabaseClient(
        $config['project_url'],
        $config['publishable_key'],
        null,
        (int)($config['max_read_retries'] ?? 2),
        (int)($config['retry_base_ms'] ?? 250)
    );
    $result = $client->healthCheck();
    fwrite(STDOUT, 'Connected to Supabase Auth health endpoint (HTTP ' . $result['status'] . ').' . PHP_EOL);
    exit(0);
} catch (SupabaseException $exception) {
    fwrite(STDERR, 'Supabase connection check failed. HTTP ' . $exception->getHttpStatus() . '; retryable=' . ($exception->isRetryable() ? 'yes' : 'no') . '.' . PHP_EOL);
    exit(1);
} catch (Throwable $exception) {
    fwrite(STDERR, $exception->getMessage() . PHP_EOL);
    exit(2);
}
