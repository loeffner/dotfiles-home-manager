{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      alias = {
        # Log
        lg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' -n 10";
        lga = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";

        # Changes
        changed = "!git diff --color --stat --find-renames $(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)...";

        # Fuzzy switch
        fswitch = ''!git switch "$(git for-each-ref --format='%(refname:short)' refs/heads | fzf --preview 'git lg --color=always {} | head -50')"'';

        # Open files
        fzffile = ''!f() { f=$(git ls-files | fzf --preview 'highlight -O ansi {} | head -50'); [ -n "$f" ] && ''${EDITOR:-vim} "$f"; }; f'';

        # Commit
        fix = "commit --fixup";

        # Push/Pull
        force = "push --force-with-lease";

        # Rebase
        reb = "rebase -i --autosquash";

        # Reset
        uncommit = "reset --soft HEAD~1";

        # Cleanup
        clean-merged = "!git branch --merged master | grep -v 'master' | xargs -n 1 git branch -d";
      };
      rerere.enabled = true;

      diff = {
        tool = "vimdiff";
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };

      difftool.prompt = false;

      merge.tool = "vimdiff";
      mergetool.prompt = false;

      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      init.defaultBranch = "master";

      push.autoSetupRemote = true;

      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };

      commit.verbose = true;
      rebase.updateRefs = true;
      submodule.recurse = true;
    };

  };
}
