{ ... }:

{
  # This laptop's physical power button has no real ACPI control-method
  # device behind it (confirmed: dmesg's `button` driver only ever
  # registers Lid Switch and Sleep Button; also confirmed via the legacy
  # /proc/acpi/button/ procfs interface, which only has a `lid/` entry),
  # only the kernel's "fixed hardware" ACPI power event - so nothing at
  # the evdev/libinput level (logind, niri keybinds) or the ACPI netlink
  # level (acpid) ever sees anything for it. The only thing that reacts
  # at all is the kernel's "tiny_power_button" driver, whose `.notify()`
  # calls `kill_cad_pid(power_signal, 1)` - a raw signal straight to PID
  # 1, bypassing every userspace layer entirely.
  #
  # This is very likely a kernel regression, not a hardware limitation:
  # https://lkml.org/lkml/2025/12/15/991 converted drivers/acpi/button.c
  # to the platform-driver model (which needs a real ACPI namespace node
  # to bind to - a pure fixed-hardware button has none), where it
  # previously used the same direct ACPI-bus-notify style
  # tiny_power_button still uses, and *did* handle fixed-hardware buttons
  # correctly. This laptop's prior EndeavourOS/KDE install (which worked)
  # almost certainly predated that patch. Pinning to an older kernel
  # (linuxPackages_6_12 is available and predates it) would be the
  # "proper" fix, restoring native evdev/logind/niri handling - not done
  # here since it's a bigger, riskier change (whole-system kernel
  # version) than retargeting this one driver; revisit if ever wanted.
  #
  # `power_signal` is a runtime-writable module parameter, so the one
  # event this hardware does give us gets retargeted from its default (38
  # = SIGRTMIN+4 = systemd's hardcoded "start poweroff.target") to 34
  # (SIGRTMIN+0 = "start default.target"). Since default.target is
  # already the running system's target, that "start" is a safe
  # effective no-op for everything already active - except it also
  # (re)starts any of its own still-inactive Wants= dependencies, which is
  # the hook systemd.services.power-button-menu below rides on.
  #
  # Tradeoff, accepted deliberately: `nixos-rebuild switch` does this
  # same "reconcile default.target's Wants=" dance as part of normal
  # activation, so it *also* fires power-button-menu.service (opening
  # wlogout) on every switch. Harmless - it's just a menu, dismiss it
  # with Escape/the Cancel button - and simpler and safer than the
  # alternative tried first: retargeting to kexec.target instead, which
  # avoided the switch collision but turned out to not be inert - starting
  # kexec.target really does pull in systemd's actual shutdown chain
  # (Requires=shutdown.target through systemd-kexec.service), which
  # cannot be cleanly stripped via a NixOS unit override (empirically
  # verified: unlike ExecStart=, an empty-value reset does NOT clear
  # Requires=/Wants=/After= accumulated from the package's own vendored
  # unit file across a drop-in boundary - and masking the required
  # service instead fails the whole transaction, taking our own hooked
  # service down with it). That attempt genuinely kexec-rebooted the
  # machine once. Caused by this driver's design, not a fix for it -
  # reverted here in favor of the wlogout-on-every-switch tradeoff.
  boot.extraModprobeConfig = ''
    options tiny_power_button power_signal=34
  '';
}
