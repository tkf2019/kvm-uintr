# Caladan Validation Notes

## Why Caladan

Caladan already contains the guest-side paths that matter for this project:

- guest kernel module: `ksched/ksched.ko`
- guest kernel UINTR logic: `ksched/uintr.c`
- guest runtime assembly and setup: `runtime/uintr.S`, `runtime/preempt.c`
- guest sender path: `iokernel/ksched.h` using `__builtin_ia32_senduipi()`

This makes Caladan a better validation target than a synthetic demo because it exercises both guest kernel and guest userspace behavior.

## What success looks like

Inside the guest:

1. Caladan builds with `-muintr`.
2. `ksched.ko` loads without concluding that UINTR is unavailable.
3. runtime UINTR setup succeeds.
4. the iokernel path reaches guest-side `senduipi`.
5. user interrupts are delivered across vCPUs as expected.

## Early triage points

If validation fails, classify the issue first:

- feature exposure failure
  - guest CPUID does not advertise UINTR;
  - guest kernel lacks the required architectural support.
- host virtualization failure
  - guest sees the feature but interrupt delivery never arrives;
  - posted interrupt wakeup path is incomplete.
- guest integration failure
  - Caladan module or runtime assumes kernel behavior the guest does not provide yet.

## Practical first checks

- inspect guest `dmesg` for UINTR-related initialization;
- inspect host `dmesg` for `kvm-uintr` logs;
- confirm Caladan code path selection around `ksched_has_uintr` and runtime setup;
- keep one vCPU-to-vCPU wakeup case as the first reproducible scenario.
