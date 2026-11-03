<?php
require __DIR__ . '/../src/Supabase/SupabaseClient.php';
require __DIR__ . '/../src/Supabase/SupabaseException.php';

use SiDonor\Supabase\SupabaseClient;
use SiDonor\Supabase\SupabaseException;

function expect(bool $condition, string $message): void
{
    if (!$condition) {
        fwrite(STDERR, "FAIL: {$message}\n");
        exit(1);
    }
}

$attempts = 0;
$seen = [];
$transport = function (string $method, string $url, array $headers, ?string $body, int $connectTimeout, int $timeout) use (&$attempts, &$seen): array {
    $attempts++;
    $seen = compact('method', 'url', 'headers', 'body', 'connectTimeout', 'timeout');
    if ($attempts === 1) {
        return ['status' => 503, 'body' => '{"message":"temporary"}', 'headers' => []];
    }
    return ['status' => 200, 'body' => '{"ok":true}', 'headers' => ['content-type' => 'application/json']];
};
$client = new SupabaseClient('https://example-project.supabase.co', 'sb_publishable_test', $transport, 2, 0);
$result = $client->request('GET', '/auth/v1/health', [], null, 'user-access-token');
expect($attempts === 2, 'safe GET should retry one transient 503');
expect($result['status'] === 200 && $result['data']['ok'] === true, 'successful JSON response should decode');
expect($seen['url'] === 'https://example-project.supabase.co/auth/v1/health', 'request URL should use the configured project origin');
$normalizedHeaders = array_change_key_case($seen['headers'], CASE_LOWER);
expect(($normalizedHeaders['apikey'] ?? null) === 'sb_publishable_test', 'publishable key must be sent as apikey');
expect(($normalizedHeaders['authorization'] ?? null) === 'Bearer user-access-token', 'user JWT should be forwarded for RLS');

$postAttempts = 0;
$postTransport = function () use (&$postAttempts): array {
    $postAttempts++;
    return ['status' => 503, 'body' => '{"message":"temporary"}', 'headers' => []];
};
$postClient = new SupabaseClient('https://example-project.supabase.co', 'sb_publishable_test', $postTransport, 2, 0);
try {
    $postClient->request('POST', '/rest/v1/profiles', [], ['full_name' => 'Demo']);
    expect(false, 'transient POST should raise an exception');
} catch (SupabaseException $exception) {
    expect($postAttempts === 1, 'writes must not be blindly retried and risk duplicate records');
}

fwrite(STDOUT, "PASS: Supabase client retries safe reads, forwards RLS identity, and never blindly retries writes.\n");
