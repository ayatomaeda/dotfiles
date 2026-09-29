# 1Password 固有のパス (select-signing-key-by-name)。
#
# **モジュールではない。** 属性の集合を返すだけのファイルで、default.nix の imports に
# 入れない。ssh.nix と git.nix が `import ./one-password.nix` で読む。
#
# 値を定義するのはここ 1 か所で、使うのは各モジュールの dotfiles.onePassword.enable の
# gate の内側だけ。このファイルを読んでも何も出力しないので、gate が false のホストの
# 生成物に 1Password のパスは現れない。定数なので option にしない (options.nix の冒頭)。
{
  # 1Password の SSH agent のソケット。ホームからの相対パスで、使う側が
  # ssh の設定では "~/…"、シェルスクリプトでは "$HOME/…" を前に付ける。
  agentSocket = "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  # 1Password の SSH 署名プログラム (git の gpg.ssh.program から、ラッパー経由で呼ぶ)。
  signProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
}
