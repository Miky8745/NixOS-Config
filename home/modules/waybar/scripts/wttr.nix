{ ... }:

{
  xdg.configFile."waybar/scripts/wttr.py" = {
    executable = true;
    text = ''
      #!/usr/bin/env python3
      import json
      import urllib.request

      # wttr.in weatherCode -> Nerd Font weather-icons glyph (codepoints verified
      # against nerd-fonts' glyphnames.json "weather-*" entries). Codes are
      # World Weather Online condition codes, which is what wttr.in's j1 format
      # reports in current_condition[0]["weatherCode"] / weather[n]["hourly"][n]
      # ["weatherCode"].
      ICONS = {
          113: "\ue30d",  # Sunny / Clear
          116: "\ue302",  # Partly cloudy
          119: "\ue312",  # Cloudy
          122: "\ue33d",  # Overcast
          143: "\ue303",  # Mist
          176: "\ue309",  # Patchy rain possible
          179: "\ue30a",  # Patchy snow possible
          182: "\ue3ad",  # Patchy sleet possible
          185: "\ue316",  # Patchy freezing drizzle possible
          200: "\ue30f",  # Thundery outbreaks possible
          227: "\ue31a",  # Blowing snow
          230: "\ue31a",  # Blizzard
          248: "\ue313",  # Fog
          260: "\ue313",  # Freezing fog
          263: "\ue30b",  # Patchy light drizzle
          266: "\ue31b",  # Light drizzle
          281: "\ue316",  # Freezing drizzle
          284: "\ue316",  # Heavy freezing drizzle
          293: "\ue309",  # Patchy light rain
          296: "\ue318",  # Light rain
          299: "\ue318",  # Moderate rain at times
          302: "\ue318",  # Moderate rain
          305: "\ue318",  # Heavy rain at times
          308: "\ue318",  # Heavy rain
          311: "\ue3ad",  # Light freezing rain
          314: "\ue3ad",  # Moderate/heavy freezing rain
          317: "\ue3ad",  # Light sleet
          320: "\ue3ad",  # Moderate/heavy sleet
          323: "\ue30a",  # Patchy light snow
          326: "\ue31a",  # Light snow
          329: "\ue31a",  # Patchy moderate snow
          332: "\ue31a",  # Moderate snow
          335: "\ue31a",  # Patchy heavy snow
          338: "\ue31a",  # Heavy snow
          350: "\ue314",  # Ice pellets
          353: "\ue319",  # Light rain shower
          356: "\ue319",  # Moderate/heavy rain shower
          359: "\ue319",  # Torrential rain shower
          362: "\ue3ad",  # Light sleet showers
          365: "\ue3ad",  # Moderate/heavy sleet showers
          368: "\ue31a",  # Light snow showers
          371: "\ue31a",  # Moderate/heavy snow showers
          374: "\ue314",  # Light showers of ice pellets
          377: "\ue314",  # Moderate/heavy showers of ice pellets
          386: "\ue31d",  # Patchy light rain with thunder
          389: "\ue31d",  # Moderate/heavy rain with thunder
          392: "\ue31d",  # Patchy light snow with thunder
          395: "\ue31d",  # Moderate/heavy snow with thunder
      }
      DEFAULT_ICON = "\ue33d"


      def fetch(url):
          req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
          with urllib.request.urlopen(req, timeout=10) as resp:
              return json.load(resp)


      def main():
          try:
              data = fetch("https://wttr.in/?format=j1")
              current = data["current_condition"][0]
              temp_c = current["temp_C"]
              code = int(current["weatherCode"])
              icon = ICONS.get(code, DEFAULT_ICON)

              lines = [f"Now: {current['weatherDesc'][0]['value']}, {temp_c}\u00b0C"]
              for day in data["weather"][:3]:
                  midday = day["hourly"][4]  # ~12:00 entry
                  desc = midday["weatherDesc"][0]["value"]
                  lines.append(
                      f"{day['date']}: {desc}, {day['mintempC']}\u2013{day['maxtempC']}\u00b0C"
                  )

              print(json.dumps({
                  "text": f"{icon} {temp_c}\u00b0C",
                  "tooltip": "\n".join(lines),
              }))
          except Exception as exc:
              print(json.dumps({
                  "text": f"{DEFAULT_ICON} ?",
                  "tooltip": f"weather unavailable: {exc}",
              }))


      if __name__ == "__main__":
          main()
    '';
  };
}
