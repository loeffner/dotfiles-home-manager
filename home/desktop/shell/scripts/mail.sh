#!/bin/sh
# Mail access for services/Mail, on top of the notmuch index of ~/Maildir
# (synced by mbsync, see home/mail.nix). Needs notmuch, jq and w3m on PATH.
# Mail is grouped into conversations (notmuch threads); a conversation's id is
# its first message's id, which stays put as replies arrive.
#   mail.sh list <query> <limit>   {"unread": N, "threads": [...]}, newest first:
#                                  the conversations with mail matching <query>
#   mail.sh thread <message-id>    that message's whole conversation, oldest
#                                  first, bodies as plain text (html via w3m)
#   mail.sh move <folder> <message-id>...
#                                  move them from <account>/Inbox to
#                                  <account>/<folder> (Archive, or Deleted)
#   mail.sh open <message-id> <part> <name>
#                                  unpack that attachment (MIME part number, as
#                                  `thread` lists it) into $XDG_RUNTIME_DIR and
#                                  open it with its default app
# Read/star state is plain `notmuch tag` (flags sync to the maildir, mbsync
# pushes them), so it needs no helper. Mail in the trash or junk folders is
# left out of conversations.
set -u

# A notmuch query for one message id ("" escapes a quote inside).
idq() {
  printf 'id:"%s"' "$(printf %s "$1" | sed 's/"/""/g')"
}

me=$(notmuch config get user.primary_email | tr 'A-Z' 'a-z')

# jq: the messages in `notmuch show --format=json` output (a thread forest),
# the leaf parts of one message, its sender, and whether it's still around.
JQ_DEFS='
def messages: [.. | objects | select(has("tags") and has("headers"))];
def leaves: [.body[]? | recurse(if (.content | type) == "array" then .content[] else empty end)];
def part($t): [leaves[] | select(."content-type" == $t and (.content | type) == "string") | .content] | first;
def attachments: [leaves[] | select(."content-disposition" == "attachment") | { name: (.filename // "attachment"), part: .id }];
def addr: (try capture("^\\s*\"?(?<name>[^\"<]*?)\"?\\s*<(?<address>[^>]+)>\\s*$") catch null)
  // { name: "", address: . };
def sender: (.headers.From // "" | addr) | .mine = ((.address | ascii_downcase) == $me)
  | .label = (if .name != "" then .name else .address end);
def tagged($t): .tags | index($t) != null;
def kept: (.filename | if type == "array" then . else [.] end) | all(test("/(Deleted|Junk)/")) | not;
'

case "$1" in
  list)
    query=$2
    unread=$(notmuch count -- "($query) and tag:unread")
    threads=$(notmuch search --format=json --output=threads --sort=newest-first --limit="$3" -- "$query" |
      jq -r 'map("thread:" + .) | join(" or ")')
    if [ -z "$threads" ]; then
      printf '{"unread":%s,"threads":[]}\n' "$unread"
      exit 0
    fi
    notmuch show --format=json --entire-thread=true --include-html -- "$threads" |
      jq -c --arg me "$me" --argjson unread "$unread" "$JQ_DEFS"'
        # jq regexes are slow on long strings: only look at the start of the
        # body (for html, from <body>, with style/script blocks dropped).
        def snippet: (part("text/plain") // "" | .[0:600])
            as $plain
          | (if $plain != "" then $plain
             else part("text/html") // "" | ((ascii_downcase | index("<body")) // 0) as $i | .[$i:$i + 8000]
               | gsub("(?is)<(style|script)[^>]*>.*?</\\1>"; "") | gsub("<[^>]+>"; " ")
             end)
          | gsub("&nbsp;"; " ") | gsub("&amp;"; "&") | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:180];
        # Who is in the conversation, in order of appearance ("me" for you).
        def people: reduce (.[] | sender | if .mine then "me" else .label end) as $n
          ([]; if any(.[]; . == $n) then . else . + [$n] end);
        { unread: $unread,
          threads: ([.[] | messages | map(select(kept))
            | select(any(.[]; .match))
            | max_by(.timestamp) as $last
            | {
                id: .[0].id,
                subject: (.[0].headers.Subject // "" | if . == "" then "(no subject)" else . end),
                from: (people | join(", ")),
                sender: ($last | sender | .label),
                snippet: ($last | snippet),
                date: ($last.timestamp * 1000),
                count: length,
                unreadCount: map(select(tagged("unread"))) | length,
                starred: any(.[]; tagged("flagged")),
                attachments: [.[] | attachments[] | .name],
                inbox: [sort_by(.timestamp)[] | select(.match) | .id],
                all: [.[].id]
              } | .unread = (.unreadCount > 0)]
            | sort_by(-.date)) }'
    ;;
  thread)
    json=$(notmuch show --format=json --entire-thread=true --include-html -- "$(idq "$2")" |
      jq -c --arg me "$me" "$JQ_DEFS"'
        messages | map(select(kept)) | sort_by(.timestamp) | map(sender as $s | {
          id,
          from: $s.label,
          address: $s.address,
          mine: $s.mine,
          to: (.headers.To // ""),
          date: (.timestamp * 1000),
          unread: tagged("unread"),
          starred: tagged("flagged"),
          attachments: attachments,
          text: part("text/plain"),
          html: (if part("text/plain") then null else part("text/html") end)
        })')
    # html-only messages: render to text, links as numbered references at the end.
    n=$(printf %s "$json" | jq length)
    i=0
    while [ "$i" -lt "$n" ]; do
      if [ "$(printf %s "$json" | jq ".[$i].html != null")" = true ]; then
        text=$(printf %s "$json" | jq -r ".[$i].html" |
          w3m -dump -T text/html -cols 88 -O UTF-8 -o display_link_number=1)
        json=$(printf %s "$json" | jq -c --argjson i "$i" --arg t "$text" '.[$i].text = $t')
      fi
      i=$((i + 1))
    done
    printf %s "$json" | jq -c 'map(del(.html) | .text //= "")'
    ;;
  move)
    folder=$2
    shift 2
    root=$(notmuch config get database.path)
    for id in "$@"; do
      notmuch search --output=files -- "$(idq "$id")" | while IFS= read -r f; do
        case $f in
          "$root"/*/Inbox/*) ;;
          *) continue ;;
        esac
        account=${f#"$root"/}
        account=${account%%/*}
        mkdir -p "$root/$account/$folder/cur"
        # Drop mbsync's ,U=<uid> so it treats the moved file as new there.
        mv "$f" "$root/$account/$folder/cur/$(basename "$f" | sed -E 's/,U=[0-9]+//')"
      done
    done
    notmuch new --no-hooks --quiet
    ;;
  open)
    # One private folder per message (runtime dir: tmpfs, user-only, gone at
    # logout), under the attachment's own name minus any path or control chars.
    dir=${XDG_RUNTIME_DIR:?}/mail-attachments/$(printf %s "$2" | sha1sum | cut -c1-16)
    name=$(basename -- "$4" | tr -d '\000-\037')
    [ -n "$name" ] || name="attachment-$3"
    mkdir -p "$dir"
    chmod 700 "${XDG_RUNTIME_DIR}/mail-attachments"
    notmuch show --format=raw --part="$3" -- "$(idq "$2")" > "$dir/$name" &&
      xdg-open "$dir/$name"
    ;;
esac
