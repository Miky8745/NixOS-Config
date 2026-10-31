# Waybar status bar.
#
# Settings/module choices are ours; the visual style (pill-shaped modules
# on a transparent bar) is adapted from Andrey0189's niri/Hyprland dotfiles:
# https://raw.githubusercontent.com/Andrey0189/nixos-config/refs/heads/main/home-manager/modules/wms/waybar.nix
# - module names swapped from hyprland/* to niri/* for this compositor, the
# battery/backlight/temperature modules dropped (desktop, no battery or
# managed backlight), every solid pill background given 80% opacity (alpha
# 0.8) per request instead of the source's fully opaque fills, and the
# source's floating top/bottom margin dropped: with a margin, the bar's
# layer-shell exclusive zone no longer lines up with where the pills are
# actually drawn, so niri's maximize-to-edges let windows fill that gap and
# visually poke through/around the bar. Anchored flush (no margin) keeps
# the exclusive zone and the visible bar the same rectangle, which is what
# keeps maximized windows from overlapping it.
#
# Module layout/widgets live in settings.nix, the CSS theme in style.nix,
# and the two custom modules' backing scripts under scripts/.
{ ... }:

{
  imports = [
    ./scripts/clock.nix
    ./scripts/wttr.nix
    ./settings.nix
    ./style.nix
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true; # starts/stops with the graphical session
  };
}
