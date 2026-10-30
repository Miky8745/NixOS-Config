{ pkgs, ... }:

{
  # ---------- Fonts ----------
  # Nerd Font patched variant, so terminal icon glyphs (oh-my-zsh's agnoster
  # theme, etc.) exist at all and render at the right cell width.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
