# Default applications (xdg-open / "Open with" from yazi, Firefox, etc.).
#
# Without this, xdg-open picks whatever .desktop happens to claim a MIME type —
# which made darktable open every JPEG and the calibre ebook viewer every PDF.
# Lightweight viewers are the defaults; the heavy tools stay one keybind away
# (Mod+U darktable, Mod+Y geeqie) or in "Open with".
{ pkgs, ... }:
let
  assoc =
    app: types:
    builtins.listToAttrs (
      map (t: {
        name = t;
        value = app;
      }) types
    );

  images = [
    "image/jpeg"
    "image/png"
    "image/gif"
    "image/webp"
    "image/avif"
    "image/heic"
    "image/heif"
    "image/jxl"
    "image/tiff"
    "image/bmp"
    "image/svg+xml"
    "image/x-icon"
  ];
  # Camera raws open in geeqie (embedded-preview culler, ./geeqie.nix), not
  # darktable — editing is a deliberate step, not a double-click.
  raws = [
    "image/x-canon-cr3"
    "image/x-canon-cr2"
    "image/x-adobe-dng"
  ];
  videos = [
    "video/mp4"
    "video/x-matroska"
    "video/webm"
    "video/quicktime"
    "video/x-msvideo"
    "video/mpeg"
    "video/ogg"
  ];
  audio = [
    "audio/mpeg"
    "audio/flac"
    "audio/ogg"
    "audio/opus"
    "audio/wav"
    "audio/x-wav"
    "audio/mp4"
    "audio/aac"
  ];
  browser = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];
in
{
  home.packages = with pkgs; [
    loupe # image viewer (GTK4/Adwaita, follows prefer-dark)
    papers # PDF viewer (GTK4 successor to Evince)
    mpv # video/audio player
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      assoc "org.gnome.Loupe.desktop" images
      // assoc "org.geeqie.Geeqie.desktop" raws
      // assoc "mpv.desktop" (videos ++ audio)
      // assoc "org.gnome.Papers.desktop" [ "application/pdf" ]
      // assoc "firefox.desktop" browser
      // {
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
  };
  # ~/.config/mimeapps.list was previously written by apps at runtime; take it
  # over instead of aborting the switch on the existing file.
  xdg.configFile."mimeapps.list".force = true;
}
