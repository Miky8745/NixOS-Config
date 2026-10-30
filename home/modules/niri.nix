# niri (Wayland compositor)
# Full KDL reference: https://niri-wm.github.io/niri/Configuration:-Introduction
# This starts from niri's own documented default config, trimmed of the
# autostart line (waybar is started via its own systemd service instead)
# and extended with polkit + wallpaper-restore on login.
{ pkgs, ... }:

let
  # Guard against stacking a second lock surface if this fires while
  # already locked. qylock-lock (programs.qylock, see configuration.nix)
  # ultimately execs `quickshell -p .../lock_shell.qml`, which is what
  # actually shows up in the process list.
  #
  # Must match by process name (-x), not full command line (-f): swayidle
  # (services.swayidle, home/modules/swayidle.nix) is a long-running daemon
  # whose own argv literally contains the string "lock_shell.qml" - because
  # that's the text of this very lockCmd passed in as ITS command argument.
  # `pgrep -f lock_shell.qml` matches against full command lines, so it was
  # matching swayidle itself and always short-circuiting the `||`, meaning
  # qylock-lock never ran - not from Mod+L, not from idle timeout, not
  # before sleep. This is what actually caused "Super+L doesn't lock".
  #
  # QT_QPA_PLATFORM=wayland is forced here because home-manager's
  # environment.nix sets it to "xcb" session-wide for Haruna/DaVinci - under
  # that override Quickshell can't use ext-session-lock-v1 at all ("Cannot
  # start session lock: The current compositor does not support the
  # ext-session-lock-v1 protocol"), which is why the old lock bind silently
  # failed.
  #
  # qylock-lock itself is referenced by absolute path (not relying on
  # PATH): it's not a nix package output exposed via `pkgs` (it's a local
  # `let` binding inside flake.nix, only reachable via
  # environment.systemPackages), and more importantly this same lockCmd
  # is reused from contexts with no normal user-session PATH at all - see
  # hosts/MikyNB/configuration.nix's power-button-menu service, invoked
  # via `runuser` from a root systemd unit, where a bare "qylock-lock"
  # command failed outright with "command not found".
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell"
    + " || QT_QPA_PLATFORM=wayland /run/current-system/sw/bin/qylock-lock";

  # Volume/mic/brightness binds below call this instead of wpctl/
  # brightnessctl directly - it performs the same change but also pops up
  # the on-screen display (home/modules/swayosd.nix runs the server side).
  swayosdClient = "${pkgs.swayosd}/bin/swayosd-client";

  # Plays a short "beep" right after a volume change so you can hear how
  # loud the new level actually is, instead of just seeing the OSD bar
  # move. The clip goes out through the same default sink swayosd-client
  # just changed the volume of, so its loudness tracks the new setting.
  # canberra-gtk-play -f sidesteps the XDG sound-theme lookup (by id)
  # entirely - just plays the given file - so no package needs adding to
  # XDG_DATA_DIRS for this to resolve it.
  #
  # Uses KDE Plasma's own "ocean" sound theme (its current default, same
  # package Dolphin/kio-extras already pull in - see
  # hosts/MikyNB/modules/packages.nix) instead of sound-theme-freedesktop's
  # version of this same clip - the freedesktop one is a flatter, more
  # synthetic-sounding beep.
  volumePreviewCmd = "${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play -f "
    + "${pkgs.kdePackages.ocean-sound-theme}/share/sounds/ocean/stereo/audio-volume-change.oga";

  # No swayosd OSD for keyboard-layout switches exists as a built-in flag
  # (only volume/brightness/caps-lock/etc.), so this builds one from
  # `--custom-message`: switch layout, then read back whichever layout
  # `niri msg keyboard-layouts` now marks with "*" (its non-JSON output -
  # avoids pulling in jq just to read one field out of --json) and show
  # that as the message.
  switchLayoutCmd = "${pkgs.niri}/bin/niri msg action switch-layout next; "
    + "name=$(${pkgs.niri}/bin/niri msg keyboard-layouts | ${pkgs.gnugrep}/bin/grep '\\*' | "
    + "${pkgs.gnused}/bin/sed -E 's/^[^0-9]*[0-9]+ //'); "
    + "${swayosdClient} --custom-message \"$name\" --custom-icon input-keyboard";
in
{
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,cz(qwerty)"
            }
            numlock
        }

        touchpad {
            tap
            natural-scroll
        }
    }

    // Run `niri msg outputs` once logged in to find your output name,
    // then uncomment and adjust a block like this if you want a fixed
    // resolution/scale/position instead of niri's automatic choice.
    // output "eDP-1" {
    //     mode "1920x1080@60.000"
    //     scale 1
    // }

    layout {
        gaps 16
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 4
            active-color "#7fc8ff"
            inactive-color "#505050"
        }

        border {
            off
        }

        struts {
        }
    }

    // waybar, swaync and swayidle are started as Home Manager systemd user
    // services (see programs.waybar / services.swaync / services.swayidle),
    // not spawned here.
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    // Pinned directly to the one image in ~/Background - simplest option,
    // and consistent with everything else here being declarative (edit this
    // file + rebuild to change it). waypaper (still installed) can pick a
    // different wallpaper interactively, but its own saved choice wouldn't
    // survive a rebuild unless this line is updated to match - ask if you'd
    // rather have waypaper's picker be the source of truth instead.
    spawn-sh-at-startup "${pkgs.swaybg}/bin/swaybg -i ~/Background/gargantua-black-5200x3250-9621.jpg -m fill"

    // Apps installed via environment.systemPackages in
    // hosts/MikyNB/configuration.nix - already on $PATH, so bare command
    // names (same as the alacritty/fuzzel binds above) are enough.
    spawn-at-startup "element-desktop"
    spawn-at-startup "discord"
    spawn-at-startup "vivaldi"
    // programs.kdeconnect.enable (configuration.nix) only installs the
    // package and opens the firewall ports - it starts no daemon. The
    // indicator binary is what actually gets kdeconnectd running too (DBus
    // activates it on demand), so spawning just the indicator is enough.
    spawn-at-startup "kdeconnect-indicator"
    // Tray icon for graphical Wi-Fi switching (click it in waybar's tray
    // module) - package is networkmanagerapplet, hosts/MikyNB/modules/packages.nix.
    spawn-at-startup "nm-applet"

    hotkey-overlay {
    }

    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    animations {
    }

    // Ask clients to drop their own title bar/min-max-close buttons -
    // everything here is driven by hotkeys, so that chrome is just wasted
    // space. Most GTK/Qt apps honor this; terminals get it explicitly below.
    prefer-no-csd

    // Nvidia's direct-scanout path has known corruption/flicker bugs on
    // proprietary drivers (same class of bug KWin works around on Nvidia);
    // this disables it so niri always composites instead.
    debug {
        disable-direct-scanout
    }

    // Open Vivaldi's picture-in-picture player as floating by default.
    // Chromium-based browsers can report a slightly different app-id; run
    // `niri msg windows` while the PiP player is open to confirm/adjust this.
    window-rule {
        match app-id=r#"vivaldi"# title="^Picture-in-Picture$"
        open-floating true
    }

    // Alacritty is semi-transparent (see home/modules/alacritty.nix). By
    // default niri draws the focus-ring as a solid filled rectangle behind
    // the window, so that fill bleeds through and makes the terminal look
    // opaque/tinted blue when focused. This stops the fill from being drawn
    // behind it, leaving just the thin ring border.
    window-rule {
        match app-id=r#"Alacritty"#
        draw-border-with-background false
    }

    // Super-slight rounding on every window. niri has no "is-maximized"
    // match predicate (open feature request upstream) to exclude maximized/
    // fullscreen windows specifically, but at this small a radius the
    // corner-clip on those is basically imperceptible, and `gaps` already
    // keeps normal tiled windows off the screen edge anyway.
    window-rule {
        geometry-corner-radius 4
        clip-to-geometry true
    }

    binds {
        // Grave (the ` key) rather than Shift+Slash: with "cz(qwerty)"
        // active (see the `input.keyboard.xkb.layout` line above),
        // Shift+Slash also fires from the physical "[" key - cz(qwerty)
        // produces the literal "slash" character there at its shifted
        // level, which collides with how niri resolves ASCII binds
        // across layouts. Grave has no such collision: cz(qwerty) only
        // reaches "grave" via AltGr, which this bind doesn't involve, so
        // it stays anchored to this one physical key either way.
        Mod+Grave { show-hotkey-overlay; }

        Mod+T hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
        Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
        Mod+L hotkey-overlay-title="Lock the Screen: qylock" { spawn-sh "${lockCmd}"; }
        // Raw string (r#"..."#) because switchLayoutCmd itself needs real
        // "quotes" around $name for the shell - a plain KDL "..." string
        // would end at the first one of those instead of at the end of
        // the command.
        Mod+Space hotkey-overlay-title="Switch Keyboard Layout" { spawn-sh r#"${switchLayoutCmd}"#; }

        // swayosd-client both makes the change and pops up the OSD (see
        // home/modules/swayosd.nix) - replaces the old direct wpctl/
        // brightnessctl calls, which changed things silently.
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "${swayosdClient} --output-volume +5 --max-volume 100 && ${volumePreviewCmd}"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "${swayosdClient} --output-volume -5 && ${volumePreviewCmd}"; }
        XF86AudioMute        allow-when-locked=true { spawn-sh "${swayosdClient} --output-volume mute-toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn-sh "${swayosdClient} --input-volume mute-toggle"; }

        XF86AudioPlay  allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioPause allow-when-locked=true { spawn-sh "playerctl play-pause"; }
        XF86AudioStop  allow-when-locked=true { spawn-sh "playerctl stop"; }
        XF86AudioPrev  allow-when-locked=true { spawn-sh "playerctl previous"; }
        XF86AudioNext  allow-when-locked=true { spawn-sh "playerctl next"; }

        XF86MonBrightnessUp   allow-when-locked=true { spawn-sh "${swayosdClient} --brightness +10"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "${swayosdClient} --brightness -10"; }

        // The hardware power button never reaches niri at all - it has no
        // real ACPI device behind it, only a "fixed hardware" event that
        // the kernel's tiny_power_button driver turns into a raw signal
        // straight to systemd (PID 1), bypassing libinput/niri entirely.
        // See hosts/MikyNB/configuration.nix's boot.extraModprobeConfig
        // comment for the actual wiring (short press -> suspend via a
        // systemd target hook; a real long hold is a hardware/EC-level
        // forced power-off below the OS, nothing to bind here either way).


        Mod+O repeat=false { toggle-overview; }

        Mod+Q repeat=false { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        // Mod+L is taken by the lock bind above; use Mod+Right for this.

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Home { focus-column-first; }
        Mod+End  { focus-column-last; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up   { focus-workspace-up; }
        Mod+U         { focus-workspace-down; }
        Mod+I         { focus-workspace-up; }

        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Ctrl+6 { move-column-to-workspace 6; }
        Mod+Ctrl+7 { move-column-to-workspace 7; }
        Mod+Ctrl+8 { move-column-to-workspace 8; }
        Mod+Ctrl+9 { move-column-to-workspace 9; }

        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }

        Mod+R       { switch-preset-column-width; }
        Mod+Shift+R { switch-preset-column-width-back; }
        Mod+F       { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+M       { maximize-window-to-edges; }
        Mod+Ctrl+F  { expand-column-to-available-width; }
        Mod+C       { center-column; }

        // Numpad rather than Minus/Equal: cz(qwerty) (see
        // input.keyboard.xkb.layout above) produces literal "minus" and
        // "equal" on different physical keys than "us" does (the "/" and
        // "-" keys respectively), which collides with niri's cross-layout
        // ASCII bind resolution and makes these jump around when
        // switching layouts. The numpad's own +/- keys have fixed
        // KP_Add/KP_Subtract keysyms that don't depend on the active
        // letter-layout at all - and the numpad otherwise goes unused.
        Mod+KP_Subtract { set-column-width "-10%"; }
        Mod+KP_Add      { set-column-width "+10%"; }

        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        Mod+W       { toggle-column-tabbed-display; }

        Print      { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print  { screenshot-window; }

        Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        Mod+Shift+E     { quit; }
        Ctrl+Alt+Delete { quit; }

        Mod+Shift+P { power-off-monitors; }
    }
  '';
}
