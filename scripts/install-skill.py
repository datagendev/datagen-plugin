#!/usr/bin/env python3
"""
install-skill.py -- Browse and install DataGen skills deterministically.

Usage:
    python3 install-skill.py --browse
    python3 install-skill.py --install <skill-id>

Exit codes:
    0  success
    1  network error / fetch failed
    2  skill not found
    3  skill not yet available (coming soon)
    4  skill has no installable path
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error

SKILLS_INDEX_URL = (
    "https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main/skills.json"
)
REPO_RAW_BASE = (
    "https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fetch_json(url):
    """Fetch and parse JSON from a URL. Returns (data, error_msg)."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "datagen-plugin/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode()), None
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
        return None, str(exc)
    except json.JSONDecodeError as exc:
        return None, f"Invalid JSON: {exc}"


def fetch_bytes(url):
    """Fetch raw bytes from a URL. Returns (bytes, error_msg)."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "datagen-plugin/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read(), None
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
        return None, str(exc)


def print_catalog(skills):
    """Print a formatted skill catalog."""
    print("DataGen Skills")
    print("=" * 60)
    print()

    for skill in skills:
        status = "[AVAILABLE]" if skill["status"] == "stable" else "[COMING SOON]"
        print(f"  {skill['id']}  {status}")
        print(f"    {skill['description']}")
        print()

        # Built-in DataGen tools
        tools = skill.get("datagen_tools", [])
        if tools:
            print(f"    Built-in tools: {', '.join(tools)}")

        # Required MCPs
        required = skill.get("datagen_mcps", {}).get("required", [])
        for mcp in required:
            alts = mcp.get("alternatives", [])
            name = " | ".join(alts) if alts else mcp["name"]
            print(f"    Required MCP:  {name} -- {mcp['purpose']}")

        # Optional MCPs
        optional = skill.get("datagen_mcps", {}).get("optional", [])
        for mcp in optional:
            print(f"    Optional MCP:  {mcp['name']} -- {mcp['purpose']}")

        # Secrets
        secrets = skill.get("secrets", [])
        if secrets:
            names = [s["name"] for s in secrets]
            print(f"    Secrets:       {', '.join(names)}")

        tags = skill.get("tags", [])
        if tags:
            print(f"    Tags: {', '.join(tags)}")
        print()

    print("-" * 60)
    print("Install a skill:     /datagen:fetch-skill <skill-id>")
    print("Connect MCP servers: https://app.datagen.dev/tools")


# ---------------------------------------------------------------------------
# Browse mode
# ---------------------------------------------------------------------------

def cmd_browse():
    data, err = fetch_json(SKILLS_INDEX_URL)
    if err:
        print(f"ERROR: Failed to fetch skill index.\n  URL: {SKILLS_INDEX_URL}\n  {err}")
        print("\nCheck your network connection and try again.")
        return 1

    skills = data.get("skills", [])
    if not skills:
        print("The skill index is empty. No skills are available yet.")
        return 0

    print_catalog(skills)
    return 0


# ---------------------------------------------------------------------------
# Install mode
# ---------------------------------------------------------------------------

def cmd_install(skill_id):
    # -- 1. Fetch index -------------------------------------------------------
    data, err = fetch_json(SKILLS_INDEX_URL)
    if err:
        print(f"ERROR: Failed to fetch skill index.\n  URL: {SKILLS_INDEX_URL}\n  {err}")
        print("\nCheck your network connection and try again.")
        return 1

    # -- 2. Show catalog ------------------------------------------------------
    skills = data.get("skills", [])
    print_catalog(skills)
    print()

    # -- 3. Validate skill ----------------------------------------------------
    match = next((s for s in skills if s["id"] == skill_id), None)
    if not match:
        print(f'Skill "{skill_id}" not found in the index.')
        print("Run /datagen:fetch-skill to see available skills.")
        return 2

    if match["status"] != "stable":
        print(f'Skill "{skill_id}" is coming soon and not yet available for install.')
        print(f"  Description: {match['description']}")
        return 3

    skill_path = match.get("path")
    if not skill_path:
        print(f'Skill "{skill_id}" has no installable path yet.')
        return 4

    print(f'Installing skill: {skill_id}')
    print(f"  Path in repo: {skill_path}")
    print()

    # -- 4. Fetch manifest ----------------------------------------------------
    manifest_url = f"{REPO_RAW_BASE}/{skill_path}/manifest.json"
    manifest, err = fetch_json(manifest_url)
    if err:
        print(f"ERROR: Failed to fetch manifest.\n  URL: {manifest_url}\n  {err}")
        return 1

    # -- 5. Download files to .claude/skills/<skill-id>/ ----------------------
    install_dir = f".claude/skills/{skill_id}"
    os.makedirs(install_dir, exist_ok=True)

    files = manifest.get("files", [])
    downloaded = 0
    skipped = []

    for filepath in files:
        remote_url = f"{REPO_RAW_BASE}/{skill_path}/{filepath}"
        local_path = os.path.join(install_dir, filepath)

        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        content, dl_err = fetch_bytes(remote_url)
        if dl_err:
            print(f"  SKIP  {filepath} ({dl_err})")
            skipped.append(filepath)
            continue

        with open(local_path, "wb") as f:
            f.write(content)
        print(f"  OK    {local_path}")
        downloaded += 1

    # Also save manifest.json
    manifest_local = os.path.join(install_dir, "manifest.json")
    with open(manifest_local, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"  OK    {manifest_local}")

    print(f"\nDownloaded {downloaded}/{len(files)} files to {install_dir}/")
    if skipped:
        print(f"  Skipped: {', '.join(skipped)}")
    print()

    # -- 6. Remap relative paths in SKILL.md ----------------------------------
    skill_md_path = os.path.join(install_dir, "SKILL.md")
    if os.path.isfile(skill_md_path):
        with open(skill_md_path, "r") as f:
            content = f.read()

        original = content
        # Replace relative script/context/learnings/tmp paths with absolute
        # Matches patterns like `scripts/`, `./scripts/`, but not already-prefixed paths
        prefix = f".claude/skills/{skill_id}"
        for subdir in ("scripts", "context", "learnings", "tmp"):
            # Pattern: standalone relative path references (not already under .claude/)
            content = re.sub(
                rf'(?<![/\w]){subdir}/',
                f'{prefix}/{subdir}/',
                content,
            )

        if content != original:
            with open(skill_md_path, "w") as f:
                f.write(content)
            print("Updated SKILL.md with absolute paths.")
        else:
            print("SKILL.md has no relative paths to update.")
    else:
        print("No SKILL.md found in skill files.")
    print()

    # -- 7. Check prerequisites -----------------------------------------------
    print("Prerequisites")
    print("-" * 40)

    # Secrets
    secrets = match.get("secrets", [])
    missing_secrets = []
    for s in secrets:
        if s.get("required") and not os.environ.get(s["name"]):
            missing_secrets.append(s)

    if missing_secrets:
        print("Missing required secrets:")
        for s in missing_secrets:
            print(f"  export {s['name']}=<value>  # {s['description']}")
    elif secrets:
        print("All required secrets are set.")
    else:
        print("No secrets required.")

    # Required MCPs
    required_mcps = match.get("datagen_mcps", {}).get("required", [])
    if required_mcps:
        print()
        print("Required MCP servers (connect at https://app.datagen.dev/tools):")
        for mcp in required_mcps:
            alts = mcp.get("alternatives", [])
            name = " | ".join(alts) if alts else mcp["name"]
            print(f"  - {name}: {mcp['purpose']}")
    print()

    # -- 8. Python dependencies -----------------------------------------------
    python_pkgs = manifest.get("requirements", {}).get("python_packages", [])
    if python_pkgs:
        pip_cmd = "pip install " + " ".join(python_pkgs)
        print("Python dependencies required:")
        print(f"  {pip_cmd}")
    else:
        print("No Python packages required.")
    print()

    # -- 9. Post-install guide ------------------------------------------------
    readme_path = os.path.join(install_dir, "README.md")
    if os.path.isfile(readme_path):
        print("=" * 60)
        print("POST-INSTALL GUIDE")
        print("=" * 60)
        with open(readme_path, "r") as f:
            print(f.read())
        print()

    print("-" * 60)
    print(f"Skill installed. To use it:")
    print(f"  /datagen:{skill_id}")
    print()
    print("The skill is now available as a slash command.")

    return 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Browse and install DataGen skills."
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--browse", action="store_true", help="List available skills")
    group.add_argument("--install", metavar="SKILL_ID", help="Install a specific skill")

    args = parser.parse_args()

    if args.browse:
        sys.exit(cmd_browse())
    else:
        sys.exit(cmd_install(args.install))


if __name__ == "__main__":
    main()
