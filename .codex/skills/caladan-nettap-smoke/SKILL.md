---
name: caladan-nettap-smoke
description: Clone, build, and smoke-test a Caladan checkout with the nettap-backed iokernel path. Use when Codex needs to clone `https://github.com/shenango/caladan`, initialize its submodules, build `ksched`, run the standard `./test.sh` flow, or verify the minimal nettap iokernel and core-allocation smoke path in a guest environment.
---

# Caladan Nettap Smoke

## Overview

Use this skill for a reproducible Caladan smoke workflow in a guest or other fresh environment. Default to cloning upstream `https://github.com/shenango/caladan` into the current workspace unless the user explicitly provides an existing checkout. Keep the flow narrow: clone, initialize submodules, build Caladan, build `ksched`, then run `./test.sh`.

## Workflow

1. Obtain a Caladan checkout. By default, clone upstream and work from that repo root:

```bash
git clone https://github.com/shenango/caladan
cd caladan
```

If the user already gave you a checkout path, use it instead of cloning.

2. Resolve the skill root so bundled resources can be referenced without host-specific absolute paths:

```bash
SKILL_ROOT=/path/to/.codex/skills/caladan-nettap-smoke
CALADAN_ROOT=$(pwd)
```

When running inside Codex on the same machine as the skill install, `SKILL_ROOT` is the directory containing this `SKILL.md`.

3. If `make` or a Rust build step fails with `error[E0133]` on `bindings/rust/src/asm.rs` for `core::arch::x86_64::__cpuid(0)`, apply the bundled compatibility patch first:

```bash
git apply "$SKILL_ROOT/patches/rust-cpuid-e0133.patch"
```

Only apply this patch when the checkout does not already contain the fix.

4. Initialize submodules. In this checkout the real script is `./build/init_submodules.sh`.
If the user says `./scripts/init_submodule.sh`, treat that as the same intent and use the existing script path in the tree.

```bash
./build/init_submodules.sh
```

5. Build Caladan:

```bash
make
```

6. Build the guest scheduler kernel module:

```bash
make -C ksched
```

7. Run the standard smoke test:

```bash
./test.sh
```

## What `./test.sh` Covers

Treat `./test.sh` as the minimal nettap smoke path for this repo. It already:

- runs `sudo scripts/setup_machine.sh`;
- starts nettap-backed `iokerneld` with:

```bash
sudo ./iokerneld ias nobw noht no_hw_qdel numanode -1 -- --allow 00:00.0 --vdev=net_tap0
```

- waits for the iokernel log to report `running dataplan`;
- generates two runtime configs with `runtime_kthreads` set to `CORES-2` and `runtime_guaranteed_kthreads 0`;
- runs the executable tests under `tests/` except storage;
- builds and runs `apps/bench/netperf`;
- builds and runs `apps/loadgen` for both TCP and UDP.

For this workflow, treat that as the minimal core-allocation smoke test as well, because it exercises runtime startup and scheduler behavior with dynamic runtime kthread counts on top of the nettap iokernel.

## Validation

Consider the workflow successful when:

- `./build/init_submodules.sh`, `make`, and `make -C ksched` exit with status 0;
- `./test.sh` exits with status 0;
- the iokernel reaches `running dataplan`;
- no step requires host-specific path assumptions beyond locating `SKILL_ROOT`.

## Execution Notes

- `./test.sh` uses `sudo`; do not split out its setup steps unless debugging a failure.
- `./test.sh` bootstraps a local Rust toolchain only if `cargo` is missing.
- If debugging is needed, inspect `/tmp/iokernel_${USER}.log`.
- The bundled patch at `patches/rust-cpuid-e0133.patch` exists only to handle the Rust `E0133` `__cpuid` mismatch seen on some toolchains.
- Reference output from a successful run is available in `references/test.log`. Treat it as a shape-of-output sample, not a source of fixed absolute paths, usernames, CPU counts, or exact timings.
