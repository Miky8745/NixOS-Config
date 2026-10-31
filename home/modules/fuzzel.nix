{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "alacritty";
        layer = "overlay";
      };
      # Gruvbox dark, matching the background alacritty.nix already uses.
      colors = {
        background = "1d2021ee";
        text = "ebdbb2ff";
        match = "fabd2fff";
        selection = "3c3836ff";
        selection-text = "ebdbb2ff";
        selection-match = "fabd2fff";
        border = "458588ff";
      };
    };
  };
}
