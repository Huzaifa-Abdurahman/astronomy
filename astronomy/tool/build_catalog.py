"""Builds assets/data/catalog.json from OpenNGC (Messier) and HYG v4.1 (stars).

Usage: python -I build_catalog.py <src_dir> <out_json>
"""
import csv
import re
import json
import sys

src, out = sys.argv[1], sys.argv[2]

CONST = {
    'And': 'Andromeda', 'Ant': 'Antlia', 'Aps': 'Apus', 'Aqr': 'Aquarius', 'Aql': 'Aquila', 'Ara': 'Ara',
    'Ari': 'Aries', 'Aur': 'Auriga', 'Boo': 'Boötes', 'Cae': 'Caelum', 'Cam': 'Camelopardalis',
    'Cnc': 'Cancer', 'CVn': 'Canes Venatici', 'CMa': 'Canis Major', 'CMi': 'Canis Minor',
    'Cap': 'Capricornus', 'Car': 'Carina', 'Cas': 'Cassiopeia', 'Cen': 'Centaurus', 'Cep': 'Cepheus',
    'Cet': 'Cetus', 'Cha': 'Chamaeleon', 'Cir': 'Circinus', 'Col': 'Columba', 'Com': 'Coma Berenices',
    'CrA': 'Corona Australis', 'CrB': 'Corona Borealis', 'Crv': 'Corvus', 'Crt': 'Crater', 'Cru': 'Crux',
    'Cyg': 'Cygnus', 'Del': 'Delphinus', 'Dor': 'Dorado', 'Dra': 'Draco', 'Equ': 'Equuleus',
    'Eri': 'Eridanus', 'For': 'Fornax', 'Gem': 'Gemini', 'Gru': 'Grus', 'Her': 'Hercules',
    'Hor': 'Horologium', 'Hya': 'Hydra', 'Hyi': 'Hydrus', 'Ind': 'Indus', 'Lac': 'Lacerta', 'Leo': 'Leo',
    'LMi': 'Leo Minor', 'Lep': 'Lepus', 'Lib': 'Libra', 'Lup': 'Lupus', 'Lyn': 'Lynx', 'Lyr': 'Lyra',
    'Men': 'Mensa', 'Mic': 'Microscopium', 'Mon': 'Monoceros', 'Mus': 'Musca', 'Nor': 'Norma',
    'Oct': 'Octans', 'Oph': 'Ophiuchus', 'Ori': 'Orion', 'Pav': 'Pavo', 'Peg': 'Pegasus', 'Per': 'Perseus',
    'Phe': 'Phoenix', 'Pic': 'Pictor', 'Psc': 'Pisces', 'PsA': 'Piscis Austrinus', 'Pup': 'Puppis',
    'Pyx': 'Pyxis', 'Ret': 'Reticulum', 'Sge': 'Sagitta', 'Sgr': 'Sagittarius', 'Sco': 'Scorpius',
    'Scl': 'Sculptor', 'Sct': 'Scutum', 'Ser': 'Serpens', 'Sex': 'Sextans', 'Tau': 'Taurus',
    'Tel': 'Telescopium', 'Tri': 'Triangulum', 'TrA': 'Triangulum Australe', 'Tuc': 'Tucana',
    'UMa': 'Ursa Major', 'UMi': 'Ursa Minor', 'Vel': 'Vela', 'Vir': 'Virgo', 'Vol': 'Volans',
    'Vul': 'Vulpecula',
}
GREEK = {'Alp': 'α', 'Bet': 'β', 'Gam': 'γ', 'Del': 'δ', 'Eps': 'ε', 'Zet': 'ζ', 'Eta': 'η', 'The': 'θ',
         'Iot': 'ι', 'Kap': 'κ', 'Lam': 'λ', 'Mu': 'μ', 'Nu': 'ν', 'Xi': 'ξ', 'Omi': 'ο', 'Pi': 'π',
         'Rho': 'ρ', 'Sig': 'σ', 'Tau': 'τ', 'Ups': 'υ', 'Phi': 'φ', 'Chi': 'χ', 'Psi': 'ψ', 'Ome': 'ω'}


def sexa_to_deg(s, hours):
    sign = -1 if s.strip().startswith('-') else 1
    parts = [float(p) for p in s.strip().lstrip('+-').split(':')]
    v = parts[0] + parts[1] / 60 + (parts[2] if len(parts) > 2 else 0) / 3600
    return round(sign * v * (15 if hours else 1), 5)


def dso_kind(t, hubble):
    if t in ('G', 'GPair', 'GTrpl', 'GGroup'):
        h = hubble or ''
        if h.startswith('E'):
            sub = 'elliptical galaxy'
        elif h.startswith('S0'):
            sub = 'lenticular galaxy'
        elif h.startswith('SB'):
            sub = 'barred spiral galaxy'
        elif h.startswith('S'):
            sub = 'spiral galaxy'
        elif h.startswith('I'):
            sub = 'irregular galaxy'
        else:
            sub = 'galaxy'
        return 'galaxy', sub
    return {
        'GCl': ('cluster', 'globular cluster'),
        'OCl': ('cluster', 'open cluster'),
        '*Ass': ('cluster', 'star cloud / asterism'),
        'Cl+N': ('nebula', 'nebula with star cluster'),
        'PN': ('nebula', 'planetary nebula'),
        'HII': ('nebula', 'emission nebula'),
        'EmN': ('nebula', 'emission nebula'),
        'RfN': ('nebula', 'reflection nebula'),
        'Neb': ('nebula', 'nebula'),
        'SNR': ('nebula', 'supernova remnant'),
        '**': ('star', 'double star'),
        'Other': ('cluster', 'asterism'),  # M73: "Four Galactic stars."
    }[t]


def read_openngc():
    rows = []
    for f in ('NGC.csv', 'addendum.csv'):
        with open(f'{src}/{f}', encoding='utf-8') as fh:
            rows += list(csv.DictReader(fh, delimiter=';'))
    by_name = {r['Name']: r for r in rows}
    messier = {}
    for r in rows:
        if r['M'] and r['Type'] != 'Dup':
            messier.setdefault(int(r['M']), r)
    # OpenNGC gives M102 no row of its own; its note on NGC 5866 says "This may be M102".
    messier[102] = by_name['NGC5866']
    return messier


def messier_entries():
    out = []
    for m, r in sorted(read_openngc().items()):
        kind, sub = dso_kind(r['Type'], r['Hubble'])
        mag = r['V-Mag'] or r['B-Mag']
        common = r['Common names'].split(',')[0].strip() if r['Common names'] else ''
        const = CONST.get(r['Const'], r['Const'])
        ngc = r['Name']
        alt_id = ''
        if ngc.startswith('NGC') or ngc.startswith('IC'):
            prefix = 'NGC' if ngc.startswith('NGC') else 'IC'
            alt_id = f"{prefix} {ngc[len(prefix):].lstrip('0')}"
        summary = f"{sub[0].upper()}{sub[1:]} in {const}"
        summary += f", magnitude {float(mag):.1f}." if mag else '.'
        if alt_id:
            summary += f' Also catalogued as {alt_id}.'
        if m == 102:
            summary += ' M102 is usually identified with NGC 5866, though Messier\'s record is ambiguous.'
        e = {
            'id': f'm{m}',
            'name': common or f'Messier {m}',
            'catalog': f'M{m}',
            'type': kind,
            'subtype': sub,
            'raDeg': sexa_to_deg(r['RA'], True),
            'decDeg': sexa_to_deg(r['Dec'], False),
            'mag': round(float(mag), 2) if mag else None,
            'constellation': const,
            'summary': summary,
        }
        if alt_id:
            e['altId'] = alt_id
        if m == 31:
            e['image'] = 'assets/backgrounds/bg-detail.jpg'
        out.append(e)
    return out


STARS = ['Sirius', 'Canopus', 'Rigil Kentaurus', 'Arcturus', 'Vega', 'Capella', 'Rigel', 'Procyon',
         'Achernar', 'Betelgeuse', 'Hadar', 'Altair', 'Acrux', 'Aldebaran', 'Antares', 'Spica', 'Pollux',
         'Fomalhaut', 'Deneb', 'Mimosa', 'Regulus', 'Castor', 'Bellatrix', 'Elnath', 'Alnilam', 'Alhena',
         'Dubhe', 'Mizar', 'Polaris']
DISPLAY = {'Rigil Kentaurus': 'Alpha Centauri'}


COLOUR = {'O': 'blue', 'B': 'blue-white', 'A': 'white', 'F': 'yellow-white', 'G': 'yellow', 'K': 'orange',
          'M': 'red'}


def star_kind(spect):
    """'A0m...' -> 'white main-sequence star', from the HYG spectral class."""
    # 'comp' marks a composite spectrum (e.g. Capella), so the class is unreliable.
    m = re.match(r'([OBAFGKM])[\d.]*:?\s*(Ia|Ib|III|II|IV|V|I)?', spect or '')
    if not m or 'comp' in spect:
        return 'star'
    lum = {'V': 'main-sequence ', 'IV': 'subgiant ', 'III': 'giant ', 'II': 'bright giant ',
           'I': 'supergiant ', 'Ia': 'supergiant ', 'Ib': 'supergiant '}.get(m.group(2) or '', '')
    return f'{COLOUR[m.group(1)]} {lum}star'


def star_entries():
    wanted = set(STARS)
    found = {}
    with open(f'{src}/hyg.csv', encoding='utf-8') as fh:
        for r in csv.DictReader(fh):
            if r['proper'] in wanted and r['proper'] not in found:
                found[r['proper']] = r
    missing = wanted - set(found)
    if missing:
        raise SystemExit(f'Missing stars in HYG: {missing}')
    out = []
    for name in STARS:
        r = found[name]
        const = CONST.get(r['con'], r['con'])
        bayer = f"{GREEK.get(r['bayer'].split('-')[0], r['bayer'])} {r['con']}" if r['bayer'] else name
        dist_pc = float(r['dist'])
        spect = r['spect'].strip()
        display = DISPLAY.get(name, name)
        e = {
            'id': display.lower().replace(' ', '-'),
            'name': display,
            'catalog': bayer,
            'type': 'star',
            'subtype': star_kind(spect),
            'raDeg': round(float(r['ra']) * 15, 5),
            'decDeg': round(float(r['dec']), 5),
            'mag': round(float(r['mag']), 2),
            'constellation': const,
            'summary': f"{'The brightest' if name == 'Sirius' else 'A bright'} star in {const}, magnitude {float(r['mag']):.2f}.",
        }
        if 0 < dist_pc < 100000:
            e['distance'] = f'{dist_pc * 3.26156:,.0f} ly'
        out.append(e)
    return out


SOLAR = [
    ('moon', 'Moon', 'planet', 'moon', 'Earth\'s natural satellite. Its position is computed for your exact location.'),
    ('mercury', 'Mercury', 'planet', 'planet', 'The innermost planet; always close to the Sun, best near twilight.'),
    ('venus', 'Venus', 'planet', 'planet', 'The brightest planet, seen as the morning or evening star.'),
    ('mars', 'Mars', 'planet', 'planet', 'The red planet.'),
    ('jupiter', 'Jupiter', 'planet', 'planet', 'The largest planet; binoculars show its four big moons.'),
    ('saturn', 'Saturn', 'planet', 'planet', 'The ringed planet; a small telescope shows the rings.'),
    ('uranus', 'Uranus', 'planet', 'planet', 'Ice giant at the limit of naked-eye visibility.'),
    ('neptune', 'Neptune', 'planet', 'planet', 'The outermost planet; needs binoculars or a telescope.'),
]


def solar_entries():
    return [{'id': i, 'name': n, 'catalog': 'Solar System', 'type': t, 'subtype': s, 'raDeg': None,
             'decDeg': None, 'mag': None, 'summary': summary} for i, n, t, s, summary in SOLAR]


catalog = {
    'sources': {
        'messier': 'OpenNGC by Mattia Verga, CC-BY-SA-4.0, https://github.com/mattiaverga/OpenNGC',
        'stars': 'HYG Database v4.1 by David Nash (astronexus), CC BY-SA 4.0, https://github.com/astronexus/HYG-Database',
        'epoch': 'J2000',
    },
    'objects': solar_entries() + star_entries() + messier_entries(),
}
with open(out, 'w', encoding='utf-8') as fh:
    json.dump(catalog, fh, ensure_ascii=False, indent=1)
print(len(catalog['objects']), 'objects')
