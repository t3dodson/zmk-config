{
  description = "zmk-config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    zephyr.url = "github:zmkfirmware/zephyr/v3.5.0+zmk-fixes";
    zephyr.flake = false;

    zephyr-nix.url = "github:adisbladis/zephyr-nix";
    zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
  };

  outputs =
    {
      nixpkgs,
      zephyr-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      zephyr = zephyr-nix.packages.${system};
      zephyr-sdk = zephyr.sdk-0_17;
      hosttools = zephyr.hosttools-0_17;
    in
    {

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (zephyr-sdk.override {
            targets = [ "arm-zephyr-eabi" ];
          })
          zephyr.pythonEnv
          zephyr-sdk
          pkgs.cmake
          #hosttools
        ];
        shellHook = ''
          export ZMK_BUILD_DIR=$(pwd)/.build;
          export ZMK_SRC_DIR=$(pwd)/zmk/app;
        '';
      };
    };
}
