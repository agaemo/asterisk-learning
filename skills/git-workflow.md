---
name: git-workflow
description: git/gh操作（状態確認・ブランチ作成・ステージング・コミット・PR作成・マージ）を安全な手順で行う。
---

## git ルール

- ユーザーが明示的に依頼しない限り、コミットしないこと。
- ユーザーが明示的に依頼しない限り、プッシュしないこと。
- `--no-verify`・main/masterへの `--force`・公開済みコミットへの `--amend` は使わないこと。
- コミット前に必ず `git diff --staged` を表示してユーザーが確認できるようにすること。
- コミットメッセージ形式：命令形・72文字以内・末尾にピリオドなし。

## gh コマンド 安全ルール

### 絶対禁止（ユーザーが明示的に指示しても必ず一度確認を取ること）
| コマンド | 理由 |
|---------|------|
| `gh repo delete` | リポジトリごと削除。復元不可 |
| `gh repo transfer` | 所有権移転。取り戻せない場合あり |
| `gh release delete` | リリース・タグ削除。公開済みなら影響大 |

### 実行前にユーザーへ内容を提示して確認を取ること
| コマンド | 理由 |
|---------|------|
| `gh pr merge` | mainへの変更は特に慎重に。`--delete-branch` は別途確認 |
| `gh pr close` | クローズは再オープン可能だが意図せず閉じると混乱を招く |
| `gh issue close` | 同上 |
| `gh secret set` | シークレット変更はCI/CD全体に影響 |

### 自由に実行してよい（読み取り・作成系）
```bash
gh pr list / gh pr view / gh pr checks   # PR確認
gh issue list / gh issue view            # Issue確認
gh repo view                             # リポジトリ確認
gh pr create ...                         # PR作成
gh issue create ...                      # Issue作成
gh run list / gh run view                # CI確認
```

## 手順

### 状態確認
```bash
git status
git diff
```

### ブランチ作成
```bash
git checkout -b <type>/<description>
# type: feat / fix / refactor / chore / docs
```

### ステージングとコミット
```bash
git add <specific-files>       # 禁止: git add -A や git add .
git diff --staged              # コミット前にレビュー
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### プッシュとPR作成
```bash
git push -u origin <branch>
gh pr create --title "<title>" --body "$(cat <<'EOF'
## 概要
- <変更点>

## テスト方法
- [ ] <確認手順>

🤖 Generated with Claude Code
EOF
)"
```

### PRのマージ（ユーザー確認後のみ）
```bash
gh pr merge <number> --squash    # squash推奨。--delete-branch は別途確認
```

### CI確認
```bash
gh pr checks <number>
gh run list --branch <branch>
```

## コミットメッセージ例

```
feat: JWTによるユーザー認証を追加
fix: 決済処理のnullポインタを防止
refactor: バリデーションロジックを独立モジュールに切り出し
chore: 依存関係を最新バージョンに更新
```
