#!/data/data/com.termux/files/home/.local/bin/python
import argparse
import locale
import sys
from collections.abc import Iterator
from typing import NoReturn
def sizes() -> Iterator[int]:
    """Yield the wasted space for each line from `findup --summary` output."""
    for line in sys.stdin:
        num, _mul, size, _rest = line.split(None, 3)
        num = int(num)
        size = int(size)
        num -= 1
        size *= num
        yield size
def human_num(num: float, divisor: int = 1, power: str = "") -> str:
    """Format a number with human-readable units.
    Args:
        num: The number to format.
        divisor: 1 for plain, 1000 for SI units, 1024 for binary units.
        power: The current power prefix (e.g., "K", "Ki").
    Returns:
        The formatted string with units.
    """
    num = float(num)
    if divisor == 1:
        return locale.format_string("%.f", num, grouping=True)
    elif divisor == 1000:
        powers: list[str] = [" ", "K", "M", "G", "T", "P"]
    elif divisor == 1024:
        powers = ["  ", "Ki", "Mi", "Gi", "Ti", "Pi"]
    else:
        raise ValueError("Invalid divisor")
    if not power:
        power = powers[0]
    while num >= 1000:
        num /= divisor
        power = powers[powers.index(power) + 1]
    if power.strip():
        num = locale.format_string("%6.1f", num, grouping=True)
    else:
        num = locale.format_string("%4.f", num, grouping=True) + "  "
    return f"{num}{power}"
def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments.
    Args:
        argv: List of arguments to parse. Defaults to ``sys.argv[1:]``.
    Returns:
        The parsed arguments namespace.
    """
    parser = argparse.ArgumentParser(description="Print the total wasted space given output from `findup --summary`")
    parser.add_argument(
        "--human",
        action="store_true",
        help="print the total in human readable form.",
    )
    return parser.parse_args(argv)
def main(argv: list[str] | None = None) -> None:
    """Main entry point for the script.
    Args:
        argv: List of command-line arguments. Defaults to ``sys.argv[1:]``.
    """
    args = parse_args(argv)
    if args.human:
        print(f"Total wasted space: {human_num(sum(sizes()), divisor=1024)}B")
    else:
        print(f"Total wasted space: {sum(sizes())} bytes")
if __name__ == "__main__":
    main()
