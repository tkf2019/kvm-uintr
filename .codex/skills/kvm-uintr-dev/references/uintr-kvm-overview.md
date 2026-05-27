# KVM UINTR Overview

## Goal

Enable a KVM guest to use Intel User Interrupts with behavior close to bare metal, while keeping feature exposure, virtualization state, and userspace integration coherent.

## Architectural pieces

- Instruction-set support and architectural state:
  `SENDUIPI`, `CLUI`, `STUI`, `TESTUI`, UINTR-related MSRs, and the guest-visible state needed by the CPU architecture.
- Delivery metadata:
  UITT entries and UPID-style interrupt target state that identifies receiver threads and notification routing.
- VMX/KVM backing state:
  posted interrupt plumbing, notification vectors, VM-entry/VM-exit save and restore, and guest state validation.
- Userspace integration:
  QEMU CPU feature exposure and launch-time capability gating.

## Likely kernel work areas

- `arch/x86/kvm/`
- `arch/x86/kvm/vmx/`
- `arch/x86/include/asm/`
- UAPI or selftest areas if guest-visible capability reporting is added

## Implementation checklist

1. Host capability detection
   - verify host CPU/kernel support for UINTR-related architectural pieces;
   - decide which parts are mandatory before KVM advertises the guest feature.
2. Guest CPU feature exposure
   - wire CPUID exposure;
   - validate CR4 and related control bits;
   - make unsupported combinations fail cleanly.
3. Guest architectural state
   - emulate or pass through UINTR MSRs;
   - handle vCPU reset, load, save, migration, and nested checks as needed.
4. VMX delivery path
   - connect guest UINTR delivery to posted interrupt or equivalent VMX notification state;
   - verify notification vector allocation and isolation from existing PI/APIC behavior.
5. Userspace/QEMU
   - expose the feature in CPU models or named flags;
   - reject enablement when KVM capability probing says no.
6. Validation
   - compile touched components;
   - launch a guest with the feature enabled;
   - run sender/receiver UINTR tests inside the guest;
   - confirm masked/disabled paths fail as expected.

## Common failure modes

- CPUID advertises UINTR but guest MSR handling is incomplete.
- KVM VMX state is partially wired, so delivery appears enabled but interrupts never arrive.
- QEMU feature masking and KVM capability checks drift apart.
- Save/restore or migration paths lose UINTR state.
