{
  description = "A program to export churros events to an online calendar.";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Generate a user-friendly version number.
      version = "alpha2";

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      # enable nix fmt
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          churros-online-calendar = pkgs: pkgs.ocamlPackages.buildDunePackage {
            inherit version;
            pname = "churros_online_calendar";
            # Tell nix that the source of the content is in the root
            src = ./.;

            nativeBuildInputs = [ pkgs.ocamlPackages.menhir ];
            buildInputs = with pkgs.ocamlPackages; [
              ppx_deriving
              ppxlib
              menhirLib
              sedlex
              lwt_ppx
              cohttp-lwt-unix
              caqti-lwt
              caqti-driver-sqlite3
              caqti-driver-postgresql
              caqti-driver-mariadb
              mirage-crypto-rng
              mirage-crypto-rng-lwt
              base64
              yojson
              ppx_yojson_conv
            ] ++ [ pkgs.mariadb ];
          };

          dockerbuilder = buildfun: pkgs:
            let
              churros-online-calendar-package = churros-online-calendar pkgs;
            in
            buildfun {
              name = "churros-online-calendar";
              tag = "latest";
              contents = [ pkgs.cacert churros-online-calendar-package ];
              config.Cmd = [ "${churros-online-calendar-package}/bin/churros_online_calendar" ];
              # IMPORTANT: MAKE HTTPS WORK
              config.Env =
                [
                  "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                ];
              # IMPORTANT: ocaml cohttp needs /etc/services, see https://github.com/mirage/ocaml-cohttp/issues/675
              enableFakechroot = true;
              fakeRootCommands = ''
                mkdir -p /etc
                cat <<EOF > /etc/services
                https            443/tcp    # http protocol over TLS/SSL
                https            443/udp    # http protocol over TLS/SSL
                https            443/sctp   # HTTPS
                EOF
              '';
            };
        in
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          # Build the application bin using glibc
          churros-online-calendar = churros-online-calendar pkgs;
          churros-online-calendar-musl = churros-online-calendar pkgs.pkgsMusl;

          # Build docker compressed image using glibc
          docker-image = dockerbuilder pkgs.dockerTools.buildLayeredImage pkgs;
          # Build script to generate uncompressed docker image (use less space in nix store)
          docker-stream = dockerbuilder pkgs.dockerTools.streamLayeredImage pkgs;

          # Build docker compressed image using musl (resulting in smaller image
          # but much longer build as not all packages are available in nixos official cache)
          docker-image-musl = dockerbuilder pkgs.dockerTools.buildLayeredImage pkgs.pkgsMusl;
          # Build script to generate uncompressed docker image using musl
          docker-stream-musl = dockerbuilder pkgs.dockerTools.streamLayeredImage pkgs.pkgsMusl;
        });

      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = (with pkgs; [ nixd ocaml dune_3 ocamlformat ocamlPackages.ocaml-lsp ocamlPackages.utop ])
              ++ (with self.packages.${system}.churros-online-calendar; nativeBuildInputs ++ buildInputs);
          };
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.churros-online-calendar);
    };
}
