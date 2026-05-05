{
  description = "Python development environment with UV (FHS)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nixSetuptools = pkgs.python312Packages.setuptools;

        serverPkg =
          let
            nginxConf = pkgs.writeText "nginx.conf" ''
              error_log /dev/stdout info;
              pid /tmp/nginx.pid;
              user root root;
              events {}
              http {
                include ${pkgs.nginx}/conf/mime.types;
                access_log /dev/stdout;

                client_body_temp_path /tmp/nginx_client_body;
                proxy_temp_path       /tmp/nginx_proxy_temp;
                fastcgi_temp_path     /tmp/nginx_fastcgi_temp;
                uwsgi_temp_path       /tmp/nginx_uwsgi_temp;
                scgi_temp_path        /tmp/nginx_scgi_temp;
      
                server {
                  listen 8000;
                  location / {
                    root /data;
          
                    # Enables the directory listing
                    autoindex on;
          
                    # Optional: Makes the file list look a bit nicer
                    autoindex_exact_size off; # Shows "1MB" instead of "1048576"
                    autoindex_localtime on;  # Uses local machine time for timestamps
                  }
                }
              }
            '';
          in
          pkgs.writeShellScriptBin "server" ''
            echo "Starting Nginx File Server on http://localhost:8000"
            exec ${pkgs.nginx}/bin/nginx -c ${nginxConf} -p $PWD -g "daemon off; error_log stderr info;"
          '';
      in
      {
        packages = {
          default = serverPkg;
          server = serverPkg;
        };

        apps.default = {
          type = "app";
          program = "${serverPkg}/bin/server";
        };

        devShells.default = (pkgs.buildFHSEnv {
          name = "python-uv-dev";
          targetPkgs = pkgs:
            with pkgs; [
              # Essential system libraries
              glibc
              stdenv.cc.cc.lib

              # Python and UV
              python312
              uv

              # Ensure setuptools is available to copy/link
              python312Packages.setuptools

              # Build tools
              gcc
              pkg-config

              # Common dependencies
              zlib
              libffi
              openssl
              ncurses
              readline
              sqlite
              tk
              xz
              libX11
              libxcb
              xcbutilwm
              xcbutilimage
              xcbutilkeysyms
              xcbutilrenderutil
              libXcursor
              libXcomposite
              libXdamage
              libXext
              libXfixes
              libXi
              libXrender
              libXtst
              libXrandr
              libXinerama
              libxkbcommon
              dbus
              xcbutilcursor
              fontconfig



              # Development tools
              git
              curl
              wget
              which

              # Additional libraries
              libxml2
              libxslt
              libjpeg
              libpng
              freetype
              blas
              lapack
              gfortran
              portaudio
              libGL
              libGLU
              glib
            ];

          runScript = "bash";

          profile = ''
            export UV_PYTHON="$(which python3.12)"
            export UV_PYTHON_DOWNLOADS="never"
            export LD_LIBRARY_PATH="/usr/lib:/usr/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"

            unset QT_PLUGIN_PATH
            unset QT_QPA_PLATFORMTHEME
            unset QT_STYLE_OVERRIDE
            unset KDE_FULL_SESSION
            unset KDE_SESSION_VERSION

            export QT_QPA_PLATFORM=xcb
            
            VENV_SP=".venv/lib/python3.12/site-packages"
            SETUPTOOLS_PATH="$VENV_SP/setuptools"

            # --- PRE-SYNC CLEANUP ---
            if [ -L "$SETUPTOOLS_PATH" ]; then rm "$SETUPTOOLS_PATH"; fi

            # Initial setup
            if [ ! -f "pyproject.toml" ]; then
                uv init --python python3.12
                uv add jupyter ipykernel ipywidgets notebook torch 
                uv add --dev black ruff isort pytest
            fi

            uv sync

            # --- POST-SYNC COPYING ---
            if [ -d "$VENV_SP" ]; then
                echo "Force-syncing Nixpkgs setuptools & pkg_resources..."
                rm -rf "$VENV_SP/setuptools" "$VENV_SP/pkg_resources"
                
                # Copy both from the Nix store
                NIX_SP="${nixSetuptools}/lib/python3.12/site-packages"
                cp -r "$NIX_SP/setuptools" "$VENV_SP/"
                cp -r "$NIX_SP/pkg_resources" "$VENV_SP/"
                chmod -R +w "$VENV_SP/setuptools" "$VENV_SP/pkg_resources"
                
                # IMPORTANT: Ensure the shell Python looks at the venv first
                export PYTHONPATH="$PWD/$VENV_SP:$PYTHONPATH"
            fi

            # Activate the virtualenv for this session
            source .venv/bin/activate

            echo "Environment ready!"
            python --version
          '';
        }).env;
      });
}


