# Upstream Status and Source Links

## Primary sources

- Intel Architecture Instruction Set Extensions Programming Reference
  - https://www.intel.com/content/www/us/en/content-details/836329/intel-architecture-instruction-set-extensions-programming-reference.html
  - Use this for UINTR instruction semantics, architectural state, and enumeration details.
- Linux kernel x86 user interrupt patch discussion
  - Example thread index: https://lkml.iu.edu/hypermail/linux/kernel/2109.1/07336.html
  - Follow linked messages in the series for MSRs, XSAVE, scheduler, signal, and syscall interactions.

## Useful search targets

- `site:lore.kernel.org UINTR KVM`
- `site:lore.kernel.org SENDUIPI KVM`
- `site:patchew.org QEMU UINTR`
- `site:github.com intel uintr linux kernel`

## Notes for this repo

- Expect the implementation to span both kernel and QEMU trees, even if this repository starts with KVM-focused code.
- When an upstream series exists, map local changes to the exact subsystem boundaries before porting.
- Preserve exact source URLs when collecting future notes so later patch archaeology stays cheap.
