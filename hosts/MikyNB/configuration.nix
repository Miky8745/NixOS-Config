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

  # No cursor theme exists anywhere by default, so the pointer would be
  # invisible on the qylock lock screen (which runs before the user's
  # home-manager session - and its env vars - exist) without this. Home
  # Manager's home.pointerCursor (see theme.nix) covers the post-login
  # session; the greeter (regreet, see below) sets its own cursor theme
  # directly since environment.variables only reaches interactive login
  # shells, not display-manager-style services.
  environment.variables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # ---------- Fonts ----------
  # Nerd Font patched variant, so terminal icon glyphs (oh-my-zsh's agnoster
  # theme, etc.) exist at all and render at the right cell width.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

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

  # ---------- Desktop: niri (Wayland) ----------
  programs.niri.enable = true;
  # File manager is Dolphin (see packages below), so the portal's file-chooser
  # falls back to its GTK implementation instead of Nautilus.
  services.gvfs.enable = true; # trash/network places for the GTK file-chooser portal
  services.udisks2.enable = true; # removable-drive mounting (also used by Dolphin)

  # Greeter: regreet (GTK, via greetd+cage), running on Wayland.
  #
  # Previously this was SDDM's own Wayland greeter (weston --shell=kiosk,
  # forced to --renderer=pixman to dodge this Maxwell Nvidia GPU's
  # direct-scanout corruption, same workaround as niri's "debug
  # { disable-direct-scanout }" below). That combination left the greeter's
  # pointer completely dead - no visible cursor, no clicks, nothing, as if
  # no pointer device existed. A live weston input-device dump ruled out the
  # obvious theories: both the touchpad and the external USB mouse were
  # correctly picked up and associated with the output, and a direct
  # `drmGetCap(DRM_CAP_CURSOR_WIDTH/HEIGHT)` query showed this GPU's hardware
  # cursor plane supports up to 256x256 - well above the 72px cursor theme
  # size tried, ruling out a plane-size overflow too. weston's kiosk-shell
  # has no fallback path if hardware-cursor-plane compositing breaks, and
  # unlike wlroots-based compositors has no documented env-var workaround for
  # exactly this failure mode.
  #
  # cage (used here via programs.regreet.enable) is wlroots-based instead -
  # a far more common pairing for Wayland greeters, and wlroots has a long-
  # documented Nvidia hardware-cursor-plane bug with a known, safe fix
  # (WLR_NO_HARDWARE_CURSORS below forces software cursor compositing).
  programs.regreet = {
    enable = true;
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    settings.background = {
      # Same image niri's swaybg uses as the desktop wallpaper (see
      # niri.nix) - copied into the repo (hosts/MikyNB/background.jpg) so
      # it's a store path, since the greeter's "greeter" system user can't
      # read into ~/Background (home is 0700, owned by miky8745).
      path = toString ./background.jpg;
      fit = "Cover"; # GTK4 ContentFit equivalent of swaybg's "-m fill"
    };
  };
  systemd.services.greetd.environment.WLR_NO_HARDWARE_CURSORS = "1";

  programs.kdeconnect.enable = true; # also opens its firewall ports

  # Lock screen (in-session only, not the greeter above): qylock
  # (github:Darkkal44/qylock), "enfield" theme. Its Quickshell lock
  # authenticates through PAM's default "login" service (not a dedicated
  # one), and runs third-party QML - a deliberate trust tradeoff over the
  # previous hand-rolled pam_unix-only setup, made knowingly rather than by
  # default.
  programs.qylock = {
    enable = true;
    theme = "enfield";
    sddm.enable = false; # no SDDM anymore - see the greeter comment above
  };

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
    # Cursor theme for everything that runs before home-manager's session
    # env vars exist (regreet greeter, qylock lock screen) - see
    # environment.variables.XCURSOR_THEME above.
    adwaita-icon-theme

    # niri desktop (bar, launcher, notifications, lock, wallpaper, polkit, XWayland compat)
    waybar
    fuzzel
    mako
    swaybg
    swaylock # kept as an emergency fallback; the active lock bind is qylock (programs.qylock above)
    quickshell
    waypaper
    polkit_gnome
    libnotify
    brightnessctl
    playerctl
    xwayland-satellite
    alacritty

    # Replacements for the former KDE apps (Kate/Ark/Gwenview/Okular/...).
    # Dolphin itself is kept (GTK file managers were worse to live with day to
    # day) - it pulls in KDE Frameworks (KIO, Breeze icons) as runtime libs,
    # same category as kdeconnect, but needs no Plasma session/desktop manager.
    kdePackages.dolphin
    # Dolphin has no built-in smb://, sftp://, etc. support - those protocol
    # workers are a separate KIO plugin package. Another incremental
    # KDE-stack dependency, same tradeoff as Dolphin itself.
    kdePackages.kio-extras
    papers # PDF/document viewer, replaces Okular
    gnome-calculator
    file-roller # archive manager, replaces Ark
    loupe # image viewer, replaces Gwenview
    gparted # replaces KDE Partition Manager
    ffmpegthumbnailer # generic video thumbnailer, replaces ffmpegthumbs

    # Internet / communication
    # Vivaldi's native-Wayland GPU path is unreliable on niri with this
    # NVIDIA legacy driver, so force it through XWayland (--ozone-platform=x11).
    # Also: Vivaldi auto-picks its OS keystore backend (gnome-libsecret vs
    # kwallet vs basic) by sniffing $XDG_CURRENT_DESKTOP, and niri isn't a
    # desktop Chromium's detection recognizes - it was landing somewhere
    # inconsistent instead of reliably hitting gnome-keyring, which is what
    # the sync-encryption key (and saved passwords/cookies) live in. Pin it
    # explicitly so it's always the same, correctly-PAM-unlocked keyring.
    (vivaldi.override { commandLineArgs = "--ozone-platform=x11 --password-store=gnome-libsecret"; })
    discord
    # Same root cause as the Vivaldi fix above: Electron auto-picks a
    # keyring backend by sniffing $XDG_CURRENT_DESKTOP, doesn't recognize
    # niri, and ends up somewhere broken - hence "Unsupported keyring".
    # Element treats this as fatal (it's guarding E2EE key storage, not
    # just saved passwords), so pin it explicitly to gnome-keyring too.
    #
    # Unlike Vivaldi, `element-desktop.override { commandLineArgs = ...; }`
    # changes the derivation hash to one Hydra never built, forcing a full
    # local rebuild through Electron's own pnpm/node-gyp/seshat toolchain -
    # genuinely expensive, unlike Vivaldi's cheap unpack-and-patch. Instead,
    # leave the real `element-desktop` alone (stays prebuilt, fetched from
    # cache) and just wrap its binary in a second, tiny derivation - its
    # .desktop file execs the bare command "element-desktop", so this wrapper
    # being the only one of that name on PATH is enough for launcher icons
    # to pick it up too, not just terminal/niri-bound launches.
    (symlinkJoin {
      name = "element-desktop-wrapped";
      paths = [ element-desktop ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm $out/bin/element-desktop
        makeWrapper ${element-desktop}/bin/element-desktop $out/bin/element-desktop \
          --add-flags "--password-store=gnome-libsecret"
      '';
    })
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

    # Games
    osu-lazer-bin
    gdlauncher-carbon

    # Development
    # VSCodium: same editor, built from the same Code - OSS source, but
    # fully open-source - no MS telemetry, no Copilot, Open VSX marketplace
    # instead of the proprietary MS one. Settings/extensions/keybindings
    # are compatible with VS Code, just stored under ~/.config/VSCodium.
    vscodium
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

  # Set once at install time. Do NOT change it when upgrading NixOS.
  system.stateVersion = "26.05";
}
