---
name: kvm-uintr-dev
description: Research, plan, port, and validate Intel User Interrupt support across KVM, Linux, and QEMU. Use this skill when the task involves KVM UINTR enablement, guest CPU feature exposure, VMX posted interrupt plumbing, UINTR-related MSR/XSAVE state handling, or tracking upstream patch/documentation status.
---

# KVM UINTR Dev

## Overview

Use this skill to turn KVM UINTR work into a repeatable engineering workflow. It is for repo setup, architecture review, implementation planning, patch porting, and validation around guest-side Intel UINTR support.

## When To Use

- The user asks for `kvm-uintr`, `uintr`, `SENDUIPI`, `UPID`, `UITT`, or guest user interrupt support.
- The task touches `arch/x86/kvm`, `vmx`, CPUID/MSR emulation, XSAVE/XSTATE, or QEMU CPU feature exposure.
- You need to compare upstream Linux/KVM/QEMU work with the local tree before coding.

## Core Workflow

1. Read [references/uintr-hardware-and-kvm-apic.md](references/uintr-hardware-and-kvm-apic.md) when the task depends on Intel UINTR hardware semantics, Caladan usage, APIC/posted-interrupt behavior, or host-transparent virtualization goals.
2. Read [references/kvm-uintr-hook-points.md](references/kvm-uintr-hook-points.md) when the task is choosing patch points in `arch/x86/kvm`, especially for CPUID, CR4, xstate, MSR, and posted-interrupt integration.
3. Read [references/upstream-status.md](references/upstream-status.md) when you need source links, likely upstream files, or patch series context.
4. Inspect the local tree first with `rg --files`, `rg "uintr|SENDUIPI|UPID|UITT|posted interrupt|xsave"` and `git status --short`.
5. Keep Linux kernel and QEMU workstreams separate. KVM guest support usually spans:
   - CPU feature enumeration: CPUID, CR4 bits, XSS/XFD or XSAVE-related state exposure as applicable.
   - Guest-visible architectural state: UINTR MSRs, save/restore, migration implications.
   - VMX backing state: posted interrupt descriptors, notification vectors, delivery routing.
   - Userspace integration: QEMU CPU model flags and KVM capability probing.
6. Validate in layers:
   - build or compile coverage for touched kernel/QEMU components;
   - boot/launch smoke test for a guest advertising UINTR;
   - sender/receiver functional test inside the guest;
   - negative tests for feature masking and disabled controls.

## Implementation Rules

- Prefer primary sources: Intel architecture docs, LKML/lore patch threads, kernel docs, QEMU patch discussions.
- Treat KVM UINTR as a cross-boundary feature. Do not stop after kernel-side enumeration if userspace CPU models still hide the feature.
- Prefer native guest execution over instruction emulation. `SENDUIPI`, `UIRET`, and related guest-visible UINTR instructions should run in guest context whenever hardware and VMX state allow it; do not design around routine VM-Exit plus software emulation.
- Mirror existing KVM patterns for new guest state. Reuse nearby code for MSR lists, vCPU reset, context switch, nested VMX checks, and migration save/restore.
- Keep patches narrowly scoped. Separate mechanical refactors from feature work.
- When patching Python tooling in this repo, follow the `python-venv-default` skill and use `.venv/bin/python` or `.venv/bin/pip`.

## Common Checks

- Confirm the guest sees the UINTR CPUID bit only when host support and KVM exposure both allow it.
- Confirm guest writes to UINTR-related MSRs are intercepted, validated, and restored correctly.
- Confirm guest UINTR instructions execute without avoidable VM-Exit in the steady-state path.
- Confirm posted interrupt notification vector handling does not collide with existing APIC/PI flows.
- Confirm vCPU migration and reset paths do not drop UINTR state.
- Confirm QEMU rejects unsupported CPU model combinations cleanly.

## References

- Hardware and KVM virtual APIC notes: [references/uintr-hardware-and-kvm-apic.md](references/uintr-hardware-and-kvm-apic.md)
- Local KVM patch-point map: [references/kvm-uintr-hook-points.md](references/kvm-uintr-hook-points.md)
- Source links and upstream tracking: [references/upstream-status.md](references/upstream-status.md)
