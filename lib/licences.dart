import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'hud_font.dart';

// What the book's Lisensi page shows besides Flutter's own notices (decisions-log 137; docs/ui-hud.md "Lisensi
// page"): the game's licence in short ([licenceSummary]; LICENSE has it in full), who made the art and the rest
// ([credits], [ownWork], [madeWith]; CREDITS.md says the same, with each pack's terms), the native libraries
// flutter_soloud compiles into the game ([nativeLicences]) and the game's font ([fontLicences]). No package's LICENSE
// file carries those, so Flutter's NOTICES misses them: [registerLicences] adds them to the [LicenseRegistry]. Their
// texts are also parts 2 and 3 of THIRD_PARTY_NOTICES.txt, which tool/third_party_notices.py writes from this file and
// the font's licence file (licence_page_test.dart checks both).

/// The game's own licence in short, as the Lisensi page says it.
const licenceSummary = [
  'Path of Hero (c) 2026 Trias BYM.',
  'Lisensi Path of Hero (source-available): kode sumbernya boleh dibaca, dibangun dan dipakai sendiri, tetapi '
      'tidak boleh dibagikan atau dijual. Nama dan ikonnya milik pembuatnya.',
  'Build resmi: triasbrata.itch.io/path-of-hero, gratis atau donasi.',
  'Gambar, UI, huruf dan sebagian besar efek berasal dari pihak ketiga (Kredit), yang tidak termasuk lisensi itu.',
  'Teks lengkapnya: LICENSE, CREDITS.md dan THIRD_PARTY_NOTICES.txt.',
];

/// A third-party pack the game's art comes from: what the game uses it for, the pack, its author and its page.
typedef Credit = ({String role, String work, String by, String link});

/// Every pack in the game and its font, in CREDITS.md's order (unTied Games' licence requires the credit; the font's,
/// the SIL Open Font License, its copyright notice and licence, which [fontLicences] carries).
const credits = <Credit>[
  (role: 'Karakter', work: 'Tiny RPG Character Asset Pack', by: 'Zerie', link: 'zerie.itch.io'),
  (role: 'UI', work: 'Cute Fantasy UI', by: 'Kenmi', link: 'kenmi-art.itch.io'),
  (role: 'Icons', work: 'Cute Fantasy Icons Premium', by: 'Kenmi', link: 'kenmi-art.itch.io'),
  (role: 'Efek', work: 'Super Pixel Effects Gigapack', by: 'unTied Games', link: 'untiedgames.itch.io'),
  (role: 'Efek', work: 'Effect and FX Pixel', by: 'BDragon1727', link: 'bdragon1727.itch.io'),
  (role: 'Town and battle backdrop', work: 'FREE Platformer Assets', by: 'GandalfHardcore', link: 'gandalfhardcore.itch.io'),
  (role: 'Smith', work: 'Mana Seed Character Base', by: 'Seliel the Shaper', link: 'seliel-the-shaper.itch.io'),
  (role: 'Anvil', work: 'Pixel Crawler', by: 'Anokolisa', link: 'www.patreon.com/Anokolisa'),
  (role: 'Huruf', work: 'Pixelify Sans', by: 'Stefie Justprince', link: 'fonts.google.com'),
];

/// What was made for the game itself (all rights reserved, LICENSE §6c), and what the app icon is made of.
const ownWork = 'Musik, efek suara dan latar ikon game: dibuat untuk game ini. Ikon game: '
    'ksatria dari Zerie dengan mahkota dari Kenmi, di atas latar itu.';

/// The engine.
const madeWith = 'Dibuat dengan Flutter dan Flame; suara oleh SoLoud (flutter_soloud).';

/// The native libraries inside flutter_soloud's sound library, as package names (the Lisensi page's list) and the
/// licence text. From flutter_soloud's sources (src/) and its prebuilt Xiph libraries in the pub cache.
const nativeLicences = <(List<String>, String)>[
  (['SoLoud'], r'''
SoLoud contains various third party libraries which vary in licenses,
but are all extremely liberal; no attribution in binary form is required.
For more information, see SoLoud manual or http://soloud-audio.com/legal.html

SoLoud proper is licensed under the zlib/libpng license:

SoLoud audio engine
Copyright (c) 2013-2018 Jari Komppa

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.'''),
  (['SoLoud'], r'''
Parts of SoLoud that flutter_soloud compiles in, as their sources state:

- sfxr: based on code (c) Tomas Pettersson, re-licensed under the zlib licence by permission.

- vizsn speech synthesizer: (c) Ville-Matias Heikkila, released under the WTFPL (http://www.wtfpl.net/txt/copying/).

- TED/SID: based on tedplay (c) 2012 Attila Grosz, used under the Unlicense (http://unlicense.org/).

- AY: based on the public domain zxssk library, "created under public domain license by SMT, jan.2006".

- Speech: based on rsynth by the late Nick Ing-Simmons (et al.), described by him as public domain; Jari Komppa's changes are public domain, or CC0 (http://creativecommons.org/publicdomain/zero/1.0/).

- FFT: based on fftreal by Laurent de Soras (WTFPL), and on Takuya Ooura's FFT (http://www.kurims.kyoto-u.ac.jp/~ooura/fft.html): "Copyright Takuya OOURA, 1996-2001. You may use, copy, modify and distribute this code for any purpose (include commercial use) and without fee. Please refer to this package when you modify this code."

- zx7 decompressor: by Jari Komppa, public domain / Unlicense, heavily based on the zx7 decompressor by Einar Saukas.'''),
  (['miniaudio'], r'''
miniaudio v0.11.25, by David Reid (https://miniaud.io): a choice of public domain (the Unlicense) or MIT No Attribution. Used under MIT No Attribution:

Copyright 2026 David Reid

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''),
  (['dr_libs'], r'''
dr_wav v0.14.2, dr_mp3 v0.7.2 and dr_flac v0.13.2, by David Reid (https://github.com/mackron/dr_libs), inside SoLoud: a choice of public domain (the Unlicense) or MIT No Attribution. Used under MIT No Attribution:

Copyright 2023 David Reid

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''),
  (['pffft'], r'''
Copyright (c) 2013  Julien Pommier ( pommier@modartt.com )

Based on original fortran 77 code from FFTPACKv4 from NETLIB
(http://www.netlib.org/fftpack), authored by Dr Paul Swarztrauber
of NCAR, in 1985.

As confirmed by the NCAR fftpack software curators, the following
FFTPACKv5 license applies to FFTPACKv4 sources. My changes are
released under the same terms.

FFTPACK license:

http://www.cisl.ucar.edu/css/software/fftpack5/ftpk.html

Copyright (c) 2004 the University Corporation for Atmospheric
Research ("UCAR"). All rights reserved. Developed by NCAR's
Computational and Information Systems Laboratory, UCAR,
www.cisl.ucar.edu.

Redistribution and use of the Software in source and binary forms,
with or without modification, is permitted provided that the
following conditions are met:

- Neither the names of NCAR's Computational and Information Systems
Laboratory, the University Corporation for Atmospheric Research,
nor the names of its sponsors or contributors may be used to
endorse or promote products derived from this Software without
specific prior written permission.

- Redistributions of source code must retain the above copyright
notices, this list of conditions, and the disclaimer below.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions, and the disclaimer below in the
documentation and/or other materials provided with the
distribution.

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE
SOFTWARE.'''),
  (['signalsmith-linear'], r'''
MIT License

Copyright (c) 2025 Signalsmith Audio

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''),
  (['signalsmith-stretch'], r'''
MIT License

Copyright (c) 2022 Geraint Luff / Signalsmith Audio Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'''),
  (['libogg'], r'''
Copyright (c) 2002, Xiph.org Foundation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'''),
  (['libvorbis'], r'''
libvorbis, with vorbisfile and vorbisenc.

Copyright (c) 2002-2020 Xiph.org Foundation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'''),
  (['libopus'], r'''
Copyright 2001-2023 Xiph.Org, Skype Limited, Octasic,
                    Jean-Marc Valin, Timothy B. Terriberry,
                    CSIRO, Gregory Maxwell, Mark Borgerding,
                    Erik de Castro Lopo, Mozilla, Amazon

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of Internet Society, IETF or IETF Trust, nor the
names of specific contributors, may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Opus is subject to the royalty-free patent licenses which are
specified at:

Xiph.Org Foundation:
https://datatracker.ietf.org/ipr/1524/

Microsoft Corporation:
https://datatracker.ietf.org/ipr/1914/

Broadcom Corporation:
https://datatracker.ietf.org/ipr/1526/'''),
  (['libFLAC'], r'''
Copyright (C) 2000-2009  Josh Coalson
Copyright (C) 2011-2025  Xiph.Org Foundation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'''),
];

/// The game's font (lib/hud_font.dart) as the Lisensi page names it, and its licence ([hudFontLicence]): the file
/// bundled beside the font, with CRLF line ends, which [registerLicences] reads as plain ones. Poh Sans is a Modified
/// Version of Pixelify Sans, so it is what was changed and from what, then google/fonts' OFL text for Pixelify Sans with
/// a copyright line for the change.
const fontLicences = [(['Poh Sans'], hudFontLicence)];

var _registered = false;

/// Adds [nativeLicences] and [fontLicences] to Flutter's [LicenseRegistry], once (main() does it; the Lisensi page too,
/// for a game started without main, as in the tests).
void registerLicences() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
      () => Stream.fromIterable([for (final (packages, text) in nativeLicences) LicenseEntryWithLineBreaks(packages, text)]));
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in fontLicences) {
      yield LicenseEntryWithLineBreaks(packages, (await rootBundle.loadString(asset)).replaceAll('\r\n', '\n'));
    }
  });
}
