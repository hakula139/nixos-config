# ==================================================================================================
# T3 Code Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  isDesktop,
  secretPath,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;

  cfg = config.hakula.t3code;
  shared = config.lib.llmAssistants;
  homeDir = config.home.homeDirectory;
  baseDir = "${homeDir}/.t3";
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.t3code = {
    enable = lib.mkEnableOption "T3 Code";
    lan = lib.mkEnableOption "serving the LAN and tailnet instead of only loopback";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf (config.hakula.llm-assistants.enable && cfg.enable) (
    let
      enableCorpGateway = config.hakula.llm-assistants.auth.enableCorpGateway;
      corpGateway = shared.profileDefinitions.providers.corp-gateway;
      caFile = secretPath corpGateway.caSecret;

      proxyCfg = config.hakula.llm-assistants.proxy;

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      # The agent CLIs, git, gh, and glab come from the Home Manager profile, since the nixpkgs
      # wrapper's own PATH entries would shadow them.
      upstreamPkg = pkgs.unstable.t3code.override {
        enableClaude = false;
        enableCodex = false;
        enableGit = false;
        enableGitHub = false;
        enableGitLab = false;
      };

      runtimePath = lib.makeBinPath [
        config.home.profileDirectory
        pkgs.coreutils
      ];

      baseWrapArgs = [
        "--prefix"
        "PATH"
        ":"
        runtimePath
      ]
      ++ repoLib.proxy.mkProxyWrapArgs proxyCfg;

      # Electron cancels fetch when NODE_USE_ENV_PROXY=1 is set, so only the CLI server exports it.
      cliWrapArgs =
        baseWrapArgs
        ++ lib.optionals proxyCfg.enable [
          "--run"
          repoLib.proxy.nodeProxyScript
        ];

      envVars = lib.optionalAttrs enableCorpGateway {
        NODE_EXTRA_CA_CERTS = caFile;
      };

      t3CliPkg = repoLib.wrapPackage {
        inherit pkgs envVars;
        wrapArgs = cliWrapArgs;
        pkg = upstreamPkg;
        name = "t3code-cli-${upstreamPkg.version}";
        bin = "t3";
      };

      t3DesktopPkg = repoLib.wrapPackage {
        inherit pkgs envVars;
        wrapArgs = baseWrapArgs;
        pkg = t3CliPkg;
        name = "t3code-${upstreamPkg.version}";
        bin = "t3code-desktop";
      };

      # Headless hosts expose only the CLI, leaving the Electron app off PATH and out of menus.
      t3HeadlessPkg = pkgs.runCommandLocal t3CliPkg.name { meta.mainProgram = "t3"; } ''
        mkdir --parents "$out/bin"
        ln --symbolic ${lib.getExe t3CliPkg} "$out/bin/t3"
      '';

      t3Bin = lib.getExe t3CliPkg;

      # --------------------------------------------------------------------------------------------
      # Config activation
      # --------------------------------------------------------------------------------------------
      managedSettings = {
        defaultRuntimeMode = "auto";
        pullRequestMergeMethod = "squash";
      };

      managedProviderInstances = {
        claudeAgent = {
          driver = "claudeAgent";
          enabled = true;
          config = {
            binaryPath = "claude";
          };
        };

        codex = {
          driver = "codex";
          enabled = true;
          config = {
            binaryPath = "codex";
          };
        };

        omp = {
          driver = "acpRegistry";
          displayName = "Oh My Pi";
          enabled = true;
          config = {
            source = "local";
            agentId = "";
            commandPath = "omp";
            commandArgs = [
              "acp"
            ];
          };
        };
      };

      activateConfig = repoLib.mkNuCommand {
        inherit pkgs;
        name = "activate-t3code-config";
        script = ./scripts/activate-config.nu;
        runtimeInputs = [ pkgs.coreutils ];

        config = {
          inherit baseDir;
          defaults = managedSettings;
          providerInstances = managedProviderInstances;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Background service
      # --------------------------------------------------------------------------------------------
      serveArgs = [
        t3Bin
        "serve"
      ]
      ++ lib.optionals cfg.lan [ "--lan" ];
    in
    lib.mkMerge [
      {
        # ------------------------------------------------------------------------------------------
        # Secrets
        # ------------------------------------------------------------------------------------------
        hakula.secrets.required = lib.optionalAttrs enableCorpGateway {
          ${corpGateway.caSecret} = { };
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        home.packages = [
          (if isDesktop then t3DesktopPkg else t3HeadlessPkg)
        ];

        # ------------------------------------------------------------------------------------------
        # Activation
        # ------------------------------------------------------------------------------------------
        home.activation.t3codeMutableConfig =
          lib.hm.dag.entryBetween [ "reloadSystemd" "setupLaunchAgents" ] [ "writeBoundary" ]
            ''
              run ${lib.getExe activateConfig}
            '';
      }

      (lib.mkIf (isDesktop && !isDarwin) {
        # ------------------------------------------------------------------------------------------
        # Systemd services (Linux)
        # ------------------------------------------------------------------------------------------
        systemd.user.services.t3code-serve = {
          Unit = {
            Description = "T3 Code headless agent control plane";
          }
          // repoLib.systemd.restartLimit;

          Service = {
            Environment = [
              "T3CODE_HOME=${baseDir}"
            ];
            ExecStart = lib.escapeShellArgs serveArgs;
            # `t3 serve` prints a one-time pairing token on every start, so keep stdout out of the
            # journal and pair through `t3 pair`.
            StandardOutput = "null";
            # Without earlyoom's DefaultOOMPolicy=continue, as on wsl-non-nixos, a kill of one agent
            # process would stop the whole unit.
            OOMPolicy = "continue";
          }
          // repoLib.systemd.restart;

          Install = {
            WantedBy = [
              "default.target"
            ];
          };
        };
      })

      (lib.mkIf (isDesktop && isDarwin) {
        # ------------------------------------------------------------------------------------------
        # Launchd agents (macOS)
        # ------------------------------------------------------------------------------------------
        launchd.agents.t3code-serve = {
          enable = true;
          config = {
            Label = "com.hakula.t3code";
            ProgramArguments = serveArgs;
            WorkingDirectory = homeDir;
            EnvironmentVariables = {
              T3CODE_HOME = baseDir;
            };
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 5;
            StandardOutPath = "/dev/null";
            StandardErrorPath = "${homeDir}/Library/Logs/t3code-serve.log";
          };
        };
      })
    ]
  );
}
