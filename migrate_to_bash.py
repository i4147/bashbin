#!/data/data/com.termux/files/usr/bin/env python
"""Migrate shell scripts between Zsh and Bash.

By default, check the selected paths for a completed Zsh-to-Bash migration.
Use --reverse for Bash-to-Zsh migration.

Examples:
    python migrate.py --check
    python migrate.py --apply ~/project
    python migrate.py --reverse --dry-run --colored-diff ~/project
    python migrate.py --apply --backup --verbose file.zsh other-directory

This tool is not a complete shell-language translator. It changes shebangs,
converts a few standalone option commands, and updates textual filename
references. Review the diff and test the resulting scripts.

Migration is not transactional: an error or interruption can leave a partially
migrated tree. Use version control or another independent backup when needed.
"""

from __future__ import annotations

import argparse
import difflib
import multiprocessing
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, TextIO

from loguru import logger


WORKERS: int = 8
CHUNK_SIZE: int = 1024 * 1024

TERMUX_BIN: Path = Path("/data/data/com.termux/files/usr/bin")
SELF: Path = Path(__file__).resolve()

SKIP_DIRS: frozenset[str] = frozenset(
    {
        ".git",
        ".hg",
        ".svn",
        ".venv",
        "venv",
        ".tox",
        ".nox",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        ".ruff_cache",
        ".cache",
        "node_modules",
        "vendor",
        ".next",
        ".nuxt",
        ".output",
        ".turbo",
        ".parcel-cache",
        ".vite",
        "build",
        "dist",
        "coverage",
        "target",
    }
)

PROLOGUE: tuple[str, ...] = (
    "setopt SH_WORD_SPLIT GLOB_SUBST",
    "unsetopt NOMATCH",
)

TO_BASH: dict[str, str] = {
    "setopt NULL_GLOB GLOB_DOTS": "shopt -s nullglob dotglob",
    "setopt NULL_GLOB": "shopt -s nullglob",
}

TO_ZSH: dict[str, str] = {
    value: key for key, value in TO_BASH.items()
}


@dataclass(frozen=True)
class Config:
    source_suffix: str
    target_suffix: str
    target_shell: str
    shebang: str
    reverse: bool
    dry_run: bool
    backup: bool
    diff: bool


@dataclass(frozen=True)
class Job:
    path: Path
    destination: Path | None
    names: tuple[str, ...]
    config: Config


@dataclass(frozen=True)
class Result:
    path: Path
    destination: Path | None
    changed: bool
    diff: str = ""
    warning: str = ""
    error: str = ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--apply",
        action="store_true",
        help="apply changes and then check the selected tree",
    )
    mode.add_argument(
        "--check",
        action="store_true",
        help="check only; the default when no migration mode is given",
    )
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="show what would change without modifying files",
    )

    parser.add_argument(
        "--reverse",
        action="store_true",
        help="migrate Bash to Zsh instead of Zsh to Bash",
    )
    parser.add_argument(
        "--only",
        metavar="STEMS",
        help="comma-separated script stems to include",
    )
    parser.add_argument(
        "--backup",
        action="store_true",
        help=(
            "create an adjacent .bak copy before changing each file; "
            "existing backups are never overwritten"
        ),
    )
    parser.add_argument(
        "--colored-diff",
        action="store_true",
        help=(
            "print unified diffs, using color when stdout is a terminal; "
            "implies --dry-run unless --apply is specified"
        ),
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="log unchanged and skipped files as well as key events",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="files or directories to scan; defaults to the current directory",
    )

    args = parser.parse_args()

    if args.check and (args.backup or args.colored_diff):
        parser.error("--check cannot be combined with --backup or --colored-diff")

    if args.backup and not (args.apply or args.dry_run or args.colored_diff):
        parser.error("--backup requires --apply or --dry-run")

    return args


def make_config(args: argparse.Namespace) -> Config:
    if args.reverse:
        source_suffix = ".sh"
        target_suffix = ".zsh"
        target_shell = "zsh"
    else:
        source_suffix = ".zsh"
        target_suffix = ".sh"
        target_shell = "bash"

    return Config(
        source_suffix=source_suffix,
        target_suffix=target_suffix,
        target_shell=target_shell,
        shebang=f"#!{TERMUX_BIN / target_shell}",
        reverse=args.reverse,
        dry_run=args.dry_run or (args.colored_diff and not args.apply),
        backup=args.backup,
        diff=args.colored_diff,
    )


def parse_only(value: str | None) -> set[str] | None:
    if value is None:
        return None

    parts = [part.strip() for part in value.split(",")]

    if any(
        not part
        or part in {".", ".."}
        or "/" in part
        or "\\" in part
        for part in parts
    ):
        raise ValueError("--only must contain nonempty script stems, not paths")

    return set(parts)


def scan(inputs: list[Path]) -> list[Path]:
    files: set[Path] = set()
    pending = list(inputs or [Path.cwd()])

    while pending:
        path = pending.pop()

        if path.is_symlink():
            logger.debug("Skipped symlink {}", path)
            continue

        if not path.exists():
            raise FileNotFoundError(f"path does not exist: {path}")

        if path.is_file():
            resolved = path.resolve(strict=True)

            if resolved != SELF:
                files.add(resolved)

            continue

        if path.is_dir():
            if path.name in SKIP_DIRS:
                logger.debug("Skipped directory {}", path)
                continue

            try:
                pending.extend(path.iterdir())
            except OSError as exc:
                raise OSError(f"cannot scan directory {path}: {exc}") from exc

            continue

        logger.debug("Skipped non-regular path {}", path)

    return sorted(files)


def select_scripts(
    files: list[Path],
    suffix: str,
    only: set[str] | None,
) -> list[Path]:
    return [
        path
        for path in files
        if path.suffix == suffix
        and (only is None or path.stem in only)
    ]


def validate_only(only: set[str] | None, scripts: list[Path]) -> None:
    if only is None:
        return

    missing = only - {path.stem for path in scripts}

    if missing:
        raise ValueError(
            "selected scripts not found: " + ", ".join(sorted(missing))
        )


def is_utf8_text(path: Path) -> bool:
    try:
        with path.open("r", encoding="utf-8", newline="") as stream:
            while chunk := stream.read(CHUNK_SIZE):
                if "\0" in chunk:
                    return False
    except UnicodeDecodeError:
        return False

    return True


def reference_pattern(names: tuple[str, ...], suffix: str) -> re.Pattern[str] | None:
    if not names:
        return None

    alternatives = "|".join(
        re.escape(name)
        for name in sorted(names, key=len, reverse=True)
    )

    return re.compile(
        rf"(?<![A-Za-z0-9_.-])"
        rf"({alternatives}){re.escape(suffix)}"
        rf"(?![A-Za-z0-9_.-])"
    )


def replace_references(
    text: str,
    pattern: re.Pattern[str] | None,
    target_suffix: str,
) -> str:
    if pattern is None:
        return text

    return pattern.sub(lambda match: match.group(1) + target_suffix, text)


def line_ending(line: str) -> str:
    if line.endswith("\r\n"):
        return "\r\n"
    if line.endswith("\n"):
        return "\n"
    if line.endswith("\r"):
        return "\r"
    return ""


def convert_command(line: str, reverse: bool) -> str:
    ending = line_ending(line)
    content = line[: -len(ending)] if ending else line
    indentation = content[: len(content) - len(content.lstrip(" \t"))]
    command = content[len(indentation) :]
    mapping = TO_ZSH if reverse else TO_BASH

    return indentation + mapping.get(command, command) + ending


def transformed_lines(stream: TextIO, job: Job) -> Iterator[str]:
    config = job.config
    pattern = reference_pattern(job.names, config.source_suffix)

    if job.destination is None:
        for line in stream:
            yield replace_references(line, pattern, config.target_suffix)
        return

    first = stream.readline()
    newline = line_ending(first) or "\n"

    yield config.shebang + newline

    if config.reverse:
        for option in PROLOGUE:
            yield option + newline

    if first and not first.startswith("#!"):
        yield replace_references(
            convert_command(first, config.reverse),
            pattern,
            config.target_suffix,
        )

    removing_prologue = not config.reverse

    for line in stream:
        if removing_prologue:
            if line.rstrip("\r\n") in PROLOGUE:
                continue
            removing_prologue = False

        yield replace_references(
            convert_command(line, config.reverse),
            pattern,
            config.target_suffix,
        )


def files_equal(first: Path, second: Path) -> bool:
    if first.stat().st_size != second.stat().st_size:
        return False

    with first.open("rb") as left, second.open("rb") as right:
        while True:
            left_chunk = left.read(CHUNK_SIZE)
            right_chunk = right.read(CHUNK_SIZE)

            if left_chunk != right_chunk:
                return False

            if not left_chunk:
                return True


def make_diff(original: Path, updated: Path, destination: Path) -> str:
    with original.open("r", encoding="utf-8", newline="") as old_stream:
        old_lines = old_stream.readlines()

    with updated.open("r", encoding="utf-8", newline="") as new_stream:
        new_lines = new_stream.readlines()

    return "".join(
        difflib.unified_diff(
            old_lines,
            new_lines,
            fromfile=str(original),
            tofile=str(destination),
        )
    )


def backup_path(path: Path) -> Path:
    return path.with_name(path.name + ".bak")


def create_backup(path: Path) -> Path:
    destination = backup_path(path)

    with path.open("rb") as source:
        with destination.open("xb") as backup:
            try:
                shutil.copyfileobj(source, backup, length=CHUNK_SIZE)
            except BaseException:
                backup.close()
                destination.unlink(missing_ok=True)
                raise

    try:
        shutil.copystat(path, destination, follow_symlinks=False)
    except OSError:
        destination.unlink(missing_ok=True)
        raise

    return destination


def process_file(job: Job) -> Result:
    path = job.path
    temporary: Path | None = None

    try:
        if not is_utf8_text(path):
            if job.destination is not None:
                return Result(
                    path=path,
                    destination=job.destination,
                    changed=False,
                    error="script is binary or is not valid UTF-8",
                )

            return Result(
                path=path,
                destination=None,
                changed=False,
                warning="skipped binary or non-UTF-8 file",
            )

        mode = stat.S_IMODE(path.stat().st_mode)

        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            prefix=".shell-migrate-",
            dir=path.parent,
            delete=False,
        ) as output:
            temporary = Path(output.name)

            with path.open("r", encoding="utf-8", newline="") as source:
                for line in transformed_lines(source, job):
                    output.write(line)

        temporary.chmod(mode)

        changed = job.destination is not None or not files_equal(path, temporary)

        if not changed:
            return Result(path=path, destination=None, changed=False)

        diff = ""
        if job.config.diff:
            diff = make_diff(path, temporary, job.destination or path)

        if job.config.dry_run:
            return Result(
                path=path,
                destination=job.destination,
                changed=True,
                diff=diff,
            )

        if job.config.backup:
            create_backup(path)

        if job.destination is None:
            temporary.replace(path)
            temporary = None
        else:
            job.destination.hardlink_to(temporary)
            temporary.unlink()
            temporary = None

            try:
                path.unlink()
            except OSError:
                job.destination.unlink(missing_ok=True)
                raise

        return Result(
            path=path,
            destination=job.destination,
            changed=True,
            diff=diff,
        )

    except (OSError, UnicodeError) as exc:
        return Result(
            path=path,
            destination=job.destination,
            changed=False,
            error=str(exc),
        )

    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError as exc:
                logger.error(
                    "Could not remove temporary file {}: {}",
                    temporary,
                    exc,
                )


def print_diff(diff: str) -> None:
    if not diff:
        return

    use_color = sys.stdout.isatty()

    for line in diff.splitlines(keepends=True):
        if not use_color:
            sys.stdout.write(line)
            continue

        if line.startswith(("---", "+++")):
            color = "\033[1m"
        elif line.startswith("@@"):
            color = "\033[36m"
        elif line.startswith("+"):
            color = "\033[32m"
        elif line.startswith("-"):
            color = "\033[31m"
        else:
            color = ""

        if color:
            sys.stdout.write(color + line.rstrip("\r\n") + "\033[0m")
            sys.stdout.write(line[len(line.rstrip("\r\n")) :])
        else:
            sys.stdout.write(line)

    if not diff.endswith(("\n", "\r")):
        sys.stdout.write("\n")


def migrate(
    files: list[Path],
    config: Config,
    only: set[str] | None,
) -> bool:
    sources = select_scripts(files, config.source_suffix, only)
    validate_only(only, sources)

    if not sources:
        logger.info("No {} scripts found", config.source_suffix)
        return True

    destinations = {
        source: source.with_suffix(config.target_suffix)
        for source in sources
    }

    conflicts = [
        destination
        for destination in destinations.values()
        if destination.exists() or destination.is_symlink()
    ]

    if conflicts:
        raise FileExistsError(
            "destinations already exist: "
            + ", ".join(str(path) for path in conflicts)
        )

    for source in sources:
        if not is_utf8_text(source):
            raise ValueError(f"script is binary or is not valid UTF-8: {source}")

    names = tuple(sorted({source.stem for source in sources}))

    logger.warning(
        "Reference updates are textual and may affect unrelated paths or prose"
    )
    logger.warning(
        "Shell conversion is incomplete; review and test the results"
    )

    if config.backup and config.dry_run:
        logger.info("Dry run: no backup files will be created")

    jobs = (
        Job(
            path=path,
            destination=destinations.get(path),
            names=names,
            config=config,
        )
        for path in files
    )

    failed = False
    changed_count = 0

    with multiprocessing.Pool(processes=WORKERS) as pool:
        for result in pool.imap_unordered(process_file, jobs, chunksize=8):
            if result.error:
                failed = True
                logger.error("{}: {}", result.path, result.error)
                continue

            if result.warning:
                logger.debug("{}: {}", result.path, result.warning)
                continue

            if not result.changed:
                logger.debug("Unchanged {}", result.path)
                continue

            changed_count += 1
            action = "Would update" if config.dry_run else "Updated"

            if result.destination is not None:
                logger.info(
                    "{} {} -> {}",
                    action,
                    result.path,
                    result.destination,
                )
            else:
                logger.info("{} {}", action, result.path)

            if result.diff:
                print_diff(result.diff)

    if failed:
        logger.error(
            "One or more operations failed; the tree may be partially migrated"
        )
        return False

    logger.success(
        "{} {} file(s), including {} script(s)",
        "Would change" if config.dry_run else "Changed",
        changed_count,
        len(sources),
    )

    return True


def check_script(path: Path, config: Config, executable: str | None) -> list[str]:
    problems: list[str] = []

    try:
        with path.open("r", encoding="utf-8", newline="") as stream:
            first = stream.readline().rstrip("\r\n")

        if first != config.shebang:
            problems.append(f"{path}: incorrect or missing shebang")

    except (OSError, UnicodeDecodeError) as exc:
        return [f"{path}: cannot read script: {exc}"]

    if executable is not None:
        try:
            result = subprocess.run(
                [executable, "-n", str(path)],
                capture_output=True,
                text=True,
                errors="replace",
                check=False,
            )
        except OSError as exc:
            problems.append(f"{path}: syntax check could not run: {exc}")
        else:
            if result.returncode:
                details = result.stderr.strip() or result.stdout.strip()
                problems.append(
                    f"{path}: {config.target_shell} -n failed: {details}"
                )

    return problems


def check(files: list[Path], config: Config, only: set[str] | None) -> bool:
    problems: list[str] = []

    sources = select_scripts(files, config.source_suffix, only)
    targets = select_scripts(files, config.target_suffix, only)

    validate_only(only, sources + targets)

    for source in sources:
        problems.append(f"source script remains: {source}")

    executable = shutil.which(config.target_shell)

    if executable is None:
        logger.warning(
            "{} is not installed; native syntax checks were skipped",
            config.target_shell,
        )

    for target in targets:
        problems.extend(check_script(target, config, executable))

    names = tuple(sorted({target.stem for target in targets}))
    pattern = reference_pattern(names, config.source_suffix)

    if pattern is not None:
        for path in files:
            try:
                if not is_utf8_text(path):
                    logger.debug("Skipped binary or non-UTF-8 file {}", path)
                    continue

                with path.open("r", encoding="utf-8", newline="") as stream:
                    for line in stream:
                        if pattern.search(line):
                            problems.append(
                                f"{path}: possible stale "
                                f"{config.source_suffix} reference"
                            )
                            break

            except OSError as exc:
                problems.append(f"{path}: cannot check references: {exc}")

    for problem in problems:
        logger.error("{}", problem)

    if problems:
        return False

    logger.success(
        "Checks passed for {} target script(s); "
        "semantic compatibility is not guaranteed",
        len(targets),
    )
    return True


def post_apply_inputs(
    inputs: list[Path],
    config: Config,
    only: set[str] | None,
) -> list[Path]:
    updated: list[Path] = []

    for path in inputs:
        if (
            not path.exists()
            and not path.is_symlink()
            and path.suffix == config.source_suffix
            and (only is None or path.stem in only)
        ):
            updated.append(path.with_suffix(config.target_suffix))
        else:
            updated.append(path)

    return updated


def main() -> int:
    args = parse_args()

    logger.remove()
    logger.add(
        sys.stderr,
        level="DEBUG" if args.verbose else "INFO",
        format="<level>{level: <8}</level> {message}",
    )

    try:
        config = make_config(args)
        only = parse_only(args.only)
        files = scan(args.paths)

        migration_requested = args.apply or config.dry_run

        if migration_requested:
            if not migrate(files, config, only):
                return 1

            if config.dry_run:
                return 0

            inputs = post_apply_inputs(args.paths, config, only)
            files = scan(inputs)

        return 0 if check(files, config, only) else 1

    except (OSError, ValueError, RuntimeError) as exc:
        logger.error("{}", exc)
        return 1

    except KeyboardInterrupt:
        logger.error("Interrupted; the tree may be partially migrated")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
