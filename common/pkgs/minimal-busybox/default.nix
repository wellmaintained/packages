# Minimal BusyBox with only the applets our container images need.
#
# Full busybox ships ~300 applets (tar, wget, netstat, etc.) which
# introduce CVEs in code paths we never use. This build compiles out
# everything except basic file operations and shell scripting essentials.
#
# Eliminates at source:
#   - CVE-2024-58251 (netstat — ANSI escape DoS)
#   - CVE-2025-46394 (tar — filename hiding via escape sequences)
#   - CVE-2025-60876 (wget — HTTP request smuggling)
{ pkgs }:

pkgs.busybox.override {
  enableMinimal = true;
  extraConfig = ''
    # Shell (ash) — needed for /bin/sh and script execution
    CONFIG_ASH y
    CONFIG_ASH_ECHO y
    CONFIG_ASH_TEST y
    CONFIG_ASH_OPTIMIZE_FOR_SIZE y

    # File operations — the reason busybox is in our images
    CONFIG_MKDIR y
    CONFIG_CHMOD y
    CONFIG_CHOWN y
    CONFIG_CP y
    CONFIG_LN y
    CONFIG_MV y
    CONFIG_RM y
    CONFIG_RMDIR y
    CONFIG_TOUCH y
    CONFIG_CAT y
    CONFIG_LS y
    CONFIG_STAT y

    # Script essentials — needed by entrypoint and init scripts
    CONFIG_ECHO y
    CONFIG_TEST y
    CONFIG_TRUE y
    CONFIG_FALSE y
    CONFIG_SLEEP y
    CONFIG_ENV y
    CONFIG_ID y
    CONFIG_BASENAME y
    CONFIG_DIRNAME y
    CONFIG_HEAD y
    CONFIG_TAIL y
    CONFIG_WC y
    CONFIG_SEQ y
    CONFIG_YES y
  '';
}
