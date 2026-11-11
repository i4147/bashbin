#!/data/data/com.termux/files/home/.local/bin/python
import errno
import hashlib
import locale
import sys
from pathlib import Path
from typing import NoReturn
CHUNK_SIZE: int = 32768
locale.setlocale(locale.LC_ALL, "")
def calc_hash(filename: str | Path, chunk_size: int = CHUNK_SIZE) -> str:
    """Calculate the SHA-256 hash of a file.
    Args:
        filename: Path to the file to hash.
        chunk_size: Size of chunks to read at a time.
    Returns:
        The hex digest of the file's SHA-256 hash.
    Raises:
        OSError: If the file cannot be read for reasons other than EINVAL.
    """
    h = hashlib.sha256()
    path = Path(filename)
    try:
        with path.open("rb") as fo:
            while chunk := fo.read(chunk_size):
                h.update(chunk)
            return h.hexdigest()
    except OSError as value:
        if value.errno == errno.EINVAL:
            return "d41d8cd98f00b204e9800998ecf8427e"
        raise
def printsum(filename: str | Path) -> None:
    """Print the SHA-256 hash and filename, or an error to stderr.
    Args:
        filename: Path to the file to hash.
    """
    try:
        sys.stdout.write(f"{calc_hash(filename)}  {filename}\n")
    except OSError as value:
        sys.stderr.write(f"sha256: {filename}: {value.strerror}\n")
def main(argv: list[str] | None = None) -> None:
    """Main entry point.
    Args:
        argv: List of filenames to process. Defaults to ``sys.argv[1:]``.
    """
    filenames = argv if argv is not None else sys.argv[1:]
    for filename in filenames:
        printsum(filename)
if __name__ == "__main__":
    main()
