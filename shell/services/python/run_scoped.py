#!/usr/bin/env python3
"""Start a program in a systemd scope of its own.

Everything the shell spawns lands in huginn.service's cgroup, and the unit is
KillMode=control-group: restarting the shell, updating it or a crash of
quickshell used to take down every app opened from the launcher or the dock
with it, terminals included. A transient scope under app.slice is what Plasma
itself does for the apps it starts, so the app outlives the shell.

Usable both as a module (scoped_argv) and from the command line:

    run_scoped.py <command> [args...]
"""
import os
import re
import secrets
import shutil
import sys


def _user_manager_available():
    if not shutil.which("systemd-run"):
        return False
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.exists(os.path.join(runtime, "systemd", "private"))


def scoped_argv(argv, name=None):
    """Return argv wrapped in systemd-run --scope, or unchanged without systemd."""
    if not argv or not _user_manager_available():
        return list(argv)
    base = name or os.path.basename(str(argv[0])) or "app"
    if base.endswith(".desktop"):
        base = base[:-8]
    base = re.sub(r"[^A-Za-z0-9_.]", "_", base)[:64] or "app"
    unit = f"app-huginn-{base}-{secrets.token_hex(4)}.scope"
    return ["systemd-run", "--user", "--scope", "--quiet", "--collect",
            "--slice=app.slice", f"--unit={unit}", "--"] + list(argv)


def scoped_shell(cmd, name=None):
    """Same for a shell command line, run through sh -c."""
    return scoped_argv(["sh", "-c", cmd], name or (cmd.split() or ["app"])[0])


if __name__ == "__main__":
    args = sys.argv[1:]
    if args:
        wrapped = scoped_argv(args)
        os.execvp(wrapped[0], wrapped)
