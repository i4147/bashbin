#!/data/data/com.termux/files/usr/bin/env python
"""Filter rmlint-style duplicate-candidate listings down to genuine duplicates.

Reads newline-delimited groups of file paths (or, in ``--non-gui`` mode,
groups separated by blank lines) from stdin and writes back only the groups
that contain more than one distinct inode, i.e. the groups that are not
already fully hardlinked together.
"""

import os
import sys

last_size: str = ""
last_inode: tuple[str, str] = ("", "")
group_to_check: list[str] = []
write_group: int = 0


def write_out_group() -> None:
    """Write the current group of duplicate candidates to stdout."""
    sys.stdout.writelines(group_to_check)


def process_non_gui() -> None:
    """Process input in `--non-gui` mode: group lines by inode.

    Each group of file paths is terminated by a blank line. A group is
    written back out only if it contains more than one distinct inode
    (i.e. the files are not already all hardlinked to each other).
    """
    dups: list[str] = []
    inodes: dict[int, bool] = {}
    for line in sys.stdin:
        path: str = line[:-1]
        if path == "":
            if len(inodes) > 1:
                sys.stdout.writelines(dups)
            dups = [line]
            inodes = {}
        else:
            try:
                inode: int = os.stat(path).st_ino
                dups.append(line)
                inodes[inode] = True
            except OSError:
                sys.stderr.write(str(sys.exc_info()[1]) + "\n")
    if len(inodes) > 1:
        sys.stdout.writelines(dups)


def process_gui() -> None:
    """Process input in GUI mode: group lines by size and inode.

    Each input line has the whitespace-separated fields ``path dev inode
    size``. Consecutive lines that share the same size form a candidate
    group; a group is written back out only if it contains more than one
    distinct ``(dev, inode)`` pair.
    """
    global last_size, last_inode, group_to_check, write_group
    for line in sys.stdin:
        dev: str
        inode: str
        size: str
        _path, dev, inode, size = line.rstrip().split(" ")
        if last_size and size == last_size:
            if (dev, inode) != last_inode:
                write_group = 1
            group_to_check.append(line)
        else:
            if write_group:
                write_out_group()
            group_to_check = [line]
            last_inode = (dev, inode)
            last_size = size
            write_group = 0
    if write_group:
        write_out_group()


def main(argv: list[str] | None = None) -> None:
    """Main entry point.
    Args:
        argv: List of command-line arguments. Defaults to ``sys.argv[1:]``.
    """
    args = argv if argv is not None else sys.argv[1:]
    if len(args) == 2 and args[0] == "--non-gui":
        process_non_gui()
    else:
        process_gui()


if __name__ == "__main__":
    main()
