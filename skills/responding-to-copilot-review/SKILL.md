---
name: responding-to-copilot-review
description: GitHub Copilot 의 PR 리뷰 코멘트(inline/review summary/issue 코멘트)를 수집·분류하고 채택/보류/기각으로 나눈 뒤 채택분만 수정·재커밋·답변 초안을 만든다. 단일 PR 또는 batch(`--all`, "내 PR 전부", "모든 PR 리뷰 대응") 모두 지원. 사용자가 "코파일럿 리뷰 대응", "copilot 코멘트 반영", "PR 리뷰 처리", "copilot 리뷰 답변", "리뷰 봇 대응", "내 PR 전부 리뷰", "PR 리스트 리뷰 대응"을 언급할 때 사용한다. /copilot-fix 슬래시 커맨드와 동일 절차.
---

# Responding to Copilot Review

GitHub Copilot 리뷰 봇이 단 코멘트를 체계적으로 수집·평가·반영하는 절차. `/copilot-fix` 커맨드의 본체.

## 1. 입력 식별
- `--all` 또는 자연어 "내 PR 전부/모든 PR" → **Batch 모드** (섹션 11)
- PR 번호 직접 지정 → 단일 PR
- 인자 없음 → 현재 branch 의 PR 자동 탐지
- 그래도 없으면 사용자 질의
- 인자 옵션: `--dry-run`, `--only <범위>`, `--skip-rejected`, `--no-reply`, `--all`, `--pick`, `--all-repos`, `--auto-push`

## 2. 수집 — 3개 엔드포인트
Copilot 은 위치에 따라 3가지로 코멘트를 남김:

| 위치 | 엔드포인트 | 특징 |
|------|----------|------|
| inline (파일/라인) | `pulls/{n}/comments` | 코드 라인 옆에 달림. 가장 actionable |
| review summary | `pulls/{n}/reviews` | 종합 평가. CHANGES_REQUESTED 등 state 동반 |
| issue-level | `issues/{n}/comments` | PR 본문 하단. 일반 의견 |

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=<번호>

gh api repos/$REPO/pulls/$PR/comments --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))]'
gh api repos/$REPO/pulls/$PR/reviews --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))]'
gh api repos/$REPO/issues/$PR/comments --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))]'
```

bot login 변형 — `copilot-pull-request-reviewer[bot]`, `github-copilot[bot]`, `Copilot` — 모두 case-insensitive 정규식으로 흡수.

## 3. 정규화 → 표

| 필드 | 의미 |
|------|------|
| 종류 | inline / review-summary / issue-comment |
| 위치 | `path:line` (inline only) |
| 요지 | body 1줄 요약 |
| 신뢰도 | 코드 인용+수정안 제시 = High, 일반론 = Low |
| URL | html_url (사용자 검증용) |

## 4. 항목별 평가 — 3분류

### 채택 (Accept)
- 실제 버그/취약점 지적
- 명백한 컨벤션 위반
- 누락된 nil/error/edge case
- 테스트 추가 권고가 합당

→ 수정안 + 영향 파일 명시

### 보류 (Defer)
- 큰 리팩터링 요구 — 별도 PR
- 컨텍스트 부족 — 사용자 판단 필요
- 다른 진행 중 PR 과 충돌

→ 보류 이유 + 후속 액션 제시 (예: TODO/Issue 생성)

### 기각 (Reject)
- false positive (Copilot 이 코드 컨텍스트 오해)
- 의도된 동작인데 봇이 일반 패턴 적용
- 이미 다른 곳에서 처리됨

→ 기각 근거 (코드/PR 본문/관련 이슈 인용)

## 5. Copilot 의 흔한 false positive

자주 나오는 패턴 — 무비판 채택 금물:

- **"이 함수에 docstring/주석 추가"** — 글로벌 룰 (`불필요한 주석/docstring 추가 금지`) 위반. 대부분 기각
- **"error 를 wrap 하세요"** — 이미 wrap 한 경우 / 의도적 sentinel error 인 경우
- **"매직 넘버 상수화"** — 한 곳에서만 쓰는 자명한 상수면 over-engineering
- **"input validation 추가"** — 내부 호출 경로면 trust boundary 밖. 시스템 경계만 검증 (`CLAUDE.md` 룰)
- **"try/catch 로 감싸세요"** — 처리 방안 없는 catch-all 은 안티패턴
- **"여기 주석으로 설명을"** — 코드가 self-explanatory 하면 거부
- **"이름을 더 길게"** — naming 은 도메인 일관성 우선

## 6. 채택분 반영
- 항목당 한 Edit chunk
- 변경 후 파일별 `git diff` 노출
- 변경된 파일에 한해 lint/test 실행 가능하면 실행

## 6.5. Self-review pass — round-N+1 핑퐁 차단 (커밋 push 전 필수)

> **빠지면 round-2 가 round-1 fix 의 새 결함을 또 잡는다.** 실측: rebel-jinmoo/network-operator PR #38·#39·#40 round-1 fix 직후, round-2 에서 받은 15개 코멘트 중 11개가 round-1 fix 가 도입한 새 inconsistency / sweep 누락 / build-blocking issue. self-review 한 번이 round-3 핑퐁의 약 2/3 를 사전 차단.

### 6.5.1 PR-wide sweep
같은 패턴이 다른 위치에도 남았는지 `grep`. 컴포넌트 이름 컨벤션 / stale phrase / hardcoded 값 / forward dead-reference. 발견되면 일괄 정리.

### 6.5.2 `code-reviewer` agent (필수)
**사전 조건**: agent 의 working tree 가 review 대상 PR branch 와 일치해야 한다 (`gh pr checkout <PR>` 또는 `git checkout <branch>` 선행). agent 는 read-only / git ref 직접 디코딩 불가 — worktree 만 본다.

병렬 spawn (PR 여러 개 batch 모드 시). 프롬프트는 high-confidence only 강조 — false positive 가 round-2 와 동급 비용.

체크 항목:
- 변경 코드의 logical correctness (새 docstring 이 묘사하는 동작이 실제 코드 동작과 일치하는가)
- doc-vs-code drift (const docstring / function comment / 에러 메시지 still consistent)
- 테스트 커버리지 (새 contract 가 end-to-end 로 테스트되는가, 기존 테스트 이름이 새 동작과 모순되진 않는가)
- cross-file consistency (관련 다른 doc / sibling component 와 일치)

### 6.5.3 Build / runtime 검증
변경된 파일 종류별:
- **Dockerfile**: `docker buildx build --check` (lint) + `docker build` (실제) — `--check` 만으론 패키지 부재 catch 못 함
- **Shell**: `sh -n` + `shellcheck`
- **Go**: `go build && go test` + `make fmt vet`
- **Python**: `python -m py_compile` + 기존 test runner
- **Helm chart**: `helm template` + `helm lint`
- **Markdown 만**: 6.5.2 의 agent 검증 + 6.5.1 의 grep 으로 충분

### 6.5.4 추가 fix 는 별도 commit
self-review 가 잡은 항목은 round-2 fix 와 별도 commit 으로:
- 메시지 prefix: `fix(<area>): self-review pass — <topic>`
- 본문에 발견 경위 (sweep / agent / build verification) 명시
- round-3 가 또 와도 self-review pass 가 동작했는지 commit 이력으로 검증 가능

### 6.5.5 사용자 승인
self-review pass 자체 (read-only sweep + read-only agent + idempotent build) 는 사용자 승인 없이 수행. 그 결과로 만든 fix commit 의 push 만 7 단계의 일반 승인 정책을 따른다.

## 7. 커밋 + 답변 초안

### 커밋 메시지 형식
```
fix(<area>): address Copilot review (#<PR>)

- #1: nil check 추가 (pkg/foo.go:142)
- #3: 누락 case 추가 (cmd/run.go:80)
- #5: false positive — 의도된 동작 (답변만)
```

DCO 필요한 repo (예: llm-d, kubernetes) 는 `--signoff` 자동. `writing-pr-description` skill 의 감지 로직 재사용.

### inline 코멘트 답변
```bash
gh api -X POST repos/$REPO/pulls/$PR/comments/<id>/replies \
  -f body='Fixed in <SHA>. <한 줄 설명>'
```

기각 시:
```bash
gh api -X POST repos/$REPO/pulls/$PR/comments/<id>/replies \
  -f body='Intentional. <근거 — 코드/이슈 링크>.'
```

### 정책
- **commit / push / comment 게시는 모두 사용자 승인 후** (`feedback_apply-confirmation`)
- dry-run 모드면 7번까지 초안만 출력

## 8. 흔한 함정
- ❌ 모든 코멘트 무비판 채택 → noise commit / 의도 손상
- ❌ 모든 코멘트 무시 → 진짜 버그 누락
- ❌ 코멘트마다 별도 commit → 노이즈, 한 커밋에 묶기
- ❌ 답변 없이 그냥 close → 후임자가 맥락 잃음
- ❌ Copilot 의 "주석 추가" 권고를 글로벌 룰 위반인데 채택 → CLAUDE.md 정책과 충돌

## 9. 30건 초과 시
- 우선순위 상위 10건만 표 + 나머지는 카테고리 요약
- 우선순위: bug/security > test/edge-case > convention > 그 외

## 10. 관련 자산
- `/copilot-fix` 커맨드 (이 skill 의 명시 호출)
- `reviewing-pr` skill — 자가 점검 (Copilot 이 놓친 항목 보강)
- `writing-pr-description` skill — DCO 감지 재사용
- `code-reviewer` agent — 대규모 PR 의 채택 여부 2차 검증
- 글로벌 룰: `~/.claude/CLAUDE.md` (주석/검증/에러 처리 정책)

## 11. Batch 모드 (`--all`) — 본인 OPEN PR 일괄 처리

**대상은 항상 본인이 author 인 OPEN PR 만**. 다른 사람 PR 의 자동 변경은 절대 금지.

### 11.1 대상 수집
```bash
# 현재 repo (기본)
gh pr list --author @me --state open \
  --json number,title,headRefName,isDraft,mergeable,baseRefName

# --all-repos: 본인이 만든 모든 repo OPEN PR
gh search prs --author=@me --state=open \
  --json url,number,title,repository
```

### 11.2 사전 스캔 — PR 별 Copilot 코멘트 수 집계

| # | PR | repo | 제목 | Copilot 코멘트 | Draft | 충돌 | 상태 |
|---|----|------|------|---------------|-------|------|------|
| 1 | #142 | foo/bar | feat(api): … | 7 | — | — | OK |
| 2 | #145 | foo/bar | fix(ui): … | 0 | — | — | skip (코멘트 0) |
| 3 | #150 | foo/bar | refactor: … | 3 | ✓ | — | skip (draft) |

**자동 skip 조건**: 코멘트 0건 / draft=true / mergeable=false (conflict).

### 11.3 사용자 선택
- 기본: "처리 가능한 N개 PR 진행할까요?" — 하나의 yes/no
- `--pick`: 표 출력 후 "어떤 번호?" → `1,4,5` 또는 `all`

### 11.4 PR 별 처리 loop
각 PR 마다:
1. **원래 branch 기록**: `ORIGINAL=$(git symbolic-ref --short HEAD)`
2. `gh pr checkout <PR>` — working tree dirty 면 skip + 보고
3. 단일 PR 절차(섹션 2~7) 호출 — commit 까지만
4. 결과 누적: 채택/기각/commit SHA
5. 다음 PR 안내 (1줄 확인) — `--auto-accept-high` 면 자동

### 11.5 push / 코멘트 게시 정책
- **기본**: 모든 PR commit 만 만들고 마지막에 일괄 push 확인 (1회)
- `--auto-push`: 시작 시점 1회 승인 후 PR 별 즉시 push
- 코멘트 답변 게시는 push 와 동일 시점에 처리

### 11.6 종료 후
- `git switch $ORIGINAL` 또는 stash 안 한 상태로 복귀
- 최종 요약 표:
  ```
  ✓ #142  채택 5 / 기각 2  → commit abcd123 (pushed)
  ✓ #143  채택 3 / 기각 0  → commit ef45678 (pushed)
  - #145  skip (코멘트 0)
  - #150  skip (draft)
  ✗ #152  failed: dirty working tree
  ```

### 11.7 안전 장치
- `git stash` 자동 사용 **금지** — dirty 면 명확히 skip + 보고
- PR 사이 200ms sleep (gh rate limit 보호)
- 10+ PR 처리 시 대상 표 한 번 더 보여주고 최종 확인
- batch 종료 후 원래 branch / HEAD 보존 검증
- `--all-repos` 는 명시적일 때만 — 기본은 현재 repo 한정
