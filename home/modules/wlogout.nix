# Power menu launched by waybar's power button and by the hardware power
# key (home/modules/waybar.nix, home/modules/niri.nix's XF86PowerOff bind),
# so both open this instead of shutting the machine down directly.
#
# Layout/look adapted from mylinuxforwork/dotfiles' wlogout config
# (https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/wlogout):
# same five actions (lock/suspend/logout/reboot/shutdown, no hibernate) and
# the same rounded-button-that-grows-on-hover feel, re-themed to match the
# pill palette waybar.nix uses instead of ML4W's own colors.
#
# Icons are looked up by name from the Adwaita icon theme via
# `-gtk-icontheme()` (home/modules/theme.nix sets gtk.iconTheme so the name
# actually resolves) rather than drawn as Nerd Font glyph text: GTK wasn't
# rendering those PUA codepoints as button labels even though the font file
# has them, so -gtk-icontheme is both the documented wlogout approach and
# sidesteps that font-rendering question entirely. The module is invoked
# with `-b 3` (buttons-per-row) wherever it's launched, since wlogout's own
# automatic column count for 5 buttons was leaving a visibly empty 6th
# slot; 3+2 has no such gap.
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
      { label = "lock"; action = lockCmd; text = "Lock"; keybind = "l"; }
      { label = "suspend"; action = "${pkgs.systemd}/bin/systemctl suspend"; text = "Sleep"; keybind = "u"; }
      { label = "logout"; action = "${pkgs.niri}/bin/niri msg action quit -s"; text = "Log Out"; keybind = "e"; }
      { label = "reboot"; action = "${pkgs.systemd}/bin/systemctl reboot"; text = "Restart"; keybind = "r"; }
      { label = "shutdown"; action = "${pkgs.systemd}/bin/systemctl poweroff"; text = "Shut Down"; keybind = "s"; }
    ];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
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
        background-repeat: no-repeat;
        background-position: center top 28px;
        background-size: 48px 48px;
        margin: 10px;
        min-width: 150px;
        min-height: 150px;
        font-size: 12pt;
        transition: all 0.3s cubic-bezier(.55, 0.0, .28, 1.682), box-shadow 0.2s ease-in-out, background-color 0.2s ease-in-out;
      }

      button:focus, button:hover {
        background-color: rgba(78, 82, 99, 0.95);
        margin: 4px;
        box-shadow: 0 0 40px rgba(0, 0, 0, 0.6);
      }

      /* Label text sits under the icon rather than overlapping it. */
      button label {
        margin-top: 86px;
      }

      #lock {
        background-image: -gtk-icontheme("system-lock-screen-symbolic");
      }

      #suspend {
        background-image: -gtk-icontheme("weather-clear-night-symbolic");
      }

      #logout {
        background-image: -gtk-icontheme("system-log-out-symbolic");
      }

      #reboot {
        background-image: -gtk-icontheme("system-reboot-symbolic");
      }

      #shutdown {
        background-image: -gtk-icontheme("system-shutdown-symbolic");
      }
    '';
  };
}
