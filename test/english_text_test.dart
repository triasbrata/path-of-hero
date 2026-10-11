// The in-game text is English (docs/ui-hud.md "In-game text"), no game: no string literal in lib/ holds an Indonesian
// word, past the count each file still waits on ([pending]). A ratchet: a file over its count has a new Indonesian
// string; one under it must lower its count, so the map only goes down, and each batch that turns a file's strings
// English zeroes its row. Ids that are never shown (save keys, telemetry values, test keys) and the legal texts the
// owner keeps are allowed ([_ids], [_legal]); personal names (lib/names.dart) stay as they are.
import 'package:flutter_test/flutter_test.dart';

import 'lib_literals.dart';

/// Indonesian words that mark a string as not yet English, matched whole and in any case: the words of the strings
/// still Indonesian, the old names of the things (troops, monsters, items, relics, ranks, titles, epithets).
const _words = [
  'dan', 'yang', 'tidak', 'belum', 'sudah', 'tiap', 'kurang', 'penuh', 'gelombang', 'pasukan', 'jenis', 'emas', //
  'detik', 'petak', 'serangan', 'musuh', 'ketuk', 'lepas', 'kembali', 'jual', 'beli', 'batal', 'yakin', 'nanti',
  'ambil', 'kocok', 'lewati', 'gugur', 'bangkit', 'tempa', 'asah', 'lebur', 'gudang', 'toko', 'peti', 'bintang',
  'mulai', 'skor', 'menang', 'kalah', 'nyala', 'mati', 'sorotan', 'lisensi', 'memuat', 'oleh', 'harga', 'hanya',
  'semua', 'muncul', 'relik', 'artefak', 'sumpah', 'serpihan', 'saran', 'pulang', 'terpasang', 'pindah', 'tidur',
  'kapasitas', 'batas', 'jeda', 'pulih', 'sembuh', 'maks', 'selesai', 'kosong', 'ganti', 'lanjut', 'lanjutkan',
  'pengaturan', 'untuk', 'dari', 'bisa', 'lagi', 'baru', 'pilih', 'naik', 'dengan', 'setiap', 'terbuka', 'butuh',
  'dulu', 'tukar', 'lebih', 'kini', 'cara', 'ulang',
  // The old names.
  'prajurit', 'ksatria', 'pendekar', 'pemanah', 'penombak', 'pendeta', 'kapak', 'berzirah', 'penyihir', 'lendir',
  'kelelawar', 'tengkorak', 'serigala', 'beruang', 'nekromanser', 'penunggang', 'pedang', 'perisai', 'sepatu', 'busur',
  'sarung', 'tangan', 'ramuan', 'tongkat', 'sihir', 'taring', 'duri', 'amarah', 'pelindung', 'raksasa', 'fajar',
  'badai', 'hampa', 'baja', 'haus', 'darah', 'genderang', 'duka', 'bermahkota', 'lengket', 'sayap', 'malam', 'tulang',
  'besi', 'penghancur', 'maut', 'bulan', 'zirah', 'panglima', 'perang', 'tembok', 'kubur', 'cakar', 'gunung',
  'pemanggil', 'penyembuh', 'kelam', 'mayat', 'hidup', 'bangkitan', 'tinggi', 'biasa', 'manusia', 'bayangan', 'ukir',
  // Small words that only Indonesian has here.
  'beri', 'selamat', 'kerusakan', 'pukulan', 'menjatuhkan', 'gratis', 'ada', 'tak', 'ini', 'itu', 'akan', 'juga', 'saat',
  'setelah', 'sebelum', 'masih', 'ke', 'di',
];

/// Indonesian words matched only as written: lower case they are code ("pusaka" the save key, "main.dart").
const _namesCased = ['Tas', 'Bos', 'Pasang', 'Pusaka', 'Elit', 'Langka', 'Epik', 'Legenda', 'Main'];

/// A whole word: no letter, digit or underscore either side (`relic_guard.png` is three words).
RegExp _whole(List<String> words, {required bool caseSensitive}) =>
    RegExp('(?<![A-Za-z0-9_])(${words.join('|')})(?![A-Za-z0-9_])', caseSensitive: caseSensitive);

final _indonesian = [_whole(_words, caseSensitive: false), _whole(_namesCased, caseSensitive: true)];

/// Literals that are ids, never shown, and never change with the words: save keys and telemetry values ("pusaka",
/// "tempa", "serpihan", "ukir"), the store's hit keys (`'tab:bangkit'`, `'bangkit:TYPE'`) and the suggestion strip's 'batal'.
const _ids = {'pusaka', 'tempa', 'serpihan', 'ukir', 'tab:bangkit', 'bangkit:', 'batal'};

/// English phrases with a word the finder reads as Indonesian: "Main" is Indonesian for play ("Main Baru"), English here.
const _english = {'Main Menu'};

/// The legal texts the owner keeps as they are (the licence summary and the credits): a whole file, and the credit
/// line the Licenses page builds from its parts.
const _legalFiles = {'lib/licences.dart', 'lib/names.dart'};
const _legal = {('lib/licence_page.dart', ': , oleh  ()')};

/// How many Indonesian literals each file still holds, until its batch turns them English (docs/ui-hud.md "In-game
/// text"). Only ever lowered; a file at 0 leaves the map. Empty since the last batch (decisions-log 200): every string
/// in lib/ is English but the ids and the legal texts above, so any Indonesian word in a new string fails.
const pending = <String, int>{};

/// The Indonesian literals of [path]'s [source]: the welcome screen's button keys (`_welcomeAt['Lanjutkan']`: ids)
/// and the `part`/`import` paths left out, then the [_ids] and [_legal] ones; the [_english] phrases aren't read.
List<String> indonesianIn(String path, String source) => [
      for (final s in dartLiterals(source.replaceAll(RegExp(r"_welcomeAt\['[^']*'\]"), '_welcomeAt[key]')))
        if (!_ids.contains(s) && !s.endsWith('.dart') && !_legal.contains((path, s)) &&
            _indonesian.any((w) => w.hasMatch(_english.fold(s, (t, e) => t.replaceAll(e, '')))))
          s,
    ];

void main() {
  test('no Indonesian word in a string in lib/ past each file\'s pending count; the counts follow the code down', () {
    final found = {
      for (final f in libFiles())
        if (!_legalFiles.contains(f.path)) f.path: indonesianIn(f.path, f.readAsStringSync()),
    }..removeWhere((_, lits) => lits.isEmpty);
    for (final MapEntry(key: path, value: lits) in found.entries) {
      final allowed = pending[path] ?? 0;
      expect(lits.length, lessThanOrEqualTo(allowed),
          reason: '$path: a new Indonesian string (${lits.length} > $allowed); in-game text is English (ui-hud.md "In-game '
              'text"): ${lits.map((s) => "'$s'").join(', ')}');
      expect(lits.length, allowed, reason: '$path: ${lits.length} Indonesian strings left, lower its pending count to that');
    }
    for (final path in pending.keys.where((p) => !found.containsKey(p))) {
      fail('$path holds no Indonesian string any more: take it out of pending');
    }
  });

  test('the finder: whole words in any case, the cased names only as written, ids and paths left out', () {
    expect(indonesianIn('lib/x.dart', "final a = 'Emas kurang', b = 'Not enough gold', c = 'Gelombang \$n';"),
        ['Emas kurang', 'Gelombang ']);
    expect(indonesianIn('lib/x.dart', "part 'tempa.dart'; final k = j['tempa']; final m = 'relic_guard.png';"), isEmpty);
    expect(indonesianIn('lib/x.dart', "final a = 'Tas', b = 'tas', c = 'Pusaka', d = 'pusaka', e = 'Bostons';"), ['Tas', 'Pusaka']);
    expect(indonesianIn('lib/x.dart', "_welcomeAt['Lanjutkan'] = r; final l = 'Lanjutkan';"), ['Lanjutkan']);
    expect(indonesianIn('lib/x.dart', "final t = 'Morgath the Summoner', u = 'High Elite Orc', v = 'Undying Templar';"), isEmpty);
    expect(indonesianIn('lib/x.dart', "final m = 'Main Menu', n = 'Main Baru', o = 'Main!';"), ['Main Baru', 'Main!']);
  });
}
