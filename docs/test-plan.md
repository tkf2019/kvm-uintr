# Test Plan

## Step 1: Guest baseline

Use an Ubuntu 24.04 virtual machine as the first guest environment.

Suggested image source:

- Ubuntu Noble 24.04 cloud image
- `https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img`

## Step 2: Guest validation framework

Use Caladan inside the guest.

Relevant Caladan components:

- `ksched/ksched.ko`
- `ksched/uintr.c`
- runtime `uintr.S` and `preempt.c`
- `iokernel/ksched.h` where `__builtin_ia32_senduipi()` is used

Validation goal:

- boot the guest with UINTR exposed;
- load guest-side Caladan pieces successfully;
- run Caladan runtime and `iokerneld`;
- confirm guest-side `senduipi` works between vCPUs.

## Step 3: Host-side implementation

Build and load `kvm-uintr.ko` on the host, then iterate against the guest validation loop.

## Bring-up order

1. Build host module.
2. Load host module and inspect `dmesg`.
3. Start Ubuntu 24.04 guest with KVM acceleration.
4. Build or install guest kernel bits required by Caladan.
5. Build Caladan in guest with UINTR enabled.
6. Run Caladan tests that exercise scheduler wakeups and UINTR delivery.

## First acceptance criteria

- host module loads cleanly;
- guest boots with the expected CPU feature exposure plan;
- Caladan `ksched.ko` no longer falls back because guest UINTR is missing;
- guest runtime reaches the `senduipi` path.
