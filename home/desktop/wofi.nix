{
  # Wofi — app launcher with Gruvbox dark theme.
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun"; # desktop apps only; swap for "run" to include $PATH binaries
      prompt = "Search...";
      filter_rate = 100; # debounce ms
      allow_markup = true; # pango markup in app names
      insensitive = true; # case-insensitive search
      allow_images = true; # show app icons
      image_size = 36;
      no_actions = true; # hide secondary actions (e.g. "New Window")
      term = "kitty"; # terminal used to launch terminal apps
      gtk_dark = true;
    };
    style = ''
      /* Gruvbox dark palette */
      /* bg shades:  #1d2021  #282828  #3c3836  #504945  #665c54  #7c6f64 */
      /* fg:         #ebdbb2  #d5c4a1  #bdae93                             */
      /* accents:    yellow #d79921  orange #d65d0e  blue #458588          */
      /*             bright-yellow #fabd2f  bright-orange #fe8019          */

      window {
        background-color: #1d2021;
        border:           2px solid #504945;
        border-radius:    10px;
        font-family:      "MesloLGS Nerd Font", monospace;
        font-size:        14px;
        color:            #ebdbb2;
      }

      /* Search input */
      #input {
        background-color: #3c3836;
        color:            #ebdbb2;
        border:           1px solid #504945;
        border-radius:    6px;
        padding:          8px 12px;
        margin:           8px;
        caret-color:      #fabd2f;
      }
      #input:focus {
        border-color:     #d79921;
        outline:          none;
      }

      /* Scroll area + entry list */
      #scroll {
        margin: 0 8px 8px 8px;
      }
      #inner-box {
        background-color: transparent;
      }
      #outer-box {
        background-color: transparent;
        padding:          4px;
      }

      /* Individual entries */
      #entry {
        background-color: transparent;
        border-radius:    6px;
        padding:          6px 10px;
        margin:           2px 0;
      }
      #entry:selected {
        background-color: #3c3836;
        border:           1px solid #d79921;
      }

      /* Entry text */
      #text {
        color:   #ebdbb2;
        margin:  0 8px;
      }
      #entry:selected #text {
        color:   #fabd2f;
      }

      /* App icons */
      #entry image {
        min-width:  36px;
        min-height: 36px;
      }
    '';
  };
}
