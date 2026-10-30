# Default apps per MIME type. Without this, GTK/KDE pick whatever last
# registered itself (or whatever was clicked "open with" once) and persist
# it mutably in ~/.config/mimeapps.list - not reproducible across rebuilds.
{ ... }:

let
  papers = "org.gnome.Papers.desktop";
  loupe = "org.gnome.Loupe.desktop";
  fileRoller = "org.gnome.FileRoller.desktop";
  vlc = "vlc.desktop";
  vivaldi = "vivaldi-stable.desktop";
  dolphin = "org.kde.dolphin.desktop";
in
{
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "inode/directory" = dolphin;

      # Vivaldi also claims application/pdf; Papers wins explicitly.
      "application/pdf" = papers;
      "application/x-cbr" = papers;
      "application/x-cbz" = papers;
      "image/vnd.djvu" = papers;

      "image/png" = loupe;
      "image/jpeg" = loupe;
      "image/gif" = loupe;
      "image/bmp" = loupe;
      "image/webp" = loupe;
      "image/tiff" = loupe;
      "image/svg+xml" = loupe;
      "image/heic" = loupe;
      "image/avif" = loupe;

      "application/zip" = fileRoller;
      "application/x-7z-compressed" = fileRoller;
      "application/x-rar" = fileRoller;
      "application/vnd.rar" = fileRoller;
      "application/x-tar" = fileRoller;
      "application/gzip" = fileRoller;
      "application/x-bzip" = fileRoller;
      "application/x-bzip2" = fileRoller;
      "application/x-xz" = fileRoller;
      "application/x-zstd-compressed-tar" = fileRoller;

      "video/mp4" = vlc;
      "video/x-matroska" = vlc;
      "video/webm" = vlc;
      "video/quicktime" = vlc;
      "video/mpeg" = vlc;
      "video/x-msvideo" = vlc;
      "video/x-ms-wmv" = vlc;
      "audio/mpeg" = vlc;
      "audio/mp4" = vlc;
      "audio/flac" = vlc;
      "audio/ogg" = vlc;
      "audio/x-wav" = vlc;
      "audio/wav" = vlc;

      "text/html" = vivaldi;
      "x-scheme-handler/http" = vivaldi;
      "x-scheme-handler/https" = vivaldi;
    };
  };
}
