{
  description = "A Kibana development flake";
  inputs.nixpkgs = {
    url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    #url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        makePkgs = { overlays ? [ ] }:
          import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                nodejs-current = prev.nodejs-16_x;
              })
            ] ++ overlays ++
            [
              (final: prev: {
                yarn = prev.yarn.override {
                  nodejs = final.nodejs-current;
                };
                chromium = prev.symlinkJoin {
                  name = "chromium";
                  paths = [ prev.chromium ];
                  buildInputs = [ final.makeWrapper ];
                  postBuild = ''
                    wrapProgram $out/bin/chromium \
                    --add-flags "--disable-gpu"
                  '';
                };
              })
            ];
          };
        makeCommonPackages = { pkgs }: [
          pkgs.nodejs-current
          pkgs.yarn
          pkgs.chromium
          pkgs.fontconfig
          pkgs.noto-fonts
          pkgs.icewm
        ];
        makeScripts = { pkgs }: [
          (pkgs.writeShellApplication {
            name = "kbn-start-xvnc";
            runtimeInputs = [
              pkgs.tigervnc
            ];
            text = ''
              Xvnc -depth 24 -geometry 1920x1080 -rfbport 5900 SecurityTypes=None
            '';
          })
          (pkgs.writeShellApplication {
            name = "kbn-start-xpack-functional-server";
            text = ''
              set -x
              cd x-pack && node scripts/functional_tests_server.js --config "''${1:-test/functional/config.js}"
            '';
          })
          (pkgs.writeShellApplication {
            name = "kbn-start-functional-runner";
            text = ''
              set -x
              node scripts/functional_test_runner.js --config "''${1:-x-pack/test/functional/config.js}"
            '';
          })
          (pkgs.writeShellApplication {
            name = "kbn-bootstrap";
            text = ''
              set -x
              node scripts/kbn.js bootstrap && NODE_OPTIONS=--openssl-legacy-provider node scripts/build_kibana_platform_plugins.js --no-examples
            '';
          })
          (pkgs.writeShellApplication {
            name = "kbn-start-dev";
            text = ''
              set -x
              NODE_OPTIONS=--openssl-legacy-provider node scripts/kibana.js --dev
            '';
          })
        ];
        makeCommonShell = { pkgs }: {
          DISPLAY = ":0";
          FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
        };
      in
      {
        devShells = {
          default =
            let
              pkgs = makePkgs { };
              scripts = [
                (pkgs.writeShellApplication {
                  name = "meta-clone";
                  runtimeInputs = [
                    pkgs.git
                    pkgs.gh
                  ];
                  text = ''
                    cd ~/repos
                    gh repo clone weltenwort/kibana
                    echo "use flake ~/nix-flakes/kibana#main" >> ~/repos/kibana/.envrc
                  '';
                })
              ];
              commonShell = makeCommonShell { inherit pkgs; };
            in
            pkgs.mkShell (commonShell // {
              packages = scripts ++ [
                pkgs.nil
                pkgs.nixpkgs-fmt
              ];
            });
          main =
            let
              pkgs = makePkgs {
                overlays = [
                  #            (final: prev: import ./nodejs-versions.nix {
                  #              pkgs = prev;
                  #              inherit nixpkgs;
                  #            })
                  #            (final: prev: {
                  #              nodejs-current = final.nodejs-16_16_0;
                  #            })
                ];
              };
              scripts = makeScripts { inherit pkgs; };
              commonPackages = makeCommonPackages { inherit pkgs; };
              commonShell = makeCommonShell { inherit pkgs; };
            in
            pkgs.mkShell commonShell // {
              packages = commonPackages ++ scripts;
            };
          v7-16 =
            let
              pkgs = makePkgs {
                overlays = [
                  (final: prev: import ./nodejs-versions.nix {
                    pkgs = prev;
                    inherit nixpkgs;
                  })
                  (final: prev: {
                    nodejs-current = final.nodejs-16_13_0;
                  })
                ];
              };
              scripts = makeScripts { inherit pkgs; };
              commonShell = makeCommonShell { inherit pkgs; };
              commonPackages = makeCommonPackages { inherit pkgs; };
            in
            pkgs.mkShell commonShell // {
              packages = commonPackages ++ scripts;
            };
        };
      });
}
