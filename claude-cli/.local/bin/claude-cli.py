#!/usr/bin/env python3
"""Run Claude Code inside a Docker container."""

import argparse
import contextlib
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import List, Optional

CLAUDE_IMAGE = os.environ.get("CLAUDE_IMAGE", "claude-cli:latest")
NOTIFY_ERROR_ICON = os.environ.get(
    "NOTIFY_ERROR_ICON", f"{os.environ.get('XDG_CONFIG_HOME', '')}/dunst/critical.png"
)
# Claude Code reads CLAUDE_CONFIG_DIR for every user level file: settings,
# skills, projects, credentials, and the global .claude.json. One bind mount
# of the host directory onto this path carries all of them.
CONTAINER_USER = "claude"
CONTAINER_HOME = f"/home/{CONTAINER_USER}"
CONTAINER_CONFIG_DIR = f"{CONTAINER_HOME}/.config/claude"

# The inline Dockerfile keeps the script self-contained, so a person can get
# the file and run it, with no other file next to it.
INLINE_DOCKERFILE = """FROM node:lts
ARG uid=1000
ARG gid=1000
ENV NPM_CONFIG_PREFIX=/home/claude/.npm
ENV PATH=/home/claude/.npm/bin:$PATH
ENV CLAUDE_CONFIG_DIR=/home/claude/.config/claude
RUN groupmod -g $gid -n claude node && \\
    usermod -u $uid -l claude -d /home/claude -m node
USER claude
RUN mkdir -p "$CLAUDE_CONFIG_DIR"
RUN npm install -g @anthropic-ai/claude-code
ENTRYPOINT ["claude"]
"""


@dataclass
class Config:
    action: Optional[str] = None
    mode: Optional[str] = None
    dir: Optional[str] = None
    dirs: List[str] = field(default_factory=list)
    workdir: Optional[str] = None


def error(message: str) -> None:
    text = f"Error: {message}"
    print(text, file=sys.stderr)
    if shutil.which("notify-send"):
        send_notification(text)


def send_notification(message: str) -> None:
    subprocess.run(["notify-send", "-i", NOTIFY_ERROR_ICON, "claude-cli", message])


def show_help() -> None:
    print(
        f"""Usage: {Path(sys.argv[0]).name} [-b] [-c] [-h] [DIR ...]

Run Claude Code ({CLAUDE_IMAGE}) inside a Docker container.

Options:
  -b    Build the Docker image (rebuilds if it already exists)
  -c    Clean up: remove all claude-cli containers and optionally the image
  -h    Show this help message

If you give no DIR argument, a prompt lets you select a run mode:
  no-dir       Run Claude with no mounted project directory
  current-dir  Mount the current working directory as the working directory
  single-dir   Type one directory path, and mount it as the working
               directory
  multi-dir    Type several directory paths, then a working directory

One DIR argument selects single-dir mode. Two or more DIR arguments select
multi-dir mode, with the first argument as the working directory.

The script keeps Claude configuration across runs. It bind mounts one host
directory onto {CONTAINER_CONFIG_DIR} and sets CLAUDE_CONFIG_DIR to that
path. The host directory is $CLAUDE_CONFIG_DIR, or $XDG_CONFIG_HOME/claude,
or ~/.config/claude. Set CLAUDE_CLI_UNHIDE_CONFIG=1 to keep the global config
in claude.json instead of .claude.json (a symlink bridges the two names).

The container user is {CONTAINER_USER} with home {CONTAINER_HOME}. A dst=
field in CLAUDE_CLI_MOUNTS that starts with the host config directory or the
host home directory is rewritten onto the container paths.

Prerequisites: docker, docker buildx, user in the docker group"""
    )


def docker_image_exists(image: str) -> bool:
    result = subprocess.run(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def cleanup() -> None:
    result = subprocess.run(
        ["docker", "ps", "-aq", "--filter", "name=claude-cli-"],
        capture_output=True,
        text=True,
    )
    container_ids = result.stdout.split()
    if container_ids:
        subprocess.run(["docker", "rm", "-f", *container_ids])

    if docker_image_exists(CLAUDE_IMAGE):
        answer = input(f"Remove {CLAUDE_IMAGE} image? [y/N] ")
        if answer.strip().lower() == "y":
            subprocess.run(["docker", "image", "rm", CLAUDE_IMAGE])


@contextlib.contextmanager
def resolve_dockerfile():
    # Dockerfile selection order:
    #   1. CLAUDE_CLI_DOCKERFILE, a custom path.
    #   2. claude-cli-dockerfile, next to this script.
    #   3. The inline Dockerfile above, written to a temporary directory.
    custom = os.environ.get("CLAUDE_CLI_DOCKERFILE")
    if custom:
        yield Path(custom)
        return

    sibling = Path(__file__).resolve().parent / "claude-cli-dockerfile"
    if sibling.is_file():
        yield sibling
        return

    with tempfile.TemporaryDirectory(prefix="claude-cli-dockerfile-") as tmp_dir:
        dockerfile = Path(tmp_dir) / "Dockerfile"
        dockerfile.write_text(INLINE_DOCKERFILE)
        yield dockerfile


def build_image() -> None:
    if docker_image_exists(CLAUDE_IMAGE):
        subprocess.run(["docker", "image", "rm", CLAUDE_IMAGE])

    with resolve_dockerfile() as dockerfile:
        if not dockerfile.is_file():
            error(f"Dockerfile not found: {dockerfile}")
            sys.exit(1)

        cmd = ["docker", "buildx", "build"]
        # CLAUDE_CLI_PULL is off by default. Set it to a non-empty value to
        # pull each base image again, instead of the local cache.
        if os.environ.get("CLAUDE_CLI_PULL"):
            cmd.append("--pull")
        cmd += [
            "--build-arg",
            f"uid={os.getuid()}",
            "--build-arg",
            f"gid={os.getgid()}",
            "-t",
            CLAUDE_IMAGE,
            "-f",
            str(dockerfile),
            str(dockerfile.parent),
        ]

        result = subprocess.run(cmd)
        if result.returncode != 0:
            error("image build error!")
            cleanup()
            sys.exit(1)


def check_prerequisite(description: str, command: str) -> None:
    result = subprocess.run(
        command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    if result.returncode != 0:
        error(f"prerequisite failed: {description}")
        sys.exit(127)


def check_prerequisites(config: Config) -> None:
    # macOS supports Docker through virtualization, so the docker group check
    # applies to Linux only.
    if platform.system() == "Linux":
        check_prerequisite("user in the docker group", "id -nG | grep -qw docker")
    check_prerequisite("docker command", "command -v docker")
    check_prerequisite("docker buildx", "docker buildx version")


def remap_host_path(path: str, host_config: str, home: str) -> str:
    # The host user is not the container user, so a destination written with
    # host paths, for example dst=$CLAUDE_CONFIG_DIR/skills, would land at
    # /Users/seth/.config/claude/skills inside the container, where Claude
    # Code never looks. Rewrite the config dir first, since it may live
    # outside the home directory, then the home directory.
    for host_prefix, container_prefix in (
        (host_config, CONTAINER_CONFIG_DIR),
        (home, CONTAINER_HOME),
    ):
        host_prefix = host_prefix.rstrip("/")
        if path == host_prefix or path.startswith(host_prefix + "/"):
            return container_prefix + path[len(host_prefix) :]
    return path


def remap_mount_spec(spec: str, host_config: str, home: str) -> str:
    fields = []
    for part in spec.split(","):
        key, sep, value = part.partition("=")
        if sep and key in ("dst", "destination", "target"):
            value = remap_host_path(value, host_config, home)
        fields.append(f"{key}{sep}{value}")
    return ",".join(fields)


def build_mounts(base: Path) -> List[str]:
    # CLAUDE_CLI_MOUNTS is a colon-separated list of Docker --mount
    # specifications, for example:
    #   CLAUDE_CLI_MOUNTS='type=bind,src=/home,dst=/home/claude/user_home'
    # Each entry becomes one "--mount <spec>" argument. The dst field is
    # remapped from the host user to the container user, every other field
    # passes through with no change.
    specs = os.environ.get("CLAUDE_CLI_MOUNTS", "")
    home = str(Path.home())
    args: List[str] = []
    for spec in specs.split(":"):
        if spec:
            args += ["--mount", remap_mount_spec(spec, str(base), home)]
    return args


LEGACY_XDG_HINT = """\
{src} holds a .claude directory, the layout of older claude-cli versions.
Claude Code now reads {src} itself as CLAUDE_CONFIG_DIR, so move the
contents up one level. The -n flag keeps a file that already exists at the
top level, for example a live .claude.json next to a stale copy inside
.claude, so compare and delete whatever the ls still shows:

  mv -n {src}/.claude/* {src}/.claude/.[^.]* {src}/
  ls -A {src}/.claude
  rmdir {src}/.claude
"""

LEGACY_HOME_HINT = """\
{src} does not exist, but {home}/.claude does. Older claude-cli versions
mounted ~/.claude and ~/.claude.json. Move them to the new location:

  mv {home}/.claude {src}
  mv {home}/.claude.json {src}/.claude.json

To keep ~/.claude for a native Claude Code install and start the container
with an empty configuration instead, create the directory:

  mkdir -p {src}
"""


def host_config_dir() -> Path:
    custom = os.environ.get("CLAUDE_CONFIG_DIR")
    if custom:
        return Path(custom).expanduser()
    xdg = os.environ.get("XDG_CONFIG_HOME")
    config_home = Path(xdg) if xdg else Path.home() / ".config"
    return config_home / "claude"


def check_legacy_layout(src: Path) -> None:
    home = Path.home()
    if (src / ".claude").is_dir():
        error(LEGACY_XDG_HINT.format(src=src))
        sys.exit(1)
    if not src.exists() and (home / ".claude").is_dir():
        error(LEGACY_HOME_HINT.format(src=src, home=home))
        sys.exit(1)


def unhide_config(src: Path) -> None:
    # Claude Code has no option for the name of its global config file. It is
    # always $CLAUDE_CONFIG_DIR/.claude.json. It does write through a symlink
    # at that path, so claude.json can hold the data with .claude.json as a
    # link to it. The atomic write lands on claude.json and the link stays.
    hidden = src / ".claude.json"
    plain = src / "claude.json"
    if hidden.is_symlink():
        return
    if hidden.is_file():
        if plain.exists():
            error(f"both {hidden} and {plain} exist, merge them by hand")
            sys.exit(1)
        hidden.rename(plain)
    elif not plain.exists():
        plain.write_text("{}\n")
    hidden.symlink_to(plain.name)


def resolve_claude_config_dir() -> Path:
    src = host_config_dir()
    check_legacy_layout(src)
    src.mkdir(parents=True, exist_ok=True)
    if os.environ.get("CLAUDE_CLI_UNHIDE_CONFIG"):
        unhide_config(src)
    return src


def select_mode() -> Optional[str]:
    options = ["no-dir", "current-dir", "single-dir", "multi-dir"]
    print("Select run mode:")
    for i, option in enumerate(options, 1):
        print(f"  {i}) {option}")
    choice = input("> ").strip()
    if choice in options:
        return choice
    if choice.isdigit() and 1 <= int(choice) <= len(options):
        return options[int(choice) - 1]
    return None


def strip_home_prefix(path: str, home: str) -> str:
    prefix = home.rstrip("/") + "/"
    if path.startswith(prefix):
        return path[len(prefix) :]
    return path


def reldir_for_pwd(pwd: str, home: str) -> str:
    prefix = home.rstrip("/") + "/"
    if pwd.startswith(prefix):
        return pwd[len(prefix) :]
    return os.path.basename(pwd)


def to_absolute(path: str) -> str:
    return path if path.startswith("/") else os.path.join(os.getcwd(), path)


def docker_run(base: Path, mounts: List[str], volumes: List[str], workdir_dst: str) -> int:
    container_name = f"claude-cli-{datetime.now():%Y%m%d-%H%M%S}"
    claude_flags = shlex.split(os.environ.get("CLAUDE_CLI_FLAGS", ""))
    # The -e flag repeats the ENV of the built-in Dockerfiles, so a custom
    # Dockerfile without that line still finds the mounted configuration.
    cmd = [
        "docker",
        "run",
        "-it",
        "--rm",
        "-e",
        f"CLAUDE_CONFIG_DIR={CONTAINER_CONFIG_DIR}",
        "-v",
        f"{base}:{CONTAINER_CONFIG_DIR}",
        *volumes,
        *mounts,
        "-w",
        workdir_dst,
        "--name",
        container_name,
        CLAUDE_IMAGE,
        *claude_flags,
    ]
    return subprocess.run(cmd).returncode


def run_no_dir(base: Path, mounts: List[str]) -> int:
    return docker_run(base, mounts, [], CONTAINER_HOME)


def run_current_dir(base: Path, mounts: List[str]) -> int:
    pwd = os.getcwd()
    home = str(Path.home())
    reldir = reldir_for_pwd(pwd, home)
    dst = f"{CONTAINER_HOME}/{reldir}"
    volumes = ["-v", f"{pwd}:{dst}"]
    return docker_run(base, mounts, volumes, dst)


def run_single_dir(base: Path, mounts: List[str], dir_arg: Optional[str]) -> Optional[int]:
    home = str(Path.home())
    directory = dir_arg or input("Directory to mount: ").strip()
    if not directory:
        return None

    directory = to_absolute(directory)
    reldir = strip_home_prefix(directory, home)
    dst = f"{CONTAINER_HOME}/{reldir}"
    volumes = ["-v", f"{directory}:{dst}"]
    return docker_run(base, mounts, volumes, dst)


def run_multi_dir(
    base: Path, mounts: List[str], dirs_arg: List[str], workdir_arg: Optional[str]
) -> Optional[int]:
    home = str(Path.home())

    if dirs_arg:
        dirs = dirs_arg
    else:
        raw = input("Directories to mount (space-separated): ").strip()
        dirs = raw.split()
    if not dirs:
        return None

    workdir = workdir_arg or input(f"Working directory {dirs}: ").strip() or dirs[0]
    if not workdir:
        return None

    volumes: List[str] = []
    for directory in dirs:
        directory = to_absolute(directory)
        reldir = strip_home_prefix(directory, home)
        volumes += ["-v", f"{directory}:{CONTAINER_HOME}/{reldir}"]

    workdir = to_absolute(workdir)
    relwork = strip_home_prefix(workdir, home)
    dst = f"{CONTAINER_HOME}/{relwork}"
    return docker_run(base, mounts, volumes, dst)


def check_and_build_image() -> None:
    if not docker_image_exists(CLAUDE_IMAGE):
        print("Claude image does not exist!")
        print("Building now...")
        build_image()


def run(config: Config) -> None:
    check_and_build_image()

    mode = config.mode or select_mode()
    if not mode:
        sys.exit(0)

    base = resolve_claude_config_dir()
    mounts = build_mounts(base)

    if mode == "no-dir":
        returncode = run_no_dir(base, mounts)
    elif mode == "current-dir":
        returncode = run_current_dir(base, mounts)
    elif mode == "single-dir":
        returncode = run_single_dir(base, mounts, config.dir)
    elif mode == "multi-dir":
        returncode = run_multi_dir(base, mounts, config.dirs, config.workdir)
    else:
        sys.exit(0)

    sys.exit(returncode if returncode is not None else 0)


def init() -> Config:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-b", action="store_true", dest="build")
    parser.add_argument("-c", action="store_true", dest="clean")
    parser.add_argument("-h", action="store_true", dest="help")
    parser.add_argument("dirs", nargs="*")
    args = parser.parse_args()

    # -h always wins and shows the help text, even with other arguments.
    if args.help:
        return Config(action="help")

    if args.build or args.clean:
        if args.dirs:
            error("-b and -c take no directory arguments")
            sys.exit(1)
        return Config(action="build" if args.build else "cleanup")

    # A DIR argument bypasses the menu: one selects single-dir mode, several
    # select multi-dir mode, with the first argument as the working
    # directory.
    if len(args.dirs) == 1:
        return Config(mode="single-dir", dir=args.dirs[0])
    if len(args.dirs) > 1:
        return Config(mode="multi-dir", dirs=args.dirs, workdir=args.dirs[0])
    return Config()


def main() -> None:
    config = init()

    if config.action == "help":
        show_help()
        return
    if config.action == "build":
        build_image()
        return
    if config.action == "cleanup":
        cleanup()
        return

    check_prerequisites(config)
    run(config)


if __name__ == "__main__":
    main()
