/*
  Invokes the NixOS init system in the container.
 */
{ config, lib, pkgs, ... }:
let
  inherit (lib) types;
in
{
  options = {
    nixos.useSystemd = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        When enabled, call the NixOS systemd-based init system.

        Configure NixOS with the `nixos.configuration` option.
      '';
    };
    nixos.runWrappersUnsafe = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        When enabled, /run/wrappers is mounted with exec,suid attributs is considered UNSAFE within context.
      '';
    };
  };

  config = lib.mkIf (config.nixos.useSystemd) {
    nixos.configuration.imports = [
      ../nixos/container-systemd.nix
      ../nixos/default-shell.nix
      (pkgs.path + "/nixos/modules/profiles/minimal.nix")
    ];
    image.command = [ "${config.nixos.build.toplevel}/init" ];
    service.environment.container = "docker";
    service.environment.PATH = "/usr/bin:/run/current-system/sw/bin/";
    service.volumes = [
      "/sys/fs/cgroup:/sys/fs/cgroup:ro"
    ];
    service.tmpfs = [
      "/run"          # noexec is fine because exes should be symlinked from elsewhere anyway
      ("/run/wrappers" + (lib.optionalString (config.nixos.runWrappersUnsafe) ":exec,suid"))  # by default noexec breaks this intentionally and no suid
    ] ++ lib.optional (config.nixos.evaluatedConfig.boot.tmpOnTmpfs) "/tmp:exec,mode=777";

    service.stop_signal = "SIGRTMIN+3";
    service.tty = true;
    service.defaultExec = [config.nixos.build.x-arion-defaultShell "-l"];
  };
}
