#!/usr/bin/env python3
"""Exercise the Compose cache dependency using isolated projects and volumes.

Usage: python3 tests/cache_startup.py [--image BACKEND_IMAGE ...]
No application services, published ports, real env files or live data are used.
"""

import argparse
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]


def run(*args, check=True):
    result = subprocess.run(args, text=True, capture_output=True, timeout=120)
    if check and result.returncode:
        raise RuntimeError(f'{args[0]} failed:\n{result.stdout}\n{result.stderr}')
    return result


PROBE = '''
test "$(id -u):$(id -g)" = 10001:10001
cache="${PU_SAVE_REPO_PATH:-repo_cache}"
test -w "$cache"
if [ -f "$cache/preserved" ]; then test "$(cat "$cache/preserved")" = original; fi
mkdir -p "$cache/repo"
git -C "$cache/repo" init -q
git -C "$cache/repo" config user.name Test
git -C "$cache/repo" config user.email test@example.invalid
printf 'change\n' >> "$cache/repo/data"
git -C "$cache/repo" add data
git -C "$cache/repo" commit -qm test
clone="$(mktemp -d)"
git clone -q "$cache/repo" "$clone"
git -C "$clone" fetch -q origin
touch "$cache/backend-started"
'''


def scenario(model, image, cache_path, seed, fail=False):
    project = 'pepeunit-cache-test-' + uuid.uuid4().hex[:12]
    with tempfile.TemporaryDirectory(prefix=project) as directory:
        directory = Path(directory)
        env_file = directory / 'test.env'
        env_file.write_text('')
        config = directory / 'compose.json'
        services = {name: copy.deepcopy(model['services'][name])
                    for name in ('backend-cache-init', 'backend')}
        for service in services.values():
            service['image'] = image
            service['volumes'][0]['target'] = '/app/' + cache_path
            service['environment'] = {'PU_SAVE_REPO_PATH': cache_path}
            for key in ('container_name', 'ports', 'networks'):
                service.pop(key, None)
            service['network_mode'] = 'none'
        services['backend-cache-init']['volumes'][1]['source'] = str(ROOT / 'scripts/prepare_repo_cache.sh')
        backend = services['backend']
        backend['restart'] = 'no'
        backend['command'] = ['/bin/bash', '-ec', PROBE.replace('$', '$$')]
        # Keep the actual dependency graph, but replace databases and brokers
        # with inert containers. Only the cache initializer performs real work.
        for name in backend['depends_on']:
            if name != 'backend-cache-init':
                services[name] = {'image': image, 'command': ['sleep', '300'],
                                  'network_mode': 'none'}
        if fail:
            services['backend-cache-init']['volumes'][0]['read_only'] = True
        config.write_text(json.dumps({'services': services,
                                      'volumes': {'backend_repo_cache': {}}}))
        compose = ['docker', 'compose', '--env-file', str(env_file),
                   '-p', project, '-f', str(config)]
        volume = project + '_backend_repo_cache'

        def root_cache(command):
            return run('docker', 'run', '--rm', '--user', '0:0', '--network', 'none',
                       '-v', volume + ':/cache', image, '/bin/bash', '-ec', command)

        def start_and_check():
            result = run(*compose, 'up', '-d', 'backend', check=not fail)
            if fail:
                assert result.returncode, 'Backend started despite failed initialization'
                container = run(*compose, 'ps', '-aq', 'backend').stdout.strip()
                if container:
                    state = json.loads(run('docker', 'inspect', container).stdout)[0]['State']
                    assert state['Status'] == 'created', state
                root_cache('test ! -e /cache/backend-started')
                return
            container = run(*compose, 'ps', '-aq', 'backend').stdout.strip()
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                state = json.loads(run('docker', 'inspect', container).stdout)[0]['State']
                if not state['Running']:
                    assert state['ExitCode'] == 0, run(*compose, 'logs', 'backend').stdout
                    break
                time.sleep(0.2)
            else:
                raise AssertionError('Backend permission probe did not finish')
            root_cache('test -f /cache/backend-started; test "$(stat -c %u:%g /cache)" = 10001:10001')

        try:
            run(*compose, 'create', 'backend')
            if seed:
                root_cache('printf original > /cache/preserved; chown -R 0:0 /cache; chmod 0700 /cache')
            start_and_check()
            if seed and not fail:
                # Restoring a backup can reintroduce old owners. A plain up
                # must rerun the initializer without a manual chown command.
                root_cache('rm /cache/backend-started; chown -R 0:0 /cache; chmod 0700 /cache')
                start_and_check()
            print(f'PASS {image}: path={cache_path!r}, old_cache={seed}, init_failure={fail}', flush=True)
        finally:
            run(*compose, 'down', '--volumes', '--remove-orphans')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', action='append', help='Override the backend image for testing')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        env_file = Path(directory) / 'test.env'
        env_file.write_text('')
        model = json.loads(run('docker', 'compose', '--env-file', str(env_file),
                              '-f', str(ROOT / 'docker-compose.yml'), 'config',
                              '--no-interpolate', '--no-normalize', '--no-path-resolution',
                              '--format', 'json').stdout)
    backend = model['services']['backend']
    initializer = model['services']['backend-cache-init']
    assert backend['image'] == initializer['image']
    assert backend['volumes'][0] == initializer['volumes'][0]
    assert backend['user'] == '10001:10001'
    assert backend['depends_on']['backend-cache-init']['condition'] == 'service_completed_successfully'
    for image in args.image or [backend['image']]:
        scenario(model, image, 'repo_cache', seed=False)
        scenario(model, image, 'repo_cache', seed=True)
        scenario(model, image, 'custom cache/repos', seed=True)
        scenario(model, image, 'repo_cache', seed=True, fail=True)


if __name__ == '__main__':
    main()
