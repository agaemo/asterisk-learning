#!/usr/bin/env node
/**
 * SessionStart hook: セッション開始時に実行される
 *
 * プロジェクトの状態確認・環境チェックに使う。
 * ここでの stdout 出力は Claude への最初のコンテキストとして渡される。
 *
 * 入力スキーマ:
 * {
 *   "session_id": "...",
 *   "cwd": "..."
 * }
 */

const { execSync } = require('child_process');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  const lines = [];

  // 現在のブランチを表示
  try {
    const branch = execSync('git branch --show-current', { stdio: 'pipe' }).toString().trim();
    const status = execSync('git status --short', { stdio: 'pipe' }).toString().trim();
    lines.push(`Git ブランチ: ${branch}`);
    if (status) lines.push(`未コミットの変更:\n${status}`);
  } catch {
    // git管理外のディレクトリでは無視
  }

  // mise のランタイムを自動インストール（バージョン出力はしない）
  if (require('fs').existsSync('.mise.toml')) {
    try {
      execSync('mise install --quiet', { stdio: 'pipe' });
    } catch {
      lines.push('WARNING: mise が使えません。インストールしてください: https://mise.jdx.dev');
    }
  }

  // TODO: プロジェクト固有の起動時チェックを追加する
  // 例（必要な環境変数の確認）:
  //   const required = ['DATABASE_URL', 'API_KEY'];
  //   const missing = required.filter(k => !process.env[k]);
  //   if (missing.length > 0) lines.push(`WARNING: 必要な環境変数が未設定: ${missing.join(', ')}`);

  if (lines.length > 0) {
    console.log(lines.join('\n'));
  }

  process.exit(0);
});
