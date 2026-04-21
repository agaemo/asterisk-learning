#!/usr/bin/env node
/**
 * Stop hook: Claudeの応答終了後に実行される
 *
 * 型チェック・テスト実行など、ターン終わりにまとめてやりたい処理に使う。
 *
 * 入力スキーマ:
 * {
 *   "stop_reason": "end_turn" | "tool_use" | ...
 * }
 *
 * exit 0 → 正常
 * exit 2 → ClaudeへのフィードバックとしてJSONを返す
 */

const { execSync } = require('child_process');

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  // ツール呼び出し中のターンはスキップ（end_turn のみ実行）
  let data;
  try { data = JSON.parse(input); } catch { process.exit(0); }
  if (data?.stop_reason !== 'end_turn') process.exit(0);

  // ファイル変更がなければスキップ
  let changed = '';
  try {
    changed = execSync('git diff --name-only HEAD', { stdio: 'pipe' }).toString().trim();
  } catch {
    // git 管理外の場合は変更ありとみなして続行
    changed = 'unknown';
  }
  if (!changed) process.exit(0);

  // TODO: プロジェクト固有のチェックをここに追加する
  //
  // 【Go プロジェクト】
  //   if (!require('fs').existsSync('go.mod')) process.exit(0);
  //   try {
  //     execSync('mise exec -- go build ./...', { stdio: 'pipe' });
  //   } catch (e) {
  //     console.log(JSON.stringify({ type: 'result', content: `go build 失敗:\n${e.stderr?.toString()}` }));
  //     process.exit(2);
  //   }
  //   try {
  //     execSync('mise exec -- go test ./...', { stdio: 'pipe' });
  //   } catch (e) {
  //     console.log(JSON.stringify({ type: 'result', content: `go test 失敗:\n${e.stdout?.toString()}` }));
  //     process.exit(2);
  //   }
  //
  // 【TypeScript プロジェクト】
  //   if (!require('fs').existsSync('package.json')) process.exit(0);
  //   try {
  //     execSync('npx tsc --noEmit', { stdio: 'pipe' });
  //   } catch (e) {
  //     console.log(JSON.stringify({ type: 'result', content: `型チェック失敗:\n${e.stdout?.toString()}` }));
  //     process.exit(2);
  //   }
  //
  // 【Python プロジェクト】
  //   try {
  //     execSync('ruff check .', { stdio: 'pipe' });
  //   } catch (e) {
  //     console.log(JSON.stringify({ type: 'result', content: `lint 失敗:\n${e.stdout?.toString()}` }));
  //     process.exit(2);
  //   }

  process.exit(0);
});
