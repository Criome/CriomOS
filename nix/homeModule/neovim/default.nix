{
  lib,
  pkgs,
  pkdjz,
  user,
  config,
  horizon,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    readFile
    elem
    concatMap
    toJSON
    ;
  inherit (lib)
    optionalString
    optionals
    optionalAttrs
    ;
  inherit (user.methods) sizedAtLeast useColemak;
  inherit (horizon) node;
  inherit (pkgs) parinfer-rust writeText;
  inherit (pkdjz) vimPloginz;

  aolPloginz = pkgs.vimPlugins // vimPloginz;

  minVimLPloginz = with aolPloginz; [
    dwm-vim
    vim-visual-multi
    fzf-vim
    zoxide-vim
    astronauta-nvim
  ];

  medVimlPlogins = with aolPloginz; [
    vim-parinfer
    nvim-yarp # UpdateRemotePlugin replacement
    gina-vim # git
    vista-vim # Tags
    vim-toml
    tokei-vim
    vim-nix
    dhall-vim
    vim-markdown
    vim-ledger
    vim-surround
    vim-pager
    vim-rooter
    ultisnips
    vim-snippets
    minimap-vim
    hop-nvim
  ];

  maxVimlPlogins = with aolPloginz; [
    vim-fugitive # git
    gv-vim
  ];

  vimlPloginz =
    minVimLPloginz
    ++ (optionals sizedAtLeast.med medVimlPlogins)
    ++ (optionals sizedAtLeast.max maxVimlPlogins);

  luaPloginz =
    minLuaPloginz
    ++ (optionals sizedAtLeast.med medLuaPloginz)
    ++ (optionals sizedAtLeast.max maxLuaPloginz);

  minLuaPloginz = with aolPloginz; [
    plenary-nvim
    popup-nvim
    nvim-tree-lua
    lir-nvim
    completion-nvim
    completion-buffers
    nvim-treesitter
    nvim-treesitter-refactor
    nvim-treesitter-textobjects
    bufferline-nvim
    telescope-nvim
    FTerm-nvim
    neogit # bogi
    gitsigns-nvim # bogi
    express_line-nvim
  ];

  medLuaPloginz = with aolPloginz; [
    nvim-web-devicons
    nvim-base16-lua
    lazygit-nvim
    fzf-lsp-nvim
    formatter-nvim
  ];

  maxLuaPloginz = with vimPlugins; [
    lspsaga-nvim
  ];

  themeKod =
    ''
      command('hi def link NeogitDiffAddHighlight SignColumn')
      command('hi def link NeogitDiffDeleteHighlight SignColumn')
      command('hi def link NeogitDiffContextHighlight SignColumn')
      command('hi def link NeogitHunkHeader SignColumn')
      command('hi def link NeogitHunkHeaderHighlight SignColumn')
    '';

  ctagsKod = ''
    vim.g['loaded_gentags#gtags'] = 1
    vim.g['gen_tags#ctags_bin'] = '${pkgs.universal-ctags}/bin/ctags'
  '';

  treeGrammars = pkgs.tree-sitter.builtGrammars;
  treesitterParserz = ''
    vim.treesitter.require_language("rust", [[${treeGrammars.tree-sitter-rust}/parser]])
  '';

  raPath = "${pkgs.rust-analyzer}/bin/rust-analyzer";
  clangdPath = "${pkgs.llvmPackages_latest.clang-unwrapped}/bin/clangd";
  cmakeLSPath = "${pkgs.cmake-language-server}/bin/cmake-language-server";
  goplsPath = "${pkgs.gopls}/bin/gopls";
  hlsWrapperPath = "${pkgs.haskell-language-server}/bin/haskell-language-server-wrapper";
  pylsPath = "${pkgs.python38Packages.python-language-server}/bin/pyls";

  minKod =
    (readFile ./min.lua)
    + ''
      require'nvim-treesitter.configs'.setup {
        incremental_selection = {
          keymaps = {
    ''
    + (
      if useColemak then
        ''
          node_decremental = "<C-N>",
          node_incremental = "<C-E>",
        ''
      else
        ''
          node_decremental = "<C-J>",
          node_incremental = "<C-K>",
        ''
    )
    + ''
          },
        },
      }
    '';

  medLangServers = {
    rust_analyzer = {
      cmd = [ raPath ];
      capabilities = { };
      settings.rust-analyzer = {
        procMacro.enable = true;
        cargo = {
          loadOutDirsFromCheck = true;
        };
        diagnostics.disabled = [ "unresolved-proc-macro" ];
      };
    };

    rnix = {
      cmd = [ "${pkgs.rnix-lsp}/bin/rnix-lsp" ];
    };
    clangd = {
      cmd = [
        clangdPath
        "--background-index"
      ];
    };
    # cmake = { cmd = [ cmakeLSPath ]; }; # broken
  };

  maxLangServers = {
    pyls = {
      cmd = [ pylsPath ];
    };
    gopls = {
      cmd = [ goplsPath ];
    };
    hls = {
      cmd = [
        hlsWrapperPath
        "--lsp"
      ];
    };
  };

  langServers =
    (optionalAttrs sizedAtLeast.med medLangServers) // (optionalAttrs sizedAtLeast.max maxLangServers);

  medKod =
    ''
      vim.g.UltiSnipsJumpBackwardTrigger = '<c-h>'
    ''
    + (
      if useColemak then
        ''
          vim.g.UltiSnipsJumpForwardTrigger = '<c-i>'
        ''
      else
        ''
          vim.g.UltiSnipsJumpForwardTrigger = '<c-l>'
        ''
    );

  maxKod = ''
    vim.g.gitblame_enabled  = 0
    require('lspsaga').init_lsp_saga()
  '';

  medLuaKod = medKod + (readFile ./med.lua) + ctagsKod;

  maxLuaKod = maxKod;

  lsp_capabilities = {
    codeAction = {
      dynamicRegistration = false;
      codeActionLiteralSupport = {
        codeActionKind = {
          valueSet = [
            "quickfix"
            "refactor"
            "refactor.extract"
            "refactor.inline"
            "refactor.rewrite"
            "source"
            "source.organizeImports"
          ];
        };
      };
    };
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true;
        };
      };
    };
  };

  nioviNix = {
    inherit lsp_capabilities langServers sizedAtLeast;
  };

  nioviNixFile = writeText "niovi-nix.json" (toJSON nioviNix);
  nixPathLuaKod = ''
    local nix_path = '${nioviNixFile}'
  '';

  luaMods = [ ];
  luaCMods = [ pkgs.luajit.pkgs.rapidjson ];

  mkLuaCPath = drv: "${drv}/lib/lua/${drv.lua.luaversion}/?.so";

  mkLuaPaths = drv: [
    "${drv}/share/lua/${drv.lua.luaversion}/?.lua"
    "${drv}/share/lua/${drv.lua.luaversion}/?/init.lua"
  ];

  luaModulesPaths = concatStringsSep ";" (optionals (luaMods != [ ]) (concatMap mkLuaPaths luaMods));

  luaCModulesPaths = concatStringsSep ";" (optionals (luaCMods != [ ]) (map mkLuaCPath luaCMods));

  loadLuaPathsKod =
    optionalString (luaMods != [ ]) ''
      package.path = package.path .. ";" .. [[${luaModulesPaths}]]
    ''
    + optionalString (luaCMods != [ ]) ''
      package.cpath = package.cpath .. ";" .. [[${luaCModulesPaths}]]
    '';

  initLuaKod =
    loadLuaPathsKod
    + nixPathLuaKod
    + (readFile ./vimLib.lua)
    + (readFile ./niovi.lua)
    + (optionalString useColemak readFile ./colemak.lua)
    + (readFile ./mappings.lua)
    + (optionalString (!useColemak) (readFile ./qwerty.lua))
    + (readFile ./dwm.lua)
    + treesitterParserz
    + (readFile ./treesitter.lua)
    + minKod
    + themeKod
    + (readFile ./expressline.lua)
    + (optionalString sizedAtLeast.med (
      medLuaKod + optionalString sizedAtLeast.max maxLuaKod
    ));

  luaVimrc = writeText "vimrc.lua" initLuaKod;

  minPackages = with pkgs; [ ];

  medPackages = with pkgs; [
    crate2nix
    llvmPackages_latest.clang
    universal-ctags
    go
    neovim-remote
    nixpkgs-fmt
    luaformatter
  ];

  maxPackages = with pkgs; [
    ghc
    cabal-install
    stack
  ];

in
{
  home = {
    packages =
      minPackages
      ++ (optionals sizedAtLeast.med (
        medPackages ++ (optionals sizedAtLeast.max maxPackages)
      ));

    sessionVariables = {
      EDITOR = if sizedAtLeast.med then "nvr -cc split --remote-wait +'set bufhidden=wipe'" else "nvim";
    };
  };

  programs = {
    neovim = {
      package = pkdjz.neovim;
      enable = true;
      withRuby = false;
      vimAlias = true;
      plugins = vimlPloginz ++ luaPloginz;

      extraConfig = readFile ./leftovers.vim + "luafile ${luaVimrc}";
    };

  };
}
