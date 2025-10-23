{
  description = "A Kibana development flake";
  inputs.nixpkgs = {
    url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        makePkgs =
          {
            overlays ? [ ],
          }:
          import nixpkgs {
            inherit system;
            overlays = [
              #              (final: prev: {
              #                chromium = prev.symlinkJoin {
              #                  name = "chromium";
              #                  paths = [ prev.chromium ];
              #                  buildInputs = [ prev.makeWrapper ];
              #                  postBuild = ''
              #                    wrapProgram $out/bin/chromium \
              #                    --add-flags "--disable-gpu"
              #                  '';
              #                };
              #              })
            ]
            ++ overlays
            ++ [
              # (final: prev: {
              #   yarn = prev.yarn.override {
              #     nodejs = final.nodejs-current;
              #   };
              # })
            ];
          };
        makeCommonPackages =
          { pkgs }:
          [
            pkgs.nodenv
            pkgs.chromium
            pkgs.fontconfig
            pkgs.noto-fonts
            pkgs.icewm
          ];
        makeScripts =
          { pkgs }:
          [
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
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                cd x-pack && node scripts/functional_tests_server.js --config "''${1:-test/functional/config.js}"
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-start-functional-runner";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/functional_test_runner.js --config "''${1:-x-pack/test/functional/config.js}"
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-bootstrap";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/kbn.js bootstrap && node scripts/build_kibana_platform_plugins.js --no-examples
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-start-dev";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/kibana.js --dev --no-base-path
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-start-serverless-oblt-dev";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/kibana.js --dev --no-base-path --serverless=oblt
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-lint-fix";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/lint_ts_projects.js --fix
                node scripts/eslint.js --fix
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-profile-bundle";
              text = ''
                set -x
                export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=8192''${NODE_OPTIONS:+ $NODE_OPTIONS}"
                node scripts/build_kibana_platform_plugins.js --dist --no-examples --profile --no-cache "--focus=''${1}"
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-synthtrace";
              text = ''
                set -x
                node scripts/synthtrace.js \
                  --target "http://elastic:changeme@localhost:9200/" \
                  --kibana "http://elastic:changeme@localhost:5601/" \
                  --logLevel debug \
                  "''${@}"
              '';
            })
            (pkgs.writeShellApplication {
              name = "kbn-serverless-synthtrace";
              text = ''
                set -x
                node scripts/synthtrace.js \
                  --target "http://elastic_serverless:changeme@localhost:9200/" \
                  --kibana "http://elastic_serverless:changeme@localhost:5601/" \
                  --logLevel debug \
                  "''${@}"
              '';
            })
            (pkgs.writeScriptBin "kbn-init-dev" ''
              #!${pkgs.fish}/bin/fish

              echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.d/99-local.conf
              sudo sysctl --system

              nvm install
              npm install -g yarn
            '')
          ];
        makeCommonShell =
          { pkgs }:
          {
            DISPLAY = ":0";
            FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
            CHROMIUM_FLAGS = "--disable-gpu";
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

                    gh repo clone weltenwort/kibana -- --filter=blob:none

                    cat <<-EOL >> ~/repos/kibana/.envrc
                    use flake ~/nix-flakes/kibana#main
                    use node
                    EOL
                  '';
                })
                (pkgs.writeShellApplication {
                  name = "meta-install-docker";
                  text = ''
                    # Add Docker's official GPG key:
                    sudo apt-get update
                    sudo apt-get install ca-certificates curl gnupg
                    sudo install -m 0755 -d /etc/apt/keyrings
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                    sudo chmod a+r /etc/apt/keyrings/docker.gpg

                    # Add the repository to Apt sources:
                    # shellcheck source=/dev/null
                    echo \
                      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    sudo apt-get update

                    # Install packages
                    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

                    # Add to group
                    sudo gpasswd -a ubuntu docker

                    # Set params for ES in docker
                    echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/local.conf
                    sudo systemctl restart procps.service
                  '';
                })
              ];
              commonShell = makeCommonShell { inherit pkgs; };
            in
            pkgs.mkShell (
              commonShell
              // {
                packages = scripts ++ [
                  pkgs.nil
                  pkgs.nixpkgs-fmt
                ];
              }
            );
          main =
            let
              pkgs = makePkgs {
                overlays = [
                  #(final: prev: import ./nodejs-versions.nix {
                  #  pkgs = prev;
                  #  inherit nixpkgs;
                  #})
                  #(final: prev:
                  #  let
                  #    pkgs-nodejs-18-18-2 = (import nixpkgs-nodejs-18-18-2 {
                  #      inherit system;
                  #    });
                  #  in
                  #  {
                  #    nodejs-current = pkgs-nodejs-18-18-2.nodejs-18_x;
                  #  }
                  #)
                  #(final: prev: {
                  #  nodejs-current = final.nodejs_20;
                  #})
                ];
              };
              scripts = makeScripts { inherit pkgs; };
              commonPackages = makeCommonPackages { inherit pkgs; };
              commonShell = makeCommonShell { inherit pkgs; };
            in
            pkgs.mkShell (
              commonShell
              // {
                packages = commonPackages ++ scripts;
              }
            );
          v7-16 =
            let
              pkgs = makePkgs {
                overlays = [
                  (
                    final: prev:
                    import ./nodejs-versions.nix {
                      pkgs = prev;
                      inherit nixpkgs;
                    }
                  )
                  (final: prev: {
                    nodejs-current = final.nodejs-16_13_0;
                  })
                ];
              };
              scripts = makeScripts { inherit pkgs; };
              commonShell = makeCommonShell { inherit pkgs; };
              commonPackages = makeCommonPackages { inherit pkgs; };
            in
            pkgs.mkShell (
              commonShell
              // {
                packages = commonPackages ++ scripts;
              }
            );
        };
      }
    );
}
