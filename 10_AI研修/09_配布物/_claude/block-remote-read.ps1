# 研修環境のガードレール。
# 他の研修生のPR・2か月目リポジトリの answer-sample・過去期の完成品・講師の issue へ到達する経路を塞ぐ。
# PreToolUse / matcher は Bash。終了コード 2 でツール実行をブロックする。
# 原則: PR番号とリポジトリを指定させない。番号を省いた gh pr は「現在のブランチのPR」＝必ず自分のPR。

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$in = [Console]::In.ReadToEnd() | ConvertFrom-Json
$cmd = $in.tool_input.command
if (-not $cmd) { exit 0 }

$deny = @(
  'gh\s+(api|repo|search|browse|auth|release|gist)',
  'gh\s+issue',
  'gh\s+pr\s+(list|checkout)',
  'gh\s+pr\s+\w+.*(\s-R\s|\s--repo\s)',
  'gh\s+pr\s+(view|diff|comment)\s+\d',
  'git\s+(fetch|clone|ls-remote|pull)',
  'git\s+remote\s+(add|set-url)',
  'api\.github\.com'
)
foreach ($p in $deny) {
  if ($cmd -match $p) {
    [Console]::Error.WriteLine("研修環境では、この GitHub 操作を塞いでいます。自分のPRは番号を付けずに gh pr view / gh pr diff で参照してください。")
    exit 2
  }
}
exit 0
