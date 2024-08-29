{
  description = "Ekiree Nix-Django Framework";

  inputs = {
    # Nix Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";

    #poetry2nix
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Setting up nix2poetry
      inherit
        (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;})
        mkPoetryApplication
        mkPoetryEnv
        defaultPoetryOverrides
        ;

      # Configure production python application with poetry2nix
      poetryProd = mkPoetryApplication {
        projectDir = self;
        overrides = p2n-overrides;
      };

      # Configure development python environment with poetry2nix
      poetryDev = mkPoetryEnv {
        projectDir = self;
        overrides = p2n-overrides;
      };

      # Configure build dependencies for individual python packages
      pypkgs-build-requirements = {
        django-localflavor = ["setuptools"];
        sphinx-press-theme = ["setuptools"];
        django-libsql = ["setuptools"];
        libsql-client = ["poetry"];
      };
      p2n-overrides = defaultPoetryOverrides.extend (
        self: super:
          builtins.mapAttrs (
            package: build-requirements:
              (builtins.getAttr package super).overridePythonAttrs (old: {
                buildInputs =
                  (old.buildInputs or [])
                  ++ (builtins.map (pkg:
                    if builtins.isString pkg
                    then builtins.getAttr pkg super
                    else pkg)
                  build-requirements);
              })
          )
          pypkgs-build-requirements
      );
    in {
      # Production Application Package
      packages.default = poetryProd.dependencyEnv;

      # Development shell
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.poetry
          pkgs.jq
          pkgs.sops
          poetryDev
        ];

        # Command run upon shell start
        shellHook = ''
          export SECRET_KEY=$(sops  --decrypt ./secrets/secrets.json | jq -r .secret_key)
          export PRODUCTION=$(sops  --decrypt ./secrets/secrets.json | jq -r .production)
          export DB_PROVIDER=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_provider)
          export DB_NAME=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_name)
          export DB_USER=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_user)
          export DB_HOST=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_host)
          export DB_PASSWORD=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_password)
          export DB_HOST=$(sops  --decrypt ./secrets/secrets.json | jq -r .db_host)
          export STATIC=$(sops  --decrypt ./secrets/secrets.json | jq -r .static)
          export USE_CLOUD_MEDIA=$(sops  --decrypt ./secrets/secrets.json | jq -r .use_cloud_media)
          export MEDIA=$(sops  --decrypt ./secrets/secrets.json | jq -r .media)
          export EMAIL_HOST=$(sops  --decrypt ./secrets/secrets.json | jq -r .email_host)
          export EMAIL_USER=$(sops  --decrypt ./secrets/secrets.json | jq -r .email_user)
          export EMAIL_PASSWORD=$(sops  --decrypt ./secrets/secrets.json | jq -r .email_password)

          export PS1="\n(develop)\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
        '';
      };
    });
}
