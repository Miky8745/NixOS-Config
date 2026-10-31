# CSS theme for home/modules/wlogout/default.nix's six-button grid.
{ pkgs, ... }:

let
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
  programs.wlogout.style = ''
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
}
