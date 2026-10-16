#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Generate an optional consumer key in the build directory, without logging it."""
import argparse
import json
import os
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True)
args = parser.parse_args()
key = os.environ.get('OPENSUBTITLES_API_KEY', '').strip()
source = os.environ.get('OPENSUBTITLES_API_KEY_FILE', '')
if source:
    text = Path(source).read_text(encoding='utf-8').strip()
    if '\n' not in text and not text.startswith(('OPENSUBTITLES_API_KEY=', 'export OPENSUBTITLES_API_KEY=')):
        key = text
    else:
        key = ''
        for line in text.splitlines():
            name, separator, value = line.strip().removeprefix('export ').partition('=')
            if separator and name.strip() == 'OPENSUBTITLES_API_KEY':
                key = value.strip().strip('"\'')
                break
        if not key:
            parser.error('The key file has no OPENSUBTITLES_API_KEY entry.')
if len(key) > 512 or any(not 0x21 <= ord(ch) <= 0x7e for ch in key):
    parser.error('The consumer key has an invalid format.')
output = Path(args.output)
content = '// Generated locally. Do not commit this file.\n#pragma once\n'
content += 'static constexpr char subtitleConsumerKey[] = ' + json.dumps(key) + ';\n'
if not output.exists() or output.read_text(encoding='utf-8') != content:
    output.write_text(content, encoding='utf-8')
    output.chmod(0o600)
