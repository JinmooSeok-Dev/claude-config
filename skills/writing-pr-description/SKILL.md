---
name: writing-pr-description
description: PR 본문을 표준화해서 작성한다. Why / What changed / How to verify / Rollback 4섹션 + Conventional Commits 제목 + DCO 자동 감지(llm-d 등) + breaking change 마커 + test plan + screenshot/log evidence. /user:pr command 의 핵심 절차. 사용자가 "PR 본문", "PR 설명", "PR 만들어줘", "pr description"을 언급할 때 사용한다.
---

# Writing PR Description

PR 본문을 일관된 구조로 작성. 리뷰어가 30초 안에 핵심 파악할 수 있도록.

## 1. 제목 (Conventional Commits)
```
<type>(<scope>): <subject 한 줄>
```

**type**:
- `feat` — 신규 기능
- `fix` — 버그 수정
- `chore` — 유지보수 (dep, ci, format)
- `docs` — 문서만
- `refactor` — 리팩토링 (기능 변화 X)
- `test` — 테스트만
- `perf` — 성능 개선

**scope**: 변경 영역 (예: `controller`, `auth`, `workflow`)
**subject**: 한 줄 명령형 (예: "fix race condition in status update")
**길이**: 70자 이내 권장

## 2. 본문 4섹션 (필수)
```markdown
## Why
<왜 이 변경이 필요한가 — 배경/문제>
- 관련 이슈: #123 (close/fix/resolve)
- 발생 빈도/영향: ...

## What changed
<무엇이 바뀌었는가 — 요점만, diff 가 자세한 건 보여줌>
- A 컴포넌트의 X 로직을 Y 로
- B 의존성 v1.2 → v1.3
- 테스트: 단위 테스트 N건 추가

## How to verify
<리뷰어/QA 가 어떻게 검증하나 — 재현 단계 + 기대 결과>
1. \`make test-controller\` → 모든 테스트 통과
2. dev cluster 에 deploy:
   \`\`\`bash
   kubectl apply -f config/samples/...
   kubectl get foo
   \`\`\`
   → status.phase == "Ready"
3. 로그에서 race 발생 안 함

## Rollback
<문제 시 어떻게 되돌리나>
- DB 마이그레이션 X — 단순 revert OK
- 또는: \`kubectl rollout undo deploy/foo\`
- 또는: feature flag \`X_ENABLED=false\` 로 무력화
```

## 3. 추가 섹션 (해당 시)

### Breaking change
```markdown
## ⚠️ Breaking Change
- API 변경: `/v1/foo` 응답 필드 `bar` → `baz`
- 마이그레이션 필요: 클라이언트 v2.5+ 권장
```
+ commit 메시지에 `BREAKING CHANGE:` footer

### Test plan (체크박스)
```markdown
## Test Plan
- [x] 단위 테스트 추가 / 통과
- [x] 통합 테스트 (envtest)
- [ ] E2E (kind) — 다음 PR
- [x] 로컬 dev cluster 검증
- [x] 메트릭 대시보드 확인
```

### Screenshot / Log evidence
```markdown
## Evidence
**Before**:
\`\`\`
... 실패 로그 ...
\`\`\`

**After**:
\`\`\`
... 정상 로그 ...
\`\`\`
```

## 4. DCO 자동 감지
다음 repo 는 DCO signoff 필수 (`Signed-off-by:` footer):
- `llm-d/*`
- 다른 OSS 기여 시 (CONTRIBUTING.md 확인)

```bash
git commit -s -m "..."   # 자동 sign-off
```

또는 PR 만들기 전 후속 커밋:
```bash
git commit --amend --signoff
```

감지 방법:
1. `.dco-required` 또는 `.github/CODEOWNERS` 확인
2. 기존 commit 의 footer 패턴 확인
3. CONTRIBUTING.md 검색

## 5. Issue 연결
- `Closes #123` / `Fixes #123` / `Resolves #123` (자동 close)
- `Refs #123` (참조만)
- 외부 tracker: `JIRA-456`, `LINEAR-XYZ`

## 6. 리뷰어 호출
- `@user1 @user2` 명시 호출
- CODEOWNERS 가 자동 할당하지만, 특정 영역 전문가 추가 호출 권장

## 7. Draft vs Ready
- 작업 진행 중 / 피드백만 원함 → **Draft** (`gh pr create --draft`)
- 머지 가능 → **Ready for review**

## 8. PR 크기 가이드
| 라인 수 | 리뷰 시간 | 권장 |
|---|---|---|
| < 100 | 10분 | ✅ ideal |
| 100~400 | 30분 | OK |
| 400~1000 | 1시간+ | 분할 검토 |
| 1000+ | 2시간+ | **분할 권장** (cleanup PR + 본 변경 분리) |

## 9. PR 생성 명령
```bash
gh pr create \
  --title "feat(controller): add finalizer cleanup" \
  --body-file /tmp/pr-body.md \
  --base main \
  --draft   # 또는 --reviewer @user1
```

또는 HEREDOC:
```bash
gh pr create --title "..." --body "$(cat <<'EOF'
## Why
...
EOF
)"
```

## 10. 흔한 함정
- ❌ 제목만 (본문 빈 PR) — 리뷰어 추측만
- ❌ "fix bug" 같은 모호한 메시지
- ❌ How to verify 없음 → QA 어려움
- ❌ Rollback 없음 → 사고 시 패닉
- ❌ Breaking change 마커 누락 → 사용자 충격
- ❌ 1000+ 줄 PR — 깊이 리뷰 불가

## 관련 자산
- `reviewing-pr` skill (리뷰어 측)
- `pr-author` agent (PR 본문 초안 작성)
- `coding-github-actions.md` rule (CI 변경 시)
- `~/.claude/CLAUDE.md` PR 본문 표준 섹션
