# Power menu launched by waybar's power button (home/modules/waybar.nix),
# so that button opens this instead of shutting the machine down directly.
#
# Layout/look adapted from mylinuxforwork/dotfiles' wlogout config
# (https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/wlogout):
# same five actions (lock/suspend/logout/reboot/shutdown, no hibernate) and
# the same rounded-button-that-grows-on-hover feel, but re-themed to match
# the pill palette waybar.nix now uses instead of ML4W's own colors, and
# built from Nerd Font glyphs instead of that repo's PNG icon files so this
# stays fully declarative (no separate image assets to track).
{ pkgs, ... }:

let
  # Same guarded lock command as niri.nix's Mod+L bind and swayidle.nix's
  # before-sleep hook - duplicated here (rather than imported) because
  # wlogout's layout actions are plain shell strings with no access to
  # niri.nix's `let`. See niri.nix for why pgrep must match by process name
  # (-x), not command line.
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
    + " || QT_QPA_PLATFORM=wayland qylock-lock";
in
{
  programs.wlogout = {
    enable = true;

    layout = [
      { label = "lock"; action = lockCmd; text = "  Lock"; keybind = "l"; }
      { label = "suspend"; action = "${pkgs.systemd}/bin/systemctl suspend"; text = "  Sleep"; keybind = "u"; }
      { label = "logout"; action = "${pkgs.niri}/bin/niri msg action quit -s"; text = "  Log Out"; keybind = "e"; }
      { label = "reboot"; action = "${pkgs.systemd}/bin/systemctl reboot"; text = "  Restart"; keybind = "r"; }
      { label = "shutdown"; action = "${pkgs.systemd}/bin/systemctl poweroff"; text = "  Shut Down"; keybind = "s"; }
    ];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
        background-image: none;
        transition: 20ms;
        box-shadow: none;
      }

      window {
        background-color: rgba(26, 26, 30, 0.6);
      }

      button {
        border-radius: 20px;
        border: 1px solid rgba(56, 60, 74, 0.9);
        color: #ffffff;
        background-color: rgba(56, 60, 74, 0.8);
        margin: 10px;
        min-width: 150px;
        min-height: 150px;
        font-size: 16pt;
        transition: all 0.3s cubic-bezier(.55, 0.0, .28, 1.682), box-shadow 0.2s ease-in-out, background-color 0.2s ease-in-out;
      }

      button:focus, button:hover {
        background-color: rgba(78, 82, 99, 0.95);
        margin: 4px;
        box-shadow: 0 0 40px rgba(0, 0, 0, 0.6);
      }
    '';
  };
}
