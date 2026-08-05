{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.isolate;

  zfs = config.boot.zfs.package;

  templateType = types.submodule {
    options = {
      dataset = mkOption {
        type = types.str;
        example = "rpool/isolate/debisl";
        description = ''
          ZFS dataset of the template. The operator creates this dataset (and a
          snapshot) themselves; this module never touches ZFS at build time, so
          a rebuild succeeds even when the dataset does not exist yet.
        '';
      };
      count = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "Number of fresh clones to keep available.";
      };
      stateDir = mkOption {
        type = types.str;
        default = "/isolate";
        description = ''
          Directory holding the _fresh / _used / .signal-* bookkeeping files.
          Must be the parent of the dataset's mountpoint (isolate derives the
          signal file as <dirname mountpoint>/.signal-<basename dataset>).
        '';
      };
    };
  };

  # trigger-only oneshot: not wantedBy any target, so it never starts at boot.
  # It runs when the .path watcher fires, or when the operator starts it by
  # hand to populate the initial clones. The zfs-list ExecStartPre makes the
  # unit fail cleanly and early when the dataset has not been created yet.
  mkService = name: t: nameValuePair "isolate-regenerate-${name}" {
    description = "regenerate isolate clones for ${t.dataset}";
    path = [ zfs ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStartPre = "${zfs}/bin/zfs list ${t.dataset}";
      ExecStart = "${cfg.package}/bin/isolate -q -r ${t.dataset} ${toString t.count}";
    };
  };

  # the persistent watcher: enabled at boot, triggers the service when isolate
  # touches the signal file on sandbox exit. Watching a not-yet-existing file
  # is fine (systemd watches the nearest existing ancestor).
  mkPath = name: t: nameValuePair "isolate-regenerate-${name}" {
    description = "watch the isolate signal file for ${t.dataset}";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = "${t.stateDir}/.signal-${baseNameOf t.dataset}";
      Unit = "isolate-regenerate-${name}.service";
    };
  };
in
{
  ###### options #############################################################
  options.services.isolate = {
    enable = mkEnableOption "isolate: single-use ZFS-clone sandbox launcher and its clone-regeneration daemon";

    package = mkOption {
      type = types.package;
      default = pkgs.isolate;
      defaultText = literalExpression "pkgs.isolate";
      description = "The isolate package to use (expects the flake overlay to be applied).";
    };

    group = mkOption {
      type = types.str;
      default = "isolate";
      description = "Group whose members are allowed to use the ZFS features of isolate.";
    };

    templates = mkOption {
      type = types.attrsOf templateType;
      default = { };
      description = ''
        Templates to keep fresh clones for. One systemd path + oneshot service
        pair is generated per attribute, named isolate-regenerate-<name>.
      '';
      example = literalExpression ''
        {
          debisl = { dataset = "rpool/isolate/debisl"; count = 10; stateDir = "/isolate"; };
        }
      '';
    };
  };

  ###### implementation ######################################################
  config = mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    environment.systemPackages = [ cfg.package ];

    systemd.services = mapAttrs' mkService cfg.templates;
    systemd.paths = mapAttrs' mkPath cfg.templates;
  };
}
