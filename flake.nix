{
  inputs = {
    flakelib = {
      url = "github:flakelib/fl";
    };
    nixpkgs = { };
  };
  outputs = { self, nixpkgs, flakelib, ... }@inputs: let
    nixlib = nixpkgs.lib;
  in flakelib {
    inherit inputs;
    packages = {
      esphome-fonts = { linkFarm, cozette }: linkFarm "esphome-fonts" [
        {
          name = "cozette.bdf";
          path = "${cozette}/share/fonts/misc/cozette.bdf";
        }
      ];
      esphome = { nixpkgs'esphome, python3Packages }: let
        pythonOverlay = pythonPackages: super: {
          esphome-dashboard = super.esphome-dashboard or (pythonPackages.callPackage (nixpkgs.outPath + "/pkgs/tools/misc/esphome/dashboard.nix") { });
        };
        python = python3Packages.python.override {
          packageOverrides = nixlib.composeManyExtensions [
            pythonOverlay
          ];
        };
        overrides'attrs = old: {
        };
        # esphome overrides `packageOverrides` in a dumb way .-.
        overrides = {
          python3Packages = python.pkgs // {
            python = python // {
              override = _: python;
            };
          };
        };
        needsOverrides = false;
      in if needsOverrides
        then (nixpkgs'esphome.override overrides).overridePythonAttrs overrides'attrs
        else nixpkgs'esphome;
      flash-espresense = { writeShellScriptBin, esptool, jq, curl }: let
        bins = [ esptool jq curl ];
      in writeShellScriptBin "flash-espresense" ''
        export PATH=''${PATH-}:${nixlib.makeBinPath bins}
        source ${./flash-espresense.sh}
      '';
    };
    devShells = {
      default = { mkShell, writeShellScriptBin, sops, gnumake, esptool, esphome, esphome-fonts }: let
        esphome-wrapper = writeShellScriptBin "esphome" ''
          exec ${nixlib.getExe esphome} -s fonts_root ${esphome-fonts} "$@"
        '';
        flash-espresense = writeShellScriptBin "flash-espresense" ''
          exec nix run --quiet .#flash-espresense ''${FLAKE_OPTS-} -- "$@"
        '';
      in mkShell {
        nativeBuildInputs = [
          flash-espresense
          esphome-wrapper
          esptool
          gnumake
          sops
        ];
      };
    };
  };
}
