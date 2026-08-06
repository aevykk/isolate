# SPDX-License-Identifier: GPL-3.0-or-later
{
  description = "isolate — single-use ZFS-clone sandbox launcher (bwrap/lxc/chroot)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    systems = [ "x86_64-linux" ];
    overlay = final: prev: {
      isolate = prev.callPackage ./default.nix { };
    };
  in
  {
    #################### overlay ####################
    overlays.default = overlay;

    #################### NixOS module ###############
    nixosModules.default = import ./module.nix;

    #################### packages ###################
    # packages.${system}.default
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      in {
        default = pkgs.isolate;
        isolate = pkgs.isolate;
      });
  };
}
