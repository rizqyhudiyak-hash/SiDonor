<?php
// Smoke test: the main route must render the donor-coordination application, not a document outline.
$entry = __DIR__ . '/../index.php';
if (!is_file($entry)) {
    fwrite(STDERR, "FAIL: main entry point index.php is missing\n");
    exit(1);
}

$_GET = [];
$_POST = [];
ob_start();
require $entry;
$html = ob_get_clean();

$required = [
    'SiDonor',
    'Dashboard operasional',
    'Permintaan donor',
    'Data pendonor',
    'Kegiatan donor',
    'Tampilan mahasiswa',
    'Data simulasi',
    'Skrining mandiri',
    'Belum terhubung',
    'Keputusan akhir tetap dilakukan petugas UDD PMI',
];

foreach ($required as $text) {
    if (stripos($html, $text) === false) {
        fwrite(STDERR, "FAIL: missing application UI content: {$text}\n");
        exit(1);
    }
}

if (stripos($html, 'Outline final untuk memisahkan') !== false) {
    fwrite(STDERR, "FAIL: main route still shows the PRD/SRS outline page\n");
    exit(1);
}

if (stripos($html, 'nomor WhatsApp') !== false || stripos($html, '0812') !== false) {
    fwrite(STDERR, "FAIL: dashboard must not expose donor contact details in demo data\n");
    exit(1);
}

fwrite(STDOUT, "PASS: main route renders the SiDonor operational app shell with safety notices.\n");
