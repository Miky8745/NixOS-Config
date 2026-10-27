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
  };

  outputs = { nixpkgs, home-manager, disko, ... }: {
    nixosConfigurations.MikyNB = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/MikyNB/configuration.nix
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        {
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
