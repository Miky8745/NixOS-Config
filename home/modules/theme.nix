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
    # Explicit rather than relying on GTK's built-in fallback - wlogout
    # (home/modules/wlogout.nix) looks up its button icons by name via
    # `-gtk-icontheme()`, which needs gtk-icon-theme-name actually set to
    # resolve "system-shutdown-symbolic" and friends.
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # No cursor theme was ever configured, so niri (and every client under it,
  # including the qylock lock screen) falls back to a "default" xcursor
  # theme that doesn't actually exist (see niri's "no default icon" startup
  # warning) - the pointer is just invisible everywhere in the session.
  home.pointerCursor = {
    enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true; # covers Xwayland clients via xwayland-satellite
  };
}
