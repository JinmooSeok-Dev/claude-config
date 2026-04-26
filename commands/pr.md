$ARGUMENTS PR 본문 작성 + 생성. dry-run 옵션 지원.

## 절차
1. **상태 확인**:
   ```bash
   git status
   git log --oneline main..HEAD     # 또는 origin/main..HEAD
   git diff --stat main..HEAD
   gh pr list --head $(git branch --show-current)   # 이미 있는지
   ```
2. **branch 검증**: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/` prefix 권장 (글로벌 baseline). 미흡하면 사용자에게 알림 (강제 X).
3. **`writing-pr-description` skill 호출** — 4섹션(Why/What/How-to-verify/Rollback) + 제목 Conventional Commits 형식
4. **DCO 자동 감지**:
   - `.github/CONTRIBUTING.md` / `.dco-required` / 기존 commit 의 `Signed-off-by:` footer 확인
   - 필요한데 누락되면 안내 (`git commit --amend --signoff` 또는 `git rebase --signoff`)
5. **인자 처리**:
   - `--draft`: draft PR 생성
   - `--reviewer @user1`: 리뷰어 지정
   - `--dry-run`: PR 만들지 않고 본문만 출력
6. **HEREDOC 으로 PR 생성**:
   ```bash
   gh pr create --title "..." --body "$(cat <<'EOF'
   ## Why
   ...
   EOF
   )"
   ```
7. **결과 출력**: PR URL + 본문 미리보기

## 안전장치
- 머지 대상 branch 가 main/master 면 base 명시 확인
- breaking change 가 의심되면 사용자에게 묻기 (제목 prefix `!` 또는 footer)
- 1000+ 줄 PR 은 분할 권장 (사용자 결정)

## 관련
- skills: writing-pr-description / reviewing-pr (자가 점검)
- agents: pr-author (복잡한 PR 본문 초안)
- `~/.claude/CLAUDE.md` PR 본문 표준
