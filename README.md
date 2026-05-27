## kvm-uintr

This repository is for implementing a host-side `kvm-uintr.ko` module so a KVM guest can use Intel User Interrupts.

## Target layering

The intended stack is:

1. host kernel
   - host KVM
   - host `kvm-uintr.ko`
2. guest kernel
   - guest kernel support required by Caladan
   - guest Caladan `ksched.ko`
3. guest userspace
   - Caladan runtime
   - `iokerneld`

That boundary matters: this repository focuses on the host-side KVM/UINTR implementation. Ubuntu 24.04 is the guest baseline, and Caladan is the guest-side validation workload.

## Initial goals

1. Build a Ubuntu 24.04 guest test environment.
2. Run Caladan inside the guest and use it as the UINTR validation framework.
3. Implement and load `kvm-uintr.ko` on the host, then verify guest-side `senduipi` between vCPUs through Caladan.

## Repository layout

- `src/`
  Host-side kernel module sources for `kvm-uintr.ko`.
- `include/`
  Shared headers for the module.
- `docs/`
  Architecture, test environment, and validation notes.
- `scripts/`
  Helper scripts for building the module and preparing guest test assets.
- `.codex/skills/`
  Project-local Codex skills for KVM UINTR work and Python `.venv` conventions.

## Local skills

- `.codex/skills/kvm-uintr-dev`
- `.codex/skills/python-venv-default`

## Current status

The repository now contains project-local skills, initial architecture notes, a host module skeleton, and guest test workflow documentation.
