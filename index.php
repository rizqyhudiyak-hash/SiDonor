<?php
/** SiDonor prototype UI. Demo-only data; no authentication, database, or WhatsApp integration. */
function app_h(string $value): string { return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function app_link(string $role, string $page): string { return 'index.php?' . http_build_query(['role' => $role, 'page' => $page]); }

$role = ($_GET['role'] ?? 'admin') === 'mahasiswa' ? 'mahasiswa' : 'admin';
$adminPages = ['dashboard', 'permintaan', 'pendonor', 'kegiatan', 'laporan'];
$studentPages = ['beranda', 'skrining', 'riwayat'];
$page = (string) ($_GET['page'] ?? ($role === 'admin' ? 'dashboard' : 'beranda'));
$allowedPages = $role === 'admin' ? $adminPages : $studentPages;
if (!in_array($page, $allowedPages, true)) { $page = $role === 'admin' ? 'dashboard' : 'beranda'; }

$dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
$monthNames = [1 => 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
$now = new DateTimeImmutable('now');
$dateLabel = $dayNames[(int)$now->format('w')] . ', ' . $now->format('j') . ' ' . $monthNames[(int)$now->format('n')] . ' ' . $now->format('Y');

$adminNav = [
    ['dashboard', 'Ringkasan', '▦'], ['permintaan', 'Permintaan darah', '＋'],
    ['pendonor', 'Data pendonor', '◎'], ['kegiatan', 'Kegiatan donor', '▣'], ['laporan', 'Rekap & laporan', '▤'],
];
$studentNav = [['beranda', 'Beranda', '⌂'], ['skrining', 'Skrining mandiri', '✓'], ['riwayat', 'Riwayat donor', '◷']];
$navItems = $role === 'admin' ? $adminNav : $studentNav;
$titles = [
    'dashboard' => ['Dashboard operasional', 'Pantau permintaan, kesiapan pendonor, dan tindak lanjut hari ini.'],
    'permintaan' => ['Permintaan darah', 'Tinjau permintaan terverifikasi dan koordinasikan kandidat pendonor.'],
    'pendonor' => ['Data pendonor', 'Cari pendonor yang cocok dan siap. Kontak dilindungi.'],
    'kegiatan' => ['Kegiatan donor', 'Kelola informasi kegiatan dan pendaftaran mahasiswa.'],
    'laporan' => ['Rekap & laporan', 'Ringkasan kegiatan dan hasil koordinasi donor.'],
    'beranda' => ['Halo, Pendonor', 'Status, informasi kegiatan, dan langkah berikutnya untuk akun Anda.'],
    'skrining' => ['Skrining mandiri', 'Tinjau acuan awal sebelum melanjutkan proses donor.'],
    'riwayat' => ['Riwayat donor', 'Lihat riwayat dan perkiraan jeda donor pribadi Anda.'],
];
[$title, $subtitle] = $titles[$page];
$otherRole = $role === 'admin' ? 'mahasiswa' : 'admin';
$otherPage = $role === 'admin' ? 'beranda' : 'dashboard';
?>
<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="SiDonor membantu pendataan dan koordinasi mahasiswa pendonor darah.">
<title><?= app_h($title) ?> — SiDonor</title><link rel="stylesheet" href="assets/css/app.css">
</head>
<body class="app-body">
<a class="skip-link" href="#main-content">Lewati ke konten utama</a>
<div class="app-shell">
<aside class="sidebar" id="sidebar" aria-label="Navigasi utama">
    <a class="brand" href="<?= app_h(app_link($role, $role === 'admin' ? 'dashboard' : 'beranda')) ?>"><span class="brand-mark">S</span><span class="brand-name">SiDonor<span>.</span></span></a>
    <p class="sidebar-caption">SISTEM KOORDINASI PENDONOR</p>
    <div class="role-switcher"><span class="role-avatar"><?= $role === 'admin' ? 'A' : 'M' ?></span><span class="role-copy"><strong><?= $role === 'admin' ? 'Admin KSR' : 'Mahasiswa' ?></strong><small><?= $role === 'admin' ? 'Pengelola kampus' : 'Area pendonor' ?></small></span><span class="role-chevron">⌄</span></div>
    <p class="nav-label">MENU</p><nav class="side-nav">
        <?php foreach ($navItems as [$navPage, $label, $icon]): ?>
        <a class="nav-link<?= $page === $navPage ? ' is-active' : '' ?>" href="<?= app_h(app_link($role, $navPage)) ?>"<?= $page === $navPage ? ' aria-current="page"' : '' ?>><span class="nav-icon" aria-hidden="true"><?= app_h($icon) ?></span><span><?= app_h($label) ?></span></a>
        <?php endforeach; ?>
    </nav>
    <div class="sidebar-spacer"></div>
    <div class="sidebar-safety"><span aria-hidden="true">◇</span><p><strong>Privasi pendonor</strong><br>Kontak dibuka setelah pendonor menyatakan bersedia.</p></div>
    <a class="role-link" href="<?= app_h(app_link($otherRole, $otherPage)) ?>"><span aria-hidden="true">⇄</span><span>Tampilan <?= $role === 'admin' ? 'mahasiswa' : 'admin' ?></span><b>→</b></a>
    <div class="account-row"><span class="account-avatar"><?= $role === 'admin' ? 'AK' : 'MD' ?></span><span class="role-copy"><strong><?= $role === 'admin' ? 'Admin KSR' : 'Mahasiswa Demo' ?></strong><small><?= $role === 'admin' ? 'Universitas Siliwangi' : 'Akun simulasi' ?></small></span><span class="account-more">···</span></div>
</aside>
<div class="main-column">
<header class="topbar"><button class="mobile-menu" type="button" aria-label="Buka navigasi" aria-controls="sidebar" aria-expanded="false">☰</button><div class="breadcrumb"><span>SiDonor</span><span>/</span><strong><?= app_h($title) ?></strong></div><div class="topbar-actions"><span class="demo-badge"><i></i> Data simulasi</span><span class="topbar-date"><?= app_h($dateLabel) ?></span><button class="notification-button" type="button" aria-label="Notifikasi">♧<i></i></button></div></header>
<main class="main-content" id="main-content">
<div class="page-heading"><div><p class="eyebrow"><?= $role === 'admin' ? 'RUANG KERJA ADMIN' : 'AREA MAHASISWA' ?></p><h1><?= app_h($title) ?></h1><p><?= app_h($subtitle) ?></p></div>
<?php if ($role === 'admin' && $page === 'dashboard'): ?><a class="button button-primary" href="<?= app_h(app_link('admin', 'permintaan')) ?>">＋ Buat permintaan</a><?php elseif ($role === 'mahasiswa' && $page === 'beranda'): ?><a class="button button-primary" href="<?= app_h(app_link('mahasiswa', 'skrining')) ?>">Mulai skrining →</a><?php endif; ?></div>

<?php if ($page === 'dashboard'): ?>
<section class="welcome-strip"><span class="welcome-symbol">✳</span><div><strong>Koordinasi yang tepat membantu donor sampai kepada yang membutuhkan.</strong><p>Periksa kecocokan, status kesediaan, dan jeda sebelum menghubungi pendonor.</p></div><span class="welcome-tag">MVP · KAMPUS</span></section>
<section class="metric-grid" aria-label="Ringkasan operasional data demo"><article class="metric-card"><span>Permintaan aktif</span><strong>02</strong><small><i class="dot orange"></i> 1 perlu tindak lanjut</small></article><article class="metric-card"><span>Pendonor siap</span><strong>24</strong><small>Sudah melewati jeda donor</small></article><article class="metric-card"><span>Menunggu verifikasi</span><strong>05</strong><small>Pendaftar baru · contoh</small></article><article class="metric-card"><span>Kegiatan mendatang</span><strong>01</strong><small>Contoh jadwal</small></article></section>
<div class="dashboard-grid"><section class="panel"><div class="panel-heading"><div><p class="eyebrow">PERLU PERHATIAN</p><h2>Permintaan donor aktif</h2></div><a class="panel-link" href="<?= app_h(app_link('admin', 'permintaan')) ?>">Lihat semua →</a></div><div class="request-row"><span class="blood-pill">O−</span><div class="request-info"><strong>Permintaan simulasi <span class="priority urgent">Darurat</span></strong><small>Tasikmalaya · 34 menit lalu</small></div><div class="request-status"><strong>Menunggu respons</strong><small>3 notifikasi demo</small></div><a class="row-arrow" href="<?= app_h(app_link('admin', 'permintaan')) ?>" aria-label="Lihat permintaan">→</a></div><div class="request-row"><span class="blood-pill blood-a">A+</span><div class="request-info"><strong>Permintaan simulasi <span class="priority normal">Terencana</span></strong><small>Kota Tasikmalaya · kemarin</small></div><div class="request-status"><strong>1 bersedia</strong><small>Kontak tetap privat</small></div><a class="row-arrow" href="<?= app_h(app_link('admin', 'permintaan')) ?>" aria-label="Lihat permintaan">→</a></div><p class="panel-footnote"><i class="dot green"></i> Contoh antarmuka—bukan permintaan nyata.</p></section>
<section class="panel"><div class="panel-heading"><div><p class="eyebrow">TINDAK LANJUT</p><h2>Perlu ditinjau</h2></div><span class="count-badge">05</span></div><a class="task-row" href="<?= app_h(app_link('admin', 'pendonor')) ?>"><span class="task-icon amber">◎</span><span><strong>Pendaftar menunggu verifikasi</strong><small>Periksa data sebelum diaktifkan</small></span><b>→</b></a><a class="task-row" href="<?= app_h(app_link('admin', 'kegiatan')) ?>"><span class="task-icon mint">▣</span><span><strong>Pengajuan kegiatan donor</strong><small>Pastikan jadwal dan mitra terkonfirmasi</small></span><b>→</b></a><a class="task-row" href="<?= app_h(app_link('mahasiswa', 'skrining')) ?>"><span class="task-icon rose">✓</span><span><strong>Skrining mandiri</strong><small>Lihat tampilan mahasiswa</small></span><b>→</b></a></section></div>
<div class="lower-grid"><section class="panel"><div class="panel-heading"><div><p class="eyebrow">KALENDER</p><h2>Kegiatan donor berikutnya</h2></div><a class="panel-link" href="<?= app_h(app_link('admin', 'kegiatan')) ?>">Semua kegiatan →</a></div><div class="event-row"><span class="event-date"><strong>18</strong><small>DES</small></span><span><strong>Kegiatan donor darah kampus</strong><small>Student Center · contoh jadwal</small></span><span class="event-state">Draf demo</span></div></section><section class="panel"><div class="panel-heading"><div><p class="eyebrow">KANAL NOTIFIKASI</p><h2>WhatsApp</h2></div><span class="connection-state"><i></i> Belum terhubung</span></div><p class="panel-copy">Pengiriman pesan belum aktif. Penyedia dan anggaran perlu ditentukan.</p><a class="panel-link" href="<?= app_h(app_link('admin', 'permintaan')) ?>">Lihat alur notifikasi →</a></section></div>
<p class="data-notice">ⓘ Data pada layar ini adalah simulasi untuk pratinjau; belum ada data yang tersimpan atau pesan yang dikirim.</p>

<?php elseif ($page === 'permintaan'): ?>
<section class="panel page-panel"><div class="panel-heading"><div><p class="eyebrow">KOORDINASI DONOR</p><h2>Daftar permintaan darah</h2><p class="panel-copy">Permintaan hanya dikirim setelah pemohon diverifikasi dan admin menyetujui penerima.</p></div><span class="demo-badge"><i></i> Data simulasi</span></div><div class="filter-row"><input type="search" placeholder="Cari ID permintaan" aria-label="Cari ID permintaan"><select aria-label="Filter status"><option>Semua status</option><option>Menunggu respons</option><option>Terpenuhi</option></select><select aria-label="Filter urgensi"><option>Semua urgensi</option><option>Darurat</option><option>Terencana</option></select></div><div class="table-wrap"><table><thead><tr><th>PERMINTAAN</th><th>GOL. DARAH</th><th>URGENSI</th><th>STATUS</th><th>DIBUAT</th></tr></thead><tbody><tr><td><strong>SIM-001</strong><small>Lokasi contoh · Tasikmalaya</small></td><td><span class="blood-pill">O−</span></td><td><span class="priority urgent">Darurat</span></td><td>Menunggu respons</td><td>34 menit lalu</td></tr><tr><td><strong>SIM-002</strong><small>Lokasi contoh · Tasikmalaya</small></td><td><span class="blood-pill blood-a">A+</span></td><td><span class="priority normal">Terencana</span></td><td>1 bersedia</td><td>Kemarin</td></tr></tbody></table></div><div class="prototype-note">Pembuatan, verifikasi pemohon, pencocokan golongan darah, dan pengiriman WhatsApp belum tersambung ke basis data/layanan eksternal.</div></section>

<?php elseif ($page === 'pendonor'): ?>
<section class="panel page-panel"><div class="panel-heading"><div><p class="eyebrow">DATA TERBATAS</p><h2>Pencarian pendonor</h2><p class="panel-copy">Hanya pendonor yang cocok, bersedia, lolos skrining awal, dan melewati jeda yang ditampilkan.</p></div><span class="privacy-chip">◇ Kontak dilindungi</span></div><div class="filter-row"><input type="search" placeholder="Cari ID pendonor" aria-label="Cari ID pendonor"><select aria-label="Filter golongan darah"><option>Semua golongan</option><option>A+</option><option>B+</option><option>AB+</option><option>O+</option><option>O−</option></select><select aria-label="Filter status"><option>Siap donor</option><option>Belum terverifikasi</option><option>Dalam masa jeda</option></select><button class="button button-secondary" type="button">Terapkan filter</button></div><div class="donor-row"><span class="donor-avatar">PD</span><span class="donor-id"><strong>Pendonor demo 01</strong><small>ID tersamarkan · data contoh</small></span><span class="blood-pill">O−</span><span class="verified-state">● Terverifikasi</span><span class="ready-state">Siap donor</span><button class="locked-action" type="button" disabled>Kontak terkunci ◇</button></div><div class="donor-row"><span class="donor-avatar lilac">PD</span><span class="donor-id"><strong>Pendonor demo 02</strong><small>ID tersamarkan · data contoh</small></span><span class="blood-pill blood-a">A+</span><span class="verified-state">● Terverifikasi</span><span class="ready-state">Siap donor</span><button class="locked-action" type="button" disabled>Kontak terkunci ◇</button></div><p class="data-notice">ⓘ Kontak tidak ditampilkan. Admin baru dapat mengakses kontak setelah pendonor menyatakan bersedia.</p></section>

<?php elseif ($page === 'kegiatan'): ?>
<section class="panel page-panel"><div class="panel-heading"><div><p class="eyebrow">KEGIATAN KAMPUS</p><h2>Pengumuman & pendaftaran</h2><p class="panel-copy">Kegiatan tampil setelah diverifikasi admin. Jadwal di bawah hanya contoh.</p></div><span class="demo-badge"><i></i> Data simulasi</span></div><div class="activity-card"><div class="activity-calendar"><span>KAMIS</span><strong>18</strong><small>DESEMBER</small></div><div><span class="event-state">Contoh jadwal</span><h3>Kegiatan donor darah kampus</h3><p>Student Center · Kuota dan mitra belum dikonfigurasi</p><small>Pendaftaran belum dibuka</small></div><button class="button button-secondary" type="button" disabled>Belum tersedia</button></div><div class="prototype-note">Fitur kegiatan berprioritas Could pada draf PRD; tahap ini menampilkan rancangan antarmuka.</div></section>

<?php elseif ($page === 'laporan'): ?>
<section class="panel page-panel"><div class="panel-heading"><div><p class="eyebrow">REKAP OPERASIONAL</p><h2>Ringkasan kegiatan</h2><p class="panel-copy">Rekap pendaftar, kehadiran, hasil donor, dan gagal skrining tanpa rincian hasil medis.</p></div><button class="button button-secondary" type="button" disabled>Unduh · belum aktif</button></div><div class="empty-state"><span>▤</span><strong>Belum ada data kegiatan</strong><p>Rekap muncul setelah kegiatan dan hasil donor dicatat.</p></div><div class="prototype-note">Target PRD bukan data aktual. Pengukuran memerlukan data operasional yang telah divalidasi.</div></section>

<?php elseif ($page === 'beranda'): ?>
<section class="welcome-strip"><span class="welcome-symbol">♥</span><div><strong>Terima kasih sudah mempertimbangkan untuk mendonor.</strong><p>Pemeriksaan resmi tetap dilakukan oleh petugas UDD PMI.</p></div><span class="welcome-tag">AKUN DEMO</span></section><div class="student-grid"><section class="panel student-card"><p class="eyebrow">STATUS PENDONOR</p><h2>Lengkapi skrining awal</h2><p>Isi skrining mandiri untuk melihat acuan awal, bukan keputusan kelayakan final.</p><a class="button button-primary" href="<?= app_h(app_link('mahasiswa', 'skrining')) ?>">Buka skrining mandiri →</a></section><section class="panel student-card"><p class="eyebrow">JEDA DONOR</p><h2>Belum ada riwayat donor</h2><p>Riwayat muncul setelah admin mencatat hasil donor.</p><a class="panel-link" href="<?= app_h(app_link('mahasiswa', 'riwayat')) ?>">Lihat riwayat →</a></section></div><section class="panel"><p class="eyebrow">INFO KEGIATAN</p><h2>Kegiatan donor mendatang</h2><p class="panel-copy">Pengumuman terverifikasi akan tampil di sini. Belum ada kegiatan aktif pada prototipe.</p></section><p class="data-notice">ⓘ Prototipe ini tidak menyimpan data pribadi atau jawaban kesehatan.</p>

<?php elseif ($page === 'skrining'): ?>
<div class="screening-layout"><section class="panel page-panel"><div class="panel-heading"><div><p class="eyebrow">FORMULIR · SIMULASI LOKAL</p><h2>Periksa acuan awal</h2><p class="panel-copy">Jawaban diproses di peramban dan tidak dikirim/disimpan. Acuan perlu konfirmasi UDD PMI.</p></div><span class="privacy-chip">Privat · tidak disimpan</span></div><div id="screening-form" class="screening-form" role="group" aria-label="Skrining mandiri lokal" autocomplete="off"><label>Usia (tahun)<input id="age" type="number" min="1" max="120" inputmode="numeric" placeholder="Contoh: 20" required></label><label>Berat badan (kg)<input id="weight" type="number" min="1" max="300" step="0.1" inputmode="decimal" placeholder="Contoh: 50" required></label><fieldset><legend>Apakah ada kondisi kesehatan atau konsumsi obat yang perlu ditinjau petugas?</legend><label><input type="radio" name="health" value="yes" required> Ya</label><label><input type="radio" name="health" value="no"> Tidak</label></fieldset><button class="button button-primary" id="screening-submit" type="button">Lihat acuan awal →</button><div id="screening-result" class="screening-result" role="status" aria-live="polite" hidden></div></div></section><aside class="panel screening-aside"><span class="eyebrow">PENTING DIKETAHUI</span><ul><li>Hasil skrining hanya perkiraan awal, bukan diagnosis.</li><li>Acuan awal draf: usia 17–65 tahun dan berat minimal 45 kg.</li><li>Aturan final dan kriteria tambahan masih perlu validasi medis.</li><li>Keputusan kelayakan akhir ada pada petugas UDD PMI.</li></ul><p class="medical-note">Keputusan akhir tetap dilakukan petugas UDD PMI.</p></aside></div>

<?php elseif ($page === 'riwayat'): ?>
<section class="panel page-panel"><p class="eyebrow">PRIVAT UNTUK AKUN INI</p><h2>Riwayat donor</h2><p class="panel-copy">Sistem hanya mencatat tanggal dan status donor, bukan hasil pemeriksaan medis rinci.</p><div class="empty-state"><span>◷</span><strong>Belum ada riwayat donor</strong><p>Riwayat ditampilkan setelah admin mencatat hasil donor.</p></div></section>
<?php endif; ?>
</main>
<footer class="app-footer"><span>SiDonor · Prototipe antarmuka</span><span>Data simulasi · WhatsApp belum aktif · Keputusan akhir tetap dilakukan petugas UDD PMI.</span></footer>
</div></div>
<script>
(() => {
    const menu = document.querySelector('.mobile-menu');
    const sidebar = document.querySelector('.sidebar');
    if (menu && sidebar) menu.addEventListener('click', () => {
        const opened = sidebar.classList.toggle('sidebar-open');
        menu.setAttribute('aria-expanded', String(opened));
    });
    const container = document.getElementById('screening-form');
    const screeningButton = document.getElementById('screening-submit');
    if (!container || !screeningButton) return;
    screeningButton.addEventListener('click', () => {
        const age = Number(document.getElementById('age').value);
        const weight = Number(document.getElementById('weight').value);
        const health = document.querySelector('input[name="health"]:checked')?.value;
        const result = document.getElementById('screening-result');
        result.hidden = false;
        if (!age || !weight || !health) {
            result.innerHTML = '<strong>Lengkapi semua jawaban.</strong><span>Jawaban tetap di halaman ini dan tidak dikirim.</span>';
            return;
        }
        if (health === 'yes') {
            result.innerHTML = '<strong>Perlu ditinjau petugas.</strong><span>Bahas kondisi/obat dengan petugas UDD PMI.</span>';
            return;
        }
        if (age < 17 || age > 65 || weight < 45) {
            result.innerHTML = '<strong>Belum sesuai acuan awal.</strong><span>Ini bukan penilaian medis. Konfirmasi aturan terbaru kepada UDD PMI.</span>';
            return;
        }
        result.innerHTML = '<strong>Sesuai rentang acuan awal.</strong><span>Bukan kelulusan donor; pemeriksaan dan keputusan akhir oleh petugas UDD PMI.</span>';
    });
})();
</script>
</body></html>
