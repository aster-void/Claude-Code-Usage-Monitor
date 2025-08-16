{
  description = "Real-time Claude Code usage monitor with predictions and warnings ";

  # Usage:
  #
  # Run the application:
  #   nix run github:Maciek-roboblog/Claude-Code-Usage-Monitor # anywhere
  #   nix run . -- --help # if you have this repo cloned
  #
  # Install to profile:
  #   nix profile install github:Maciek-roboblog/Claude-Code-Usage-Monitor
  #
  # Run with specific command:
  #   nix run .#claude-monitor -- --plan pro --view realtime
  #   nix run .#cmonitor -- --theme dark
  #
  # Development:
  #   nix develop          # Enter dev shell with all dependencies
  #   nix build            # Build the package
  #   nix flake check      # Run all validation checks
  #   nix fmt .            # Format the flake.nix
  #
  # Available apps:
  #   claude-monitor (default) - Main application
  #   claude-code-monitor      - Alternative name
  #   cmonitor                 - Short alias
  #   ccmonitor               - Short alias
  #   ccm                     - Shortest alias
  #
  # All apps support the same command-line arguments as the Python package.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      claude-monitor = pkgs.python3Packages.buildPythonApplication {
        pname = "claude-monitor";
        version = "3.1.0";
        format = "pyproject";

        src = ./.;

        nativeBuildInputs = with pkgs.python3Packages; [
          setuptools
          wheel
        ];

        propagatedBuildInputs = with pkgs.python3Packages;
          [
            numpy
            pydantic
            pydantic-settings
            pyyaml
            pytz
            rich
          ]
          ++ pkgs.lib.optionals (pkgs.python3Packages.pythonOlder "3.11") [
            tomli
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isWindows [
            tzdata
          ];

        # Optional development dependencies
        passthru.optional-dependencies = {
          dev = with pkgs.python3Packages;
            [
              black
              isort
              mypy
              pytest
              pytest-asyncio
              pytest-benchmark
              pytest-cov
              pytest-mock
              pytest-xdist
              ruff
              build
              twine
            ]
            ++ [pkgs.pre-commit];
          test = with pkgs.python3Packages; [
            pytest
            pytest-cov
            pytest-mock
            pytest-asyncio
            pytest-benchmark
          ];
        };

        # Skip tests during build (they can be run separately)
        doCheck = false;

        # Ensure the package is properly installed
        postInstall = ''
          # Verify the main entry points are available
          $out/bin/claude-monitor --help > /dev/null
        '';

        meta = with pkgs.lib; {
          description = "A real-time terminal monitoring tool for Claude Code token usage with advanced analytics and Rich UI";
          homepage = "https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor";
          license = licenses.mit;
          maintainers = [];
          platforms = platforms.unix;
          mainProgram = "claude-monitor";
        };
      };

      # Development shell with all dependencies
      devShell = pkgs.mkShell {
        packages =
          [
            pkgs.python3
            pkgs.python3Packages.pip
            pkgs.python3Packages.setuptools
            pkgs.python3Packages.wheel
            pkgs.pre-commit
          ]
          ++ claude-monitor.propagatedBuildInputs
          ++ (with pkgs.python3Packages; [
            black
            isort
            mypy
            pytest
            pytest-asyncio
            pytest-benchmark
            pytest-cov
            pytest-mock
            pytest-xdist
            ruff
            build
            twine
          ]);
      };
    in {
      packages = {
        default = claude-monitor;
        claude-monitor = claude-monitor;
      };

      apps = {
        default = {
          type = "app";
          program = "${claude-monitor}/bin/claude-monitor";
        };
        claude-monitor = {
          type = "app";
          program = "${claude-monitor}/bin/claude-monitor";
        };
        claude-code-monitor = {
          type = "app";
          program = "${claude-monitor}/bin/claude-code-monitor";
        };
        cmonitor = {
          type = "app";
          program = "${claude-monitor}/bin/cmonitor";
        };
        ccmonitor = {
          type = "app";
          program = "${claude-monitor}/bin/ccmonitor";
        };
        ccm = {
          type = "app";
          program = "${claude-monitor}/bin/ccm";
        };
      };

      devShells.default = devShell;

      # Checks for `nix check`
      checks = {
        # Build test - ensures the package builds correctly
        build = claude-monitor;

        # Format check - ensures code is properly formatted
        format-check =
          pkgs.runCommand "format-check" {
            buildInputs = [pkgs.alejandra];
          } ''
            alejandra --check ${./.}/flake.nix
            touch $out
          '';

        # Python syntax check
        python-syntax =
          pkgs.runCommand "python-syntax" {
            buildInputs = [pkgs.python3];
          } ''
            # Copy source to writable location to avoid permission issues
            cp -r ${./.}/src /tmp/src
            cd /tmp

            # Check Python syntax
            python3 -c "import ast; ast.parse(open('src/claude_monitor/__main__.py').read())"
            python3 -c "import ast; ast.parse(open('src/claude_monitor/__init__.py').read())"

            touch $out
          '';

        # Package installation test
        install-test =
          pkgs.runCommand "install-test" {
            buildInputs = [claude-monitor];
          } ''
            claude-monitor --version
            claude-monitor --help > /dev/null
            touch $out
          '';
      };

      # Formatter for `nix fmt .`
      formatter = pkgs.alejandra;
    });
}
