{ ... }:

{
  programs.waybar.style = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font Mono";
      font-weight: bold;
      font-size: 13px;
      min-height: 20px;
    }

    window#waybar {
      background: transparent;
    }

    window#waybar.hidden {
      opacity: 0.2;
    }

    #workspaces {
      margin-right: 8px;
      border-radius: 10px;
      transition: none;
      background: rgba(56, 60, 74, 0.8);
    }

    #workspaces button {
      transition: none;
      color: #7c818c;
      background: transparent;
      padding: 5px 10px;
      font-size: 16px;
    }

    #workspaces button:hover {
      transition: none;
      box-shadow: inherit;
      text-shadow: inherit;
      border-radius: inherit;
      color: #383c4a;
      background: rgba(124, 129, 140, 0.8);
    }

    #workspaces button.active {
      background: rgba(78, 82, 99, 0.8);
      color: white;
      border-radius: inherit;
    }

    #language {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #window {
      padding: 0 16px;
      border-radius: 10px;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #custom-clock {
      padding: 0 16px;
      border-radius: 10px 0px 0px 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #custom-weather {
      padding: 0 16px;
      border-radius: 0px 10px 10px 0px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #network {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #custom-notification {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    /* Joined pill, same two-half pattern as #custom-clock/#custom-weather. */
    #custom-media-pause {
      padding: 0 14px;
      border-radius: 10px 0px 0px 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #custom-media-next {
      margin-right: 8px;
      padding: 0 14px;
      border-radius: 0px 10px 10px 0px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #pulseaudio {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #pulseaudio.muted {
      background-color: rgba(144, 177, 177, 0.8);
      color: #2a5c45;
    }

    #memory {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #cpu {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #tray {
      margin-right: 8px;
      padding: 0 16px;
      border-radius: 10px;
      transition: none;
      color: #ffffff;
      background: rgba(56, 60, 74, 0.8);
    }

    #custom-power {
      padding: 0 18px;
      border-radius: 10px;
      transition: none;
      font-size: 16px;
      color: #1a1a1a;
      background: rgba(255, 108, 108, 0.8);
    }

    #custom-power:hover {
      background: rgba(255, 108, 108, 1);
    }
  '';
}
