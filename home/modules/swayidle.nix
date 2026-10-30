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
  # unlock. Relevant to every call site below that still uses this
  # (idle-timeout, after-resume) - before-sleep stopped using it entirely,
  # see that event's own comment for why.
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
      # Deliberately NOT lockCmd. Traced the real suspend-hang root cause
      # to here: qylock's "enfield" theme decodes and plays an mp4
      # background video via Qt Multimedia/ffmpeg on launch, and that GPU
      # work was still in flight when the actual kernel suspend call froze
      # the GPU mid-commit (confirmed against an older commit, from before
      # a pgrep matching bug was fixed - back when this call was
      # accidentally a no-op, suspend never hung at all). No amount of
      # waiting fixes this; the only thing that can't race the kernel
      # suspend call is doing no GPU work here at all. Blanking the
      # outputs is instant (no decode, no scene load) and after-resume
      # below already re-asserts the real lock as soon as the screen comes
      # back on, so the screen is never left actually unlocked - just
      # briefly not-yet-relocked while the display itself is still off.
      before-sleep = "${pkgs.niri}/bin/niri msg action power-off-monitors";
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
