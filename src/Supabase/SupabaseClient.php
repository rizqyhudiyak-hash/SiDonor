<?php
namespace SiDonor\Supabase;

use InvalidArgumentException;
use RuntimeException;

/** Minimal server-side Supabase REST/Auth client using only a publishable/anon key plus an optional user JWT. */
final class SupabaseClient
{
    /** @var callable|null Test seam: fn(method, url, headers, body, connectTimeout, timeout): array */
    private $transport;
    private string $projectUrl;
    private string $publishableKey;
    private int $maxReadRetries;
    private int $retryBaseMs;

    public function __construct(
        string $projectUrl,
        string $publishableKey,
        ?callable $transport = null,
        int $maxReadRetries = 2,
        int $retryBaseMs = 250
    ) {
        $parts = parse_url(trim($projectUrl));
        if (!is_array($parts) || empty($parts['scheme']) || empty($parts['host'])) {
            throw new InvalidArgumentException('Supabase project URL is invalid.');
        }
        $isLocal = in_array(strtolower($parts['host']), ['localhost', '127.0.0.1'], true);
        if ($parts['scheme'] !== 'https' && !($isLocal && $parts['scheme'] === 'http')) {
            throw new InvalidArgumentException('Supabase URL must use HTTPS.');
        }
        if (isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment'])) {
            throw new InvalidArgumentException('Supabase URL must be an origin, without credentials, query, or fragment.');
        }
        if (trim($publishableKey) === '' || self::isServiceRoleKey(trim($publishableKey))) {
            throw new InvalidArgumentException('Use the Supabase publishable/anon key, never the service_role key.');
        }
        if ($maxReadRetries < 0 || $maxReadRetries > 3 || $retryBaseMs < 0 || $retryBaseMs > 2000) {
            throw new InvalidArgumentException('Retry settings are outside the allowed bounds.');
        }

        $this->projectUrl = rtrim(trim($projectUrl), '/');
        $this->publishableKey = trim($publishableKey);
        $this->transport = $transport;
        $this->maxReadRetries = $maxReadRetries;
        $this->retryBaseMs = $retryBaseMs;
    }

    /** @return array{status:int,data:mixed,headers:array<string,string>} */
    public function request(
        string $method,
        string $path,
        array $query = [],
        ?array $jsonBody = null,
        ?string $userAccessToken = null,
        array $extraHeaders = []
    ): array {
        $method = strtoupper(trim($method));
        if (!in_array($method, ['GET', 'HEAD', 'POST', 'PATCH', 'PUT', 'DELETE'], true)) {
            throw new InvalidArgumentException('Unsupported HTTP method.');
        }
        $path = $this->normalizePath($path);
        $url = $this->projectUrl . '/' . $path;
        if ($query !== []) {
            $url .= '?' . http_build_query($query, '', '&', PHP_QUERY_RFC3986);
        }

        $headers = [
            'apikey' => $this->publishableKey,
            'accept' => 'application/json',
        ];
        if ($userAccessToken !== null && trim($userAccessToken) !== '') {
            $headers['authorization'] = 'Bearer ' . trim($userAccessToken);
        }
        if ($jsonBody !== null) {
            $headers['content-type'] = 'application/json';
        }
        foreach ($extraHeaders as $name => $value) {
            $normalized = strtolower(trim((string)$name));
            $value = (string)$value;
            if (!preg_match('/^[a-z0-9-]+$/D', $normalized) || preg_match('/[\r\n]/', $value)) {
                throw new InvalidArgumentException('Invalid extra HTTP header.');
            }
            if (in_array($normalized, ['apikey', 'authorization', 'host'], true)) {
                throw new InvalidArgumentException('Authentication and host headers are managed by the client.');
            }
            $headers[$normalized] = $value;
        }

        $body = null;
        if ($jsonBody !== null) {
            $body = json_encode($jsonBody, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        }

        $safeRead = in_array($method, ['GET', 'HEAD'], true);
        $attemptLimit = $safeRead ? $this->maxReadRetries + 1 : 1;
        $lastResult = null;
        for ($attempt = 0; $attempt < $attemptLimit; $attempt++) {
            $result = $this->send($method, $url, $headers, $body);
            $lastResult = $result;
            $status = (int)($result['status'] ?? 0);
            $retryable = $this->isTransient($status, $result['error'] ?? null);
            if ($status >= 200 && $status < 300) {
                $responseBody = (string)($result['body'] ?? '');
                if ($responseBody === '') {
                    $data = null;
                } else {
                    $data = json_decode($responseBody, true);
                    if (json_last_error() !== JSON_ERROR_NONE) {
                        $data = $responseBody;
                    }
                }
                return ['status' => $status, 'data' => $data, 'headers' => $result['headers'] ?? []];
            }

            if (!$safeRead || !$retryable || $attempt + 1 >= $attemptLimit) {
                $message = $status > 0
                    ? 'Supabase request failed with HTTP ' . $status . '.'
                    : 'Supabase could not be reached. Check the network and server configuration.';
                throw new SupabaseException($message, $status, $retryable);
            }
            $this->pauseBeforeRetry($attempt, $result['headers'] ?? []);
        }

        $status = (int)($lastResult['status'] ?? 0);
        throw new SupabaseException('Supabase request failed.', $status, $this->isTransient($status, $lastResult['error'] ?? null));
    }

    /** Safe, read-only probe used by the CLI setup check. */
    public function healthCheck(): array
    {
        return $this->request('GET', 'auth/v1/health');
    }

    private function normalizePath(string $path): string
    {
        $path = ltrim(trim($path), '/');
        if ($path === '' || str_contains($path, '..') || str_contains($path, "\0")) {
            throw new InvalidArgumentException('Supabase API path is invalid.');
        }
        if (!str_starts_with($path, 'rest/v1/') && !str_starts_with($path, 'auth/v1/')) {
            throw new InvalidArgumentException('Only Supabase REST and Auth API paths are allowed.');
        }
        return $path;
    }

    private function send(string $method, string $url, array $headers, ?string $body): array
    {
        if ($this->transport !== null) {
            return ($this->transport)($method, $url, $headers, $body, 5, 15);
        }
        if (!function_exists('curl_init')) {
            throw new RuntimeException('PHP cURL extension is required to connect to Supabase.');
        }

        $curlHeaders = [];
        foreach ($headers as $name => $value) {
            $curlHeaders[] = $name . ': ' . $value;
        }
        $responseHeaders = [];
        $handle = curl_init($url);
        if ($handle === false) {
            return ['status' => 0, 'body' => '', 'headers' => [], 'error' => 'curl_init_failed'];
        }
        $options = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $curlHeaders,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_HEADERFUNCTION => static function ($curl, string $line) use (&$responseHeaders): int {
                $length = strlen($line);
                $parts = explode(':', $line, 2);
                if (count($parts) === 2) {
                    $responseHeaders[strtolower(trim($parts[0]))] = trim($parts[1]);
                }
                return $length;
            },
        ];
        if ($body !== null) {
            $options[CURLOPT_POSTFIELDS] = $body;
        }
        curl_setopt_array($handle, $options);
        $responseBody = curl_exec($handle);
        $errorCode = curl_errno($handle);
        $status = (int)curl_getinfo($handle, CURLINFO_HTTP_CODE);
        curl_close($handle);

        return [
            'status' => $status,
            'body' => is_string($responseBody) ? $responseBody : '',
            'headers' => $responseHeaders,
            'error' => $errorCode === 0 ? null : 'curl_error_' . $errorCode,
        ];
    }

    private function isTransient(int $status, ?string $error): bool
    {
        return $error !== null || in_array($status, [0, 408, 425, 429, 502, 503, 504], true);
    }

    private function pauseBeforeRetry(int $attempt, array $headers): void
    {
        $retryAfter = (int)($headers['retry-after'] ?? 0);
        $delayMs = $retryAfter > 0 ? min($retryAfter * 1000, 2000) : $this->retryBaseMs * (2 ** $attempt);
        if ($delayMs > 0) {
            usleep($delayMs * 1000);
        }
    }

    private static function isServiceRoleKey(string $key): bool
    {
        if (str_starts_with($key, 'sb_secret_')) {
            return true;
        }
        $parts = explode('.', $key);
        if (count($parts) === 3) {
            $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')) ?: '', true);
            return is_array($payload) && ($payload['role'] ?? null) === 'service_role';
        }
        return false;
    }
}
