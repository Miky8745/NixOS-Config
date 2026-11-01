{ ... }:

{
  # Weekly run of the gh-bot Discord bot (~/Programming/gohigher/gh-bot).
  # bot.py isn't actually a long-running daemon despite being a
  # discord.py client: on_ready() does one _do_check() pass (scrape
  # podporatalentu.cz/sitport.cz/hackmania.cz, post anything new to
  # Discord) and then calls bot.close() itself - so a one-shot weekly
  # timer is the right shape, not a persistent service. launcher.py in
  # the same repo is Windows-only (registers a HKCU Run startup entry)
  # and isn't used here.
  #
  # WorkingDirectory has to be the repo root: bot.py opens state.json via
  # a bare relative path, and .env (DISCORD_TOKEN) is loaded by bot.py
  # itself from its own directory, so neither needs help from this unit
  # - but state.json does.
  systemd.services.gh-bot = {
    description = "Run the gh-bot Discord activity-announcer once";
    serviceConfig = {
      Type = "oneshot";
      User = "miky8745";
      WorkingDirectory = "/home/miky8745/Programming/gohigher/gh-bot";
      ExecStart = "/home/miky8745/Programming/gohigher/gh-bot/.venv/bin/python bot.py";
    };
  };

  systemd.timers.gh-bot = {
    description = "Weekly trigger for gh-bot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Midnight at the start of Sunday. Adjust the time-of-day here if a
      # different hour is wanted.
      OnCalendar = "Sun *-*-* 00:00:00";
      Persistent = true;
    };
  };
}
