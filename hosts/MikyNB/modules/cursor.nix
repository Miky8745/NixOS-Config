{ ... }:

{
  # ---------- Cursor theme (pre-login) ----------
  # No cursor theme exists anywhere by default, so the pointer would be
  # invisible on the qylock lock screen (which runs before the user's
  # home-manager session - and its env vars - exist) without this. Home
  # Manager's home.pointerCursor (see theme.nix) covers the post-login
  # session; the greeter (regreet, see desktop.nix) sets its own cursor
  # theme directly since environment.variables only reaches interactive
  # login shells, not display-manager-style services.
  environment.variables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };
}
