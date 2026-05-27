# Python .venv Usage

## Repository convention

Python commands in this repository should use the repo-local `.venv` by default.

## Preferred command forms

- `.venv/bin/python --version`
- `.venv/bin/python script.py`
- `.venv/bin/python -m pytest`
- `.venv/bin/pip install <package>`

## Why

- avoids dependency drift between system Python and repo tooling;
- keeps package installs local to the repository;
- makes automation reproducible across shells and sessions.

## Bootstrap

If `.venv` does not exist yet:

1. `python3 -m venv .venv`
2. `.venv/bin/python -m pip install --upgrade pip setuptools wheel`
