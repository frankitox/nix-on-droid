# Copyright (c) 2019-2026, see AUTHORS. Licensed under MIT License, see LICENSE.

# Parts from nixpkgs/nixos/modules/programs/gnupg.nix
# MIT Licensed. Copyright (c) 2003-2026 Eelco Dolstra and the Nixpkgs/NixOS contributors

{ pkgs, lib, config, ... }:
let
  inherit (lib) types;

  cfg = config.programs.gnupg;

  agentSettingsFormat = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } " ";
  };
in {
  options = {
    programs.gnupg = {
      package = lib.mkOption {
        description = ''
          The GnuPG package to use.
        '';
        type = types.package;
        default = pkgs.gnupg;
        defaultText = lib.literalExpression "pkgs.gnupg";
      };

      agent.enable = lib.mkOption {
        description = ''
          Whether to enable the GnuPG agent, which caches passphrases and
          can optionally act as an SSH agent.

          Unlike NixOS, Nix-on-Droid has no systemd to socket-activate the
          agent on demand, so it is instead launched from every new login
          shell via {option}`environment.extraInit` using
          `gpgconf --launch`, which is a no-op if an agent is already
          running.
        '';
        type = types.bool;
        default = false;
      };

      agent.enableSSHSupport = lib.mkOption {
        description = ''
          Enable SSH agent support in GnuPG agent. Also sets `SSH_AUTH_SOCK`
          for new login shells, if it isn't already set.
        '';
        type = types.bool;
        default = false;
      };

      agent.pinentryPackage = lib.mkOption {
        description = ''
          Which pinentry package to use. The path to the `mainProgram` as
          defined in the package's meta attributes will be set in
          {file}`/etc/gnupg/gpg-agent.conf`.

          Most graphical pinentry flavors won't work inside of the proot
          environment Nix-on-Droid runs in, so, unlike NixOS, this defaults
          to the terminal-based {var}`pinentry-curses` rather than picking
          a flavor based on the desktop environment.
        '';
        type = types.nullOr types.package;
        default = pkgs.pinentry-curses;
        defaultText = lib.literalExpression "pkgs.pinentry-curses";
        example = lib.literalExpression "pkgs.pinentry-tty";
      };

      agent.settings = lib.mkOption {
        description = ''
          Configuration for {file}`/etc/gnupg/gpg-agent.conf`.
          See {manpage}`gpg-agent(1)` for supported options.
        '';
        type = agentSettingsFormat.type;
        default = { };
        example = { default-cache-ttl = 600; };
      };
    };
  };

  config = lib.mkIf cfg.agent.enable {
    programs.gnupg.agent.settings = lib.mkIf (cfg.agent.pinentryPackage != null) {
      pinentry-program = lib.getExe cfg.agent.pinentryPackage;
    };

    environment.etc."gnupg/gpg-agent.conf".source =
      agentSettingsFormat.generate "gpg-agent.conf" cfg.agent.settings;

    environment.packages = [ cfg.package ];

    environment.extraInit = ''
      # Bind gpg-agent to this TTY if gpg commands are used.
      export GPG_TTY=$(tty)

      # GnuPG doesn't create its homedir itself; it just fails when it's
      # missing. On NixOS this never comes up because the agent socket
      # lives under systemd's $XDG_RUNTIME_DIR, which always exists. We
      # have neither, so GnuPG falls back to ~/.gnupg, which needs to
      # exist up front.
      mkdir -p -m 0700 "$HOME/.gnupg"

      # gpg-agent auto-starts itself for GnuPG clients, but ssh doesn't know
      # how to do that, so make sure an agent is running before anything
      # tries to use SSH_AUTH_SOCK below. This is a no-op if one is already
      # running.
      ${cfg.package}/bin/gpgconf --launch gpg-agent

      ${lib.optionalString cfg.agent.enableSSHSupport ''
        if [ -z "$SSH_AUTH_SOCK" ]; then
          export SSH_AUTH_SOCK="$(${cfg.package}/bin/gpgconf --list-dirs agent-ssh-socket)"
        fi
      ''}
    '';
  };
}
