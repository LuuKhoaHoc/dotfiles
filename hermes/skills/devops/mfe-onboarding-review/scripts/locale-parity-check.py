#!/usr/bin/env python3
"""Locale parity + duplicate-key check cho namespace i18n (dùng trong MFE onboarding review).

Usage:
  python3 scripts/locale-parity-check.py packages/locales/src/translations/vi/partner.json packages/locales/src/translations/en/partner.json [vi/common.json en/common.json ...]

- `object_pairs_hook` bắt duplicate key (json.load mặc định âm thầm lấy giá trị cuối).
- Flat bằng dict-accumulate (generator `yield from` dễ quên -> false MISSING).
- Exit 1 khi có dup hoặc lệch parity.
"""
import json
import sys


def flat(o, prefix=""):
    out = {}
    for k, v in o.items():
        np = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flat(v, np))
        else:
            out[np] = v
    return out


def dup_keys(path):
    dups = []

    def hook(pairs):
        d = {}
        for k, v in pairs:
            if k in d:
                dups.append(k)
            d[k] = v
        return d

    json.load(open(path), object_pairs_hook=hook)
    return dups


def main():
    paths = sys.argv[1:]
    if len(paths) < 2:
        print(__doc__)
        sys.exit(2)

    all_dups = []
    for p in paths:
        dups = dup_keys(p)
        all_dups += dups
        print(f"{p}: dup_keys={dups}")

    # Cặp vi/en đầu tiên -> parity
    vi = flat(json.load(open(paths[0])))
    en = flat(json.load(open(paths[1])))
    only_vi, only_en = set(vi) - set(en), set(en) - set(vi)
    print(f"parity: vi keys={len(vi)} en keys={len(en)}")
    print("  missing in EN:", sorted(only_vi))
    print("  missing in VI:", sorted(only_en))

    if all_dups or only_vi or only_en:
        sys.exit(1)
    print("OK")


if __name__ == "__main__":
    main()