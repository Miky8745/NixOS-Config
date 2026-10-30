{ ... }:

{
  # ---------- Qt dark theme ----------
  # GTK's dconf dark-mode setting (see home-manager) doesn't reach Qt apps -
  # Qt has its own, separate theming, normally fed by Plasma. Dolphin is a Qt
  # app, so without this it just falls back to a plain light style.
  # platformTheme "gnome" makes Qt read the same GSettings/dconf
  # color-scheme=prefer-dark the GTK apps already use (see home-manager's
  # theme.nix) - without it, style=adwaita-dark only changes widget drawing,
  # not the palette KDE Frameworks apps like Dolphin actually paint with.
  qt = {
    enable = true;
    style = "adwaita-dark";
    platformTheme = "gnome";
  };
}
