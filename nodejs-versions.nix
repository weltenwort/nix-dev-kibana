{ pkgs, nixpkgs }:
let
  buildNodejs = pkgs.callPackage (nixpkgs + "/pkgs/development/web/nodejs/nodejs.nix") {
    openssl = pkgs.openssl;
    python = pkgs.python3;
  };
in
{
  nodejs-16_13_0 = buildNodejs {
    enableNpm = true;
    version = "16.13.0";
    sha256 = "1k6bgs83s5iaawi63dcc826g23lfqr13phwbbzwx0pllqcyln49j";
  };
  nodejs-16_13_2 = buildNodejs {
    enableNpm = true;
    version = "16.13.2";
    sha256 = "185lm13q0kwz0qimc38c7mxn8ml6m713pjdjsa9jna9az4gxxccq";
    patches = [
      (pkgs.fetchpatch {
        url = "https://github.com/nodejs/node/commit/65119a89586b94b0dd46b45f6d315c9d9f4c9261.patch";
        sha256 = "sha256-dihKYEdK68sQIsnfTRambJ2oZr0htROVbNZlFzSAL+I=";
      })
    ];
  };
  nodejs-16_16_0 = buildNodejs {
    enableNpm = true;
    version = "16.16.0";
    sha256 = "sha256-FFFR7/Oyql6+czhACcUicag3QK5oepPJjGKM19UnNus=";
    patches = [
      # Fix npm silently fail without a HOME directory https://github.com/npm/cli/issues/4996
      (pkgs.fetchpatch {
        url = "https://github.com/npm/cli/commit/9905d0e24c162c3f6cc006fa86b4c9d0205a4c6f.patch";
        sha256 = "sha256-RlabXWtjzTZ5OgrGf4pFkolonvTDIPlzPY1QcYDd28E=";
        includes = [ "deps/npm/lib/npm.js" "deps/npm/lib/utils/log-file.js" ];
        stripLen = 1;
        extraPrefix = "deps/npm/";
      })
    ];
  };
}
