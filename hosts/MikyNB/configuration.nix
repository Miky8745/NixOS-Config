{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # ---------- Boot ----------
  # The laptop boots in legacy BIOS mode (Windows on sdb is MBR/BIOS too),
  # so stay on BIOS GRUB to keep the Windows dual boot working.
  # The install disk is set by disko (EF02 partition in disko.nix).
  boot.loader.grub = {
    enable = true;
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages; # NixOS default = LTS kernel
  boot.supportedFilesystems = [ "ntfs" ];

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
    powerManagement.enable = true; # suspend/hibernate (nvidia-suspend services)
    nvidiaSettings = true;

    moduleParams = {
      # nixpkgs auto-enables nvidia-drm.fbdev for driver >=545 whenever
      # modesetting is on (this laptop ran the same 580xx driver on Arch
      # without glitching, where fbdev isn't on by default) - the fbdev
      # console framebuffer handoff is a known source of visual corruption
      # on some hardware, so turn it back off.
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

  # ---------- Networking ----------
  networking.hostName = "MikyNB";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn networkmanager-openconnect ];
  };
  networking.firewall.enable = true; # replaces firewalld/ufw
  networking.wireguard.enable = true;

  # ---------- Locale ----------
  time.timeZone = "Europe/Prague";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "cs_CZ.UTF-8";
    LC_IDENTIFICATION = "cs_CZ.UTF-8";
    LC_MEASUREMENT = "cs_CZ.UTF-8";
    LC_MONETARY = "cs_CZ.UTF-8";
    LC_NAME = "cs_CZ.UTF-8";
    LC_NUMERIC = "cs_CZ.UTF-8";
    LC_PAPER = "cs_CZ.UTF-8";
    LC_TELEPHONE = "cs_CZ.UTF-8";
    LC_TIME = "cs_CZ.UTF-8";
  };
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";

  # ---------- Desktop: niri (Wayland) ----------
  programs.niri.enable = true;
  # xdg-desktop-portal-gnome (screencast) wants Nautilus as the file-chooser backend.
  programs.niri.useNautilus = true;
  services.gvfs.enable = true; # trash, network places, mounting for Nautilus
  services.udisks2.enable = true; # removable-drive mounting for Nautilus

  # SDDM greeter, running on Wayland (no Xorg needed just for login).
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.kdeconnect.enable = true; # also opens its firewall ports

  # ---------- Audio / Bluetooth ----------
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  hardware.bluetooth.enable = true;

  # ---------- Printing / scanning (Canon via cnijfilter2) ----------
  services.printing = {
    enable = true;
    drivers = [ pkgs.cnijfilter2 ];
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  hardware.sane.enable = true;

  # ---------- Services ----------
  services.power-profiles-daemon.enable = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  services.openssh.enable = false; # set true if you want to SSH *into* this laptop
  hardware.xpadneo.enable = true; # Xbox controllers over Bluetooth

  # ---------- Btrfs snapshots (snapper) ----------
  # Hourly snapshots of /home; restore with `snapper -c home list` / `snapper -c home undochange`,
  # or just copy files out of /home/.snapshots/<n>/snapshot/.
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "miky8745" ];
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 24;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };
  services.btrfs.autoScrub.enable = true; # monthly checksum check of all data

  # Snapshots don't include nested subvolumes, so big, constantly changing
  # folders get their own subvolume ("v") to keep them out of /home snapshots.
  systemd.tmpfiles.rules = [
    # The VMs mount below creates /home/miky8745 as root before the user exists; fix ownership
    "d /home/miky8745 0700 miky8745 users -"
    "d /home/miky8745/.local 0755 miky8745 users -"
    "d /home/miky8745/.local/share 0755 miky8745 users -"
    "v /home/miky8745/.cache 0700 miky8745 users -"
    "v /home/miky8745/.local/share/Steam 0755 miky8745 users -"
    # VMs subvolume (from disko): owned by the user, no copy-on-write for new files
    "d /home/miky8745/VMs 0755 miky8745 users -"
    "h /home/miky8745/VMs - - - - +C"
  ];

  # ---------- Virtualisation ----------
  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.virtualbox.host.enable = true;

  # ---------- Programs ----------
  # Needed so zsh can be a login shell; the actual config lives in Home Manager
  # (home/miky8745.nix), so plugins are not enabled here to avoid loading them twice.
  programs.zsh.enable = true;
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true; # run AppImages directly
  };
  # Lets prebuilt Linux binaries (Unity editor, Arduino toolchains, pip wheels...)
  # find their libraries even though NixOS has no /lib.
  programs.nix-ld.enable = true;

  # ---------- User ----------
  users.users.miky8745 = {
    isNormalUser = true;
    description = "Miky";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" "networkmanager" "docker" "vboxusers"
      "dialout" # serial ports / Arduino (was uucp on Arch)
      "scanner" "lp"
    ];
  };

  # ---------- Packages ----------
  environment.systemPackages = with pkgs; [
    # niri desktop (bar, launcher, notifications, lock, wallpaper, polkit, XWayland compat)
    waybar
    fuzzel
    mako
    swaybg
    swaylock
    waypaper
    polkit_gnome
    libnotify
    brightnessctl
    playerctl
    xwayland-satellite
    alacritty

    # GTK app replacements for the former KDE apps (Dolphin/Kate/Ark/Gwenview/Okular/...)
    nautilus
    papers # PDF/document viewer, replaces Okular
    gnome-calculator
    file-roller # archive manager, replaces Ark
    loupe # image viewer, replaces Gwenview
    gparted # replaces KDE Partition Manager
    ffmpegthumbnailer # video thumbnails in Nautilus, replaces ffmpegthumbs

    # Internet / communication
    vivaldi
    discord
    element-desktop
    filezilla
    remmina
    freerdp
    parsec-bin

    # Media / creative
    vlc
    obs-studio
    audacity
    lmms
    blender
    davinci-resolve
    vcv-rack
    cava
    yt-dlp
    ffmpeg

    # Office
    libreoffice-qt
    meld

    # Engineering / making
    freecad
    kicad
    prusa-slicer
    arduino-ide
    rpi-imager
    satdump

    # Games
    osu-lazer-bin
    gdlauncher-carbon

    # Development
    vscode
    git
    lazygit
    godot
    unityhub
    android-studio
    android-tools
    gcc
    gnumake
    cmake
    rustup
    nodejs
    pnpm
    yarn
    claude-code
    uv
    pipx
    (python3.withPackages (ps: with ps; [ numpy pyqt6 shapely tqdm jinja2 ]))
    dotnetCorePackages.sdk_10_0
    dotnetCorePackages.sdk_8_0
    mkdocs

    # CLI tools
    wget
    tree
    tldr
    btop
    glances
    nvtopPackages.nvidia
    fastfetch
    cmatrix
    pv
    pigz
    unzip
    unrar
    p7zip
    rsync
    lftp
    nmap
    nethogs
    traceroute
    netcat-openbsd
    wireguard-tools
    wl-clipboard

    # Disks / hardware
    compsize # real disk usage with btrfs compression: sudo compsize /home
    ntfs3g
    exfatprogs
    cifs-utils # mount Windows shares (restoring the backup)
    ddrescue
    testdisk
    smartmontools
    usbutils
    pciutils
    inxi
    hwinfo
    qdirstat
    pavucontrol
  ];

  # ---------- Nix itself ----------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Set once at install time. Do NOT change it when upgrading NixOS.
  system.stateVersion = "26.05";
}
