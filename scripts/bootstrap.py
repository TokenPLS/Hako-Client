#!/usr/bin/env python3
"""Build the pinned public SDK and materialize the pinned Adapter sources."""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def run(*args, cwd=ROOT, env=None):
    subprocess.run(args,cwd=cwd,env=env,check=True)

def checkout(name, pin):
    path=ROOT/'.build/dependencies'/name
    if not path.exists():
        path.parent.mkdir(parents=True,exist_ok=True)
        run('git','clone',pin['repository'],str(path))
    remote=subprocess.check_output(['git','remote','get-url','origin'],cwd=path,text=True).strip()
    if remote!=pin['repository']: raise RuntimeError('Unexpected dependency origin')
    if subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=path):
        raise RuntimeError('Dependency checkout contains changes')
    run('git','fetch','origin',pin['revision'],cwd=path)
    run('git','checkout','--detach',pin['revision'],cwd=path)
    return path

def inventory(path):
    return {str(p.relative_to(path)):('link:'+os.readlink(p) if p.is_symlink() else hashlib.sha256(p.read_bytes()).hexdigest())
            for p in sorted(path.rglob('*')) if p.is_file() or p.is_symlink()}

def verify_sdk(sdk, revision):
    manifest=plistlib.loads((sdk/'Info.plist').read_bytes())
    slices=manifest['AvailableLibraries']
    actual={(x['SupportedPlatform'],x.get('SupportedPlatformVariant','')) for x in slices}
    if actual!={('ios',''),('ios','simulator'),('tvos',''),('tvos','simulator'),('macos','')}:
        raise RuntimeError('Expected all five Apple SDK slices')
    for entry in slices:
        info=json.loads((sdk/entry['LibraryIdentifier']/'Hako.framework/Versions/A/Resources/HakoBuildInfo.json').read_text())
        if info['sourceRevision']!=revision or info['sourceDirty'] or info['internalDiagnostics'] or info['debugBuild']:
            raise RuntimeError('SDK provenance does not match public source build')

def main():
    lock=json.loads((ROOT/'Dependencies.lock.json').read_text())
    kernel=checkout('kernel',lock['kernel']);adapter=checkout('adapter',lock['adapter'])
    sdk=kernel/'Hako.xcframework';receipt=kernel.parent/'sdk-inventory.json'
    reuse=sdk.exists() and receipt.exists() and json.loads(receipt.read_text())==inventory(sdk)
    if not reuse:
        if sdk.exists(): raise RuntimeError('Unverified SDK exists; move it aside before rebuilding')
        bins=ROOT/'.build/bin';bins.mkdir(parents=True,exist_ok=True)
        env=dict(os.environ,GOBIN=str(bins),PATH=str(bins)+os.pathsep+os.environ['PATH'])
        for tool in ('gomobile','gobind'): run('go','install',lock[tool],env=env)
        run('make','lib_apple',cwd=kernel,env=env)
        verify_sdk(sdk,lock['kernel']['revision'])
        receipt.write_text(json.dumps(inventory(sdk),sort_keys=True))
    verify_sdk(sdk,lock['kernel']['revision'])
    target=ROOT/'Hako.xcframework'
    if target.exists() or target.is_symlink():
        if not target.is_symlink() or target.resolve()!=sdk.resolve(): raise RuntimeError('Refusing to replace SDK')
    else: target.symlink_to(sdk.relative_to(ROOT),target_is_directory=True)
    vendor=ROOT/'Vendor/HakoAdapter/Sources/HakoAdapter';vendor.mkdir(parents=True,exist_ok=True)
    for source in (adapter/'Sources/HakoAdapter').glob('*.swift'):
        dest=vendor/source.name
        if dest.exists() and dest.read_bytes()!=source.read_bytes(): raise RuntimeError('Adapter has local modifications')
        shutil.copyfile(source,dest)
    shutil.copyfile(adapter/'LICENSE',vendor.parent.parent/'LICENSE')
    print('Public dependencies verified. Run python3 scripts/configure.py, then build an app scheme.')

if __name__=='__main__':main()
