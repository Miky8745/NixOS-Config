{ config, lib, pkgs, ... }:

{
  # ---------- NVIDIA Quadro M2000M (Maxwell) ----------
  # Drivers 590+ dropped Maxwell, so pin the 580 legacy branch (supported until 2028).
  # Maxwell is not supported by the open kernel modules.
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / Wine
  };
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    modesetting.enable = true;
    # suspend/hibernate (nvidia-suspend services, unmodified nixpkgs
    # defaults). Suspend hung repeatedly tonight (repeated "[drm:
    # nv_drm_atomic_commit] *ERROR* Flip event timeout on head 0", full
    # hard-reset-required hang) - traced to home/modules/swayidle.nix's
    # before-sleep hook launching qylock's video-background lock theme,
    # GPU work that was still in flight when the kernel suspend call froze
    # the GPU mid-commit (confirmed against an older commit where a since-
    # fixed pgrep bug had been accidentally making that same call a no-op -
    # suspend never hung there). before-sleep no longer does any GPU work
    # at all, which was the actual fix - every custom nvidia-suspend/
    # resume/hibernate.service override tried before that (replacing
    # nvidia-sleep.sh, unbinding/rebinding the driver around sleep) turned
    # out to be unnecessary complexity chasing the wrong layer. Back to
    # plain nixpkgs defaults here.
    powerManagement.enable = true;
    nvidiaSettings = true;

    moduleParams = {
      # nixpkgs auto-enables nvidia-drm.fbdev for driver >=545 whenever
      # modesetting is on (this laptop ran the same 580xx driver on Arch
      # without glitching, where fbdev isn't on by default) - the fbdev
      # console framebuffer handoff is a known source of visual corruption
      # on some hardware, so turn it back off.
      #
      # Tried leaving this on once, to chase an unrelated suspend-resume
      # kernel hang - confirmed instead it causes real, visible screen
      # glitches on this hardware during normal use. Back off = 0.
      "nvidia-drm".fbdev = lib.mkForce 0;

      # Maxwell/Pascal mobile GPUs have a known bug where dynamic P-state
      # switching (this card idles at P8/135MHz between frames) causes
      # visual corruption. Forcing max performance avoids the reclocking.
      # Trade-off: higher idle power draw/heat on battery. Speculative -
      # commented out to test fbdev=0 alone first; re-enable if glitching
      # persists.
      # nvidia.NVreg_RegistryDwords =
      #   ''"PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"'';
    };
  };
}
