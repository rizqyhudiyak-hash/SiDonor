<?php
$schemaPath = __DIR__ . '/../database/migrations/20261102_001_initial_schema.sql';
if (!is_file($schemaPath)) {
    fwrite(STDERR, "FAIL: initial Supabase schema migration is missing\n");
    exit(1);
}
$sql = file_get_contents($schemaPath);
$required = [
    'public.profiles', 'public.donor_profiles', 'public.private_contacts',
    'public.consents', 'public.screening_records', 'public.blood_requests',
    'public.request_candidates', 'public.donor_history', 'public.donor_activities',
    'public.activity_registrations', 'public.app_settings', 'public.admin_audit_log',
    'ENABLE ROW LEVEL SECURITY', 'get_accepted_donor_contact',
    'respond_to_candidate', 'withdraw_consent', 'Southeast Asia',
];
foreach ($required as $needle) {
    if (stripos($sql, $needle) === false) {
        fwrite(STDERR, "FAIL: schema missing required item: {$needle}\n");
        exit(1);
    }
}
if (stripos($sql, 'service_role') !== false || stripos($sql, 'SUPABASE_SERVICE_ROLE_KEY') !== false) {
    fwrite(STDERR, "FAIL: service-role secrets must never be embedded in migrations\n");
    exit(1);
}
fwrite(STDOUT, "PASS: schema contract covers donor workflows, RLS, and protected admin functions.\n");
