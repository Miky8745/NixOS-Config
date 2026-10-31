# Power menu launched by waybar's power button and by the hardware power
# key (home/modules/waybar.nix, home/modules/niri.nix's XF86PowerOff bind),
# so both open this instead of shutting the machine down directly.
#
# Layout adapted from mylinuxforwork/dotfiles' wlogout config
# (https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/wlogout):
# same five actions (lock/suspend/logout/reboot/shutdown, no hibernate),
# plus a sixth "cancel" button (action is a no-op - wlogout always closes
# itself and runs the clicked button's action, in that order, so a no-op
# action is all "just close the menu" needs) to fill the 2x3 grid's
# otherwise-empty last slot. That slot being empty also wasn't just a
# cosmetic gap: wlogout has a bug where an incomplete last grid row causes
# one GTK_IS_LABEL assertion failure per missing slot (verified directly -
# 5 buttons at 3-per-row logs one, 4 at 2-per-row or 6 at 3-per-row logs
# none) since it iterates the full rectangular grid including slots with
# no real button. Harmless (GTK assertions don't crash wlogout, they just
# skip that call), but six buttons sidesteps it entirely too.
#
# The module is invoked with `-b 3` (buttons-per-row) wherever it's
# launched, so these six lay out as two clean rows of three rather than
# whatever wlogout's own automatic column count would have picked.
#
# Icons/CSS theme live in style.nix.
{ pkgs, ... }:

let
  # Same guarded lock command as niri.nix's Mod+L bind and swayidle.nix's
  # before-sleep hook - duplicated here (rather than imported) because
  # wlogout's layout actions are plain shell strings with no access to
  # niri.nix's `let`. See niri.nix for why pgrep must match by process name
  # (-x), not command line.
  # qylock-lock by absolute path, not bare command name: this exact
  # layout action is invoked from the power-button-menu systemd service
  # (hosts/MikyNB/configuration.nix) via `runuser` from a root unit with
  # no normal user-session PATH, where a bare "qylock-lock" failed
  # outright with "command not found".
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
    + " || QT_QPA_PLATFORM=wayland /run/current-system/sw/bin/qylock-lock";
in
{
  imports = [ ./style.nix ];

  programs.wlogout = {
    enable = true;

    layout = [
      { label = "lock"; action = lockCmd; text = "Lock"; keybind = "l"; }
      # Was briefly repointed to poweroff while suspend appeared to hang
      # unrecoverably - root cause turned out to be swayidle.nix's
      # before-sleep hook racing the kernel suspend call with GPU work
      # (see that file's comment), now fixed at the source. Real suspend
      # restored.
      { label = "suspend"; action = "${pkgs.systemd}/bin/systemctl suspend"; text = "Sleep"; keybind = "u"; }
      { label = "logout"; action = "${pkgs.niri}/bin/niri msg action quit -s"; text = "Log Out"; keybind = "e"; }
      { label = "reboot"; action = "${pkgs.systemd}/bin/systemctl reboot"; text = "Restart"; keybind = "r"; }
      { label = "shutdown"; action = "${pkgs.systemd}/bin/systemctl poweroff"; text = "Shut Down"; keybind = "s"; }
      { label = "cancel"; action = "${pkgs.coreutils}/bin/true"; text = "Cancel"; keybind = "c"; }
    ];
  };
}
