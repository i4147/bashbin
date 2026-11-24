#!/data/data/com.termux/files/usr/bin/env python
"""Migrate shell scripts between Zsh and Bash without requiring a repository.

Default direction: Zsh to Bash.
Use --reverse for Bash to Zsh.
Use --apply to modify files; otherwise, the script only checks.

Inputs may be files or directories. Directories are scanned recursively.
With no inputs, the current directory is scanned recursively.

This is not a complete shell-language translator. Review the results and test
the migrated scripts. Textual reference updates can affect unrelated paths,
comments, or prose containing the same script filename.
"""

from __future__ import annotations

import argparse
import multiprocessing
import os
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

TERMUX_BIN: Path = Path("/data/data/com.termux/files/usr/bin")

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

SELF: Path = Path(__file__).resolve()


@dataclass(frozen=True)
class Config:
    source_suffix: str
    target_suffix: str
    target_shell: str
    shebang: str
    reverse: bool
    apply: bool


@dataclass(frozen=True)
class Job:
    path: Path
    destination: Path | None
    names: tuple[str, ...]
    config: Config


@dataclass(frozen=True)
class Result:
    path: Path
    changed: bool
    error: str | None = None
    warning: str | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--apply",
        action="store_true",
        help="apply changes, then run checks",
    )
    mode.add_argument(
        "--check",
        action="store_true",
        help="check only; this is the default",
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
        "paths",
        nargs="*",
        type=Path,
        help="files or directories to scan; defaults to the current directory",
    )

    return parser.parse_args()


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
        apply=args.apply,
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


def scan(
    inputs: list[Path],
) -> tuple[list[Path], list[Path]]:
    files: set[Path] = set()
    links: set[Path] = set()

    def visit(path: Path) -> None:
        if path.is_symlink():
            links.add(path.absolute())
            return

        if path.is_file():
            resolved = path.resolve(strict=True)

            if resolved != SELF:
                files.add(resolved)

            return

        if path.is_dir():
            for child in path.iterdir():
                visit(child)
            return

        raise OSError(f"input or directory entry is not a regular file: {path}")

    for path in inputs or [Path.cwd()]:
        if not path.exists() and not path.is_symlink():
            raise FileNotFoundError(f"input does not exist: {path}")

        visit(path)

    return sorted(files), sorted(links)


def selected_scripts(
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


def validate_only(
    only: set[str] | None,
    scripts: list[Path],
) -> None:
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
            while chunk := stream.read(1024 * 1024):
                if "\0" in chunk:
                    return False
    except UnicodeDecodeError:
        return False

    return True


def replace_references(
    line: str,
    names: tuple[str, ...],
    source_suffix: str,
    target_suffix: str,
) -> str:
    import re

    if not names:
        return line

    alternatives = "|".join(
        re.escape(name)
        for name in sorted(names, key=len, reverse=True)
    )
    pattern = re.compile(
        rf"(?<![A-Za-z0-9_.-])"
        rf"({alternatives}){re.escape(source_suffix)}"
        rf"(?![A-Za-z0-9_.-])"
    )

    return pattern.sub(
        lambda match: match.group(1) + target_suffix,
        line,
    )


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


def transformed_lines(
    stream: TextIO,
    job: Job,
) -> Iterator[str]:
    config = job.config
    first = stream.readline()

    if job.destination is None:
        if first:
            yield replace_references(
                first,
                job.names,
                config.source_suffix,
                config.target_suffix,
            )

        for line in stream:
            yield replace_references(
                line,
                job.names,
                config.source_suffix,
                config.target_suffix,
            )

        return

    newline = line_ending(first) or "\n"

    yield config.shebang + newline

    if config.reverse:
        for option in PROLOGUE:
            yield option + newline

    if first and not first.startswith("#!"):
        yield replace_references(
            convert_command(first, config.reverse),
            job.names,
            config.source_suffix,
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
            job.names,
            config.source_suffix,
            config.target_suffix,
        )


def process_file(job: Job) -> Result:
    path = job.path
    temporary: Path | None = None

    try:
        if not is_utf8_text(path):
            if job.destination is not None:
                return Result(
                    path,
                    False,
                    error="script is binary or is not valid UTF-8",
                )

            return Result(
                path,
                False,
                warning="skipped binary or non-UTF-8 file",
            )

        mode = stat.S_IMODE(path.stat().st_mode)

        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            dir=path.parent,
            prefix=".shell-migrate-",
            delete=False,
        ) as output:
            temporary = Path(output.name)

            with path.open("r", encoding="utf-8", newline="") as source:
                for line in transformed_lines(source, job):
                    output.write(line)

        temporary.chmod(mode)

        if job.destination is not None:
            temporary.hardlink_to(job.destination)
            temporary.unlink()
            temporary = None

            try:
                path.unlink()
            except OSError:
                job.destination.unlink(missing_ok=True)
                raise

            return Result(path, True)

        if files_equal(path, temporary):
            temporary.unlink()
            temporary = None
            return Result(path, False)

        temporary.replace(path)
        temporary = None
        return Result(path, True)

    except (OSError, UnicodeError) as exc:
        return Result(path, False, error=str(exc))

    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError as exc:
                logger.error("Could not remove temporary file {}: {}", temporary, exc)


def files_equal(first: Path, second: Path) -> bool:
    if first.stat().st_size != second.stat().st_size:
        return False

    with first.open("rb") as left, second.open("rb") as right:
        while True:
            left_chunk = left.read(1024 * 1024)
            right_chunk = right.read(1024 * 1024)

            if left_chunk != right_chunk:
                return False

            if not left_chunk:
                return True


def link_changes(
    links: list[Path],
    source_to_destination: dict[Path, Path],
) -> list[tuple[Path, Path]]:
    changes: list[tuple[Path, Path]] = []

    for link in links:
        target = link.readlink()
        resolved_target = (link.parent / target).resolve(strict=False)

        if resolved_target not in source_to_destination:
            continue

        destination = source_to_destination[resolved_target]

        if target.is_absolute():
            new_target = destination
        else:
            new_target = target.with_suffix(destination.suffix)

        changes.append((link, new_target))

    return changes


def retarget_link(link: Path, target: Path) -> None:
    temporary: Path | None = None

    try:
        with tempfile.NamedTemporaryFile(
            dir=link.parent,
            prefix=".shell-link-",
            delete=False,
        ) as handle:
            temporary = Path(handle.name)

        temporary.unlink()
        temporary.symlink_to(target)
        temporary.replace(link)
        temporary = None

    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def migrate(
    files: list[Path],
    links: list[Path],
    config: Config,
    only: set[str] | None,
) -> bool:
    sources = selected_scripts(files, config.source_suffix, only)
    validate_only(only, sources)

    if not sources:
        logger.info("No {} scripts found", config.source_suffix)
        return True

    source_to_destination = {
        source: source.with_suffix(config.target_suffix)
        for source in sources
    }

    conflicts = [
        destination
        for destination in source_to_destination.values()
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
    planned_links = link_changes(links, source_to_destination)

    logger.warning(
        "Reference updates are textual; review all changes after migration"
    )
    logger.warning(
        "Migration is not transactional; partial changes can remain on failure"
    )

    jobs = (
        Job(
            path=path,
            destination=source_to_destination.get(path),
            names=names,
            config=config,
        )
        for path in files
    )

    failed = False
    changed = 0

    with multiprocessing.Pool(processes=WORKERS) as pool:
        for result in pool.imap_unordered(process_file, jobs, chunksize=8):
            if result.error:
                failed = True
                logger.error("{}: {}", result.path, result.error)
            elif result.warning:
                logger.warning("{}: {}", result.path, result.warning)
            elif result.changed:
                changed += 1
                logger.info("Updated {}", result.path)

    if failed:
        logger.error(
            "Some file operations failed; symlinks were not retargeted. "
            "The tree may be partially migrated."
        )
        return False

    for link, target in planned_links:
        try:
            retarget_link(link, target)
            logger.info("Retargeted {} -> {}", link, target)
        except OSError as exc:
            failed = True
            logger.error("Could not retarget {}: {}", link, exc)

    logger.info(
        "Processed {} scripts, changed {} files, planned {} symlink updates",
        len(sources),
        changed,
        len(planned_links),
    )

    return not failed


def check_script(path: Path, config: Config) -> list[str]:
    problems: list[str] = []

    try:
        with path.open("r", encoding="utf-8", newline="") as stream:
            first = stream.readline().rstrip("\r\n")

        if first != config.shebang:
            problems.append(f"{path}: incorrect or missing shebang")

    except (OSError, UnicodeDecodeError) as exc:
        return [f"{path}: cannot read script: {exc}"]

    executable = shutil.which(config.target_shell)

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


def check(
    files: list[Path],
    links: list[Path],
    config: Config,
    only: set[str] | None,
) -> bool:
    problems: list[str] = []

    sources = selected_scripts(files, config.source_suffix, only)
    targets = selected_scripts(files, config.target_suffix, only)

    validate_only(only, sources + targets)

    for source in sources:
        problems.append(f"source script remains: {source}")

    if shutil.which(config.target_shell) is None:
        logger.warning(
            "{} is not installed; native syntax checks were skipped",
            config.target_shell,
        )

    for target in targets:
        problems.extend(check_script(target, config))

    target_names = tuple(sorted({target.stem for target in targets}))

    if target_names:
        for path in files:
            try:
                if not is_utf8_text(path):
                    continue

                with path.open("r", encoding="utf-8", newline="") as stream:
                    for line in stream:
                        rewritten = replace_references(
                            line,
                            target_names,
                            config.source_suffix,
                            config.target_suffix,
                        )
                        if rewritten != line:
                            problems.append(
                                f"{path}: possible stale "
                                f"{config.source_suffix} reference"
                            )
                            break

            except OSError as exc:
                problems.append(f"{path}: cannot check references: {exc}")

    target_set = set(targets)

    for link in links:
        try:
            raw_target = link.readlink()
            candidate = (link.parent / raw_target).resolve(strict=False)

            if (
                candidate.suffix == config.source_suffix
                and candidate.with_suffix(config.target_suffix) in target_set
            ):
                problems.append(f"{link}: stale symlink target {raw_target}")

        except OSError as exc:
            problems.append(f"{link}: cannot inspect symlink: {exc}")

    for problem in problems:
        logger.error("{}", problem)

    if problems:
        return False

    logger.success(
        "Checks passed for {} target scripts; semantic compatibility "
        "is not guaranteed",
        len(targets),
    )
    return True


def main() -> int:
    args = parse_args()

    logger.remove()
    logger.add(
        sys.stderr,
        level="INFO",
        format="<level>{level: <8}</level> {message}",
    )

    try:
        config = make_config(args)
        only = parse_only(args.only)
        files, links = scan(args.paths)

        if config.apply:
            if not migrate(files, links, config, only):
                return 1

            files, links = scan(args.paths)

        return 0 if check(files, links, config, only) else 1

    except (OSError, ValueError, RuntimeError) as exc:
        logger.error("{}", exc)
        return 1

    except KeyboardInterrupt:
        logger.error("Interrupted; the tree may be partially migrated")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
