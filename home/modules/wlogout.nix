# Power menu launched by waybar's power button and by the hardware power
# key (home/modules/waybar.nix, home/modules/niri.nix's XF86PowerOff bind),
# so both open this instead of shutting the machine down directly.
#
# Layout adapted from mylinuxforwork/dotfiles' wlogout config
# (https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/wlogout):
# same five actions (lock/suspend/logout/reboot/shutdown, no hibernate),
# plus a sixth "close" button (action is a no-op - wlogout always closes
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
# Icons use wlogout's own bundled PNGs (${pkgs.wlogout}/share/wlogout/icons/)
# via the exact `background-image: image(url(...))` pattern from wlogout's
# own default /etc/wlogout/style.css - that's the package's own
# known-working approach, rather than a Nerd Font glyph or -gtk-icontheme
# lookup (both tried previously; the glyph text never rendered, and a
# stray `background-position: center top 28px` - an invalid value, GTK CSS
# doesn't support the 2-axis-plus-offset syntax - was logged by wlogout
# itself as "Junk at end of value", on top of a `button label { margin-top
# }` override that was fighting wlogout's *own* built-in text placement:
# per `man 5 wlogout`, each layout entry's height/width (default 0.9/0.5)
# already position the text, so this file doesn't need to touch it at all).
#
# The module is invoked with `-b 3` (buttons-per-row) wherever it's
# launched, so these six lay out as two clean rows of three rather than
# whatever wlogout's own automatic column count would have picked.
{ pkgs, ... }:

let
  # Same guarded lock command as niri.nix's Mod+L bind and swayidle.nix's
  # before-sleep hook - duplicated here (rather than imported) because
  # wlogout's layout actions are plain shell strings with no access to
  # niri.nix's `let`. See niri.nix for why pgrep must match by process name
  # (-x), not command line.
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
    + " || QT_QPA_PLATFORM=wayland qylock-lock";

  icon = name: "${pkgs.wlogout}/share/wlogout/icons/${name}.png";
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
      { label = "close"; action = "${pkgs.coreutils}/bin/true"; text = "Cancel"; keybind = "c"; }
    ];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
        background-image: none;
        box-shadow: none;
        transition: 20ms;
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
        background-position: center;
        background-size: 25%;
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

      #lock {
        background-image: image(url("${icon "lock"}"));
      }

      #suspend {
        background-image: image(url("${icon "suspend"}"));
      }

      #logout {
        background-image: image(url("${icon "logout"}"));
      }

      #reboot {
        background-image: image(url("${icon "reboot"}"));
      }

      #shutdown {
        background-image: image(url("${icon "shutdown"}"));
      }

      /* No bundled icon for this one - just text, and a muted background
         so it visually reads as the safe/non-destructive option. */
      #close {
        background-color: rgba(40, 42, 50, 0.8);
        font-size: 14pt;
      }

      #close:focus, #close:hover {
        background-color: rgba(60, 63, 74, 0.95);
      }
    '';
  };
}
