#!/usr/bin/env python3
"""Deduplicate files by hardlinking or symlinking duplicates to the first occurrence.
Reads file paths from stdin, groups consecutive duplicates, and either:
- hardlinks them to the first file (default)
- symlinks them to the first file (symlink mode)
- deletes them (del mode)
"""
import os
import sys
from pathlib import Path
from typing import Literal, TextIO
# Type aliases
Mode = Literal["link", "del", "symlink"]
Suffix = str
def parse_args(args: list[str]) -> tuple[Mode, bool]:
    """Parse command line arguments.
    Args:
        args: Command line arguments (excluding program name)
    Returns:
        Tuple of (mode, dry_run) where mode is one of "link", "del", or "symlink"
    Raises:
        ValueError: If an invalid argument is provided
    """
    if len(args) != 1:
        return "link", False
    arg = args[0]
    mode_map: dict[str, tuple[Mode, bool]] = {
        "del": ("del", False),
        "tdel": ("del", True),
        "tmerge": ("link", True),
        "symlink": ("symlink", False),
        "tsymlink": ("symlink", True),
    }
    if arg not in mode_map:
        raise ValueError(f"Invalid argument: {arg}")
    return mode_map[arg]
def create_link(source: Path, target: Path, suffix: str, mode: Mode) -> None:
    """Create a hardlink or symlink from source to target.
    Args:
        source: The file to link from (the keeper)
        target: The file to link to (the duplicate)
        suffix: Backup suffix for existing files
        mode: Either "link" for hardlink or "symlink" for symlink
    """
    backup_target = Path(f"{target}{suffix}")
    try:
        if mode == "link":
            # Try hardlink first, fall back to symlink if it fails
            try:
                os.link(source, target)
            except OSError:
                os.symlink(source, target)
        else:  # symlink mode
            os.symlink(source, target)
    except OSError:
        # If target exists, try with backup
        if target.exists():
            target.rename(backup_target)
            try:
                if mode == "link":
                    os.link(source, target)
                else:
                    os.symlink(source, target)
            finally:
                backup_target.unlink(missing_ok=True)
        else:
            raise
def process_files(
    input_stream: TextIO = sys.stdin,
    mode: Mode = "link",
    dry_run: bool = False,
) -> None:
    """Process file paths from input stream and deduplicate them.
    Args:
        input_stream: File-like object to read paths from (default: stdin)
        mode: Operation mode - "link", "del", or "symlink"
        dry_run: If True, only print what would be done without executing
    """
    suffix = f".fixdup.{os.getpid()}"
    keep_file: Path | None = None
    for line in input_stream:
        file_path = line.strip()
        if not file_path:
            # Empty line resets the keeper
            keep_file = None
            continue
        current = Path(file_path)
        if keep_file is None:
            # First file in group becomes the keeper
            keep_file = current
            if dry_run:
                print(f"\n\nkeeping:     {keep_file}")
                action = {
                    "link": "hardlinking: ",
                    "symlink": "symlinking: ",
                    "del": "deleting: ",
                }[mode]
                print(action, end="")
        else:
            # Duplicate file - process according to mode
            if dry_run:
                print(f"{current} ", end="")
            else:
                if mode == "del":
                    current.unlink(missing_ok=True)
                else:
                    create_link(keep_file, current, suffix, mode)
    if dry_run and keep_file is not None:
        print()
def main() -> None:
    """Main entry point."""
    try:
        mode, dry_run = parse_args(sys.argv[1:])
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("Usage: dedup [del|tdel|tmerge|symlink|tsymlink]", file=sys.stderr)
        sys.exit(1)
    process_files(mode=mode, dry_run=dry_run)
if __name__ == "__main__":
    main()
