#!/data/data/com.termux/files/home/.local/bin/python
import os
import sys
from pathlib import Path
from typing import NoReturn
last_size: int = 0
last_inode: tuple[int, int] = (0, 0)
group_to_check: list[str] = []
write_group: int = 0
def write_out_group() -> None:
    """Write the current group of duplicate candidates to stdout."""
    sys.stdout.writelines(group_to_check)
def process_non_gui() -> None:
    """Process input in `--non-gui` mode: group lines by inode."""
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
    else:
        if len(inodes) > 1:
            sys.stdout.writelines(dups)
def process_gui() -> None:
    """Process input in GUI mode: group lines by size and inode."""
    global last_size, last_inode, group_to_check, write_group
    for line in sys.stdin:
        path: str
        dev: str
        inode: str
        size: str
        path, dev, inode, size = line.rstrip().split(" ")
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
    else:
        if write_group:
            write_out_group()
def main(argv: list[str] | None = None) -> None:
    """Main entry point.
    Args:
        argv: List of command-line arguments. Defaults to ``sys.argv[1:]``.
    """
    if len(argv if argv is not None else sys.argv[1:]) == 2 and (argv if argv is not None else sys.argv[1:])[0] == "--non-gui":
        process_non_gui()
    else:
        process_gui()
if __name__ == "__main__":
    main()
