{
  description = "activity watch";

  inputs = {
    # for building rust apps
    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # for building node js apps
    napalm = {
      url = "github:nix-community/napalm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # for getting rust nightly
    rust-overlay.url = "github:oxalica/rust-overlay";

    # to be able to install on non-flake NixOS configuration.nix
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = { self, naersk, nixpkgs, napalm, rust-overlay, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      # TODO: Remove hardcoded platform and support others using forAllPlatforms flake utils

      platform = "x86_64-linux";
      version = "0.11.0";
      sources = fetchFromGitHub {
        owner = "ActivityWatch";
        repo = "activitywatch";
        rev = "62fbdec9c22739fb7c997b6c626b92747e8fd90c";
        sha256 = "izRR5Ik7eyE35q2hKwgSSkjNmdLZEog/QMmEopeKoRA=";
        fetchSubmodules = true;
      };

      python3 = nixpkgs.legacyPackages.${platform}.python38;
      fetchFromGitHub = nixpkgs.legacyPackages.${platform}.fetchFromGitHub;
      libsForQt5 = nixpkgs.legacyPackages.${platform}.libsForQt5;
      xdg-utils = nixpkgs.legacyPackages.${platform}.xdg-utils;
      pkg-config = nixpkgs.legacyPackages.${platform}.pkg-config;
      perl = nixpkgs.legacyPackages.${platform}.perl;
      openssl = nixpkgs.legacyPackages.${platform}.openssl;
      makeWrapper = nixpkgs.legacyPackages.${platform}.makeWrapper;
      nixPkgsWithNpalm = import nixpkgs {
        system = "${platform}";
        overlays = [ napalm.overlay ];
      };

      naerskUnstable =
        let
          nixPkgsWithNightlyRust = import nixpkgs {
            system = "${platform}";
            overlays = [ rust-overlay.overlay ];
          };
          rust = nixPkgsWithNightlyRust.pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
        in
        naersk.lib.${platform}.override {
          cargo = rust;
          rustc = rust;
        };

      aw-core = python3.pkgs.buildPythonPackage rec {
        pname = "aw-core";
        inherit version;

        format = "pyproject";

        src = "${sources}/aw-core";

        nativeBuildInputs = [
          python3.pkgs.poetry
        ];

        propagatedBuildInputs = with python3.pkgs; [
          jsonschema
          peewee
          appdirs
          iso8601
          python-json-logger
          TakeTheTime
          pymongo
          strict-rfc3339
          tomlkit
          deprecation
          timeslot
        ];

        postPatch = ''
          sed -E 's#python-json-logger = "\^0.1.11"#python-json-logger = "^2.0"#g' -i pyproject.toml
          sed -E 's#tomlkit = "\^0.6.0"#tomlkit = "^0.7"#g' -i pyproject.toml
        '';

        meta = with lib; {
          description = "Core library for ActivityWatch";
          homepage = "https://github.com/ActivityWatch/aw-core";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mpl20;
        };
      };

      aw-client = python3.pkgs.buildPythonPackage rec {
        pname = "aw-client";
        inherit version;

        format = "pyproject";

        src = "${sources}/aw-client";

        nativeBuildInputs = [
          python3.pkgs.poetry
        ];

        propagatedBuildInputs = with python3.pkgs; [
          aw-core
          requests
          persist-queue
          click
        ];

        postPatch = ''
          sed -E 's#click = "\^7.1.1"#click = "^8.0"#g' -i pyproject.toml
        '';

        meta = with lib; {
          description = "Client library for ActivityWatch";
          homepage = "https://github.com/ActivityWatch/aw-client";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mpl20;
        };
      };

      persist-queue = python3.pkgs.buildPythonPackage rec {
        version = "0.6.0";
        pname = "persist-queue";

        src = python3.pkgs.fetchPypi {
          inherit pname version;
          sha256 = "5z3WJUXTflGSR9ljaL+lxRD95mmZozjW0tRHkNwQ+Js=";
        };

        checkInputs = with python3.pkgs; [
          msgpack
          nose2
        ];

        checkPhase = ''
          runHook preCheck
          nose2
          runHook postCheck
        '';

        meta = with lib; {
          description = "Thread-safe disk based persistent queue in Python";
          homepage = "https://github.com/peter-wangxu/persist-queue";
          license = licenses.bsd3;
        };
      };

      TakeTheTime = python3.pkgs.buildPythonPackage rec {
        pname = "TakeTheTime";
        version = "0.3.1";

        src = python3.pkgs.fetchPypi {
          inherit pname version;
          sha256 = "2+MEU6G1lqOPni4/qOGtxa8tv2RsoIN61cIFmhb+L/k=";
        };

        checkInputs = [
          python3.pkgs.nose
        ];

        doCheck = false; # tests not available on pypi

        checkPhase = ''
          runHook preCheck
          nosetests -v tests/
          runHook postCheck
        '';

        meta = with lib; {
          description = "Simple time taking library using context managers";
          homepage = "https://github.com/ErikBjare/TakeTheTime";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mit;
        };
      };

      timeslot = python3.pkgs.buildPythonPackage rec {
        pname = "timeslot";
        version = "0.1.2";

        src = python3.pkgs.fetchPypi {
          inherit pname version;
          sha256 = "oqyZhlfj87nKkodXtJBq3SwFOQxfwU7XkruQKNCFR7E=";
        };

        meta = with lib; {
          description = "Data type for representing time slots with a start and end";
          homepage = "https://github.com/ErikBjare/timeslot";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mit;
        };
      };

      aw-qt = python3.pkgs.buildPythonApplication rec {
        pname = "aw-qt";
        inherit version;

        format = "pyproject";

        src = "${sources}/aw-qt";

        nativeBuildInputs = [
          python3.pkgs.poetry
          python3.pkgs.pyqt5 # for pyrcc5
          libsForQt5.wrapQtAppsHook
          xdg-utils
        ];

        propagatedBuildInputs = with python3.pkgs; [
          aw-core
          pyqt5
          click
        ];

        # Prevent double wrapping
        dontWrapQtApps = true;

        postPatch = ''
          sed -E 's#click = "\^7.1.2"#click = "^8.0"#g' -i pyproject.toml
          sed -E 's#PyQt5 = "5.15.2"#PyQt5 = "^5.15.2"#g' -i pyproject.toml
        '';

        preBuild = ''
          make aw_qt/resources.py
        '';

        postInstall = ''
          install -Dt $out/etc/xdg/autostart resources/aw-qt.desktop
          xdg-icon-resource install --novendor --size 32 media/logo/logo.png activitywatch
          xdg-icon-resource install --novendor --size 512 media/logo/logo.png activitywatch
        '';

        preFixup = ''
          makeWrapperArgs+=(
            "''${qtWrapperArgs[@]}"
          )
        '';

        meta = with lib; {
          description = "Tray icon that manages ActivityWatch processes, built with Qt";
          homepage = "https://github.com/ActivityWatch/aw-qt";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mpl20;
        };
      };

      aw-server-rust = naerskUnstable.buildPackage {
        name = "aw-server-rust";
        inherit version;

        root = "${sources}/aw-server-rust";

        nativeBuildInputs = [
          pkg-config
          perl
        ];

        buildInputs = [
          openssl
        ];

        overrideMain = attrs: {
          nativeBuildInputs = attrs.nativeBuildInputs or [ ] ++ [
            makeWrapper
          ];

          postFixup = attrs.postFixup or "" + ''
            wrapProgram "$out/bin/aw-server" \
              --prefix XDG_DATA_DIRS : "$out/share"
            mkdir -p "$out/share/aw-server"
            ln -s "${aw-webui}" "$out/share/aw-server/static"
          '';
        };

        meta = with lib; {
          description = "Cross-platform, extensible, privacy-focused, free and open-source automated time tracker";
          homepage = "https://github.com/ActivityWatch/aw-server-rust";
          maintainers = with maintainers; [ jtojnar ];
          platforms = platforms.linux;
          license = licenses.mpl20;
        };
      };

      aw-watcher-afk = python3.pkgs.buildPythonApplication rec {
        pname = "aw-watcher-afk";
        inherit version;

        format = "pyproject";

        src = "${sources}/aw-watcher-afk";

        nativeBuildInputs = [
          python3.pkgs.poetry
        ];

        propagatedBuildInputs = with python3.pkgs; [
          aw-client
          xlib
          pynput
        ];

        postPatch = ''
          sed -E 's#python-xlib = \{ version = "\^0.28"#python-xlib = \{ version = "^0.29"#g' -i pyproject.toml
        '';

        meta = with lib; {
          description = "Watches keyboard and mouse activity to determine if you are AFK or not (for use with ActivityWatch)";
          homepage = "https://github.com/ActivityWatch/aw-watcher-afk";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mpl20;
        };
      };

      aw-watcher-window = python3.pkgs.buildPythonApplication rec {
        pname = "aw-watcher-window";
        inherit version;

        format = "pyproject";

        src = "${sources}/aw-watcher-window";

        nativeBuildInputs = [
          python3.pkgs.poetry
        ];

        propagatedBuildInputs = with python3.pkgs; [
          aw-client
          xlib
        ];

        postPatch = ''
          sed -E 's#python-xlib = \{version = "\^0.28"#python-xlib = \{ version = "^0.29"#g' -i pyproject.toml
        '';

        meta = with lib; {
          description = "Cross-platform window watcher (for use with ActivityWatch)";
          homepage = "https://github.com/ActivityWatch/aw-watcher-window";
          maintainers = with maintainers; [ jtojnar ];
          license = licenses.mpl20;
        };
      };

      aw-webui =
        let
          # Node.js used by napalm.
          nodejs = nixpkgs.legacyPackages.${platform}.nodejs-16_x;

          installHeadersForNodeGyp = ''
            mkdir -p "$HOME/.cache/node-gyp/${nodejs.version}"
            # Set up version which node-gyp checks in <https://github.com/nodejs/node-gyp/blob/4937722cf597ccd1953628f3d5e2ab5204280051/lib/install.js#L87-L96> against the version in <https://github.com/nodejs/node-gyp/blob/4937722cf597ccd1953628f3d5e2ab5204280051/package.json#L15>.
            echo 9 > "$HOME/.cache/node-gyp/${nodejs.version}/installVersion"
            # Link node headers so that node-gyp does not try to download them.
            ln -sfv "${nodejs}/include" "$HOME/.cache/node-gyp/${nodejs.version}"
          '';

          stopNpmCallingHome = ''
            # Do not try to find npm in napalm-registry –
            # it is not there and checking will slow down the build.
            npm config set update-notifier false
            # Same for security auditing, it does not make sense in the sandbox.
            npm config set audit false
          '';
        in
        nixPkgsWithNpalm.napalm.buildPackage "${sources}/aw-server-rust/aw-webui" {
          nodejs = nixpkgs.legacyPackages.${platform}.nodejs-16_x;
          nativeBuildInputs = [
            # deasync uses node-gyp
            python3
          ];

          npmCommands = [
            # Let’s install again, this time running scripts.
            "npm install --loglevel verbose"

            # Build the front-end.
            "npm run build"
          ];

          postConfigure = ''
            # configurePhase sets $HOME
            ${installHeadersForNodeGyp}
            ${stopNpmCallingHome}
          '';

          installPhase = ''
            runHook preInstall
            mv dist $out
            runHook postInstall
          '';
        };
    in
    {
      # Executed by `nix flake check`
      checks.${platform} = { };

      # Executed by `nix build .#<name>`
      packages.${platform} = {
        aw-core = aw-core;
        aw-server-rust = aw-server-rust;
        aw-qt = aw-qt;
        aw-watcher-afk = aw-watcher-afk;
        aw-watcher-window = aw-watcher-window;
        aw-webui = aw-webui;
      };

      # Executed by `nix build .`
      defaultPackage.${platform} = aw-server-rust;

      # Executed by `nix run .#<name>`
      apps.${platform} = {
        aw-watcher-afk = {
          type = "app";
          program = "${self.packages.${platform}.aw-watcher-afk}/bin/aw-watcher-afk";
        };
        aw-watcher-window = {
          type = "app";
          program = "${self.packages.${platform}.aw-watcher-window}bin/aw-watcher-window";
        };
        aw-server = {
          type = "app";
          program = "${self.packages.${platform}.aw-server-rust}/bin/aw-server";
        };
      };

      # Executed by `nix run . -- <args?>`
      # TODO: Make a default app which runs all services required by activity watch
      defaultApp.${platform} = {
        type = "app";
        program = "${self.packages.${platform}.aw-server-rust}/bin/aw-server";
      };

      # TODO: Make a proper development shell
      # Executed by `nix develop`
      devShell.${platform} =
        nixpkgs.legacyPackages.${platform}.mkShell {
          buildInputs = [
            self.packages.${platform}.aw-server-rust
            self.packages.${platform}.aw-watcher-afk
            self.packages.${platform}.aw-watcher-window
          ];
          # TODO: MOVE THIS BASH RUN SCRIPT INTO DEFAULT APP
          shellHook = ''
            echo 'Starting activity watch'
            aw-watcher-afk & aw-watcher-window & aw-server
          '';
        };
    };
}
