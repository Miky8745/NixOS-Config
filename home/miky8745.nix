# Home Manager: your user-level config (dotfiles, user programs).
{ config, lib, ... }:

{
  home.username = "miky8745";
  home.homeDirectory = "/home/miky8745";

  programs.git = {
    enable = true;
    settings.user = {
      name = "Miky8745";
      email = "mikulas.vanecek@gmail.com";
    };
  };

  # ---------- Zsh (generates ~/.zshrc and ~/.zshenv) ----------
  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs"; # bindkey -e

    history = {
      path = "${config.home.homeDirectory}/.histfile"; # keep the old file, so restored history works
      size = 1000;
      save = 1000;
      share = true;
      ignoreDups = true;
    };
    setOptions = [ "INC_APPEND_HISTORY" ];

    # Replaces the default compinit line, so bash completions load too
    completionInit = ''
      autoload -Uz compinit && compinit
      autoload -Uz bashcompinit && bashcompinit
    '';

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lh --color=auto";
      la = "ls -lha --color=auto";
    };

    initContent = lib.mkMerge [
      ''
        PROMPT='[%n@%m %c] %# '

        # NVM (prebuilt Node binaries run thanks to programs.nix-ld)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
      ''
      (lib.mkAfter "fastfetch") # neofetch is unmaintained; fastfetch replaces it
    ];
  };

  # Replaces the `dircolors /etc/DIR_COLORS` line (that file doesn't exist on NixOS)
  programs.dircolors.enable = true;

  # ---------- Environment (loaded by every zsh via ~/.zshenv) ----------
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/Android/Sdk/cmdline-tools/latest/bin"
    "$HOME/Android/Sdk/platform-tools"
    "$HOME/.lmstudio/bin"
  ];

  home.sessionVariables = {
    ANDROID_HOME = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
    ANDROID_AVD_HOME = "$HOME/VMs/android-avd"; # emulator images on the no-CoW VMs subvolume
    ROS_DISTRO = "jazzy";

    # Haruna + DaVinci
    QT_QPA_PLATFORM = "xcb";
    QT_OPENGL = "desktop";

    # Disable VA-API, force NVIDIA GLX
    LIBVA_DRIVER_NAME = "dummy";
    VDPAU_DRIVER = "dummy";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  programs.home-manager.enable = true;

  # Same rule as system.stateVersion: set once, never change.
  home.stateVersion = "26.05";
}
