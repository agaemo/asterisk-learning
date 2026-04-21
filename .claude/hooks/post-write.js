#!/usr/bin/env node
/**
 * PostToolUse hook: Write / Edit
 *
 * ファイル書き込み後に実行される。
 * フォーマッタや lint を自動実行するのに使う。
 *
 * 入力スキーマ:
 * {
 *   "tool_name": "Write" | "Edit",
 *   "tool_input": { "file_path": "..." },
 *   "tool_response": { ... }
 * }
 */

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }

  const filePath = data?.tool_input?.file_path ?? '';

  // TODO: 言語・ツールに合わせてフォーマッタを設定する
  // 例（TypeScript）:
  //   const { execSync } = require('child_process');
  //   if (filePath.endsWith('.ts') || filePath.endsWith('.tsx')) {
  //     try { execSync(`npx prettier --write "${filePath}"`); } catch {}
  //   }
  //
  // 例（Python）:
  //   if (filePath.endsWith('.py')) {
  //     try { execSync(`ruff format "${filePath}"`); } catch {}
  //   }

  process.exit(0);
});
