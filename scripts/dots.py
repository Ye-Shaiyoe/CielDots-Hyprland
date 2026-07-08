#!/usr/bin/env python3
# /* ---- 💫 CielDots — Dotfiles CLI Manager 💫 ---- */
# Usage:
#   dots sync              → create/update all symlinks
#   dots backup            → tar.gz backup of active configs
#   dots restore <file>    → extract backup and restore files
#   dots status            → show symlink health
#   dots diff              → diff dotfiles vs installed

import os
import sys
import json
import shutil
import tarfile
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional


# ── Config ────────────────────────────────────────────────────
DOTS_DIR    = Path(__file__).resolve().parent.parent   # repo root
HOME        = Path.home()
BACKUP_DIR  = HOME / ".local" / "share" / "cieldots" / "backups"
LOG_FILE    = HOME / ".cache" / "cieldots-dots.log"

# Map: source (relative to DOTS_DIR) → destination (relative to HOME)
SYMLINK_MAP = {
    ".config/hypr/hyprland.conf":         ".config/hypr/hyprland.conf",
    ".config/hypr/hyprlock.conf":         ".config/hypr/hyprlock.conf",
    ".config/hypr/hypridle.conf":         ".config/hypr/hypridle.conf",
    ".config/waybar/config.jsonc":        ".config/waybar/config.jsonc",
    ".config/waybar/style.css":           ".config/waybar/style.css",
    ".config/kitty/kitty.conf":           ".config/kitty/kitty.conf",
    ".config/kitty/themes/rimuru.conf":   ".config/kitty/themes/rimuru.conf",
    ".config/mako/config":                ".config/mako/config",
    ".config/wofi/config":                ".config/wofi/config",
    ".config/wofi/style.css":             ".config/wofi/style.css",
    ".config/zsh/.zshrc":                 ".config/zsh/.zshrc",
    ".config/starship/starship.toml":     ".config/starship/starship.toml",
    ".config/gtk-3.0/settings.ini":       ".config/gtk-3.0/settings.ini",
    ".config/gtk-4.0/settings.ini":       ".config/gtk-4.0/settings.ini",
    ".config/fastfetch/config.jsonc":     ".config/fastfetch/config.jsonc",
    ".config/fastfetch/rimuru.txt":       ".config/fastfetch/rimuru.txt",
    ".config/waybar/dynamic-colors.css":  ".config/waybar/dynamic-colors.css",
    ".config/kitty/themes/dynamic.conf":  ".config/kitty/themes/dynamic.conf",
}

# Scripts symlinked to ~/.config/hypr/scripts/ and ~/.local/bin/
SCRIPTS_DIR = DOTS_DIR / "scripts"


# ── Colors (Rimuru palette ANSI) ─────────────────────────────
C_CYAN   = "\033[38;2;0;229;255m"
C_BLUE   = "\033[38;2;41;182;246m"
C_GREEN  = "\033[38;2;0;230;118m"
C_AMBER  = "\033[38;2;255;179;0m"
C_RED    = "\033[38;2;255;82;82m"
C_SILVER = "\033[38;2;200;214;232m"
C_MIST   = "\033[38;2;122;145;176m"
C_RESET  = "\033[0m"


def c(color: str, text: str) -> str:
    return f"{color}{text}{C_RESET}"


def info(msg: str):  print(f"  {c(C_CYAN,'[INFO]')}  {msg}")
def ok(msg: str):    print(f"  {c(C_GREEN,'[ OK ]')}  {msg}")
def warn(msg: str):  print(f"  {c(C_AMBER,'[WARN]')}  {msg}")
def err(msg: str):   print(f"  {c(C_RED,'[ERR ]')}  {msg}")


def banner():
    print(f"\n  {c(C_CYAN,'💫 CielDots')} {c(C_MIST,'— dotfiles manager')}")
    print(f"  {c(C_MIST, f'repo: {DOTS_DIR}')}\n")


# ── Sync ─────────────────────────────────────────────────────

def cmd_sync(args):
    banner()
    info("Syncing symlinks...")
    added = updated = skipped = failed = 0

    for src_rel, dst_rel in SYMLINK_MAP.items():
        src = DOTS_DIR / src_rel
        dst = HOME     / dst_rel

        if not src.exists():
            warn(f"source missing: {src_rel}")
            failed += 1
            continue

        dst.parent.mkdir(parents=True, exist_ok=True)

        if dst.is_symlink():
            if dst.resolve() == src.resolve():
                skipped += 1
                continue
            else:
                dst.unlink()
                dst.symlink_to(src)
                ok(f"updated  {dst_rel}")
                updated += 1
        elif dst.exists():
            # Real file in the way — back it up
            bak = dst.with_suffix(dst.suffix + ".bak")
            dst.rename(bak)
            warn(f"backed up existing {dst_rel} → {bak.name}")
            dst.symlink_to(src)
            ok(f"linked   {dst_rel}")
            added += 1
        else:
            dst.symlink_to(src)
            ok(f"linked   {dst_rel}")
            added += 1

    # Scripts
    scripts_target = HOME / ".config" / "hypr" / "scripts"
    bin_target     = HOME / ".local"  / "bin"
    scripts_target.mkdir(parents=True, exist_ok=True)
    bin_target.mkdir(parents=True, exist_ok=True)

    for script in SCRIPTS_DIR.glob("*"):
        if script.suffix in (".sh", ".py"):
            link = scripts_target / script.name
            if not link.exists() or link.is_symlink():
                link.unlink(missing_ok=True)
                link.symlink_to(script)
                script.chmod(0o755)

            # Also expose in ~/.local/bin without extension for .sh
            stem = script.stem
            binlink = bin_target / stem
            if not binlink.exists() or binlink.is_symlink():
                binlink.unlink(missing_ok=True)
                binlink.symlink_to(script)

    print()
    print(f"  {c(C_GREEN,'added')}: {added}  "
          f"{c(C_BLUE,'updated')}: {updated}  "
          f"{c(C_MIST,'skipped')}: {skipped}  "
          f"{c(C_RED,'failed')}: {failed}")


# ── Status ────────────────────────────────────────────────────

def cmd_status(args):
    banner()
    info("Checking symlink status...\n")

    col_w = max(len(v) for v in SYMLINK_MAP.values()) + 2
    ok_count = broken = missing = conflict = 0

    for src_rel, dst_rel in SYMLINK_MAP.items():
        src = DOTS_DIR / src_rel
        dst = HOME     / dst_rel
        label = dst_rel.ljust(col_w)

        if not src.exists():
            print(f"  {c(C_AMBER,'SOURCE?')}  {label}  {c(C_MIST, str(src))}")
            broken += 1
        elif dst.is_symlink() and dst.resolve() == src.resolve():
            print(f"  {c(C_GREEN,'    OK ')}  {label}")
            ok_count += 1
        elif dst.is_symlink():
            target = dst.resolve()
            print(f"  {c(C_RED,'BROKEN ')}  {label}  → {c(C_MIST, str(target))}")
            broken += 1
        elif dst.exists():
            print(f"  {c(C_AMBER,'CONFLICT')} {label}  (real file — run sync to fix)")
            conflict += 1
        else:
            print(f"  {c(C_MIST,'MISSING')}  {label}")
            missing += 1

    print()
    print(f"  OK: {ok_count}  BROKEN: {broken}  MISSING: {missing}  CONFLICT: {conflict}")
    if broken + missing + conflict > 0:
        print(f"\n  Run {c(C_CYAN,'dots sync')} to fix issues.")


# ── Backup ────────────────────────────────────────────────────

def cmd_backup(args):
    banner()
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    ts      = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive = BACKUP_DIR / f"cieldots-backup-{ts}.tar.gz"

    info(f"Creating backup → {archive}")

    with tarfile.open(archive, "w:gz") as tar:
        for src_rel, dst_rel in SYMLINK_MAP.items():
            target = HOME / dst_rel
            if target.is_symlink():
                real = target.resolve()
            elif target.exists():
                real = target
            else:
                continue
            tar.add(real, arcname=dst_rel)

        # Include scripts
        for script in SCRIPTS_DIR.glob("*"):
            if script.suffix in (".sh", ".py"):
                tar.add(script, arcname=f"scripts/{script.name}")

    size = archive.stat().st_size // 1024
    ok(f"Backup saved: {archive.name}  ({size} KB)")

    # Keep only last 10 backups
    backups = sorted(BACKUP_DIR.glob("cieldots-backup-*.tar.gz"))
    for old in backups[:-10]:
        old.unlink()
        info(f"Removed old backup: {old.name}")


# ── Restore ───────────────────────────────────────────────────

def cmd_restore(args):
    banner()
    if not args:
        err("Usage: dots restore <backup-file>")
        sys.exit(1)

    archive = Path(args[0])
    if not archive.exists():
        # Try in backup dir
        archive = BACKUP_DIR / args[0]
    if not archive.exists():
        err(f"File not found: {args[0]}")
        sys.exit(1)

    if not tarfile.is_tarfile(archive):
        err(f"Not a valid tar.gz file: {archive}")
        sys.exit(1)

    info(f"Restoring from {archive.name}...")

    with tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        for member in members:
            dst = HOME / member.name
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists() and not dst.is_symlink():
                bak = dst.with_suffix(dst.suffix + f".pre-restore.bak")
                dst.rename(bak)
                warn(f"backed up {member.name}")

            tar.extract(member, HOME, filter="data")
            ok(f"restored {member.name}")

    ok(f"\nRestore complete. Run 'dots sync' to re-create symlinks.")


# ── Diff ─────────────────────────────────────────────────────

def cmd_diff(args):
    banner()
    info("Diffing dotfiles vs installed...\n")
    found_diff = False

    for src_rel, dst_rel in SYMLINK_MAP.items():
        src = DOTS_DIR / src_rel
        dst = HOME     / dst_rel

        if not src.exists():
            continue

        # Resolve symlinks for diff
        real_dst = dst.resolve() if dst.is_symlink() else dst
        if real_dst == src.resolve():
            continue  # Same file, skip
        if not real_dst.exists():
            warn(f"Not installed: {dst_rel}")
            found_diff = True
            continue

        result = subprocess.run(
            ["diff", "--color=always", "-u",
             f"--label=dotfiles/{src_rel}",
             f"--label=installed/{dst_rel}",
             str(src), str(real_dst)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(result.stdout)
            found_diff = True

    if not found_diff:
        ok("All configs are in sync — no differences found.")


# ── List backups ─────────────────────────────────────────────

def cmd_list(args):
    banner()
    if not BACKUP_DIR.exists():
        info("No backups found.")
        return

    backups = sorted(BACKUP_DIR.glob("cieldots-backup-*.tar.gz"))
    if not backups:
        info("No backups found.")
        return

    info(f"Backups in {BACKUP_DIR}:\n")
    for b in reversed(backups):
        size = b.stat().st_size // 1024
        ts   = b.stem.replace("cieldots-backup-", "")
        try:
            dt = datetime.strptime(ts, "%Y%m%d_%H%M%S")
            ts_fmt = dt.strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            ts_fmt = ts
        print(f"  {c(C_CYAN, b.name)}  {c(C_MIST, f'{size} KB')}  {c(C_MIST, ts_fmt)}")



def cmd_help(args):
    print(f"""
  {c(C_CYAN, '💫 CielDots')} {c(C_SILVER, '— dotfiles manager')}

  {c(C_CYAN, 'Usage:')}  dots <command> [args]

  {c(C_CYAN, 'Commands:')}
    {c(C_GREEN, 'sync')}              Create or update all symlinks
    {c(C_GREEN, 'status')}            Check symlink health (OK/BROKEN/MISSING/CONFLICT)
    {c(C_GREEN, 'diff')}              Show diff between dotfiles and installed configs
    {c(C_GREEN, 'backup')}            Create tar.gz backup of all active configs
    {c(C_GREEN, 'restore')} <file>    Restore configs from a backup archive
    {c(C_GREEN, 'list')}              List available backups
    {c(C_GREEN, 'help')}              Show this help

  {c(C_CYAN, 'Examples:')}
    dots sync
    dots status
    dots backup
    dots restore cieldots-backup-20260703_120000.tar.gz
    dots diff
""")



COMMANDS = {
    "sync":    cmd_sync,
    "status":  cmd_status,
    "diff":    cmd_diff,
    "backup":  cmd_backup,
    "restore": cmd_restore,
    "list":    cmd_list,
    "help":    cmd_help,
}

def main():
    argv = sys.argv[1:]
    if not argv or argv[0] in ("help", "--help", "-h"):
        cmd_help([])
        return

    cmd = argv[0]
    rest = argv[1:]

    if cmd not in COMMANDS:
        err(f"Unknown command: '{cmd}'")
        cmd_help([])
        sys.exit(1)

    COMMANDS[cmd](rest)


if __name__ == "__main__":
    main()