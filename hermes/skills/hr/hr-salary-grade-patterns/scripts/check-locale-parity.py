#!/usr/bin/env python3
"""Check en/vi key parity for HR locale files (run from repo root).

Usage:
    python3 <path-to>/check-locale-parity.py              # whole hr.json
    python3 <path-to>/check-locale-parity.py features.salary.create.formulaNotes
Exits 1 with a diff listing when keys diverge; prints OK otherwise.
"""
import json
import sys

BASE = 'packages/locales/src/translations'


def load(lang: str) -> dict:
    with open(f'{BASE}/{lang}/hr.json', encoding='utf-8') as f:
        return json.load(f)


def subtree(data: dict, path: list[str]) -> dict:
    for key in path:
        data = data[key]
    return data


def leaf_keys(obj: dict, prefix: str = '') -> set[str]:
    out: set[str] = set()
    for k, v in obj.items():
        full = f'{prefix}.{k}' if prefix else k
        if isinstance(v, dict):
            out |= leaf_keys(v, full)
        else:
            out.add(full)
    return out


def main() -> int:
    vi, en = load('vi'), load('en')
    path = sys.argv[1].split('.') if len(sys.argv) > 1 else []
    vk = leaf_keys(subtree(vi, path))
    ek = leaf_keys(subtree(en, path))
    only_vi = sorted(vk - ek)
    only_en = sorted(ek - vk)
    if only_vi or only_en:
        print('vi-only:', only_vi)
        print('en-only:', only_en)
        return 1
    print('OK: en/vi keys are in sync')
    return 0


if __name__ == '__main__':
    sys.exit(main())
