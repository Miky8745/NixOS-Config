{ ... }:

{
  xdg.configFile."waybar/scripts/clock.py" = {
    executable = true;
    text = ''
      #!/usr/bin/env python3
      # Drives custom/clock. A plain "clock" module can't show a second,
      # independent timezone in its tooltip-format (its placeholders all
      # read from the module's own single configured timezone), so UTC is
      # computed here and appended below the calendar instead.
      import calendar
      import json
      from datetime import datetime, timezone


      def build_calendar(now):
          cal = calendar.TextCalendar(firstweekday=0)
          lines = [cal.formatweekheader(2)]
          for week in cal.monthdayscalendar(now.year, now.month):
              cells = []
              for day in week:
                  if day == 0:
                      cells.append("  ")
                  elif day == now.day:
                      cells.append(f"<b>{day:2d}</b>")
                  else:
                      cells.append(f"{day:2d}")
              lines.append(" ".join(cells))
          return "\n".join(lines)


      def main():
          now = datetime.now()
          utc_now = datetime.now(timezone.utc)

          text = now.strftime("%a; %d %b, %H:%M")
          tooltip = (
              f"<big>{now.strftime('%Y %B')}</big>\n"
              f"<tt><small>{build_calendar(now)}</small></tt>\n"
              f"UTC: {utc_now.strftime('%H:%M:%S')}"
          )

          print(json.dumps({"text": text, "tooltip": tooltip}))


      if __name__ == "__main__":
          main()
    '';
  };
}
