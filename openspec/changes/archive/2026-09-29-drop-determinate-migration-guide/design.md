## Context

core を使う Mac は 2026-09-30 にすべて upstream の Nix へ入れ替えた。入れ替えの手順 (`use-upstream-nix` の README の節と
spec の要件) は、その作業のためだけにあった。

## Goals / Non-Goals

**Goals:**

- 一度きりの手順を README と spec から除き、必要になったときの在りかだけを示す。

**Non-Goals:**

- 「Determinate Nix が残っている Mac では activation が止まる」という振る舞いの記述を消すこと。これは今の構成の性質なので、
  README の「利用側が与えるもの」、モジュールのコメント、spec の scenario に残す。

## Decisions

### D1. 手順は削り、在りかを示す

後で Determinate Nix の入った Mac に core を使うことがあれば、`use-upstream-nix` をマージした時点の README
(コミット `ba5dfb1`) の手順が使える。README の表とモジュールのコメントからは、そのコミットを指す。手順を別のファイルに
移して残すことはしない。読む人のいない文書を保守し続けることになるため。

- 代案: `docs/` に移して残す。保守の対象が増えるだけなので採らない。
