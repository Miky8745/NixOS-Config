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

  # Default is 5s; cut to 2 - short enough to not meaningfully add to boot
  # time, long enough to still interrupt and pick Windows from the
  # os-prober entry when needed.
  boot.loader.timeout = 2;

  # This laptop's physical power button has no real ACPI control-method
  # device behind it (confirmed: dmesg's `button` driver only ever
  # registers Lid Switch and Sleep Button; also confirmed via the legacy
  # /proc/acpi/button/ procfs interface, which only has a `lid/` entry),
  # only the kernel's "fixed hardware" ACPI power event - so nothing at
  # the evdev/libinput level (logind, niri keybinds) or the ACPI netlink
  # level (acpid) ever sees anything for it. The only thing that reacts
  # at all is the kernel's "tiny_power_button" driver, whose `.notify()`
  # calls `kill_cad_pid(power_signal, 1)` - a raw signal straight to PID
  # 1, bypassing every userspace layer entirely.
  #
  # This is very likely a kernel regression, not a hardware limitation:
  # https://lkml.org/lkml/2025/12/15/991 converted drivers/acpi/button.c
  # to the platform-driver model (which needs a real ACPI namespace node
  # to bind to - a pure fixed-hardware button has none), where it
  # previously used the same direct ACPI-bus-notify style
  # tiny_power_button still uses, and *did* handle fixed-hardware buttons
  # correctly. This laptop's prior EndeavourOS/KDE install (which worked)
  # almost certainly predated that patch. Pinning to an older kernel
  # (linuxPackages_6_12 is available and predates it) would be the
  # "proper" fix, restoring native evdev/logind/niri handling - not done
  # here since it's a bigger, riskier change (whole-system kernel
  # version) than retargeting this one driver; revisit if ever wanted.
  #
  # `power_signal` is a runtime-writable module parameter, so the one
  # event this hardware does give us gets retargeted from its default (38
  # = SIGRTMIN+4 = systemd's hardcoded "start poweroff.target") to 34
  # (SIGRTMIN+0 = "start default.target"). Since default.target is
  # already the running system's target, that "start" is a safe
  # effective no-op for everything already active - except it also
  # (re)starts any of its own still-inactive Wants= dependencies, which is
  # the hook systemd.services.power-button-menu below rides on.
  #
  # Tradeoff, accepted deliberately: `nixos-rebuild switch` does this
  # same "reconcile default.target's Wants=" dance as part of normal
  # activation, so it *also* fires power-button-menu.service (opening
  # wlogout) on every switch. Harmless - it's just a menu, dismiss it
  # with Escape/the Cancel button - and simpler and safer than the
  # alternative tried first: retargeting to kexec.target instead, which
  # avoided the switch collision but turned out to not be inert - starting
  # kexec.target really does pull in systemd's actual shutdown chain
  # (Requires=shutdown.target through systemd-kexec.service), which
  # cannot be cleanly stripped via a NixOS unit override (empirically
  # verified: unlike ExecStart=, an empty-value reset does NOT clear
  # Requires=/Wants=/After= accumulated from the package's own vendored
  # unit file across a drop-in boundary - and masking the required
  # service instead fails the whole transaction, taking our own hooked
  # service down with it). That attempt genuinely kexec-rebooted the
  # machine once. Caused by this driver's design, not a fix for it -
  # reverted here in favor of the wlogout-on-every-switch tradeoff.
  boot.extraModprobeConfig = ''
    options tiny_power_button power_signal=34
  '';

  # Fires every time the kernel asks for "start default.target" (every
  # power-button press, and every nixos-rebuild switch - see above). No
  # `RemainAfterExit`, so it resets to inactive after each run and is
  # ready to fire again.
  systemd.services.power-button-menu = {
    description = "Open the wlogout power menu (triggered by the ACPI power button via tiny_power_button's retargeted signal)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Default KillMode (control-group) kills every process still in this
      # unit's cgroup the moment the oneshot's ExecStart (the runuser/
      # wlogout chain below) finishes - which happens almost immediately,
      # since wlogout closes its own window and then just detach-spawns the
      # clicked action rather than waiting on it. Suspend/reboot/poweroff
      # survive that teardown because systemctl's D-Bus call to logind is
      # already accepted before the kill lands; the Lock button doesn't -
      # qylock-lock's chain (lock.sh -> quickshell lock_shell.qml) *is* a
      # long-running process that has to keep existing after this unit is
      # "done", and was instead getting SIGKILLed mid-startup (confirmed via
      # `journalctl -u power-button-menu`: "Killed" / exit 137, right after
      # lock.sh's last "Theme path: ..." log line, before quickshell's lock
      # screen ever appeared). KillMode=process limits the kill to the one
      # PID systemd tracks as this unit's main process, leaving whatever it
      # detached-spawned alone.
      KillMode = "process";
    };
    script = ''
      runtime_dir=/run/user/1000
      wayland_sock=$(${pkgs.coreutils}/bin/ls "$runtime_dir"/wayland-* 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
      # niri's IPC socket, needed for wlogout's "logout" action (`niri msg
      # action quit -s`, see home/modules/wlogout.nix) to find niri at all -
      # without NIRI_SOCKET set, niri msg fails outright with "NIRI_SOCKET
      # is not set, are you running this within niri?" (confirmed via
      # `journalctl -u power-button-menu`). Named after the Wayland display
      # socket it sits next to, same directory.
      niri_sock=$(${pkgs.coreutils}/bin/ls "$runtime_dir"/niri.wayland-*.sock 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
      # Forced rather than left to qylock's own lock.sh, which tries to
      # self-detect this via `loginctl show-session ... -p Type` - but
      # that queries whatever logind session runuser itself just opened
      # below (a throwaway PAM session, not the real graphical one), and
      # its detection chain also silently breaks here anyway (no awk on
      # this service's restricted PATH). Getting anything other than the
      # literal string "wayland" makes qylock's lock_shell.qml skip its
      # real Wayland session-lock surface (WlSessionLock, backed by
      # ext-session-lock-v1 - the thing niri actually enforces, blocking
      # input/window-switching while locked) in favor of its X11 fallback
      # branch: a plain top-level window with no protocol backing it at
      # all, dismissible with an ordinary niri keybind like Mod+Left/
      # Right (confirmed - this was exactly the "lock opens a window but
      # Mod+Left/Right gets you right back in" symptom). Forcing it
      # directly here is simpler and more reliable than fixing lock.sh's
      # own detection, and correct by construction: this whole branch only
      # runs once a real Wayland socket was already found above.
      if [ -n "$wayland_sock" ]; then
        ${pkgs.util-linux}/bin/runuser -u miky8745 -- \
          ${pkgs.coreutils}/bin/env XDG_RUNTIME_DIR="$runtime_dir" \
            WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_sock")" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
            NIRI_SOCKET="$niri_sock" \
            XDG_SESSION_TYPE="wayland" \
            ${pkgs.wlogout}/bin/wlogout -b 3
      fi
    '';
  };

  # wlogout's suspend/reboot/shutdown buttons call plain `systemctl
  # suspend/reboot/poweroff`, authorized by polkit's default
  # org.freedesktop.login1.* rules - which auto-allow those actions only
  # when the calling process belongs to the *active, local* session.
  # When wlogout is opened by power-button-menu above, `runuser -u
  # miky8745` opens a brand-new PAM/logind session just to host it - the
  # real niri session (started at login) stays the one marked active on
  # the seat, so that new session fails the active-session check and
  # polkit falls back to requiring interactive authentication, which
  # nothing here can satisfy. Result: wlogout's UI responds fine (that's
  # just GTK, no privilege involved) but Suspend/Restart/Shut Down are
  # silently denied - confirmed via `journalctl -u power-button-menu`:
  # "Call to Suspend failed: Access denied as the requested operation
  # requires interactive authentication." (lock/cancel aren't affected;
  # neither goes through logind/polkit.) Dropping the active-session
  # requirement for this one local user is reasonable here: the only way
  # this service's wlogout instance ever opens is a physical power-button
  # press, which already implies physical access.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "miky8745" &&
          (action.id == "org.freedesktop.login1.suspend" ||
           action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions")) {
        return polkit.Result.YES;
      }
    });
  '';

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

  # ---------- Networking ----------
  networking.hostName = "MikyNB";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn networkmanager-openconnect ];
  };
  networking.firewall.enable = true; # replaces firewalld/ufw
  networking.wireguard.enable = true;

  # Single biggest userspace boot-time item (`systemd-analyze blame`:
  # 5.4s), and nothing on this machine needs confirmed network
  # connectivity before considering boot "done" - NetworkManager itself
  # still starts and connects in the background regardless of this.
  systemd.services.NetworkManager-wait-online.enable = false;

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

  # Turns out this laptop's power button never reaches logind at all (see
  # the extraModprobeConfig comment above for the real mechanism) - this
  # setting was a first, insufficient attempt at fixing it. Left in place
  # as harmless defensive config in case any *other* path ever does route
  # a power keypress through logind.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Lid-close was briefly forced to "poweroff" while suspend appeared to
  # hang unrecoverably - see wlogout.nix's Sleep-button comment, same root
  # cause, now fixed. Back to systemd's own default ("suspend") rather
  # than an explicit override.


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
