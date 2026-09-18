# 端末エミュレータ (Ghostty) の設定。
#
# 実体は ~/.config/ghostty/config。以前は config/ghostty/config への
# out-of-store symlink で置いていたが、宣言から生成する形に変えた
# (retire-out-of-store-symlinks)。反映には Ghostty の再読み込みが要る点は
# 以前と変わらない。
{ ... }:
{
  programs.ghostty = {
    enable = true;

    # **パッケージは入れない。** Ghostty は Homebrew の cask で入れる
    # (modules/darwin/homebrew.nix の "ghostty")。GUI アプリなので /Applications に
    # 置く必要がある。
    #
    # **利用側との約束 (split-public-core):** Ghostty 本体と、下の font-family に
    # 書いた 2 つのフォントは、core の Homebrew のリストが宣言している。それが効くのは
    # 利用側が homebrew.enable = true にしたときだけなので、Homebrew を使わない利用側は
    # 本体とフォントを別の方法で入れる。フォントが無いと、Ghostty は黙って代わりの
    # フォントを使う。
    # package = null のとき installBatSyntax は既定で false になるので
    # (`default = cfg.package != null`)、bat の構文定義も増えない。
    package = null;

    # **シェル統合はモジュールに書かせない。** 既定は true で、.zshrc に
    #   if [[ -r "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration ]]; then …
    # を initContent の既定の順序 (1000) で足す。同じ読み込みは
    # modules/common/terminal.nix が mkOrder 1500 で既に書いており、そちらは
    # 「starship の初期化より後」という実測した順序に合わせてある。
    # 両方を有効にすると読み込みが 2 か所になり、順序の根拠が分からなくなる。
    enableZshIntegration = false;

    # 値はすべて移行前の config/ghostty/config と同じ。生成される順序は
    # 属性名の昇順になるが、Ghostty はキーの順序に依存しない。
    settings = {
      theme = "TokyoNight";

      # listsAsDuplicateKeys = true なので、リストは同じキーの複数行になる。
      # Ghostty の font-family は「この順で探す」意味なので順序を保つ必要がある。
      # 日本語が入る行を先に置く。
      font-family = [
        "Source Han Code JP"
        "SauceCodePro Nerd Font Mono"
      ];
      font-size = 14;
      adjust-cell-height = "10%";

      # 小数は文字列で書く。Nix の float を渡すと toString が
      # "0.800000" のような表記に展開され、宣言と生成物の見た目がずれる。
      background-opacity = "0.8";
      background-blur-radius = 20;

      window-padding-x = 4;
      window-padding-y = 4;
      window-padding-balance = true;
      window-save-state = "always";

      mouse-hide-while-typing = true;
    };
  };
}
