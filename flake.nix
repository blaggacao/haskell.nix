{
  description = "Alternative Haskell Infrastructure for Nixpkgs";

  inputs = {
    # Note: keep this in sync with sources.json!
    nixpkgs.url = github:NixOS/nixpkgs/f02bf8ffb9a5ec5e8f6f66f1e5544fd2aa1a0693;
  };

  outputs = { self, nixpkgs, ... }: let
    config = import ./config.nix;
    # We can't import ./nix/sources.nix directly, because that uses nixpkgs to fetch by default,
    # and importing nixpkgs without specifying localSystem doesn't work on flakes.
    sources = let
      sourcesInfo =
        builtins.fromJSON (builtins.readFile ./nix/sources.json);
      fetch = sourceInfo:
        builtins.fetchTarball { inherit (sourceInfo) url sha256; };
    in builtins.mapAttrs (_: fetch) sourcesInfo;

    nixpkgsArgs = {
      inherit config;
      overlays = [ self.overlay ];
    };
  in {
    # Using the eval-on-build version here as the plan is that
    # `builtins.currentSystem` will not be supported in flakes.
    # https://github.com/NixOS/rfcs/pull/49/files#diff-a5a138ca225433534de8d260f225fe31R429
    overlay = self.overlays.combined-eval-on-build;
    overlays = import ./overlays { sourcesOverride = sources; };
    legacyPackages = let
      genAttrs = lst: f:
        builtins.listToAttrs (map (name: {
          inherit name;
          value = f name;
        }) lst);
    in genAttrs [ "x86_64-linux" "x86_64-darwin" ] (system:
      import nixpkgs
      (nixpkgsArgs // { localSystem = { inherit system; }; }));
  };
}
