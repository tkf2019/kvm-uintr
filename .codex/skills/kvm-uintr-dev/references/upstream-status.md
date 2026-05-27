# Upstream Status and Source Links

## Primary sources

- Linux kernel x86 user interrupt patch discussion
  - Example thread index: https://lkml.iu.edu/hypermail/linux/kernel/2109.1/07336.html
  - Follow linked messages in the series for MSRs, XSAVE, scheduler, signal, and syscall interactions.

For Intel architectural semantics and the local KVM/APIC interpretation, use [uintr-hardware-and-kvm-apic.md](uintr-hardware-and-kvm-apic.md).

## Useful search targets

- `site:lore.kernel.org UINTR KVM`
- `site:lore.kernel.org SENDUIPI KVM`
- `site:patchew.org QEMU UINTR`
- `site:github.com intel uintr linux kernel`

## Notes for this repo

- Expect the implementation to span both kernel and QEMU trees, even if this repository starts with KVM-focused code.
- When an upstream series exists, map local changes to the exact subsystem boundaries before porting.
- Preserve exact source URLs when collecting future notes so later patch archaeology stays cheap.
