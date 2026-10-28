{
  description = "NixOS configuration for MikyNB";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, disko, qylock, ... }:
    let
      system = "x86_64-linux";

      # Every theme qylock ships calls `keyboard.numLock = true` in
      # Component.onCompleted - copy-pasted from real SDDM greeter QML,
      # which does provide a global `keyboard` object. Quickshell's
      # SddmShim (programs.qylock's in-session lock, as opposed to the
      # SDDM greeter which still uses real SDDM) never defines one, so
      # that line throws a ReferenceError early enough that Quickshell
      # aborts before the lock surface is actually presented - Mod+L
      # (see niri.nix) silently does nothing. Patch in a no-op stand-in.
      qylockQuickshellPatched = (qylock.legacyPackages.${system}.mkQuickshell {
        defaultTheme = "enfield";
      }).overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i '/id: shim/a\    property var keyboard: QtObject { property bool numLock: false }' \
            quickshell-lockscreen/shim/SddmShim.qml
        '';
      });
    in {
    nixosConfigurations.MikyNB = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/MikyNB/configuration.nix
        disko.nixosModules.disko
        qylock.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          # Install our patched build instead of qylock's own (broken) one.
          programs.qylock.quickshell.enable = false;
          environment.systemPackages = [ qylockQuickshellPatched ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # If a file HM wants to create already exists (e.g. a restored ~/.zshrc),
          # rename it to *.backup instead of failing the rebuild.
          home-manager.backupFileExtension = "backup";
          home-manager.users.miky8745 = import ./home/miky8745.nix;
        }
      ];
    };
  };
}
