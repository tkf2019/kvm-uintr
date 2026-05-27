# Architecture

## Scope

This repository targets the host-side module that extends KVM so a guest can use Intel User Interrupts.

## Layering

1. Host kernel
   - stock or patched host KVM
   - `kvm-uintr.ko` from this repository
2. Guest kernel
   - Ubuntu 24.04 guest baseline
   - guest kernel features needed by Caladan `ksched.ko`
3. Guest userspace
   - Caladan runtime
   - `iokerneld`

## Validation target

The feature is considered minimally working when Caladan runs inside the guest and successfully uses `senduipi` for user interrupt delivery between vCPUs.

## Host-side responsibilities

- decide when the guest may enumerate UINTR support;
- connect guest UINTR delivery to host KVM/VMX interrupt machinery;
- preserve guest UINTR state across vCPU run transitions;
- avoid breaking existing posted interrupt and APIC flows.

## Guest-side role

The guest is not the implementation target for this repo. It is the validation environment:

- Ubuntu 24.04 gives a stable guest userspace/kernel baseline;
- Caladan `ksched.ko` and runtime exercise the guest UINTR path;
- guest test failures should be triaged against host feature exposure, guest kernel support, and Caladan assumptions.
