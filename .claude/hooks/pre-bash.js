#!/usr/bin/env node
/**
 * PreToolUse hook: Bash
 *
 * stdin から JSON を受け取り、危険なコマンドをブロックする。
 * exit 0 → 許可  /  exit 2 → ブロック（Claude にメッセージを返せる）
 *
 * 入力スキーマ:
 * {
 *   "tool_name": "Bash",
 *   "tool_input": { "command": "..." }
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
    process.exit(0); // パース失敗は通す
  }

  const command = data?.tool_input?.command ?? '';

  // TODO: プロジェクト固有のブロックルールを追加する
  const BLOCKED_PATTERNS = [
    /rm\s+-rf\s+\//,          // ルート削除
    /git\s+push\s+--force/,   // force push
    /git\s+reset\s+--hard/,   // hard reset（確認なし）
    /DROP\s+TABLE/i,           // DBテーブル削除
    />\s*\.env/,               // .env への書き込み
  ];

  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(command)) {
      // stdout に書いた内容が Claude へのフィードバックとして返る
      console.log(`pre-bash フックによりブロックされました: コマンドがブロックパターン ${pattern} に一致します`);
      process.exit(2);
    }
  }

  process.exit(0);
});
