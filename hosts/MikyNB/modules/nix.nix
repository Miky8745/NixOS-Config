{ ... }:

{
  # ---------- Nix itself ----------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  # Automatic garbage collection via nh (also prunes gcroots, e.g. stale
  # `result` symlinks from builds, which plain nix-collect-garbage leaves
  # behind and which would otherwise keep their build inputs alive forever).
  # Policy: always keep the last 5 generations, plus anything from the last
  # 7 days no matter how many that is (so a quiet week still has history,
  # and a busy day of rebuilds doesn't get thinned to one-per-day - see the
  # chat for why that's not quite "5 + 1/day + 0/week" but a close, simpler
  # stand-in). Checked daily; a day with nothing to do is a no-op.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep 5 --keep-since 7d";
    };
    flake = "/home/miky8745/Programming/nixos_conf";
  };
}
