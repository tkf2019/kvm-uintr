# UINTR Hardware and KVM APIC Notes

## Goal

Understand the hardware mechanisms UINTR depends on, how Caladan and `uintr-next` consume them, and how the local KVM/VMX APIC virtualization path on this machine is structured.

## Primary sources

- Intel Architecture Instruction Set Extensions Programming Reference
  - https://www.intel.com/content/www/us/en/content-details/836329/intel-architecture-instruction-set-extensions-programming-reference.html
  - Intel currently publishes `Version 61 (Latest)` on the active content pages checked on 2026-05-27:
    - content ID 819680, dated 2024-03-29
    - content ID 826290, dated 2024-06-27
- Caladan upstream repository
  - `ksched/uintr.c`
  - `ksched/uintr_hw.h`
  - `runtime/preempt.c`
  - `iokernel/ksched.h`
- `uintr-linux-kernel` `uintr-next` branch
  - `arch/x86/kernel/uintr.c`
  - `arch/x86/kernel/traps.c`
  - `arch/x86/include/uapi/asm/uintr.h`
- local kernel source tree used for KVM/APIC analysis
  - `/tkf-workspace/flux/kernel`

## Scope note

The local full source tree available in this environment is `/tkf-workspace/flux/kernel`. Its top-level `Makefile` reports version `6.6.0`. The running kernel is `6.17.13-flux`, and only headers are available for that exact build in `/usr/src/linux-headers-6.17.13-flux`.

Use the local tree for structure and mechanism analysis. If exact patching against the running kernel is needed, obtain the matching full `6.17.13-flux` source tree.

## Intel UINTR hardware model

From the Intel reference and the guest-side code paths:

- instructions
  - `SENDUIPI`
  - `CLUI`
  - `STUI`
  - `TESTUI`
  - `UIRET`
- enablement and enumeration
  - CPUID advertises UINTR capability
  - `CR4.UINTR` enables the architectural feature
- dedicated architectural state
  - UINTR state is XSAVE component 14
  - `XSAVES/XRSTORS` preserve the UINTR state
- UINTR MSRs
  - `IA32_UINTR_RR`
  - `IA32_UINTR_HANDLER`
  - `IA32_UINTR_STACKADJUST`
  - `IA32_UINTR_MISC`
  - `IA32_UINTR_PD`
  - `IA32_UINTR_TT`
- data structures
  - UPID for receiver-side delivery state
  - UITT for sender-side target table
- notification routing
  - a notification vector wakes the receiver context when a user interrupt becomes pending

## How Caladan uses UINTR

Caladan assumes the guest already sees a working UINTR architectural surface.

### Guest kernel side

`ksched/uintr.c`:

- saves and restores UINTR xstate with `XSAVES/XRSTORS`;
- programs handler, stack, `uif`, notification vector, `upid_addr`, and `uitt_addr`;
- manages per-CPU UPID state and per-context UITT entries;
- borrows KVM posted-interrupt wakeup behavior through `kvm_set_posted_intr_wakeup_handler()`.

### Guest userspace side

`runtime/preempt.c` and `runtime/uintr.S`:

- register a user interrupt handler through `KSCHED_IOC_UINTR_SETUP_USER`;
- save and restore xstate in the user interrupt path;
- assume UINTR is a real architectural feature.

### Guest sender path

`iokernel/ksched.h`:

- directly emits `__builtin_ia32_senduipi()`.

### Consequence

Caladan needs the full contract:

- guest CPUID and `CR4.UINTR`;
- guest UINTR xstate;
- guest-visible UINTR MSRs;
- UPID/UITT semantics;
- wakeup behavior compatible with posted-interrupt style notification.

## How `uintr-next` enables UINTR

The `uintr-next` branch makes Linux itself understand and expose UINTR.

### What it adds

- UAPI and control surface
  - `arch/x86/include/uapi/asm/uintr.h`
  - syscalls and ioctls for handlers, senders, and target tables
- x86 kernel UINTR state management
  - `arch/x86/kernel/uintr.c`
  - xstate/MSR programming through `start_update_xsave_msrs()` and `xsave_wrmsrl()`
- trap fixups
  - `arch/x86/kernel/traps.c` decodes and repairs `SENDUIPI`-related #UD and #GP cases
- entry/notification integration
  - entry path and notification vector handling

### What it means

This model assumes the guest kernel is UINTR-aware and participates in context switch, trap, and ABI handling.

## Existing guest-side models

### Model A: guest kernel natively supports UINTR

The `uintr-next` approach.

- pros
  - architecturally complete
  - aligns with intended Linux UINTR ABI handling
- cons
  - needs a guest kernel with UINTR patches
  - guest is not unaware

### Model B: guest kernel module enables a Caladan-specific UINTR path

The Caladan `ksched.ko` approach.

- pros
  - lighter than carrying a full guest kernel branch
  - good workload-driven validation path
- cons
  - still assumes guest-visible UINTR state exists
  - guest is still aware because the module directly programs UINTR state

## Desired model: host-transparent virtualization

This repository targets a different model:

- no guest `uintr-next` branch should be required;
- ideally no guest-side UINTR enablement beyond consuming the architectural feature;
- host KVM should virtualize the UINTR surface completely enough that guest software behaves as if real UINTR hardware exists.

## Design direction

For the steady-state fast path, guest UINTR instructions should execute natively in guest context.

That implies:

- `SENDUIPI` should not rely on routine VM-Exit and instruction emulation;
- `UIRET` should return entirely within guest architectural state handling;
- KVM should focus on virtualizing the guest-visible UINTR state and mapping guest delivery semantics onto host VMX mechanisms.

VM-Exit is still acceptable for control-plane work such as:

- initial feature exposure and setup;
- guest MSR interception and validation;
- vCPU state load/save/reset paths;
- exceptional or disabled-feature fault handling.

## Local KVM/APIC analysis

The local tree does not contain UINTR support code, which is useful because it isolates what KVM already provides today for interrupt virtualization.

### APIC hardware concepts present in the local tree

`arch/x86/include/asm/apicdef.h` defines:

- APIC IRR/ISR/TMR registers;
- APIC ICR, destination modes, and delivery modes;
- LAPIC timer and LVT controls.

Useful locations:

- `APIC_IRR`, `APIC_ISR`: [apicdef.h](/tkf-workspace/flux/kernel/arch/x86/include/asm/apicdef.h:60)
- `APIC_ICR` and delivery mode fields: [apicdef.h](/tkf-workspace/flux/kernel/arch/x86/include/asm/apicdef.h:70)

### KVM host vectors used for posted interrupt handling

The host-side vectors reserved by KVM are:

- `POSTED_INTR_VECTOR`
- `POSTED_INTR_WAKEUP_VECTOR`
- `POSTED_INTR_NESTED_VECTOR`

Location:

- [irq_vectors.h](/tkf-workspace/flux/kernel/arch/x86/include/asm/irq_vectors.h:86)

These are host-internal vectors. They are not guest UINTR notification vectors.

### Virtual LAPIC representation

KVM keeps a guest-visible LAPIC register page in `struct kvm_lapic.regs`.

Important note from the source:

- the layout matches the guest-visible APIC register page 1:1 because VMX microcode accesses it directly.

Location:

- [lapic.h](/tkf-workspace/flux/kernel/arch/x86/kvm/lapic.h:74)

### KVM interrupt routing to LAPICs

KVM routes APIC interrupts with:

- `kvm_irq_delivery_to_apic()`
- `kvm_apic_set_irq()`
- `__apic_accept_irq()`

Locations:

- delivery routing: [irq_comm.c](/tkf-workspace/flux/kernel/arch/x86/kvm/irq_comm.c:47)
- accept and classify delivery mode: [lapic.c](/tkf-workspace/flux/kernel/arch/x86/kvm/lapic.c:1288)

The LAPIC path is vector-oriented: pick a destination vCPU, update LAPIC state, then inject or post the interrupt.

### KVM APIC interrupt consumption

When KVM needs to inject a LAPIC interrupt in software, it pulls the highest pending vector from LAPIC IRR and moves it into ISR.

Location:

- [lapic.c](/tkf-workspace/flux/kernel/arch/x86/kvm/lapic.c:2889)

### APICv and virtual interrupt delivery

APICv activation is controlled per-VM and per-vCPU.

Locations:

- APICv activation bookkeeping: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:10323)
- VMX execution controls toggled for APICv: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4433)
- VMX optional controls list: [vmx.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.h:549)

When APICv is active, VMX enables:

- `SECONDARY_EXEC_APIC_REGISTER_VIRT`
- `SECONDARY_EXEC_VIRTUAL_INTR_DELIVERY`
- optional `TERTIARY_EXEC_IPI_VIRT`

### Posted interrupt descriptor

VMX posted interrupt state is carried in `struct pi_desc`.

Fields of interest:

- `pir[]` pending bitmap
- `on`
- `sn`
- `nv`
- `ndst`

Location:

- [posted_intr.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.h:10)

This is the host-side structure most similar to UINTR UPID behavior.

### Posted interrupt delivery path

When VMX can use posted interrupts:

1. set the vector in `pi_desc.pir`
2. set `ON`
3. trigger the host posted interrupt notification vector

Location:

- [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4240)

If posted delivery cannot be used, KVM falls back to:

1. setting pending LAPIC state in software;
2. requesting event injection;
3. kicking the target vCPU.

Relevant path:

- fallback from posted interrupt to LAPIC IRR: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4275)

### Posted interrupt wakeup path

When the target vCPU blocks or is preempted, VMX can switch the posted-interrupt descriptor to a wakeup vector and later restore it:

- schedule-in PI restore: [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:53)
- schedule-out wakeup-vector switch: [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:148)
- wakeup handler: [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:218)
- PI descriptor invariant on init: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4841)

- setting LAPIC IRR
- making `KVM_REQ_EVENT`
- kicking the vCPU

Location:

- [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4270)

### VMX control bits relevant to APIC virtualization

- `PIN_BASED_POSTED_INTR`
  - [vmx.h](/tkf-workspace/flux/kernel/arch/x86/include/asm/vmx.h:91)
- `SECONDARY_EXEC_VIRTUALIZE_APIC_ACCESSES`
- `SECONDARY_EXEC_VIRTUALIZE_X2APIC_MODE`
- `SECONDARY_EXEC_APIC_REGISTER_VIRT`
- `SECONDARY_EXEC_VIRTUAL_INTR_DELIVERY`

Locations:

- [vmx.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.h:507)
- [vmx.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.h:549)

### APIC access page

VMX programs `APIC_ACCESS_ADDR` for APIC MMIO virtualization.

Location:

- [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:6795)

This is relevant for LAPIC MMIO virtualization, but it is not enough for UINTR because UINTR also requires new architectural state and MSRs.

## What this means for UINTR virtualization

### What cannot be reused directly

UINTR is not just another LAPIC vector. The existing LAPIC path is based on:

- guest LAPIC IRR/ISR/TMR;
- APIC destination matching;
- LAPIC vector injection rules.

UINTR instead centers on:

- sender UITT entries;
- receiver UPID state;
- UINTR MSRs and XSAVE state;
- guest user-level interrupt semantics.

### What is reusable

The VMX posted interrupt machinery is the closest host-side primitive to UINTR delivery.

The useful similarities are:

- pending bitmap
- outstanding/suppress notification
- notification vector
- notification destination

That makes `pi_desc` and posted-interrupt wakeup logic the most promising host-side substrate for implementing guest UINTR delivery.

### Important distinction

Host posted interrupt vectors such as `POSTED_INTR_VECTOR` are internal to KVM. Guest UINTR notification vectors are guest architectural state and must be virtualized separately.

The host path may reuse posted interrupts internally, but guest-visible `UINV` must remain guest-defined state.

## Implications for `kvm-uintr.ko`

Host-transparent virtualization must cover all guest-visible UINTR surfaces, not just instruction execution.

### Minimum guest-visible contract

1. enumeration
   - expose the UINTR CPUID bit only when host support and KVM support are ready
2. control
   - virtualize `CR4.UINTR`
3. architectural state
   - virtualize XSAVE component 14 per vCPU
   - preserve it across vCPU entry, exit, reset, and state save/restore
4. MSRs
   - trap and emulate UINTR MSRs
5. delivery semantics
   - model guest receiver UPID and sender UITT state in a way KVM can consume
   - translate guest `SENDUIPI` effects into target-vCPU wakeups and pending notifications
6. exception behavior
   - match guest-visible UINTR faults and success cases closely enough for Linux and Caladan expectations

### Practical boundary

If the guest kernel is completely unmodified and does not understand UINTR, full transparency is much harder because some layer still needs to preserve and consume the architectural state correctly.

A practical first goal is:

- no `uintr-next` guest kernel branch;
- host provides the full UINTR virtual hardware surface;
- guest software such as Caladan can consume it as if it were native.

## Practical conclusion

Caladan is a good validation workload because it exercises the full UINTR state machine. It also proves that guest-visible `SENDUIPI` alone is not enough.

The host side must supply:

- CPUID
- `CR4.UINTR`
- UINTR XSAVE state
- UINTR MSRs
- UPID/UITT-backed delivery
- notification and wakeup behavior

The most promising KVM reuse point is the VMX posted interrupt path, not the ordinary LAPIC IRR/ISR injection path alone.
