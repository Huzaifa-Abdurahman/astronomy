"""Downloads the Google Fonts files SkyGuide uses into assets/google_fonts/.

google_fonts loads bundled assets before trying the network, so the app's
typography also works offline (e.g. at a dark-sky site with no signal).
The file URLs and SHA-256 hashes are read from the installed google_fonts
package, so these are byte-for-byte the files it would fetch at runtime.

Usage: python tool/bundle_fonts.py <google_fonts package lib/src dir> <out dir>
"""
import hashlib
import pathlib
import re
import sys
import urllib.request

SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

# (dart function name, asset filename prefix, weights used by lib/core/theme/app_text.dart)
FAMILIES = [
    ('bricolageGrotesque', 'BricolageGrotesque', [700, 800]),
    ('dmSans', 'DMSans', [400, 500, 600, 700]),
    ('dmMono', 'DMMono', [400, 500]),
]
WEIGHT_NAMES = {100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium',
                600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black'}
ENTRY = re.compile(
    r"fontWeight: FontWeight\.w(\d00),\s*fontStyle: FontStyle\.normal,\s*\): const GoogleFontsFile\(\s*'([0-9a-f]{64})',\s*(\d+),")

OUT.mkdir(parents=True, exist_ok=True)
parts = '\n'.join(p.read_text(encoding='utf-8') for p in SRC.glob('google_fonts_parts/*.dart'))
for func, prefix, weights in FAMILIES:
    start = parts.index(f'static TextStyle {func}(')
    block = parts[start:parts.index('return googleFontsTextStyle(', start)]
    files = {int(w): (h, int(n)) for w, h, n in ENTRY.findall(block)}
    for w in weights:
        sha, size = files[w]
        data = urllib.request.urlopen(f'https://fonts.gstatic.com/s/a/{sha}.ttf', timeout=60).read()
        if len(data) != size or hashlib.sha256(data).hexdigest() != sha:
            raise SystemExit(f'Checksum mismatch for {prefix} {w}')
        (OUT / f'{prefix}-{WEIGHT_NAMES[w]}.ttf').write_bytes(data)
        print(f'{prefix}-{WEIGHT_NAMES[w]}.ttf', size)
