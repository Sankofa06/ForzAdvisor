#!/usr/bin/env python3
"""Allocate or verify a private release task beneath the real system temp root."""

from __future__ import annotations

import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path


class UnsafeWorkspaceError(ValueError):
    pass


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def temporary_root(alias: Path) -> Path:
    if not alias.is_absolute() or ".." in alias.parts:
        raise UnsafeWorkspaceError
    try:
        root = alias.resolve(strict=True)
        info = root.stat()
    except OSError as error:
        raise UnsafeWorkspaceError from error
    if not stat.S_ISDIR(info.st_mode):
        raise UnsafeWorkspaceError
    return root


def validate_directory(path: Path, *, private_owner: bool) -> Path:
    if path.is_symlink():
        raise UnsafeWorkspaceError
    try:
        info = path.lstat()
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise UnsafeWorkspaceError from error
    if not stat.S_ISDIR(info.st_mode) or resolved != path:
        raise UnsafeWorkspaceError
    mode = stat.S_IMODE(info.st_mode)
    if private_owner:
        if info.st_uid != os.getuid() or mode & 0o022:
            raise UnsafeWorkspaceError
    elif mode & 0o022 and not mode & stat.S_ISVTX:
        raise UnsafeWorkspaceError
    return path


def configured_workspace_root(value: str, temp_alias: Path = Path("/tmp")) -> Path:
    alias = temp_alias
    requested = Path(value)
    if not requested.is_absolute() or ".." in requested.parts or any("\n" in part or "\r" in part for part in requested.parts):
        raise UnsafeWorkspaceError
    try:
        relative = requested.relative_to(alias)
    except ValueError as error:
        raise UnsafeWorkspaceError from error
    if not relative.parts or any(part in ("", ".", "..") for part in relative.parts):
        raise UnsafeWorkspaceError

    root = temporary_root(alias)
    current = root
    for index, component in enumerate(relative.parts):
        current = current / component
        if current.is_symlink():
            raise UnsafeWorkspaceError
        try:
            current.mkdir(mode=0o700)
        except FileExistsError:
            pass
        except OSError as error:
            raise UnsafeWorkspaceError from error
        validate_directory(current, private_owner=index == len(relative.parts) - 1)
    if current == root or not is_within(current, root):
        raise UnsafeWorkspaceError
    return current


def canonical_workspace_root(value: str, temp_alias: Path = Path("/tmp")) -> Path:
    base = temporary_root(temp_alias)
    root = Path(value)
    if not root.is_absolute() or ".." in root.parts or root == base or not is_within(root, base):
        raise UnsafeWorkspaceError
    relative = root.relative_to(base)
    if not relative.parts:
        raise UnsafeWorkspaceError
    current = base
    for index, component in enumerate(relative.parts):
        current = current / component
        validate_directory(current, private_owner=index == len(relative.parts) - 1)
    if current.resolve(strict=True) != current:
        raise UnsafeWorkspaceError
    return current


def validate_task_directory(workspace_value: str, task_value: str, temp_alias: Path = Path("/tmp")) -> tuple[Path, Path]:
    root = canonical_workspace_root(workspace_value, temp_alias)
    task = Path(task_value)
    if not task.is_absolute() or ".." in task.parts or task.parent != root or task.is_symlink():
        raise UnsafeWorkspaceError
    validate_directory(task, private_owner=True)
    try:
        info = task.lstat()
        resolved = task.resolve(strict=True)
    except OSError as error:
        raise UnsafeWorkspaceError from error
    if resolved != task or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        raise UnsafeWorkspaceError
    return root, task


def allocate_remote_task(
    workspace_value: str,
    repo_slug: str,
    commit_prefix: str,
    temp_alias: Path = Path("/tmp"),
) -> tuple[Path, Path]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", repo_slug):
        raise UnsafeWorkspaceError
    if not re.fullmatch(r"[a-f0-9]{12}", commit_prefix):
        raise UnsafeWorkspaceError
    root = configured_workspace_root(workspace_value, temp_alias)
    try:
        task = Path(tempfile.mkdtemp(prefix=f"{repo_slug}-{commit_prefix}-", dir=root))
        validate_task_directory(str(root), str(task), temp_alias)
    except (OSError, UnsafeWorkspaceError) as error:
        if "task" in locals() and task.parent == root and not task.is_symlink():
            try:
                task.rmdir()
            except OSError:
                pass
        raise UnsafeWorkspaceError from error
    return root, task


def main(arguments: list[str]) -> int:
    try:
        if len(arguments) == 4 and arguments[0] == "allocate":
            root, task = allocate_remote_task(arguments[1], arguments[2], arguments[3])
            print(json.dumps({"workspaceRoot": str(root), "taskDir": str(task)}))
            return 0
        if len(arguments) == 3 and arguments[0] == "validate":
            validate_task_directory(arguments[1], arguments[2])
            return 0
    except (OSError, UnsafeWorkspaceError):
        print("runner workspace validation failed", file=sys.stderr)
        return 2
    print("runner workspace operation is invalid", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
