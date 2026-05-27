---
name: python-venv-default
description: Default all Python work in this repository to the repo-local .venv. Use this skill when running Python commands, installing Python packages, creating helper scripts, or editing automation that depends on Python so commands consistently use .venv/bin/python and .venv/bin/pip.
---

# Python Venv Default

## Overview

This skill establishes a strict local convention: Python commands use the repository `.venv` by default. It avoids mixing system Python with project tooling and keeps dependency state local to the repo.

## Rules

- Prefer `.venv/bin/python` over `python` or `python3`.
- Prefer `.venv/bin/pip` over `pip` or `pip3`.
- If a tool exposes a console script, prefer `.venv/bin/<tool>`.
- Only fall back to system Python when `.venv` does not exist and bootstrapping it is the explicit task.

## Default Commands

- Version check: `.venv/bin/python --version`
- Run a script: `.venv/bin/python path/to/script.py`
- Install a package: `.venv/bin/pip install <pkg>`
- Freeze deps: `.venv/bin/pip freeze`
- Run tests: `.venv/bin/pytest`

## Bootstrap

When `.venv` is missing and the task requires Python:

1. Create it with `python3 -m venv .venv`
2. Upgrade base tooling with `.venv/bin/python -m pip install --upgrade pip setuptools wheel`
3. Continue using `.venv/bin/...` paths for all commands

## References

- Usage notes: [references/venv-usage.md](references/venv-usage.md)
