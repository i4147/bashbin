#!/usr/bin/env python3
"""Migrate top-level Bash scripts and their command aliases to Zsh.

Run with ``--apply`` to rename root-level ``*.sh`` scripts to ``*.zsh``, set
Termux's Zsh interpreter and Bash-compatible word/glob options, translate a few
standard shell builtins, update matching in-repository references, and retarget
extensionless symlinks. Run with ``--check`` (the default) to verify the result.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHEBANG = "#!/data/data/com.termux/files/usr/bin/zsh"
PROLOGUE = "setopt SH_WORD_SPLIT GLOB_SUBST\nunsetopt NOMATCH\n"


def root_scripts() -> list[Path]:
    return sorted(
        path
        for path in ROOT.glob("*.sh")
        if path.is_file() and not path.is_symlink()
    )


def rewrite_bashisms(text: str) -> str:
    """Translate simple Bash-only setup commands to their Zsh equivalents."""
    text = text.replace(
        "shopt -s nullglob dotglob", "setopt NULL_GLOB GLOB_DOTS"
    )
    # In the migrated script the wildcard is `*`, so nocaseglob has no effect.
    text = text.replace("shopt -s nullglob nocaseglob", "setopt NULL_GLOB")
    text = text.replace("shopt -s nullglob", "setopt NULL_GLOB")
    text = re.sub(r"\bdeclare\s+-A\b", "typeset -A", text)
    text = re.sub(r"\bdeclare\s+-a\b", "typeset -a", text)
    text = re.sub(r"\bdeclare\s+-i\b", "typeset -i", text)
    text = re.sub(r"\btype\s+-P\b", "whence -p", text)
    return text


def with_zsh_header(text: str) -> str:
    lines = text.splitlines(keepends=True)
    newline = "\r\n" if lines and lines[0].endswith("\r\n") else "\n"
    if lines and lines[0].startswith("#!"):
        lines[0] = SHEBANG + newline
    else:
        lines.insert(0, SHEBANG + newline)

    # Keep the old Bash scripts' ordinary word splitting and unmatched-glob
    # behavior when they run under Zsh; array-indexing builtins are migrated
    # explicitly in the handful of scripts that use them.
    header = PROLOGUE.replace("\n", newline)
    if len(lines) > 1 and lines[1].startswith(PROLOGUE.splitlines()[0]):
        return "".join(lines)
    lines.insert(1, header)
    return "".join(lines)


def moved_script_names() -> list[str]:
    return [path.stem for path in root_scripts()]


def rewrite_references(names: list[str]) -> int:
    """Update text references to migrated root scripts, avoiding substrings."""
    if not names:
        return 0
    alternatives = "|".join(re.escape(name) for name in sorted(names, key=len, reverse=True))
    reference = re.compile(
        rf"(?<![A-Za-z0-9_.-])({alternatives})\.sh(?![A-Za-z0-9_.-])"
    )
    try:
        listed = subprocess.check_output(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            cwd=ROOT,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuntimeError(f"could not enumerate repository files: {error}") from error

    changed = 0
    for raw_path in listed.split(b"\0"):
        if not raw_path:
            continue
        path = ROOT / os.fsdecode(raw_path)
        if path == Path(__file__) or path.is_symlink() or not path.is_file():
            continue
        try:
            original = path.read_bytes()
            if b"\0" in original:
                continue
            text = original.decode("utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        updated = reference.sub(lambda match: f"{match.group(1)}.zsh", text)
        if updated != text:
            path.write_text(updated, encoding="utf-8", newline="")
            changed += 1
    return changed


def migrate() -> tuple[int, int, int]:
    scripts = root_scripts()
    destinations = [path.with_suffix(".zsh") for path in scripts]
    conflicts = [destination for destination in destinations if destination.exists()]
    if conflicts:
        raise RuntimeError(
            "refusing to overwrite existing destinations: "
            + ", ".join(str(path.relative_to(ROOT)) for path in conflicts)
        )

    names = [path.stem for path in scripts]
    for source, destination in zip(scripts, destinations):
        text = source.read_text(encoding="utf-8")
        text = with_zsh_header(rewrite_bashisms(text))
        mode = source.stat().st_mode
        source.rename(destination)
        destination.write_text(text, encoding="utf-8", newline="")
        destination.chmod(mode)

    links_changed = 0
    for path in sorted(ROOT.iterdir()):
        if not path.is_symlink():
            continue
        target = os.readlink(path)
        if target.endswith(".sh"):
            os.unlink(path)
            os.symlink(target[:-3] + ".zsh", path)
            links_changed += 1

    references_changed = rewrite_references(names)
    return len(scripts), links_changed, references_changed


def check() -> tuple[list[str], int, int]:
    problems: list[str] = []
    zsh_files = sorted(
        path
        for path in ROOT.glob("*.zsh")
        if path.is_file() and not path.is_symlink()
    )
    scripts: list[Path] = []
    shell_sources = sorted(ROOT.glob("*.sh"))
    if shell_sources:
        problems.append(f"{len(shell_sources)} root .sh path(s) remain")

    for path in zsh_files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            problems.append(f"cannot read {path.name}: {error}")
            continue
        lines = text.splitlines()
        first_line = lines[0] if lines else ""
        if first_line.startswith("#!"):
            if first_line != SHEBANG:
                problems.append(f"{path.name}: incorrect Zsh shebang")
            scripts.append(path)
            bash_only_patterns = (
                r"\bshopt\b",
                r"\bmapfile\b",
                r"\breadarray\b",
                r"\bcompgen\b",
                r"\bexport\s+-f\b",
                r"\bdeclare\s+-",
                r"\btype\s+-P\b",
                r"\bread\s+[^\n]*\s-p\s",
                r"\$\{![^}]+\[@\]\}",
            )
            for pattern in bash_only_patterns:
                if re.search(pattern, text):
                    problems.append(f"{path.name}: contains unconverted Bash syntax ({pattern})")
                    break

    reference_names = [path.stem for path in zsh_files]
    if reference_names:
        alternatives = "|".join(
            re.escape(name) for name in sorted(reference_names, key=len, reverse=True)
        )
        stale_reference = re.compile(
            rf"(?<![A-Za-z0-9_.-])({alternatives})\.sh(?![A-Za-z0-9_.-])"
        )
        try:
            listed = subprocess.check_output(
                ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                cwd=ROOT,
            )
            for raw_path in listed.split(b"\0"):
                if not raw_path:
                    continue
                candidate = ROOT / os.fsdecode(raw_path)
                if candidate.is_symlink() or not candidate.is_file():
                    continue
                try:
                    data = candidate.read_bytes()
                    if b"\0" in data:
                        continue
                    content = data.decode("utf-8")
                except (OSError, UnicodeDecodeError):
                    continue
                if stale_reference.search(content):
                    problems.append(
                        f"{candidate.relative_to(ROOT)}: contains a stale reference to a root .sh script"
                    )
        except (OSError, subprocess.CalledProcessError) as error:
            problems.append(f"could not verify script references: {error}")

    links = [path for path in ROOT.iterdir() if path.is_symlink()]
    broken_links = [path.name for path in links if not path.exists()]
    wrong_targets = [
        f"{path.name} -> {os.readlink(path)}"
        for path in links
        if os.readlink(path).endswith(".sh")
    ]
    if broken_links:
        problems.append("broken root symlinks: " + ", ".join(broken_links))
    if wrong_targets:
        problems.append("root symlinks still target .sh files: " + ", ".join(wrong_targets))

    zsh_executable = shutil.which("zsh")
    if zsh_executable:
        for path in scripts:
            result = subprocess.run(
                [zsh_executable, "-n", str(path)],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
            if result.returncode:
                details = result.stderr.strip() or result.stdout.strip()
                problems.append(f"{path.name}: Zsh syntax check failed: {details}")
    return problems, len(scripts), len(links)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="perform the migration")
    mode.add_argument("--check", action="store_true", help="verify the migrated tree (default)")
    args = parser.parse_args()

    try:
        if args.apply:
            renamed, links, references = migrate()
            print(
                f"Migrated {renamed} root scripts; retargeted {links} symlinks; "
                f"updated references in {references} text file(s)."
            )
        problems, scripts, links = check()
    except (OSError, RuntimeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if problems:
        for problem in problems:
            print(f"FAIL: {problem}", file=sys.stderr)
        return 1
    print(f"OK: {scripts} root .zsh scripts; {links} root symlinks resolve and target .zsh files.")
    if not shutil.which("zsh"):
        print("NOTE: zsh is not installed here; native zsh -n checks were skipped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
