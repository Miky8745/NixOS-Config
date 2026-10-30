{ pkgs, ... }:

{
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
}
