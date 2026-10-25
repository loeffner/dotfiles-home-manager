# Mail: the Outlook.com account over IMAP with OAuth2 (Microsoft disabled
# password logins), synced into ~/Maildir and indexed by notmuch.
#
# Personal single-user machines only (imported by hosts/terra.nix). Never
# import it from common.nix, personal.nix or the work config: on a shared host
# the synced mail sits in $HOME and the token in a keyring others' admins can
# reach.
#
#   oama    — the Microsoft OAuth login. Keeps the refresh token in gnome-keyring
#             (unlocked by swaylock at login, see CLAUDE.md) and prints a fresh
#             access token on `oama access <address>`. One-time setup:
#             `oama authorize microsoft <address>` (browser login).
#   mbsync  — two-way IMAP <-> ~/Maildir sync (XOAUTH2), every 3 minutes via the
#             systemd timer; `notmuch new` indexes after each run (even a
#             failed one).
#   notmuch — the index the Quickshell mail panel reads
#             (desktop/shell/services/Mail.qml); its post-new hook pings the
#             panel and sends a notification for new unread mail.
# Sending and anything else the panel can't do happens in Outlook on the web
# (the panel's open-in-browser button).
{ pkgs, ... }:
let
  address = "andreas.loesel@outlook.com";
  # mbsync speaks XOAUTH2 only through the cyrus-sasl plugin (off by default).
  isync = pkgs.isync.override { withCyrusSaslXoauth2 = true; };
  oama = "${pkgs.oama}/bin/oama";
  notmuch = "${pkgs.notmuch}/bin/notmuch";
  jq = "${pkgs.jq}/bin/jq";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
in
{
  # jq + w3m: the shell's mail helper (desktop/shell/scripts/mail.sh).
  home.packages = [
    pkgs.oama
    pkgs.jq
    pkgs.w3m
  ];

  # Thunderbird's public Azure client ID (a public client: no secret). This
  # oama version waits on a localhost redirect, so it needs the browser
  # `authorize` endpoint; its default device-code endpoint never completes.
  xdg.configFile."oama/config.yaml".text = ''
    encryption:
      tag: KEYRING

    services:
      microsoft:
        client_id: 9e5f94bc-e8a4-4e73-b8be-63364c29d753
        auth_endpoint: https://login.microsoftonline.com/common/oauth2/v2.0/authorize
        auth_scope: https://outlook.office.com/IMAP.AccessAsUser.All
          https://outlook.office.com/SMTP.Send
          offline_access
        tenant: common
  '';

  accounts.email.accounts.outlook = {
    primary = true;
    inherit address;
    realName = "Andreas Lösel";
    flavor = "outlook.office365.com";
    passwordCommand = "${oama} access ${address}";
    folders.trash = "Deleted"; # Outlook's name; inbox/sent/drafts match the defaults

    mbsync = {
      enable = true;
      create = "both";
      expunge = "both";
      # A folder deleted on the server (webmail clean-up) is dropped locally
      # too. Never the other way round, and without it the stale local copy
      # fails every sync ("far side box … cannot be opened anymore").
      remove = "maildir";
      extraConfig.account.AuthMechs = "XOAUTH2";
    };
    notmuch.enable = true;
  };

  programs.mbsync = {
    enable = true;
    package = isync;
  };
  services.mbsync = {
    enable = true;
    package = isync;
    frequency = "*:0/3";
  };
  # Index after every run, not only successful ones (postExec would be
  # ExecStartPost): one broken folder must not hold back the rest of the mail.
  systemd.user.services.mbsync.Service.ExecStopPost = "${notmuch} new";

  programs.notmuch = {
    enable = true;
    # `new` marks what this run imported, for the hook; maildir flag sync
    # (notmuch's default) then drops `unread` from mail already read elsewhere.
    settings.new.tags = [
      "unread"
      "inbox"
      "new"
    ];
    hooks.postNew = ''
      q="tag:new and tag:unread and folder:outlook/Inbox"
      n=$(${notmuch} count -- "$q")
      # Skip the flood on a first sync.
      if [ "$n" -gt 0 ] && [ "$n" -le 20 ]; then
        if [ "$n" -eq 1 ]; then
          body=$(${notmuch} search --format=json --limit=1 -- "$q" | ${jq} -r '.[0] | "\(.authors) — \(.subject)"')
          ${notifySend} -a Mail -i mail-unread "New mail" "$body"
        else
          ${notifySend} -a Mail -i mail-unread "$n new mails"
        fi
      fi
      ${notmuch} tag -new -- tag:new
      ${pkgs.quickshell}/bin/qs ipc call mail refresh >/dev/null 2>&1 || true
    '';
  };
}
