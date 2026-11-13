#!/usr/bin/env python3
"""Publish a figwire wire document into a Firebase Remote Config string param.

`firebase deploy --only remoteconfig` replaces the WHOLE template, so publishing
from a committed template file means every stale parameter in it overwrites its
live counterpart. This script never keeps one: it re-pulls the live template on
every run and edits exactly one parameter, so the blast radius is that parameter
and nothing else. `remoteconfig.template.json` is regenerated scratch, gitignored.

    tool/publish_guide.py dev                    # publish mcp_alpha.json -> guide_mcp_v2 (old builds keep guide_mcp)
    tool/publish_guide.py dev --dry-run          # pull + diff, publish nothing
    tool/publish_guide.py prod --yes             # prod requires the explicit flag
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, 'remoteconfig.template.json')


def run(*cmd):
    """Run a firebase command from the repo root, failing loudly with its stderr."""
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        err = (proc.stderr.strip() or proc.stdout.strip())
        sys.exit(f'$ {" ".join(cmd)}\n{err}')
    return proc.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('alias', choices=['dev', 'prod'], help='the .firebaserc project alias')
    ap.add_argument('--wire', default='deliverables/mcp/mcp_alpha.json',
                    help='wire JSON to publish (default: %(default)s)')
    ap.add_argument('--param', default='guide_mcp_v2',
                    help='Remote Config parameter to overwrite (default: %(default)s)')
    ap.add_argument('--dry-run', action='store_true', help='pull and diff, but do not publish')
    ap.add_argument('--yes', action='store_true', help='required to publish to prod')
    args = ap.parse_args()

    if args.alias == 'prod' and not args.yes and not args.dry_run:
        sys.exit('refusing to publish to prod without --yes')

    # Parse the wire first: a malformed doc should fail before anything touches Firebase.
    wire_path = os.path.join(ROOT, args.wire)
    with open(wire_path, encoding='utf-8') as f:
        wire = json.load(f)
    value = json.dumps(wire, ensure_ascii=False, separators=(',', ':'))

    # Always re-pull: the live template is the only safe baseline to edit.
    run('firebase', 'remoteconfig:get', '--project', args.alias, '-o', TEMPLATE)
    with open(TEMPLATE, encoding='utf-8') as f:
        tpl = json.load(f)

    params = tpl.get('parameters') or {}
    if args.param not in params:
        sys.exit(f'{args.param!r} is not in the live {args.alias} template — refusing to '
                 f'create it (a typo here would publish a dead parameter).\n'
                 f'present: {", ".join(sorted(params))}')

    before_count = len(params)
    old = params[args.param].get('defaultValue', {}).get('value', '')
    params[args.param]['defaultValue'] = {'value': value}
    assert len(params) == before_count, 'parameter count changed — aborting'

    version = tpl.get('version', {})
    print(f'project    {args.alias}')
    print(f'template   v{version.get("versionNumber")} @ {version.get("updateTime")}')
    print(f'parameters {before_count} (untouched except {args.param!r})')
    print(f'{args.param:<10} {len(old)} -> {len(value)} bytes'
          f'{"  (no change)" if old == value else ""}')

    if args.dry_run:
        print('\ndry run — nothing published')
        return
    if old == value:
        print('\nidentical to live — nothing to publish')
        return

    with open(TEMPLATE, 'w', encoding='utf-8') as f:
        json.dump(tpl, f, ensure_ascii=False, indent=2)
    print(run('firebase', 'deploy', '--only', 'remoteconfig', '--project', args.alias))


if __name__ == '__main__':
    main()
