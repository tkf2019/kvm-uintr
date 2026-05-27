# KVM UINTR Hook Points

## Goal

Map each guest-visible UINTR requirement to the existing KVM and VMX hook points in the local kernel source tree.

This note is based on the local source tree at `/tkf-workspace/flux/kernel`. It is a structure map for implementation planning, not proof that upstream KVM already supports UINTR.

Environment and source-version caveats are tracked in [uintr-hardware-and-kvm-apic.md](uintr-hardware-and-kvm-apic.md). This file focuses only on patch points.

## Hook-point summary

| UINTR surface | Existing KVM hook point | Local evidence | Notes |
| --- | --- | --- | --- |
| CPUID feature exposure | `arch/x86/kvm/cpuid.c` | [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:409), [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:452) | Guest CPUID model is accepted in `kvm_set_cpuid()` and finalized in `kvm_vcpu_after_set_cpuid()`. |
| Dynamic CPUID updates after guest state changes | `kvm_update_cpuid_runtime()` | [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:265), [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:309) | Existing pattern for features whose visibility depends on CR4 or xstate-related settings. |
| CPUID leaf `0xD` / xstate enumeration | `cpuid.c` leaf `0xD` handling | [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:1011) | This is the natural place to add xstate component 14 exposure once KVM tracks it. |
| Guest-supported XCR0 derivation | `cpuid_get_supported_xcr0()` and `vcpu->arch.guest_supported_xcr0` | [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:254), [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:360) | KVM already derives per-vCPU xfeature visibility from guest CPUID. |
| Host-supported xstate mask | `kvm_caps.supported_xcr0` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:224), [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:9505) | UINTR xstate cannot be exposed until the host-supported mask includes it. |
| IA32_XSS support surface | `kvm_caps.supported_xss`, CPUID `0xD.1`, `MSR_IA32_XSS` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:9512), [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:9550), [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:7890) | Existing plumbing is in place, but this tree currently zeros `supported_xss` for VMX. |
| Guest `XSETBV` validation | `__kvm_set_xcr()` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1074) | UINTR xstate exposure must extend the valid-bit logic here. |
| Guest and host XSAVE load/restore | `kvm_load_guest_xsave_state()`, `kvm_load_host_xsave_state()` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1018), [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1041) | Existing xsave swap path is the place to include UINTR xstate state switching. |
| Userspace KVM XSAVE ABI | `KVM_GET_XSAVE`, `KVM_SET_XSAVE`, `KVM_GET_XSAVE2` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:5852), [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:5870) | Guest migration and save/restore will need this ABI to understand xstate component 14. |
| CR4 validation | `kvm_set_cr4()` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1192) | Guest-visible `CR4.UINTR` enablement belongs in the normal CR4 path. |
| Vendor CR4 programming | `vmx_set_cr4()` | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:3427) | VMX-specific guest/hardware CR4 programming happens here. |
| CR4 guest-owned mask | `set_cr4_guest_host_mask()` and `KVM_POSSIBLE_CR4_GUEST_BITS` | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4358), [kvm_cache_regs.h](/tkf-workspace/flux/kernel/arch/x86/kvm/kvm_cache_regs.h:8) | This tree does not list `X86_CR4_UINTR`, so the CR4 ownership mask would need extension. |
| UINTR MSR emulation | generic RDMSR/WRMSR emulation in `arch/x86/kvm/x86.c` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:2052), [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:2077), [emulate.c](/tkf-workspace/flux/kernel/arch/x86/kvm/emulate.c:3340), [emulate.c](/tkf-workspace/flux/kernel/arch/x86/kvm/emulate.c:3356) | The natural implementation pattern is to add `case MSR_IA32_UINTR_*` handling beside other architectural MSRs. |
| VMX MSR intercept policy | VMCS01 MSR bitmap helpers | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:3957), [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4001), [vmx.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.h:423) | If UINTR MSRs should always trap, add them through the existing bitmap-control pattern. |
| Invalid-opcode path for UINTR instructions | `handle_ud()` -> `kvm_emulate_instruction()` | [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:7495), [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:5205) | If hardware execution is not directly enabled, KVM can reach software emulation through the `#UD` path. |
| Instruction interception gating | secondary exec control adjustment pattern | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4520), [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4585) | Existing model for CPUID-controlled instructions; useful if VMX later adds UINTR-related execution controls. |
| Posted interrupt backing state | `struct pi_desc` | [posted_intr.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.h:10) | Closest in-tree host primitive to guest UINTR UPID behavior. |
| Posted interrupt delivery | `vmx_deliver_posted_interrupt()` | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4240) | Promising substrate for host-side delivery, but it is still LAPIC-vector based today. |
| Posted interrupt wakeup / blocking path | `vmx_vcpu_pi_put()`, `pi_wakeup_handler()`, `vmx_vcpu_pi_load()` | [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:53), [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:148), [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:218) | Useful reference for guest user-interrupt wakeup semantics when the target vCPU is blocked. |
| Posted interrupt consumption back into LAPIC state | PI.ON -> `kvm_apic_update_irr()` | [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:6867) | Important limitation: current PI flow drains into LAPIC IRR, which is not the same as UINTR user interrupt state. |

## Detailed notes

### 1. CPUID exposure

The first integration boundary is guest CPUID modeling. KVM accepts the userspace-provided CPUID model in `kvm_set_cpuid()` and then derives secondary state in `kvm_vcpu_after_set_cpuid()`:

- [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:409)
- [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:452)

This is the correct layer for:

- exposing the UINTR architectural CPUID bit;
- filtering the bit when host support is missing;
- deriving follow-on constraints such as reserved CR4 bits and xstate masks.

### 2. XSTATE leaf `0xD`

KVM already has a complete path for filtering xstate leaves and recalculating save-area sizes:

- CPUID `0xD` filtering: [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:1011)
- dynamic xsave size updates: [cpuid.c](/tkf-workspace/flux/kernel/arch/x86/kvm/cpuid.c:286)
- host-supported xcr0 mask initialization: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:9505)

This is the place to add xstate component 14 once the host kernel and KVM can represent it.

The important current limitation in this tree is that `KVM_SUPPORTED_XCR0` does not include any UINTR-related xfeature:

- [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:224)

### 3. IA32_XSS and XSAVES

KVM already handles guest `MSR_IA32_XSS` reads, writes, and CPUID `0xD.1` interactions:

- write path: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:3787)
- read path: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:4255)
- guest/host xsave switch: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1018)

But VMX setup in this local tree currently leaves `kvm_caps.supported_xss` at zero:

- [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:7890)

That means UINTR xstate virtualization is blocked here until the host and VMX side start advertising and switching the relevant XSS-managed state.

### 4. CR4.UINTR

Architecturally, UINTR is toggled through `CR4.UINTR`. In KVM, guest CR4 writes are validated in generic x86 code and then programmed by the VMX backend:

- generic validation: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:1192)
- VMX programming: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:3427)

The existing CR4 guest-owned set does not include a UINTR bit:

- [kvm_cache_regs.h](/tkf-workspace/flux/kernel/arch/x86/kvm/kvm_cache_regs.h:8)

So adding `CR4.UINTR` is not only a validation change. It also touches:

- guest-owned bit masks;
- guest/host mask programming in `set_cr4_guest_host_mask()`;
- any VMX-side emulation or execution-control toggles associated with the bit.

### 5. UINTR MSRs

KVM already has a standard implementation pattern for architectural MSRs:

- generic `WRMSR` emulation enters `set_msr_with_filter()`: [emulate.c](/tkf-workspace/flux/kernel/arch/x86/kvm/emulate.c:3340)
- generic `RDMSR` emulation enters `get_msr_with_filter()`: [emulate.c](/tkf-workspace/flux/kernel/arch/x86/kvm/emulate.c:3356)
- KVM vendor exit dispatch routes VMX MSR exits to the common emulators: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:6078)

For UINTR this suggests a straightforward first implementation shape:

1. define per-vCPU storage for guest `IA32_UINTR_*` state;
2. add `case MSR_IA32_UINTR_*` handling in generic KVM x86 read/write paths;
3. decide whether those MSRs always trap or can sometimes passthrough;
4. preserve that state across reset, run, and migration paths.

### 6. SENDUIPI and related instructions

This local tree does not contain any explicit UINTR instruction support. The closest generic fallback is the invalid-opcode path:

- VMX exception exit path calls `handle_ud()` on invalid opcode: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:5205)
- `handle_ud()` routes to `kvm_emulate_instruction()`: [x86.c](/tkf-workspace/flux/kernel/arch/x86/kvm/x86.c:7495)

This gives two possible implementation directions:

- direct execution, if future VMX controls allow guest UINTR instructions to execute natively once state is virtualized;
- software emulation through KVM's instruction emulator path.

For this project, software emulation should be treated as a fallback/debug path, not the primary design. The target design is native guest execution for `SENDUIPI`, `UIRET`, and the rest of the architectural UINTR instruction set once:

- guest CPUID advertises the feature;
- guest `CR4.UINTR` and xstate are valid;
- guest UINTR MSRs point to properly virtualized receiver/sender state;
- host VMX backing state can absorb the delivery semantics.

At this stage, direct execution is not demonstrated by the local tree. The `#UD` path is therefore best understood as the place to study fault behavior and as a temporary bring-up fallback, not as the desired steady-state architecture.

### 7. Delivery substrate

The most reusable host-side state is the VMX posted interrupt descriptor:

- descriptor layout: [posted_intr.h](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.h:10)
- posting path: [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:4240)
- wakeup logic for blocked/preempted vCPUs: [posted_intr.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/posted_intr.c:148)

That is the right reference point for host-internal delivery because it already models:

- a pending bitmap;
- outstanding notification;
- suppress-notification behavior;
- a notification vector and destination.

But the current PI flow ultimately drains into LAPIC IRR:

- [vmx.c](/tkf-workspace/flux/kernel/arch/x86/kvm/vmx/vmx.c:6867)
- [lapic.c](/tkf-workspace/flux/kernel/arch/x86/kvm/lapic.c:2889)

So PI is a useful substrate, not a complete UINTR implementation.

## Bottom line

The best current implementation anchor is not the generic LAPIC injection path. It is the combination of:

- KVM CPUID and xstate filtering;
- KVM generic MSR emulation;
- VMX CR4 programming;
- VMX posted interrupt state and wakeup flow.
