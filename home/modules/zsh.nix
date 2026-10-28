# Zsh (generates ~/.zshrc and ~/.zshenv)
{ config, lib, ... }:

{
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
      rebuild-nixos = "cd ~/Programming/nixos_conf && sudo nh os switch";
    };

    initContent = lib.mkMerge [
      ''
        # NVM (prebuilt Node binaries run thanks to programs.nix-ld)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
      ''
      (lib.mkAfter "fastfetch") # neofetch is unmaintained; fastfetch replaces it
    ];

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
      theme = "agnoster"; # blinks is also really nice
    };
  };

  # Replaces the `dircolors /etc/DIR_COLORS` line (that file doesn't exist on NixOS)
  programs.dircolors.enable = true;
}
