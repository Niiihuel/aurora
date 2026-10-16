#!/usr/bin/env python3
"""Check aurora's translations.

    scripts/check-i18n.py [shell-dir]      # default: shell

Fails (exit 1) when:
  - a key passed to I18n.tr("...") in QML is missing from any language file;
  - a language file lacks keys that en.json (the reference) has, or has extra
    keys en.json doesn't;
  - a QML file sets visible text from a plain string literal
    (text:/title:/detail: "...") instead of I18n.tr — mark deliberate
    exceptions (brand names, symbols) with a trailing `// i18n-ignore`.

Dev-only files (gallery.qml) are exempt from the literal check. Keys built at
runtime can't be found by a scan: list them in a comment as
`// i18n-keys: area.one area.two` next to the code that builds them.
"""
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "shell")
i18n_dir = root / "i18n"
DEV_ONLY = {"gallery.qml"}

TR = re.compile(r'I18n\.tr\(\s*"([^"]+)"')
DECLARED = re.compile(r'i18n-keys:\s*([\w.\s]+)')
LITERAL = re.compile(r'\b(text|title|detail|placeholderText)\s*:\s*"[^"]*[A-Za-zÀ-ÿ][^"]*"')

errors = []

languages = {}
for f in sorted(i18n_dir.glob("*.json")):
    try:
        languages[f.stem] = json.loads(f.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{f}: invalid JSON: {e}")

if "en" not in languages:
    errors.append(f"{i18n_dir}/en.json is missing (English is the reference)")
reference = set(languages.get("en", {}))

used = {}
for qml in sorted(root.rglob("*.qml")):
    rel = qml.relative_to(root)
    for n, line in enumerate(qml.read_text().splitlines(), 1):
        for group in DECLARED.findall(line):
            for key in group.split():
                used.setdefault(key, f"{rel}:{n}")
        # Comment lines (docs, examples) aren't code.
        if line.lstrip().startswith(("//", "*", "/*")):
            continue
        for key in TR.findall(line):
            used.setdefault(key, f"{rel}:{n}")
        if qml.name not in DEV_ONLY and LITERAL.search(line) and "i18n-ignore" not in line and "I18n.tr" not in line:
            errors.append(f"{rel}:{n}: visible text is a plain string; use I18n.tr(\"key\") -> {line.strip()}")

def base(key):
    return re.sub(r"_(one|other)$", "", key)

declared = set(used)
for key, where in sorted(used.items()):
    # `I18n.tr("area.kind." + value)` is a runtime key: its literal part is a
    # prefix ending in "."; the full keys must be declared with i18n-keys.
    if key.endswith("."):
        if not any(k.startswith(key) and k != key for k in declared):
            errors.append(f"{where}: runtime key '{key}…' has no `// i18n-keys:` declaration")
        continue
    for code, strings in languages.items():
        if key not in strings and not any(base(k) == key for k in strings):
            errors.append(f"{where}: key '{key}' missing from {code}.json")

for code, strings in languages.items():
    if code == "en":
        continue
    keys = set(strings)
    for k in sorted(reference - keys):
        errors.append(f"{code}.json: missing '{k}' (present in en.json)")
    for k in sorted(keys - reference):
        errors.append(f"{code}.json: extra key '{k}' (not in en.json)")

unused = sorted(k for k in reference if not k.startswith("_meta.") and base(k) not in used and k not in used)
for k in unused:
    print(f"note: '{k}' is defined but not used", file=sys.stderr)

if errors:
    print("\n".join(errors), file=sys.stderr)
    print(f"\ni18n check failed: {len(errors)} problem(s)", file=sys.stderr)
    sys.exit(1)
print(f"i18n ok: {len(used)} keys used, languages: {', '.join(sorted(languages))}")
