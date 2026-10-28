{
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.95;
      window.decorations = "None"; # no title bar / min-max-close buttons

      font = {
        size = 13.0;
        # draw_bold_text_with_bright_colors = true;
        # "JetBrains Mono" was never actually installed anywhere, so this
        # fell back to a random font. The "Nerd Font Mono" variant (vs. the
        # plain "Nerd Font" one) matters here too: it forces icon glyphs to
        # exact 1/2-cell widths, which is what fixes misaligned spacing in a
        # terminal grid (the plain variant lets icons be oddly-sized).
        normal = {
          family = "JetBrainsMono Nerd Font Mono";
          style = "Bold";
        };
      };

      colors.primary.background = "#1d2021";
    };
  };
}
