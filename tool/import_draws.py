"""Convert the official XLSX export to a validated, reproducible app asset.

Usage: python tool/import_draws.py source.xlsx assets/draws.json
"""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

source, target = map(Path, sys.argv[1:])
ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
records = []
with zipfile.ZipFile(source) as archive:
    rows = ET.fromstring(archive.read('xl/worksheets/sheet1.xml')).findall('.//s:row', ns)
    for row in rows[1:]:
        cells = {re.sub(r'\d', '', c.attrib['r']): c.find('s:v', ns).text
                 for c in row.findall('s:c', ns) if c.find('s:v', ns) is not None}
        def number(column):
            value = float(cells[column])
            if not value.is_integer():
                raise ValueError('Non-integer number')
            return int(value)
        round_no = number('B')
        numbers = [number(c) for c in 'CDEFGH']
        bonus = number('I')
        if len(set(numbers)) != 6 or any(n < 1 or n > 45 for n in numbers + [bonus]) or bonus in numbers:
            raise ValueError(f'Invalid draw {round_no}')
        records.append(dict(round=round_no, numbers=sorted(numbers), bonus=bonus))
records.sort(key=lambda r: r['round'])
if [r['round'] for r in records] != list(range(1, records[-1]['round'] + 1)):
    raise ValueError('Duplicate or missing rounds')
payload = dict(schemaVersion=1, source='동행복권', sourceUrl='https://www.dhlottery.co.kr/lt645/result',
               sourceFile=source.name, sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),
               latestRound=records[-1]['round'], draws=records)
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
print(f'Validated {len(records)} draws; latest {records[-1]["round"]}')
