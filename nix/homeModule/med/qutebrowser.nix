{
  lib,
  pkgs,
  user,
  profile,
  config,
  ...
}:
let
  inherit (builtins) readFile toString;
  inherit (lib) mkIf optionalString;
  inherit (user.methods) useColemak sizedAtLeast;
  inherit (profile) dark;

  badDomains = [
    "www.reddit.com"
    "www.goodreads.com"
    "www.allmusic.com"
    "www.imdb.com"
    "rumble.com"
    "astro-charts.com"
    "www.amazon.com"
    "canva.com"
  ];

  bankingDomains = [
    "*.royalbank.com"
    "*.coinbase.com"
    "*.eqbank.ca"
  ];

  undesirableDomains = [
    "duckduckgo.com"
    "www.cloudflare.com"
    "dash.cloudflare.com"
    "admin.gandi.net"
    "cloud.linode.com"
    "login.linode.com"
    "github.com"
    "bitbucket.org"
  ];

  betterDomains = [
    "gitlab.com"
    "gitlab.gnome.org"
    "gitlab.redox-os.org"
    "gitlab.freedesktop.org"
    "gitlab.e.foundation/e/apps"
    "gitea.com"
    "codeberg.org"
    "source.puri.sm"
    "clojuredocs.org"
    "clojure.org"
    "crates.io"
    "docs.rs"
    "doc.rust-lang.org"
    "rustc-dev-guide.rust-lang.org"
    "rust-lang.github.io/async-book"
    "lib.rs"
    "hydra.nixos.org"
    "download.lineageos.org"
    "opengapps.org"
    "postmarketos.org"

    "odysee.com"
    "mail.protonmail.com"
    "login.protonmail.com"
    "mail.proton.me"
    "login.proton.me"
    "account.proton.me"
    "asciinema.org"
    "cal.com"
    "app.cal.com"
    "meet.jit.si"
  ];

  unsafeBadDomains = [
    "*.koodomobile.com"
    "*.google.com"
    "*.youtube.com"
    "*.aliexpress.com"
    "*.locals.com"
    "*.stripe.com"
    "*.x.com"
    "*.linktr.ee"
    "*.facebook.com"
    "*.instagram.com"
    "*.streamyard.com"
    "*.amazon.com"
    "*.amazon.ca"
  ];

  unstrictWhitelist = unsafeBadDomains ++ bankingDomains;

  strictWhitelist = betterDomains ++ undesirableDomains ++ badDomains;

  whitelist = unstrictWhitelist ++ strictWhitelist;

  mkDomainString = domain: "config.set('content.javascript.enabled', True, 'https://${domain}/*')";
  mkDomainsList = map (domain: mkDomainString domain) whitelist;
  domainListBlok = builtins.concatStringsSep "\n" mkDomainsList;

in
lib.mkIf sizedAtLeast.med {
  home = {
    packages = [ pkgs.qutebrowser ];

    file = {
      ".config/qutebrowser/config.py".text =
        ''
          config.load_autoconfig(False)
          c.qt.force_platform = "wayland"
          # General configurations
          c.downloads.remove_finished = 2000
          c.completion.delay = 200
          c.completion.web_history.max_items = 5000
          c.completion.web_history.exclude = [
            "https://google.com/"
            "https://duckduckgo.com/"
            "https://startpage.com/"
            "https://github.com/"
          ]

          c.scrolling.smooth = True
          c.scrolling.bar = "never"
          c.colors.webpage.darkmode.enabled = ${if dark then "True" else "False"}
          c.fonts.web.size.default = 18

          config.set('content.javascript.enabled', False)
          config.set('content.javascript.enabled', True, 'http://[::1]*')

          config.set('content.javascript.enabled', True, 'file://${config.home.homeDirectory}/html/*')

          ${domainListBlok}

          c.url.start_pages = ["qute://history/"]

          c.url.searchengines = {
          "DEFAULT": "https://duckduckgo.com/?q={}",
          "g": "https://google.com/search?hl=en&q={}",
          "s": "https://www.startpage.com/do/dsearch?query={}",
          "sx": "https://searx.me/?q={}",
          "d": "https://duckduckgo.com/?q={}",
          "cb": "https://codeberg.org/explore/repos?tab=&sort=recentupdate&q={}",
          "gl": "https://gitlab.com/search?utf8=%E2%9C%93&search={}",
          "gh": "https://github.com/search?utf8=/&q={}",
          "gist": "https://gist.github.com/search?utf8=%E2%9C%93&q={}",
          "ghr": "https://github.com/search?utf8=/&q={}%20language%3Arust",
          "ghqtb": "https://github.com/qutebrowser/qutebrowser/search?q={}&type=Issues",
          "ghpkgs": "https://github.com/NixOS/nixpkgs/search?q={}&type=Issues",
          "ghnix": "https://github.com/NixOS/nix/search?q={}&type=Issues",
          "ghhome": "https://github.com/rycee/home-manager/search?q={}&type=Issues",
          "ghvim": "https://github.com/neovim/neovim/search?q={}&type=Issues",
          "ghsway": "https://github.com/swaywm/sway/search?q={}&type=Issues",
          "librs": "https://lib.rs/search?q={}",
          "aw": "https://wiki.archlinux.org/?search={}",
          "gw": "https://wiki.gentoo.org/index.php?title=Special%3ASearch&search={}",
          "alw": "https://wiki.alpinelinux.org/w/index.php?title=Special%3ASearch&profile=default&search={}",
          "so": "https://stackoverflow.com/search?q={}",
          "w": "http://en.wikipedia.org/w/index.php?title=Special:Search&search={}",
          "yt": "https://www.youtube.com/results?search_query={}",
          "leet": "https://1337x.to/torrent/search/{}/1/",
          "gr": "https://www.goodreads.com/search?q={}",
          }

          c.bindings.commands["normal"] = {
            # User bindings
            "<Ctrl-M>": "spawn mpv --ytdl-format=webm {url}",
            ";m": "hint links spawn mpv --ytdl-format=webm {hint-url}",
            "<Ctrl-R>": "config-source ",
            "<Ctrl-E>": "cmd-set-text -s :buffer ",
            "zu": 'spawn --userscript qute-pass --username-target secret --username-pattern "login: (.+)" --dmenu-invocation "wofi --show dmenu"',
            'znu': 'spawn --userscript qute-pass --username-target secret --username-pattern "login: (.+)" --dmenu-invocation "wofi --show dmenu" --username-only',
            'ztu': 'spawn --userscript qute-pass  --dmenu-invocation "wofi --show dmenu" --password-only',
            'zou': 'spawn --userscript qute-pass  --dmenu-invocation "wofi --show dmenu" --otp-only',
        ''
        + (optionalString useColemak ''
          # Indentation hak
            ";G": "hint images tab",
            ";Y": "hint links fill :open -t -r {hint-url}",
            ";P": "hint --rapid links window",
            ";J": "hint links yank-primary",
            ";s": "hint links download",
            ";t": "hint all tab-fg",
            ";g": "hint images",
            ";y": "hint links fill :open {hint-url}",
            ";p": "hint --rapid links tab-bg",
            ";u": "hint inputs",
            ";j": "hint links yank",
            "<Ctrl-S>": "scroll-page 0 0.5",
            "<Ctrl-T>": "scroll-page 0 1",
            "<Ctrl-K>": "open -w",
            "<Ctrl-Shift-K>": "open -p",
            "<Ctrl-Shift-G>": "undo",
            "<Ctrl-G>": "open -t",
            "<Ctrl-L>": "scroll-page 0 -0.5",
            "<Ctrl-o>": "tab-pin",
            "<Ctrl-r>": "stop",
            "S": "tab-close -o",
            "T": "hint all tab",
            "G": "scroll-to-perc",
            "N": "tab-next",
            "E": "tab-prev",
            "I": "forward",
            "K": "search-prev",
            "Y": "cmd-set-text -s :open -t",
            "O": "", # unbind
            "OO": "open -t -- {primary}",
            "Oo": "open -t -- {clipboard}",
            "P": "reload -f",
            "Rb": "open qute://bookmarks#bookmarks",
            "Rh": "open qute://history",
            "Rq": "open qute://bookmarks",
            "Rr": "open qute://settings",
            "G": "tab-focus",
            "D": "scroll-to-perc 100",
            "as": "download-cancel",
            "cs": "download-clear",
            "cy": "tab-only",
            "s": "tab-close",
            "t": "hint",
            "d": "",  # Needed to unbind
            "d$": "tab-focus -1",
            "d0": "tab-focus 1",
            "dB": "cmd-set-text -s :bookmark-load -t",
            "dC": "tab-clone",
            "dY": "cmd-set-text :open -t -r {url:pretty}",
            "dL": "navigate up -t",
            "d^": "tab-focus 1",
            "da": "open -t",
            "db": "cmd-set-text -s :bookmark-load",
            "ds": "download",
            "dt": "view-source",
            "dd": "scroll-to-perc 0",
            "du": "hint inputs --first",
            "di": "tab-move -",
            "dm": "tab-move",
            "dy": "cmd-set-text :open {url:pretty}",
            "dp": "tab-move +",
            "dg": "cmd-set-text -s :buffer",
            "dl": "navigate up",
            "u": "enter-mode insert",
            "n": "scroll down",
            "e": "scroll up",
            "i": "scroll right",
            "k": "search-next",
            "y": "cmd-set-text -s :open",
            "o": "",
            "oO": "open -- {primary}",
            "oo": "open -- {clipboard}",
            "p": "reload",
            "rt": "save",
            "re": "cmd-set-text -s :bind",
            "ri": "cmd-set-text -s :set -t",
            "rr": "cmd-set-text -s :set",
            "gOH": "config-cycle -p -u *://*.{url:host}/* content.plugins ;; reload",
            "gOh": "config-cycle -p -u *://{url:host}/* content.plugins ;; reload",
            "gOl": "config-cycle -p -u {url} content.plugins ;; reload",
            "gRH": "config-cycle -p -u *://*.{url:host}/* content.javascript.enabled ;; reload",
            "gRh": "config-cycle -p -u *://{url:host}/* content.javascript.enabled ;; reload",
            "gRu": "config-cycle -p -u {url} content.javascript.enabled ;; reload",
            "gh": "back -t",
            "gi": "forward -t",
            "goH": "config-cycle -p -t -u *://*.{url:host}/* content.plugins ;; reload",
            "goh": "config-cycle -p -t -u *://{url:host}/* content.plugins ;; reload",
            "gol": "config-cycle -p -t -u {url} content.plugins ;; reload",
            "grH": "config-cycle -p -t -u *://*.{url:host}/* content.javascript.enabled ;; reload",
            "grh": "config-cycle -p -t -u *://{url:host}/* content.javascript.enabled ;; reload",
            "grl": "config-cycle -p -t -u {url} content.javascript.enabled ;; reload",
            "l": "undo",
            "wY": "cmd-set-text :open -w {url:pretty}",
            "wO": "open -w -- {primary}",
            "wt": "hint all window",
            "wu": "inspector",
            "wi": "forward -w",
            "wy": "cmd-set-text -s :open -w",
            "wo": "open -w -- {clipboard}",
            "xY": "cmd-set-text :open -b -r {url:pretty}",
            "xy": "cmd-set-text -s :open -b",
            "j": "",
            "jS": "yank domain -s",
            "jO": "yank pretty-url -s",
            "jG": "yank title -s",
            "jJ": "yank -s",
            "js": "yank domain",
            "jo": "yank pretty-url",
            "jg": "yank title",
            "jj": "yank",
        '')
        + ''
          }
        ''
        + (optionalString useColemak ''
          c.hints.chars = "arstdhneio"
          c.bindings.commands["caret"] = {
            "D": "move-to-end-of-document",
            "N": "scroll down",
            "E": "scroll up",
            "I": "scroll right",
            "J": "yank selection -s",
            "f": "move-to-end-of-word",
            "dd": "move-to-start-of-document",
            "n": "move-to-next-line",
            "e": "move-to-prev-line",
            "i": "move-to-next-char",
            "j": "yank selection",
          }
          c.bindings.commands["command"] = {
            "<Alt-S>": "rl-kill-word",
            "<Alt-T>": "rl-forward-word",
            "<Ctrl-S>": "completion-item-del",
            "<Ctrl-F>": "rl-end-of-line",
            "<Ctrl-T>": "rl-forward-char",
            "<Ctrl-E>": "rl-kill-line",
            "<Ctrl-K>": "command-history-next",
            "<Ctrl-O>": "command-history-prev",
            "<Ctrl-L>": "rl-unix-line-discard",
            "<Ctrl-J>": "rl-yank",
          }
          c.bindings.commands["hint"] = {
            "<Ctrl-T>": "hint links",
            "<Ctrl-P>": "hint --rapid links tab-bg",
          }
          c.bindings.commands["insert"] = {
            "<Ctrl-F>": "open-editor",
          }
        '');

    };

  };
}
