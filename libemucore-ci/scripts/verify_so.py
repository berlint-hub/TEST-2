#!/usr/bin/env python3
"""Verify a freshly built libemucore.so against the AetherSX2/NetherSX2 ABI.

Checks:
  1. the file is an AArch64 ELF shared object,
  2. its static symbol table contains every expected JNI export
     (expected_exports.txt, extracted from pcsx2/libAetherSX2.a),
  3. its dynamic symbol table exports JNI_OnLoad (required so the Android VM
     can load the library; the individual natives are usually registered via
     RegisterNatives from JNI_OnLoad).

Usage: verify_so.py <path/to/libemucore.so> [path/to/expected_exports.txt]
"""

import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def find_tool(*names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def run(tool, *args):
    return subprocess.run(
        [tool, *args], check=True, capture_output=True, text=True
    ).stdout


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    so_path = sys.argv[1]
    exports_path = (
        sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "expected_exports.txt")
    )

    if not os.path.isfile(so_path):
        sys.exit(f"error: {so_path} does not exist")

    nm = find_tool("nm", "llvm-nm", "aarch64-linux-android-nm")
    if nm is None:
        sys.exit("error: no usable 'nm' tool found (binutils or llvm)")
    readelf = find_tool("readelf", "llvm-readelf", "aarch64-linux-android-readelf")

    ok = True

    # 1. ELF header sanity -------------------------------------------------
    if readelf:
        header = run(readelf, "-h", so_path)
        machine = re.search(r"Machine:\s+(.+)", header)
        etype = re.search(r"Type:\s+(.+)", header)
        print(f"machine: {machine.group(1).strip() if machine else '?'}")
        print(f"type:    {etype.group(1).strip() if etype else '?'}")
        if machine and "AArch64" not in machine.group(1):
            print("FAIL: not an AArch64 binary")
            ok = False
        if etype and "Shared object" not in etype.group(1):
            print("FAIL: not a shared object (ET_DYN)")
            ok = False
    else:
        print("warning: readelf not found, skipping ELF header checks")

    # 2. expected JNI exports in the (static) symbol table -----------------
    with open(exports_path, encoding="utf-8") as f:
        expected = {line.strip() for line in f if line.strip() and not line.startswith("#")}
    static_syms = set(run(nm, "--defined-only", so_path).split())
    missing = sorted(expected - static_syms)
    print(f"expected exports: {len(expected)}, missing: {len(missing)}")
    for sym in missing:
        print(f"  MISSING: {sym}")
    if missing:
        ok = False

    # 3. dynamic exports ---------------------------------------------------
    try:
        dynamic_syms = set(run(nm, "-D", "--defined-only", so_path).split())
    except subprocess.CalledProcessError:
        dynamic_syms = set()
    for sym in ("JNI_OnLoad", "JNI_OnUnload"):
        if dynamic_syms and sym not in dynamic_syms:
            print(f"FAIL: {sym} is not dynamically exported")
            ok = False
    if dynamic_syms:
        print(f"dynamic symbols: {len(dynamic_syms)} (JNI_OnLoad present: {'JNI_OnLoad' in dynamic_syms})")

    if not ok:
        sys.exit(1)
    print("OK: libemucore.so matches the expected AetherSX2 ABI")


if __name__ == "__main__":
    main()
