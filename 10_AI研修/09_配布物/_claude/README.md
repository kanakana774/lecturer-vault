# _claude — 研修用リポジトリの `.claude/` に置くもの

| ここ | 配置先 |
|---|---|
| `settings.json` | `.claude/settings.json` |
| `block-remote-read.ps1` | `.claude/hooks/block-remote-read.ps1` |

vault 側はパス長を短く保つためフラットに置く（`09_配布物/README.md` と同じ方針）。

## settings.json

**取り消しのきかない操作を `ask` に置く**（コミット・push・PR への書き込み・`rm`・`psql`）。
**`mvn` は `allow`。**B で何度も回すので、ここで止めると流れが死ぬ。

**`WebFetch` / `WebSearch` も `ask` にしてある。**外に出すものを研修生に意識させるため
（前提のガバナンス2「渡してはいけないものを渡さない」と揃えた）。塞ぐためではない。

**`pom.xml` は `deny` にしていない。**塞ぐとレビュー観点7（依存を勝手に足さない）が
成立しなくなる。`ask` にして、研修生の目の前を通す。

## block-remote-read.ps1

**正本は `03_研修環境とガードレール.md` §5。**原則は「PR番号とリポジトリを指定させない」。

**⚠ UTF-8 BOM 付きで保存すること。** Windows PowerShell 5.1 は BOM が無いと .ps1 を
ANSI として読み、日本語のメッセージでパースに失敗する（実測）。
**冒頭の `[Console]::OutputEncoding` も消さない。**無いと stderr が CP932 で出て文字化けする。

### 動作確認（2026-09-24 実施）

`{"tool_input":{"command":"..."}}` を標準入力に流して終了コードを見た。**30件すべて期待どおり。**

| 通る（exit 0） | `gh pr view --comments` ／ `gh pr diff` ／ `gh pr comment -b "..."` ／ `gh pr create` ／ `gh pr review` ／ `git push` ／ `mvn test` ／ `git diff develop...HEAD -- docs/` ／ `git log` ／ `git status` |
|---|---|
| **塞ぐ（exit 2）** | `gh pr view 3` ／ `gh pr diff 12` ／ `gh pr comment 5 -b x` ／ `-R` `--repo` 付き ／ `gh pr list` ／ `gh pr checkout` ／ `gh api` ／ `gh repo` ／ `gh search` ／ `gh browse` ／ `gh auth` ／ `git fetch` ／ `git clone` ／ `git ls-remote` ／ `git pull` ／ `git remote add` ／ `api.github.com` |

**確認できていないのは配線のほう。**`settings.json` の `$CLAUDE_PROJECT_DIR` が展開され、
PreToolUse が実際に発火するかは、リポジトリを立ててから確かめる（→ 試走）。
**発火しなければ素通りする**（スクリプトが見つからず exit 1 になり、ブロックにならない）ので、
**試走の最初に `gh pr view 3` を1回叩いて、止まることを確かめる。**

### 03 からの差分

`git remote add` / `git remote set-url` を1行足した。`git fetch` を塞いでも、
リモートを足してから取りに行く経路が残るため（2026-09-24）。
