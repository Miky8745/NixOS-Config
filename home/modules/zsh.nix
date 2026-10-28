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
    };

    initContent = lib.mkMerge [
      ''
        # NVM (prebuilt Node binaries run thanks to programs.nix-ld)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

        # rebuild-nixos [-c "commit message"] [-p]
        # nh self-elevates; don't sudo it. Rebuilds first so a broken config
        # never gets committed/pushed; -c and -p are independent (e.g. `-p`
        # alone just pushes whatever's already committed).
        rebuild-nixos() {
          local OPTIND opt commit_msg="" do_push=0
          while getopts "c:p" opt; do
            case "$opt" in
              c) commit_msg="$OPTARG" ;;
              p) do_push=1 ;;
              *) echo "Usage: rebuild-nixos [-c \"commit message\"] [-p]" >&2; return 1 ;;
            esac
          done

          (cd ~/Programming/nixos_conf && nh os switch) || return 1

          if [ -n "$commit_msg" ]; then
            (cd ~/Programming/nixos_conf && git add -A && git commit -m "$commit_msg") || return 1
          fi

          if [ "$do_push" -eq 1 ]; then
            (cd ~/Programming/nixos_conf && git push) || return 1
          fi
        }
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
