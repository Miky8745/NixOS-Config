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
  # qylock-lock by absolute path, not bare command name: this exact
  # layout action is invoked from the power-button-menu systemd service
  # (hosts/MikyNB/configuration.nix) via `runuser` from a root unit with
  # no normal user-session PATH, where a bare "qylock-lock" failed
  # outright with "command not found".
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
    + " || QT_QPA_PLATFORM=wayland /run/current-system/sw/bin/qylock-lock";

  icon = name: "${pkgs.wlogout}/share/wlogout/icons/${name}.png";

  # wlogout ships no "cancel" icon (only lock/hibernate/logout/shutdown/
  # suspend/reboot), and Adwaita's own window-close-symbolic.svg is a dark
  # grey (#2e3436) glyph meant for light backgrounds - invisible against
  # this button's dark fill. Same path geometry, recolored white to match
  # the other buttons' icons/text.
  #
  # Rasterized to a PNG at build time (rather than referencing an SVG
  # directly) because wlogout's own binary isn't nix-wrapped with
  # GDK_PIXBUF_MODULE_FILE, so gdk-pixbuf's SVG loader (librsvg) never
  # gets found at runtime - confirmed by testing: the PNG icons above
  # render fine, but pointing a button's background-image at a plain SVG
  # file (regardless of its CSS label/id - "close", "cancel", and a
  # generic "b5" id all showed the same failure) makes that single button
  # render as a collapsed red rectangle with unstyled text, which is GTK's
  # fallback when an image fails to load. A build-time PNG sidesteps the
  # runtime SVG loader question entirely, same as every other icon here.
  cancelIconSvg = pkgs.writeText "wlogout-cancel.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
      <path d="m 4 4 h 1 h 0.03125 c 0.253906 0.011719 0.511719 0.128906 0.6875 0.3125 l 2.28125 2.28125 l 2.3125 -2.28125 c 0.265625 -0.230469 0.445312 -0.304688 0.6875 -0.3125 h 1 v 1 c 0 0.285156 -0.035156 0.550781 -0.25 0.75 l -2.28125 2.28125 l 2.25 2.25 c 0.1875 0.1875 0.28125 0.453125 0.28125 0.71875 v 1 h -1 c -0.265625 0 -0.53125 -0.09375 -0.71875 -0.28125 l -2.28125 -2.28125 l -2.28125 2.28125 c -0.1875 0.1875 -0.453125 0.28125 -0.71875 0.28125 h -1 v -1 c 0 -0.265625 0.09375 -0.53125 0.28125 -0.71875 l 2.28125 -2.25 l -2.28125 -2.28125 c -0.210938 -0.195312 -0.304688 -0.46875 -0.28125 -0.75 z m 0 0" fill="#ffffff"/>
    </svg>
  '';

  cancelIcon = pkgs.runCommand "wlogout-cancel.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    rsvg-convert -w 128 -h 128 ${cancelIconSvg} -o $out
  '';
in
{
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

      /* Muted background so this one visually reads as the safe,
         non-destructive option rather than a system action. */
      #cancel {
        background-color: rgba(40, 42, 50, 0.8);
        background-image: image(url("${cancelIcon}"));
      }

      #cancel:focus, #cancel:hover {
        background-color: rgba(60, 63, 74, 0.95);
      }
    '';
  };
}
