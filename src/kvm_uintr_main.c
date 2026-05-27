#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/moduleparam.h>

static bool enable_debug;
module_param(enable_debug, bool, 0644);
MODULE_PARM_DESC(enable_debug, "Enable verbose host-side KVM UINTR logging");

static int __init kvm_uintr_init(void)
{
	pr_info("kvm-uintr: host module loaded\n");

	if (enable_debug)
		pr_info("kvm-uintr: debug logging enabled\n");

	/*
	 * Future implementation points:
	 * - detect host UINTR and posted interrupt capabilities
	 * - bind to host KVM/VMX hooks needed for guest UINTR exposure
	 * - provide guest-visible state handling required by Caladan in the VM
	 */

	return 0;
}

static void __exit kvm_uintr_exit(void)
{
	pr_info("kvm-uintr: host module unloaded\n");
}

module_init(kvm_uintr_init);
module_exit(kvm_uintr_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kaifu Tian");
MODULE_DESCRIPTION("Host-side KVM User Interrupt support skeleton");
