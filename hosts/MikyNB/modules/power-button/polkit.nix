{ ... }:

{
  # wlogout's suspend/reboot/shutdown buttons call plain `systemctl
  # suspend/reboot/poweroff`, authorized by polkit's default
  # org.freedesktop.login1.* rules - which auto-allow those actions only
  # when the calling process belongs to the *active, local* session.
  # When wlogout is opened by power-button-menu above, `runuser -u
  # miky8745` opens a brand-new PAM/logind session just to host it - the
  # real niri session (started at login) stays the one marked active on
  # the seat, so that new session fails the active-session check and
  # polkit falls back to requiring interactive authentication, which
  # nothing here can satisfy. Result: wlogout's UI responds fine (that's
  # just GTK, no privilege involved) but Suspend/Restart/Shut Down are
  # silently denied - confirmed via `journalctl -u power-button-menu`:
  # "Call to Suspend failed: Access denied as the requested operation
  # requires interactive authentication." (lock/cancel aren't affected;
  # neither goes through logind/polkit.) Dropping the active-session
  # requirement for this one local user is reasonable here: the only way
  # this service's wlogout instance ever opens is a physical power-button
  # press, which already implies physical access.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user == "miky8745" &&
          (action.id == "org.freedesktop.login1.suspend" ||
           action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions")) {
        return polkit.Result.YES;
      }
    });
  '';
}
