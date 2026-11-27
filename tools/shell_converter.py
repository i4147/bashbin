#!/data/data/com.termux/files/usr/bin/env python3
import argparse
import os
from pathlib import Path
import re
import stat
import subprocess

TERMUX_PREFIX = os.environ.get("PREFIX", "/data/data/com.termux/files/usr")
TERMUX_BIN = f"{TERMUX_PREFIX}/bin"

ZSH_SHEBANG = f"#!{TERMUX_BIN}/zsh"
SH_SHEBANG = f"#!{TERMUX_BIN}/bash"

ZSH_COMPAT_BLOCK = (
    "setopt SH_WORD_SPLIT GLOB_SUBST\n"
    "unsetopt NOMATCH\n"
)


def detect_newline(lines: list[str]) -> str:
  if lines and lines[0].endswith("\r\n"):
    return "\r\n"
  return "\n"


def sh_to_zsh(content: str) -> str:
  # 1. Replace shopt and Bash builtins
  content = re.sub(r"\bshopt\s+-s\s+nullglob\s+dotglob\b", "setopt NULL_GLOB GLOB_DOTS", content)
  content = re.sub(r"\bshopt\s+-s\s+nullglob\s+nocaseglob\b", "setopt NULL_GLOB NO_CASE_GLOB", content)
  content = re.sub(r"\bshopt\s+-s\s+nullglob\b", "setopt NULL_GLOB", content)
  content = re.sub(r"\bshopt\s+-s\s+dotglob\b", "setopt GLOB_DOTS", content)
  content = re.sub(r"\bdeclare\s+-A\b", "typeset -A", content)
  content = re.sub(r"\bdeclare\s+-a\b", "typeset -a", content)
  content = re.sub(r"\bdeclare\s+-i\b", "typeset -i", content)
  content = re.sub(r"\btype\s+-P\b", "whence -p", content)

  # Rewrite hardcoded /bin or /usr/bin paths to Termux $PREFIX/bin
  content = re.sub(
      r"(?<![\w/])/(?:usr/)?bin/(bash|sh|zsh|env)\b",
      rf"{TERMUX_BIN}/\1",
      content,
  )

  # 2. Update shebang and inject Zsh compatibility options
  lines = content.splitlines(keepends=True)
  nl = detect_newline(lines)

  if lines and lines[0].startswith("#!"):
    lines[0] = ZSH_SHEBANG + nl
  else:
    lines.insert(0, ZSH_SHEBANG + nl)

  compat_block = ZSH_COMPAT_BLOCK.replace("\n", nl)
  first_compat_line = ZSH_COMPAT_BLOCK.splitlines()[0]

  if len(lines) <= 1 or not lines[1].startswith(first_compat_line):
    lines.insert(1, compat_block)

  return "".join(lines)


def zsh_to_sh(content: str) -> str:
  # 1. Strip injected Zsh compatibility options if present
  lines = content.splitlines(keepends=True)
  nl = detect_newline(lines)

  if lines and lines[0].startswith("#!"):
    lines[0] = SH_SHEBANG + nl
  else:
    lines.insert(0, SH_SHEBANG + nl)

  # Remove the 2-line Zsh compatibility header if it was inserted
  if len(lines) > 2 and lines[1].strip() == "setopt SH_WORD_SPLIT GLOB_SUBST" and lines[2].strip() == "unsetopt NOMATCH":
    del lines[1:3]

  content = "".join(lines)

  # 2. Reverse setopt and Zsh builtins back to Bash equivalents
  content = re.sub(r"\bsetopt\s+NULL_GLOB\s+GLOB_DOTS\b", "shopt -s nullglob dotglob", content)
  content = re.sub(r"\bsetopt\s+NULL_GLOB\s+NO_CASE_GLOB\b", "shopt -s nullglob nocaseglob", content)
  content = re.sub(r"\bsetopt\s+NULL_GLOB\b", "shopt -s nullglob", content)
  content = re.sub(r"\bsetopt\s+GLOB_DOTS\b", "shopt -s dotglob", content)
  content = re.sub(r"\btypeset\s+-A\b", "declare -A", content)
  content = re.sub(r"\btypeset\s+-a\b", "declare -a", content)
  content = re.sub(r"\btypeset\s+-i\b", "declare -i", content)
  content = re.sub(r"\bwhence\s+-p\b", "type -P", content)

  content = re.sub(
      r"(?<![\w/])/(?:usr/)?bin/(bash|sh|zsh|env)\b",
      rf"{TERMUX_BIN}/\1",
      content,
  )

  return content


def collect_targets(paths: list[str]) -> list[Path]:
  targets: list[Path] = []
  seen: set[Path] = set()

  for raw_path in paths:
    p = Path(raw_path).expanduser()
    if not p.exists():
      print(f"Warning: Path not found, skipping: {p}")
      continue

    if p.is_file():
      if not p.is_symlink() and p.suffix.lower() in {".sh", ".zsh"}:
        resolved = p.resolve()
        if resolved not in seen:
          seen.add(resolved)
          targets.append(p)
    elif p.is_dir():
      for item in sorted(p.rglob("*")):
        if item.is_file() and not item.is_symlink() and item.suffix.lower() in {".sh", ".zsh"}:
          resolved = item.resolve()
          if resolved not in seen:
            seen.add(resolved)
            targets.append(item)

  return targets


def update_repo_references(root: Path, converted_map: dict[str, str]) -> int:
  """Update references to renamed scripts (e.g., foo.sh -> foo.zsh) across git-tracked files."""
  if not converted_map:
    return 0

  stems = sorted(converted_map.keys(), key=len, reverse=True)
  pattern = re.compile(
      r"(?<![A-Za-z0-9_.-])(" + "|".join(re.escape(s) for s in stems) + r")(\.(?:sh|zsh))(?![A-Za-z0-9_.-])"
  )

  try:
    raw = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        stderr=subprocess.DEVNULL,
    )
  except (OSError, subprocess.CalledProcessError):
    return 0

  updated_files = 0
  for entry in raw.split(b"\x00"):
    if not entry:
      continue
    file_path = root / entry.decode("utf-8", errors="surrogateescape")
    if not file_path.is_file() or file_path.is_symlink():
      continue

    try:
      text = file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
      continue

    def repl(match: re.Match) -> str:
      stem, old_ext = match.group(1), match.group(2)
      target_ext = converted_map.get(stem)
      if target_ext and old_ext != target_ext:
        return f"{stem}{target_ext}"
      return match.group(0)

    new_text, count = pattern.subn(repl, text)
    if count > 0:
      file_path.write_text(new_text, encoding="utf-8")
      updated_files += 1

  return updated_files


def convert_file(src: Path, output_dir: Path | None = None) -> tuple[Path, str]:
  ext = src.suffix.lower()
  content = src.read_text(encoding="utf-8")

  if ext == ".sh":
    converted = sh_to_zsh(content)
    new_ext = ".zsh"
  else:
    converted = zsh_to_sh(content)
    new_ext = ".sh"

  new_name = src.with_suffix(new_ext).name
  dest = (output_dir / new_name) if output_dir else src.with_name(new_name)
  dest.parent.mkdir(parents=True, exist_ok=True)
  dest.write_text(converted, encoding="utf-8")

  try:
    src_mode = src.stat().st_mode
    if src_mode & stat.S_IXUSR:
      dest.chmod(dest.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
  except PermissionError:
    pass

  print(f"Converted: {src} -> {dest}")
  return dest, new_ext


def main():
  parser = argparse.ArgumentParser(
      description="Convert .sh files to .zsh and vice versa in Termux."
  )
  parser.add_argument(
      "paths",
      nargs="*",
      default=["."],
      help="One or more .sh/.zsh files or directories (defaults to '.')",
  )
  parser.add_argument(
      "-o",
      "--output-dir",
      type=Path,
      help="Optional output directory (defaults to alongside each source file)",
  )
  parser.add_argument(
      "--update-refs",
      action="store_true",
      help="Update references to renamed scripts across git-tracked files",
  )
  args = parser.parse_args()

  out_dir = args.output_dir.expanduser() if args.output_dir else None
  files = collect_targets(args.paths)

  if not files:
    print("No .sh or .zsh files found.")
    return

  converted_map: dict[str, str] = {}
  for file_path in files:
    _, new_ext = convert_file(file_path, out_dir)
    converted_map[file_path.stem] = new_ext

  if args.update_refs:
    updated = update_repo_references(Path.cwd(), converted_map)
    print(f"Updated references in {updated} git-tracked file(s).")


if __name__ == "__main__":
  main()
