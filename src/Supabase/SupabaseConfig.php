<?php
namespace SiDonor\Supabase;

use RuntimeException;

final class SupabaseConfig
{
    public static function load(?string $projectRoot = null): array
    {
        $projectRoot ??= dirname(__DIR__, 2);
        $configPath = rtrim($projectRoot, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'config' . DIRECTORY_SEPARATOR . 'supabase.local.php';
        if (!is_file($configPath)) {
            throw new RuntimeException('Supabase is not configured. Copy config/supabase.local.php.example to config/supabase.local.php and add the publishable key.');
        }

        $config = require $configPath;
        if (!is_array($config)) {
            throw new RuntimeException('Supabase local config must return an array.');
        }
        foreach (['https://xntitudhvosktvdaswqk.supabase.co', 'sb_publishable_tOIWvuU7rWzQqb-8QRm6kw_2dQYpL9s'] as $required) {
            if (!isset($config[$required]) || !is_string($config[$required]) || trim($config[$required]) === '') {
                throw new RuntimeException('Missing Supabase configuration value: ' . $required);
            }
        }
        if (str_contains($config['sb_publishable_tOIWvuU7rWzQqb-8QRm6kw_2dQYpL9s'], 'REPLACE_WITH_')) {
            throw new RuntimeException('Replace the placeholder publishable key in config/supabase.local.php.');
        }

        return $config;
    }
}
