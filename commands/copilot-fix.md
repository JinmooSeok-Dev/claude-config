$ARGUMENTS PR 의 Copilot 리뷰 코멘트를 수집·분류하고, 항목별 대응안을 제시한 뒤 채택분만 수정·재커밋한다.

사용 예:
- `/copilot-fix 142` — 단일 PR
- `/copilot-fix` — 현재 branch 의 PR 자동 탐지
- `/copilot-fix --all` — 본인이 author 인 현재 repo 의 OPEN PR 전부 (batch 모드)
- `/copilot-fix --all --pick` — 사전 표를 보고 번호로 선택
- `/copilot-fix --all --all-repos` — 본인의 모든 repo OPEN PR (사용 시 신중)
- `/copilot-fix 142 --dry-run` — 수정안만 출력

## 절차

### 1. PR 식별
- `--all` 플래그 → **Batch 모드** (아래 섹션 8 참조). 본인이 author 인 OPEN PR 만 대상 (다른 사람 PR 절대 자동 변경 금지)
- 인자가 PR 번호 → 그 번호 사용
- 인자 없음 → `gh pr view --json number,headRefName,baseRefName -q .` 로 현재 branch 의 PR 자동 탐지
- 그래도 없으면 사용자에게 PR 번호 요청

### 2. Copilot 코멘트 수집 (3개 엔드포인트 병렬)
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=<번호>

# (a) inline review comments — 파일/라인 단위
gh api repos/$REPO/pulls/$PR/comments --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))
        | {id, path, line, side, body, diff_hunk, in_reply_to_id, html_url}]'

# (b) review-level summaries — Copilot 의 종합 리뷰 본문
gh api repos/$REPO/pulls/$PR/reviews --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))
        | {id, state, body, submitted_at, html_url}]'

# (c) issue-level (PR 본문 하단) 코멘트
gh api repos/$REPO/issues/$PR/comments --paginate \
  --jq '[.[] | select(.user.login | test("copilot|github-copilot"; "i"))
        | {id, body, html_url}]'
```
- bot login 표기 변형: `copilot-pull-request-reviewer[bot]`, `github-copilot[bot]`, `Copilot` — 모두 `i` 옵션 정규식으로 흡수
- 결과 0건이면 사용자에게 보고 후 종료

### 3. 항목 정규화 + 표 출력
각 코멘트를 다음 행으로 정렬해 마크다운 표로 제시:

| # | 종류 | 위치 | 요지 | 신뢰도 | URL |
|---|------|------|------|--------|-----|
| 1 | inline | `pkg/foo.go:142` | nil check 누락 가능 | High | … |
| 2 | review-summary | — | 테스트 커버리지 부족 | Med | … |

- **종류**: `inline` / `review-summary` / `issue-comment`
- **신뢰도** 기준: 코드 인용 + 구체적 수정안 제시 = High, 일반론 = Low

### 4. 항목별 분류 — 채택 / 보류 / 기각
각 항목에 대해 짧게 의견(현 코드 확인 후) + 권장 액션 제시:
- **채택**: 수정안과 영향 파일/라인 명시
- **보류**: 추가 정보 필요 — 어떤 정보인지 명시
- **기각**: false positive 또는 의도된 동작 — 이유 명시

사용자에게 "이대로 진행 / 일부만 / 수정" 확인.

### 5. 채택분 반영
- 한 항목 = 한 chunk Edit (컨텍스트 충돌 방지)
- 항목별 처리 후 `git diff <파일>` 으로 변경 확인 보고
- lint/test 실행 가능하면 변경된 파일 범위로 한정 실행

### 5.5. Self-review pass — round-N+1 핑퐁 차단 (BEFORE 커밋 push)

> **이 단계는 round-1 fix 가 도입한 새 inconsistency / build-blocking 이슈 / doc-vs-code drift 를 잡아 round-2 reviewer 가 "또 같은 류" 코멘트 남기는 ping-pong 을 막는다.** 한 번의 self-review 가 평균 round-2 의 11/15 정도를 사전에 catch 한 실측 결과 (rebel-jinmoo/network-operator PR #38·#39·#40 ping-pong audit, 2026-05-04).
>
> "round-1 끝나니 round-2 가 또 와서 핑퐁 도는데 우리 self-review 안 동작해?" 류 사용자 피드백이 root cause. 이 단계가 빠지면 fix 자체에 대한 검증이 0회라 같은 패턴이 반복된다.

#### 5.5.1 Sweep — 같은 패턴이 다른 위치에 있는지 grep

`grep` 으로 같은 류의 stale phrase / 잘못된 인용 / 부정확한 컨벤션 표기 가 PR 의 다른 파일에 남아있는지 점검:

```bash
# 컴포넌트 이름 컨벤션 (camelCase vs snake_case file path)
grep -rnE 'snake_case_pattern' <changed-files>

# stale doc phrase (이전 동작 묘사)
grep -rnE 'first.*node|fall back|previous.*behavior' <changed-files>

# hardcoded 가 별도 위치에도 있는지 (e.g. ghcr.io/<your-org>)
grep -rnE 'ghcr\.io/specific-org' <PR-scope>
```

발견된 잔존은 한 chunk 에 일괄 정리. PR-wide sweep 의 재실행이 핵심.

#### 5.5.2 `code-reviewer` agent spawn (필수)

> **사전 조건**: agent 의 working tree 가 review 대상 PR branch 와 일치해야 한다. main agent 가 spawn 전에 `gh pr checkout <PR>` 또는 `git checkout <branch>` 수행. agent 는 read-only 이며 git ref 직접 디코딩이 불가하므로 worktree 기준만 본다.

각 PR 별로 agent 호출. 프롬프트는 fix 의 특성에 맞춰 high-confidence 만 reporting:

```
Read-only review of the LATEST commit on branch <branch> (commit <sha>).

Context: round-1 addressed N Copilot comments. Round-2 raised M more.
Latest commit fixes those M.
The user is frustrated by ping-pong cycles — this self-review is to
catch round-3 issues BEFORE they go to the reviewer.

Find:
1. Logical / correctness issues in the diff (does X behave as the
   new docstring describes?)
2. Doc-vs-code drift — are const docstrings, function comments,
   error messages still consistent with implementation?
3. Test coverage gaps — does the new test cover the new contract
   end-to-end? Are existing tests now incorrectly named?
4. Cross-file consistency — does the doc match the code in the
   related component / other doc?

Report only HIGH-CONFIDENCE issues. False positives waste another
round. Under 400 words.
```

여러 PR 을 처리할 땐 각 PR 별로 한 agent 씩 병렬 spawn (`Agent` tool 의 multiple-tool-call-in-one-message).

#### 5.5.3 Build / runtime 검증 — 가능하면 무조건

변경된 파일 종류에 따라:

- **Dockerfile**: `docker buildx build --check <dir>` (lint) + `docker build -t <tag> <dir>` (실제 빌드). 빌드 후 `docker run --rm <tag> --entrypoint /bin/sh -c '<sanity command>'` 로 산출물 검증. **`--check` 만으로는 부족**: `dnf install` 실패 같은 build-time 패키지 부재는 lint 가 안 잡는다.
- **Shell script**: `sh -n <file>` (POSIX syntax) + `shellcheck <file>`.
- **Go**: `go build ./... && go test ./...` (변경 패키지 우선) + `make fmt vet`.
- **Python**: `python -m py_compile` + 기존 test runner.
- **Helm chart**: `helm template <chart>` (rendering) + `helm lint <chart>`.
- **Markdown 만**: 외부 검증 도구 없으면 grep 으로 stale 패턴 확인 + 5.5.2 agent 검증으로 충분.

검증 중 발견된 결함은 추가 fix 로 반영.

#### 5.5.4 추가 fix 는 별도 commit

self-review 가 잡은 항목은 round-2 fix 와 **별도 commit** 으로 분리:

- 메시지 prefix: `fix(<area>): self-review pass — <topic>` (또는 `address Copilot round-N review`)
- 본문에 발견 경위 명시 (sweep / agent / build verification)
- round-2 fix 의 어떤 한계가 self-review 단계에서 catch 되었는지 — 다음 사이클 학습용

별도 commit 으로 두는 이유: reviewer 가 "round-2 → round-3" 를 "fix → meta-fix" 로 명확히 인식. 또한 round-3 가 또 오면 self-review pass 가 동작했는지 commit 이력으로 검증 가능.

#### 5.5.5 보고 + 다음 단계 진입

self-review 결과를 사용자에게 표로 보고:

```
PR #X round-2 self-review:
 - Sweep: K 패턴 추가 발견, 일괄 적용
 - Agent: J high-confidence finding (또는 0 건)
 - Build: <docker|sh|go> 검증 <성공|실패→fix N건>
 → +SHA <self-review-sha> on top of round-2 SHA
```

그 다음 6 단계 (커밋 push + reply) 로 진입. **self-review pass 자체는 사용자 승인 없이 수행** (read-only sweep + read-only agent + idempotent build verification 만 포함). fix commit 의 push 만 6 단계의 일반 승인 정책을 따른다.

### 6. 커밋 + 코멘트 응답 초안
- 단일 커밋 메시지 초안: `fix(<area>): address Copilot review (#<PR>)` + 본문에 항목 번호 → 변경 요약
- DCO 필요한 repo 면 `--signoff` 자동 추가 (`writing-pr-description` skill 의 DCO 감지 로직 재사용)
- 각 inline 코멘트에 답변 초안 제시 (수정한 commit SHA 인용 또는 기각 사유):
  ```bash
  gh api -X POST repos/$REPO/pulls/$PR/comments/<comment_id>/replies \
    -f body='Fixed in <SHA>. <간단 설명>'
  ```
- **커밋·push·코멘트 게시는 사용자 명시 승인 후 실행** (`apply-confirmation` 정책)

### 7. 옵션
- `--dry-run`: 5번까지 진행, 6번은 초안만 출력
- `--only <번호 범위>`: 예 `--only 1,3-5`
- `--skip-rejected`: 기각 항목 표시 생략
- `--no-reply`: 코멘트 답변 생략, 커밋만
- `--all`: batch 모드 (섹션 8)
- `--pick`: batch 모드에서 사전 표 보고 번호 선택
- `--all-repos`: batch 모드 범위를 모든 repo 로 확장
- `--auto-push`: batch 모드에서 PR 별 push 까지 일괄 자동 (단, **사용자 승인 1회 후**)

### 8. Batch 모드 (`--all`)

**대상 범위 — 항상 본인 author 만**:
```bash
# 현재 repo 한정 (기본)
gh pr list --author @me --state open \
  --json number,title,headRefName,isDraft,mergeable,baseRefName

# --all-repos: 모든 repo 까지 확장
gh search prs --author=@me --state=open \
  --json url,number,title,repository
```

**8.1 사전 스캔 표** — PR 별 Copilot 코멘트 수 미리 집계해서 우선순위 표시:

| # | PR | repo (--all-repos 시) | 제목 | Copilot 코멘트 | Draft | 충돌 | 상태 |
|---|----|----|------|---------------|-------|------|------|
| 1 | #142 | foo/bar | feat(api): … | 7 | — | — | OK |
| 2 | #145 | foo/bar | fix(ui): … | 0 | — | — | skip (코멘트 0) |
| 3 | #150 | foo/bar | refactor: … | 3 | ✓ | — | skip (draft) |
| 4 | #151 | foo/bar | chore: … | 5 | — | ✓ | skip (conflict) |

자동 skip 조건: 코멘트 0 건 / draft / mergeable=false (conflict).

**8.2 사용자 선택**:
- `--pick` 없으면: "처리 가능한 N개 PR 진행할까요?" → yes/no
- `--pick` 있으면: 표 출력 후 "어떤 번호 진행?" (예: `1,4,5` 또는 `all`)

**8.3 PR 별 loop** — 각 PR 마다:
1. head branch 로 fetch + checkout (`gh pr checkout <PR>`) — working tree dirty 면 skip
2. 단일 PR 절차(섹션 2~6) 그대로 호출
3. PR 별 결과 누적 (채택/기각/commit SHA/push 여부)
4. PR 끝마다 다음 진행 1줄 확인 — 단, `--auto-accept-high` 옵션 있으면 신뢰도 High 자동 채택

**8.4 push 일괄 처리**:
- 기본: 모든 PR commit 만 만들고, **마지막에 한 번에** "이 PR 들 push? (목록 제시)" 확인
- `--auto-push` 있으면: 시작 시점에 한 번만 승인 받고 PR 별 즉시 push
- 코멘트 답변 게시도 동일 — 마지막에 일괄 또는 `--auto-push` 시 즉시

**8.5 최종 요약 표**:
```
✓ #142  채택 5 / 기각 2  → commit abcd123 (pushed)
✓ #143  채택 3 / 기각 0  → commit ef45678 (pushed)
- #145  skip (코멘트 0)
- #150  skip (draft)
- #151  skip (conflict — 사용자 해결 필요)
✗ #152  failed: head branch checkout 실패 (dirty working tree)
```

**8.6 Rate limit / 안전 장치**:
- PR 사이 200ms sleep (gh API rate limit 보호)
- 10+ PR 처리 시 한 번 더 대상 표 보여주고 최종 확인
- `git stash` 자동 사용 금지 — dirty 면 그냥 skip + 보고
- 원래 branch 로 복귀 (`git switch -` 또는 처음 기록한 ref)

## 안전장치
- 기존 unstaged 변경 있으면 먼저 보고 (덮어쓰기 위험). batch 모드면 해당 PR skip
- Copilot 코멘트가 30건 초과하면 우선순위 상위 10건만 표 출력 + 나머지는 요약
- diff_hunk 와 현재 파일 라인이 어긋나면 (rebase·force-push 후) 해당 항목 보류 처리
- batch 모드는 **본인 author PR 만** 처리 (다른 사람 PR 의 자동 변경 금지)
- batch 모드 시작 전·후로 원래 branch / HEAD 보존

## 관련
- skills: `responding-to-copilot-review` (자연어 트리거), `reviewing-pr` (자가 점검), `writing-pr-description` (DCO 감지)
- agents: `code-reviewer` (대규모 PR 의 채택 여부 2차 검증)
- 정책: 변경은 사용자 승인 전 commit/push 금지 (`feedback_apply-confirmation`)
