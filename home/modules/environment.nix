# Environment (loaded by every zsh via ~/.zshenv)
{
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/Android/Sdk/cmdline-tools/latest/bin"
    "$HOME/Android/Sdk/platform-tools"
    "$HOME/.lmstudio/bin"
  ];

  home.sessionVariables = {
    ANDROID_HOME = "$HOME/Android/Sdk";
    ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
    ANDROID_AVD_HOME = "$HOME/VMs/android-avd"; # emulator images on the no-CoW VMs subvolume
    ROS_DISTRO = "jazzy";

    # Haruna + DaVinci
    QT_QPA_PLATFORM = "xcb";
    QT_OPENGL = "desktop";

    # Disable VA-API, force NVIDIA GLX
    LIBVA_DRIVER_NAME = "dummy";
    VDPAU_DRIVER = "dummy";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
