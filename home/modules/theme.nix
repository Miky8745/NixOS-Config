# Dark mode.
# dconf's color-scheme is the single source of truth GTK4/libadwaita apps
# (Loupe, Papers, file-roller) read directly, and what xdg-desktop-portal-
# gnome's Settings backend reports to portal-aware apps (Chromium/Vivaldi,
# Firefox) for the prefers-color-scheme media query.
{ pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };

  # Older GTK3-only apps don't read color-scheme; they need this instead.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
