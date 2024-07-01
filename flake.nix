{
  description = "A simple Go package";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Generate a user-friendly version number.
      version = "alpha1";

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
          pkgs = nixpkgsFor.${system};
        in
        {

          churros-online-calendar = pkgs.ocamlPackages.buildDunePackage {
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
              mirage-crypto-rng
              mirage-crypto-rng-lwt
              base64
            ];
          };
        });

      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ nixd ocaml dune_3 ocamlformat ocamlPackages.ocaml-lsp ]
              ++ (with self.packages.${system}.churros-online-calendar; nativeBuildInputs ++ buildInputs);
          };
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.churros-online-calendar);
    };
}
