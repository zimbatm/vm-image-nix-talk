{ lib, config, ... }:

let
  cfg = config.services.spa-app;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.services.spa-app = {
    enable = mkEnableOption "serving the SPA with nginx";

    package = mkOption {
      type = types.package;
      description = "Derivation containing the SPA static assets.";
      default = null;
      example = lib.literalExpression "spaPackage";
    };

    host = mkOption {
      type = types.str;
      default = "spa.local";
      description = "Hostname used for the nginx virtual host.";
      example = "example.org";
    };

    port = mkOption {
      type = types.int;
      default = 80;
      description = "TCP port nginx listens on for the SPA.";
      example = 8080;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.spa-app.package must be set when enabling services.spa-app.";
      }
    ];

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      virtualHosts."${cfg.host}" = {
        default = true;
        root = cfg.package;
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
      };
    };
  };
}
