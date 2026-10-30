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
      pkgs = nixpkgs.legacyPackages.${system};

      # Every theme qylock ships calls `keyboard.numLock = true` in
      # Component.onCompleted - copy-pasted from real SDDM greeter QML,
      # which does provide a global `keyboard` object. Quickshell's
      # SddmShim (programs.qylock's in-session lock, as opposed to the
      # SDDM greeter which still uses real SDDM) never defines one, so
      # that line throws a ReferenceError early enough that Quickshell
      # aborts before the lock surface is actually presented - Mod+L
      # (see niri.nix) silently does nothing. Patch in a no-op stand-in.
      #
      # Separately, video-background themes (e.g. "enfield") render only
      # their particle overlay and no actual video: the makeWrapper call in
      # qylock's own flake sets QML2_IMPORT_PATH/QML_IMPORT_PATH (for QML
      # modules) but never QT_PLUGIN_PATH, so Qt Multimedia can't find
      # either of qtmultimedia's bundled backend plugins (ffmpeg/gstreamer)
      # and silently has no backend at all ("No QtMultimedia backends
      # found" at runtime). Re-wrap with QT_PLUGIN_PATH set and the ffmpeg
      # backend pinned explicitly (fewer runtime deps than gstreamer, which
      # would also need its own plugin scanning/cache).
      qylockQuickshellPatched = (qylock.legacyPackages.${system}.mkQuickshell {
        defaultTheme = "enfield";
      }).overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i '/id: shim/a\    property var keyboard: QtObject { property bool numLock: false }' \
            quickshell-lockscreen/shim/SddmShim.qml

          # "enfield"'s action row (bottom-right of the lock screen) only
          # wires up Restart/Shut Down - the shim's sddm object had no
          # suspend() at all. Add one next to reboot()/powerOff() (same
          # systemd-first, loginctl-fallback shape) and surface it as a
          # third action button.
          sed -i '/function powerOff/a\    function suspend() { Quickshell.execDetached(["bash", "-c", "if [ -d /run/systemd/system ]; then systemctl suspend; else loginctl suspend; fi"]); }' \
            quickshell-lockscreen/shim/SddmShim.qml

          substituteInPlace themes/enfield/Main.qml \
            --replace-fail $'                    { label: "Restart",   act: 0 },\n                    { label: "Shut Down", act: 1 }' $'                    { label: "Restart",   act: 0 },\n                    { label: "Suspend",   act: 2 },\n                    { label: "Shut Down", act: 1 }' \
            --replace-fail $'                                if (d.act === 0) sddm.reboot()\n                                else             sddm.powerOff()' $'                                if (d.act === 0) sddm.reboot()\n                                else if (d.act === 2) sddm.suspend()\n                                else             sddm.powerOff()'
        '';
        postInstall = (old.postInstall or "") + ''
          wrapProgram $out/bin/qylock-lock \
            --suffix QT_PLUGIN_PATH : "${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins" \
            --set-default QT_MEDIA_BACKEND ffmpeg
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
