#!/usr/bin/env python3
"""
Poe the Poet command implementations - Template.

Ayna Deployment Standard v2.1
See: UNIFIED_STANDARD.md

Blue-Green Deployment Architecture:
    /opt/ayna/{project}/
    ├── releases/
    │   ├── v1/                 # Previous release
    │   ├── v2/                 # Current active release
    │   └── current -> v2       # Symlink to active release
    ├── shared/
    │   ├── media/              # Shared media files
    │   ├── backups/            # Database backups
    │   ├── .env.dev
    │   ├── .env.staging
    │   └── .env.production
    └── (development files)     # Working directory for development

CUSTOMIZATION:
    Update the configuration section below for your project.
"""

import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

# =============================================================================
# CONFIGURATION - CUSTOMIZE FOR YOUR PROJECT
# =============================================================================

PROJECT_NAME = "myproject"  # TODO: Change to your project name
PROJECT_ROOT = Path(f"/opt/ayna/{PROJECT_NAME}")
RELEASES_DIR = PROJECT_ROOT / "releases"
SHARED_DIR = PROJECT_ROOT / "shared"
CURRENT_LINK = RELEASES_DIR / "current"
BACKUPS_DIR = SHARED_DIR / "backups"
VENV_DIR = PROJECT_ROOT / "venv"

# Port assignments - see PORT_REGISTRY.md for available ranges
PORTS = {
    "web": 8100,    # Django/Flask
    "api": 8101,    # FastAPI
    "docs": 8102,   # Sphinx
}

# Environment configurations
ENVIRONMENTS = {
    "dev": {
        "django_settings": "config.settings.development",
        "env_file": ".env.dev",
        "services": [f"{PROJECT_NAME}-web", f"{PROJECT_NAME}-api"],
    },
    "staging": {
        "django_settings": "config.settings.staging",
        "env_file": ".env.staging",
        "services": [
            f"{PROJECT_NAME}-web",
            f"{PROJECT_NAME}-api",
            f"{PROJECT_NAME}-celery",
            f"{PROJECT_NAME}-beat",
        ],
    },
    "production": {
        "django_settings": "config.settings.production",
        "env_file": ".env.production",
        "services": [
            f"{PROJECT_NAME}-web",
            f"{PROJECT_NAME}-api",
            f"{PROJECT_NAME}-celery",
            f"{PROJECT_NAME}-beat",
        ],
    },
}

# Services and their systemd unit names
SERVICES = {
    "web": f"{PROJECT_NAME}-web",
    "api": f"{PROJECT_NAME}-api",
    "celery": f"{PROJECT_NAME}-celery",
    "beat": f"{PROJECT_NAME}-beat",
}


# =============================================================================
# TERMINAL COLORS
# =============================================================================


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"  # No Color
    BOLD = "\033[1m"


def log_info(msg: str) -> None:
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")


def log_success(msg: str) -> None:
    print(f"{Colors.GREEN}[OK]{Colors.NC} {msg}")


def log_warning(msg: str) -> None:
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {msg}")


def log_error(msg: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")


def log_step(step: int, total: int, msg: str) -> None:
    print(f"{Colors.CYAN}[{step}/{total}]{Colors.NC} {msg}")


# =============================================================================
# UTILITIES
# =============================================================================


def run_cmd(
    cmd: str,
    check: bool = True,
    capture: bool = False,
    cwd: Optional[Path] = None,
) -> subprocess.CompletedProcess:
    """Run a shell command."""
    result = subprocess.run(
        cmd,
        shell=True,
        check=check,
        capture_output=capture,
        text=True,
        cwd=cwd or PROJECT_ROOT,
    )
    return result


def get_env_config(env: str) -> dict:
    """Get configuration for an environment."""
    if env not in ENVIRONMENTS:
        log_error(f"Unknown environment: {env}. Valid: {', '.join(ENVIRONMENTS.keys())}")
        sys.exit(1)
    return ENVIRONMENTS[env]


def get_current_release() -> Optional[Path]:
    """Get the current active release directory."""
    if CURRENT_LINK.exists() and CURRENT_LINK.is_symlink():
        return CURRENT_LINK.resolve()
    return None


def get_next_version() -> int:
    """Get the next release version number."""
    if not RELEASES_DIR.exists():
        return 1

    versions = []
    for item in RELEASES_DIR.iterdir():
        if item.is_dir() and item.name.startswith("v"):
            try:
                versions.append(int(item.name[1:]))
            except ValueError:
                pass

    return max(versions, default=0) + 1


def get_current_version() -> Optional[int]:
    """Get the current active release version number."""
    current = get_current_release()
    if current and current.name.startswith("v"):
        try:
            return int(current.name[1:])
        except ValueError:
            pass
    return None


def activate_venv_prefix() -> str:
    """Get the command prefix to activate venv."""
    return f"source {VENV_DIR}/bin/activate &&"


# =============================================================================
# ENVIRONMENT MANAGEMENT
# =============================================================================


def env_setup(env: str = "dev") -> None:
    """Setup environment symlink (.env -> .env.{env})."""
    config = get_env_config(env)
    env_filename = config["env_file"]

    log_info(f"Setting up environment: {env}")

    # Ensure directories exist
    SHARED_DIR.mkdir(parents=True, exist_ok=True)
    (SHARED_DIR / "backups").mkdir(exist_ok=True)
    (SHARED_DIR / "media").mkdir(exist_ok=True)

    # Find the env file
    env_file = SHARED_DIR / env_filename
    if not env_file.exists():
        env_file = PROJECT_ROOT / env_filename

    if not env_file.exists():
        log_error(f"Environment file not found: {env_filename}")
        log_info(f"Please create {SHARED_DIR / env_filename}")
        sys.exit(1)

    # Create .env symlink
    dotenv = PROJECT_ROOT / ".env"
    if dotenv.exists() or dotenv.is_symlink():
        dotenv.unlink()

    dotenv.symlink_to(env_file)
    log_success(f"Created .env -> {env_file}")


def env_check() -> None:
    """Verify environment setup and dependencies."""
    log_info("Checking environment...")

    errors = []

    # Check .env
    dotenv = PROJECT_ROOT / ".env"
    if not dotenv.exists():
        errors.append(".env file missing")
    else:
        log_success(".env exists")

    # Check venv
    if not VENV_DIR.exists():
        errors.append("venv not found")
    else:
        log_success("venv exists")

    # Check required directories
    for dir_name in ["web", "api"]:
        if (PROJECT_ROOT / dir_name).exists():
            log_success(f"{dir_name}/ exists")
        else:
            log_warning(f"{dir_name}/ missing (may be optional)")

    if errors:
        log_error("Environment check failed:")
        for error in errors:
            print(f"  - {error}")
        sys.exit(1)

    log_success("Environment check passed")


# =============================================================================
# DEVELOPMENT
# =============================================================================


def dev() -> None:
    """Start development servers (web + api)."""
    log_info("Starting development environment...")
    log_info(f"Web:  http://localhost:{PORTS['web']}")
    log_info(f"API:  http://localhost:{PORTS['api']}")
    log_info("Press Ctrl+C to stop")

    # For simplicity, just run Django dev server
    os.chdir(PROJECT_ROOT / "web")
    os.execvp(
        f"{VENV_DIR}/bin/python",
        ["python", "manage.py", "runserver", f"0.0.0.0:{PORTS['web']}"],
    )


def dev_web() -> None:
    """Start Django development server."""
    os.chdir(PROJECT_ROOT / "web")
    os.execvp(
        f"{VENV_DIR}/bin/python",
        ["python", "manage.py", "runserver", f"0.0.0.0:{PORTS['web']}"],
    )


def dev_api() -> None:
    """Start FastAPI development server."""
    os.chdir(PROJECT_ROOT)
    os.execvp(
        f"{VENV_DIR}/bin/uvicorn",
        [
            "uvicorn",
            "api.main:app",
            "--host",
            "0.0.0.0",
            "--port",
            str(PORTS["api"]),
            "--reload",
        ],
    )


# =============================================================================
# SERVICES MANAGEMENT (systemd)
# =============================================================================


def services_status() -> None:
    """Check status of all services."""
    print(f"\n{Colors.GREEN}=== {PROJECT_NAME.upper()} Services ==={Colors.NC}\n")

    for name, service in SERVICES.items():
        result = run_cmd(f"systemctl is-active {service}", check=False, capture=True)
        status = result.stdout.strip()

        if status == "active":
            print(f"  {name}: {Colors.GREEN}{status}{Colors.NC}")
        elif status == "inactive":
            print(f"  {name}: {Colors.YELLOW}{status}{Colors.NC}")
        else:
            print(f"  {name}: {Colors.RED}{status}{Colors.NC}")

    print(f"\n{Colors.GREEN}=== Health Checks ==={Colors.NC}\n")

    # Check web
    result = run_cmd(
        f"curl -sf http://localhost:{PORTS['web']}/ > /dev/null", check=False
    )
    if result.returncode == 0:
        print(f"  Web:  {Colors.GREEN}healthy{Colors.NC}")
    else:
        print(f"  Web:  {Colors.RED}unhealthy{Colors.NC}")

    # Check API
    result = run_cmd(
        f"curl -sf http://localhost:{PORTS['api']}/health > /dev/null", check=False
    )
    if result.returncode == 0:
        print(f"  API:  {Colors.GREEN}healthy{Colors.NC}")
    else:
        print(f"  API:  {Colors.RED}unhealthy{Colors.NC}")

    print()


def services_start() -> None:
    """Start all services."""
    log_info("Starting all services...")

    for name, service in SERVICES.items():
        result = run_cmd(f"sudo systemctl start {service}", check=False)
        if result.returncode == 0:
            log_success(f"Started {name}")
        else:
            log_warning(f"Failed to start {name}")


def services_stop() -> None:
    """Stop all services."""
    log_info("Stopping all services...")

    for name, service in SERVICES.items():
        result = run_cmd(f"sudo systemctl stop {service}", check=False)
        if result.returncode == 0:
            log_success(f"Stopped {name}")
        else:
            log_warning(f"Failed to stop {name} (may not be running)")


def services_restart() -> None:
    """Restart all services."""
    log_info("Restarting all services...")

    for name, service in SERVICES.items():
        result = run_cmd(f"sudo systemctl restart {service}", check=False)
        if result.returncode == 0:
            log_success(f"Restarted {name}")
        else:
            log_warning(f"Failed to restart {name}")


def services_reload() -> None:
    """Gracefully reload all services."""
    log_info("Reloading all services...")

    for name, service in SERVICES.items():
        # Try reload first, fall back to restart
        result = run_cmd(f"sudo systemctl reload {service}", check=False)
        if result.returncode != 0:
            result = run_cmd(f"sudo systemctl restart {service}", check=False)

        if result.returncode == 0:
            log_success(f"Reloaded {name}")
        else:
            log_warning(f"Failed to reload {name}")


# =============================================================================
# LOGS
# =============================================================================


def logs(service: str = "all") -> None:
    """Stream logs from services."""
    if service == "all":
        units = " ".join([f"-u {s}" for s in SERVICES.values()])
        os.execvp("journalctl", ["journalctl", "-f"] + units.split())
    else:
        unit = SERVICES.get(service)
        if not unit:
            log_error(f"Unknown service: {service}. Valid: {', '.join(SERVICES.keys())}")
            sys.exit(1)
        os.execvp("journalctl", ["journalctl", "-f", "-u", unit])


# =============================================================================
# DATABASE
# =============================================================================


def migrate() -> None:
    """Run database migrations."""
    log_info("Running database migrations...")
    os.chdir(PROJECT_ROOT / "web")
    run_cmd(f"{VENV_DIR}/bin/python manage.py migrate --noinput")
    log_success("Migrations complete")


def makemigrations() -> None:
    """Create new migrations."""
    log_info("Creating migrations...")
    os.chdir(PROJECT_ROOT / "web")
    run_cmd(f"{VENV_DIR}/bin/python manage.py makemigrations")
    log_success("Migrations created")


# =============================================================================
# STATIC FILES
# =============================================================================


def collectstatic() -> None:
    """Collect static files."""
    log_info("Collecting static files...")
    os.chdir(PROJECT_ROOT / "web")
    run_cmd(f"{VENV_DIR}/bin/python manage.py collectstatic --noinput")
    log_success("Static files collected")


# =============================================================================
# DATABASE BACKUP
# =============================================================================


def db_backup(env: str = "dev") -> None:
    """Create database backup using pg_dump."""
    config = get_env_config(env)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    backup_file = BACKUPS_DIR / f"{PROJECT_NAME}_{env}_{timestamp}.sql.gz"

    # Load database URL from env file
    env_file = PROJECT_ROOT / ".env"
    if not env_file.exists():
        env_file = SHARED_DIR / config["env_file"]

    db_url = None
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                if line.startswith("DATABASE_URL="):
                    db_url = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break

    if not db_url:
        log_warning("Could not find DATABASE_URL, skipping backup")
        return

    # Parse DATABASE_URL (postgres://user:pass@host:port/dbname)
    match = re.match(r"postgres(?:ql)?://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)", db_url)
    if match:
        user, password, host, port, db_name = match.groups()
        os.environ["PGPASSWORD"] = password

        log_info(f"Backing up database {db_name}...")
        result = run_cmd(
            f"pg_dump -h {host} -p {port} -U {user} {db_name} | gzip > {backup_file}",
            check=False,
        )

        if result.returncode == 0:
            log_success(f"Backup saved to {backup_file}")
        else:
            log_warning("Database backup failed")
    else:
        log_warning(f"Could not parse DATABASE_URL: {db_url[:20]}...")


# =============================================================================
# RELEASES CLEANUP
# =============================================================================


def releases_cleanup(keep: int = 10) -> None:
    """Remove old releases, keeping the last N."""
    if not RELEASES_DIR.exists():
        return

    current = get_current_version()

    releases = []
    for d in RELEASES_DIR.iterdir():
        if d.is_dir() and d.name.startswith("v"):
            try:
                version = int(d.name[1:])
                releases.append((version, d))
            except ValueError:
                pass

    releases.sort(key=lambda x: x[0], reverse=True)

    # Keep the last N and the current
    to_keep = set()
    for i, (version, _) in enumerate(releases):
        if i < keep or version == current:
            to_keep.add(version)

    removed = 0
    for version, path in releases:
        if version not in to_keep:
            log_info(f"Removing v{version}...")
            shutil.rmtree(path)
            removed += 1

    if removed > 0:
        log_success(f"Cleaned up {removed} old release(s). Kept {len(to_keep)} release(s).")


# =============================================================================
# DEPLOYMENT (Blue-Green)
# =============================================================================


def deploy(env: str = "production", skip_backup: bool = False) -> None:
    """
    Full blue-green deployment:
    1. Database backup (unless --skip-backup)
    2. Create new release directory
    3. Copy code from git
    4. Install dependencies
    5. Run migrations
    6. Collect static files
    7. Switch symlink
    8. Reload services
    9. Health check (rollback if failed)
    10. Cleanup old releases (keep 10)
    """
    config = get_env_config(env)
    total_steps = 9 if skip_backup else 10
    step = 0

    print(f"\n{Colors.GREEN}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}  {PROJECT_NAME.upper()} Deployment - {env.upper()}{Colors.NC}")
    if skip_backup:
        print(f"{Colors.YELLOW}  (skipping database backup){Colors.NC}")
    print(f"{Colors.GREEN}{'='*60}{Colors.NC}\n")

    # Step 1: Database backup (unless skipped)
    if not skip_backup:
        step += 1
        log_step(step, total_steps, "Creating database backup...")
        db_backup(env)

    # Step 2: Create release directory
    step += 1
    version = get_next_version()
    release_dir = RELEASES_DIR / f"v{version}"
    log_step(step, total_steps, f"Creating release v{version}")

    RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    release_dir.mkdir()

    # Step 3: Copy code
    step += 1
    log_step(step, total_steps, "Copying code from git...")
    run_cmd(f"git archive HEAD | tar -x -C {release_dir}")

    # Step 4: Install dependencies
    step += 1
    log_step(step, total_steps, "Installing dependencies...")
    run_cmd(f"{VENV_DIR}/bin/pip install -e '.[web,api]'", cwd=release_dir)

    # Step 5: Run migrations
    step += 1
    log_step(step, total_steps, "Running migrations...")
    os.environ["DJANGO_SETTINGS_MODULE"] = config["django_settings"]
    run_cmd(
        f"{VENV_DIR}/bin/python manage.py migrate --noinput", cwd=release_dir / "web"
    )

    # Step 6: Collect static files
    step += 1
    log_step(step, total_steps, "Collecting static files...")
    run_cmd(
        f"{VENV_DIR}/bin/python manage.py collectstatic --noinput",
        cwd=release_dir / "web",
    )

    # Step 7: Switch symlink
    step += 1
    log_step(step, total_steps, "Switching to new release...")
    previous_release = get_current_release()

    if CURRENT_LINK.exists() or CURRENT_LINK.is_symlink():
        CURRENT_LINK.unlink()
    CURRENT_LINK.symlink_to(release_dir)

    # Step 8: Reload services
    step += 1
    log_step(step, total_steps, "Reloading services...")
    services_reload()

    # Step 9: Health check
    step += 1
    log_step(step, total_steps, "Running health check...")
    time.sleep(3)  # Give services time to start

    # Check web health
    result = run_cmd(
        f"curl -sf http://localhost:{PORTS['web']}/ > /dev/null", check=False
    )
    web_healthy = result.returncode == 0

    # Check API health
    result = run_cmd(
        f"curl -sf http://localhost:{PORTS['api']}/health > /dev/null", check=False
    )
    api_healthy = result.returncode == 0

    if web_healthy and api_healthy:
        # Step 10: Cleanup old releases
        log_step(total_steps, total_steps, "Cleaning up old releases...")
        releases_cleanup(keep=10)

        print(f"\n{Colors.GREEN}{'='*60}{Colors.NC}")
        print(f"{Colors.GREEN}  Deployment successful! (v{version}){Colors.NC}")
        print(f"{Colors.GREEN}{'='*60}{Colors.NC}\n")
    else:
        log_error("Health check failed! Rolling back...")
        if previous_release:
            CURRENT_LINK.unlink()
            CURRENT_LINK.symlink_to(previous_release)
            services_reload()
            log_warning(f"Rolled back to {previous_release.name}")
        sys.exit(1)


def rollback() -> None:
    """Instant rollback to previous release."""
    log_info("Rolling back to previous release...")

    current = get_current_release()
    if not current:
        log_error("No current release found")
        sys.exit(1)

    # Find previous release
    releases = sorted(
        [
            d
            for d in RELEASES_DIR.iterdir()
            if d.is_dir() and d.name.startswith("v") and d != current
        ],
        key=lambda x: int(x.name[1:]),
        reverse=True,
    )

    if not releases:
        log_error("No previous release to roll back to")
        sys.exit(1)

    previous = releases[0]

    log_info(f"Rolling back: {current.name} -> {previous.name}")

    CURRENT_LINK.unlink()
    CURRENT_LINK.symlink_to(previous)

    services_reload()

    log_success(f"Rolled back to {previous.name}")


# =============================================================================
# SHELL ACCESS
# =============================================================================


def shell() -> None:
    """Open Django shell."""
    os.chdir(PROJECT_ROOT / "web")
    os.execvp(f"{VENV_DIR}/bin/python", ["python", "manage.py", "shell"])


def dbshell() -> None:
    """Open database shell."""
    os.chdir(PROJECT_ROOT / "web")
    os.execvp(f"{VENV_DIR}/bin/python", ["python", "manage.py", "dbshell"])


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    # Allow direct execution for testing
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "status":
            services_status()
        elif cmd == "deploy":
            env_arg = sys.argv[2] if len(sys.argv) > 2 else "production"
            deploy(env_arg)
        elif cmd == "rollback":
            rollback()
        else:
            print(f"Unknown command: {cmd}")
    else:
        print("Usage: python poe_commands.py <command>")
