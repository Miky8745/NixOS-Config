# Idle handling that Plasma's powerdevil used to provide: lock the session
# after inactivity, then turn the screens off, and always lock before suspend.
{ pkgs, ... }:

let
  # Guard against stacking a second lock surface if this fires while already
  # locked (e.g. idle timeout right after a manual lock). Must match by
  # process name (-x quickshell), not full command line (-f) - this
  # swayidle process's own argv contains the literal text "lock_shell.qml"
  # (it's quoting this very lockCmd as its own command argument), so `-f`
  # would match swayidle itself and always skip qylock-lock. See niri.nix
  # for the detailed story and why QT_QPA_PLATFORM is forced here
  # (environment.nix's xcb override otherwise breaks Quickshell's
  # session-lock protocol support).
  #
  # Must also actually return once the lock is up, rather than exec'ing
  # straight into the persistent lock daemon the way qylock-lock's own
  # wrapper does (that *is* the lock screen, by design running until you
  # unlock) - swayidle's unit uses `-w` (wait for command to finish), a
  # single-threaded wait, so any invocation that never returns wedges
  # swayidle's whole event loop, including its D-Bus listening, until
  # unlock. Concretely this broke suspend: before-sleep held logind's
  # delay-lock inhibitor open via exactly this never-returning command,
  # Quickshell finished loading in ~1s but the command still hadn't
  # returned 14s later when logind's InhibitDelayMaxSec gave up and forced
  # suspend through anyway - mid-render, with no synchronization - which is
  # what the kernel then hung on (repeated nvidia-drm "Flip event timeout",
  # full hard-reset-required hang). Backgrounding the launch and waiting
  # for the process to actually start (then a short settle) instead lets
  # every call site here finish on its own terms, so logind/swayidle only
  # ever proceed because this command voluntarily let go.
  #
  # qylock-lock by absolute path - see niri.nix's copy of this lockCmd for
  # why (not a PATH-reliant call: isn't a nix package exposed via `pkgs`,
  # and gets reused from PATH-less contexts elsewhere too).
  # Everything below is by absolute path, not relying on PATH at all - the
  # swayidle unit's Environment=PATH only has bash-interactive's own bin dir
  # (no coreutils), confirmed the hard way: a first version of this used
  # bare `seq`/`sleep`, which both failed with "command not found", so the
  # wait loop below did nothing and the command returned instantly anyway -
  # no safer than the original bug.
  lockCmd = "${pkgs.procps}/bin/pgrep -x quickshell >/dev/null || "
    + "{ QT_QPA_PLATFORM=wayland /run/current-system/sw/bin/qylock-lock & "
    + "i=0; while [ \"$i\" -lt 50 ] && ! ${pkgs.procps}/bin/pgrep -x quickshell >/dev/null; "
    + "do ${pkgs.coreutils}/bin/sleep 0.1; i=$((i + 1)); done; "
    + "${pkgs.coreutils}/bin/sleep 2; }";
in
{
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = lockCmd; }
      { timeout = 600; command = "${pkgs.niri}/bin/niri msg action power-off-monitors"; }
    ];
    events = {
      before-sleep = lockCmd;
      # Without this, resuming from suspend can leave the outputs in
      # whatever DPMS state they were last in instead of actually waking
      # up, so the (correctly locked) screen just stays dark/unresponsive.
      # Force the monitors back on and re-assert the lock (idempotent via
      # the pgrep guard, in case the lock surface itself didn't survive
      # the suspend/resume cycle) every time the system wakes up.
      after-resume = "${pkgs.niri}/bin/niri msg action power-on-monitors && " + lockCmd;
    };
  };
}
