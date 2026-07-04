# geeqie — fast keyboard culler for the birding raws, with a one-key reject flow.
#
# geeqie shows CR3's embedded JPEG preview, so flipping is instant. The Delete
# key is repurposed (via geeqie's documented geeqie-delete-command override, see
# its org.geeqie.template.desktop) to "reject": advance to the next frame, then
# move the current CR3 (and any darktable .xmp sidecar) into a `rejected/`
# subfolder. Keepers are left untouched. Ctrl+Z un-rejects the last one. When a
# day's cull looks good, `rm -r <folder>/rejected`.
{ pkgs, ... }:
let
  cull-sort = pkgs.writeShellApplication {
    name = "cull-sort";
    runtimeInputs = [
      pkgs.geeqie # geeqie --next (remote advance)
      pkgs.coreutils
      pkgs.findutils
      pkgs.libnotify
    ];
    text = ''
      # cull-sort rejected <file>   reject the frame (move to ./rejected/)
      # cull-sort undo     <file>   restore the most-recently-rejected frame
      bucket=$1
      file=$2
      dir=$(dirname -- "$file")

      if [ "$bucket" = undo ]; then
        rej="$dir/rejected"
        # newest non-sidecar file in rejected/
        last=$(find "$rej" -maxdepth 1 -type f ! -name '*.xmp' -printf '%T@\t%p\n' 2>/dev/null \
          | sort -rn | head -1 | cut -f2- || true)
        if [ -n "$last" ]; then
          mv -n -- "$last" "$dir"/
          if [ -e "$last.xmp" ]; then mv -n -- "$last.xmp" "$dir"/; fi
          notify-send -a cull "Cull" "Un-rejected $(basename -- "$last")  —  press ← to view"
        else
          notify-send -a cull "Cull" "Nothing to un-reject"
        fi
        exit 0
      fi

      # Reject: advance FIRST so the frame leaves the screen and geeqie's folder
      # monitor can't double-advance, THEN move the (no-longer-current) file out.
      # mv within the same NAS mount is an instant server-side rename.
      geeqie --next >/dev/null 2>&1 || true
      dest="$dir/$bucket"
      mkdir -p -- "$dest"
      mv -n -- "$file" "$dest"/
      # darktable writes "<name>.CR3.xmp" next to the raw — take it along.
      if [ -e "$file.xmp" ]; then mv -n -- "$file.xmp" "$dest"/; fi
    '';
  };
in
{
  home.packages = [
    pkgs.geeqie
    cull-sort
  ];

  # Repurpose geeqie's Delete key as "reject". A desktop file named exactly
  # geeqie-delete-command.desktop replaces geeqie's built-in delete, so Delete
  # runs our command — no key-binding conflict, no trash dialog. geeqie must be
  # restarted to register a newly-added plugin.
  xdg.configFile."geeqie/applications/geeqie-delete-command.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=Cull: Reject (move to rejected/)
    Exec=${cull-sort}/bin/cull-sort rejected %f
    Icon=gtk-delete
    Categories=X-Geeqie;Graphics;
    OnlyShowIn=X-Geeqie;
  '';

  # Un-reject the last frame, bound to Ctrl+Z via the plugin's own hotkey field
  # (a chord that geeqie doesn't use by default, so no conflict).
  xdg.configFile."geeqie/applications/cull-undo.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=Cull: Un-reject last
    Exec=${cull-sort}/bin/cull-sort undo %f
    Icon=gtk-undo
    Categories=X-Geeqie;Graphics;
    OnlyShowIn=X-Geeqie;
    X-Geeqie-Menu-Path=FileMenu/FileOpsSection
    X-Geeqie-Hotkey=<control>z
  '';
}
