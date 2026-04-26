---
name: auditing-workflow
description: GitHub Actions 워크플로우의 보안·품질 점검을 수행한다. SHA pinning 누락, pull_request_target 위험, secret echo, permissions 최소화, ${{ }} injection(이슈 제목/PR 본문), 멀티 라이너 함정 등을 검사하고 점검 보고서를 만든다. 사용자가 "워크플로우 보안 점검", "이 워크플로우 안전해", "audit", "취약점 검사", "secret 노출"을 언급할 때 사용한다.
---

# Auditing Workflow

워크플로우의 보안·품질 점검 (정적 분석 + 휴리스틱).

## 1. 입력
- 점검 대상: 단일 파일 `.github/workflows/<name>.yml` 또는 디렉토리 전체
- 추가: composite action `.github/actions/<name>/action.yml`

## 2. 체크 항목 (우선순위 순)

### P0 (즉시 수정 필요)
1. **`pull_request_target` + fork checkout**
   - 위험: fork 코드가 elevated permission + secrets 로 실행
   - 패턴: `on: pull_request_target` + `actions/checkout` (with `ref: ${{ github.event.pull_request.head.sha }}`)
   - 수정: `on: pull_request` 사용 또는 fork 차단 (`if: github.event.pull_request.head.repo.full_name == github.repository`)

2. **secret echo / mask 우회**
   - 패턴: `echo "${{ secrets.X }}"`, `echo $X >> log`, `printenv` 전체 출력
   - 수정: secret 은 출력 금지. 디버깅 시에도 partial mask 사용

3. **`${{ }}` injection (untrusted user input)**
   - 위험 입력: `github.event.issue.title`, `github.event.issue.body`, `github.event.pull_request.title`, `github.event.pull_request.body`, `github.event.comment.body`, `github.event.head_commit.message`
   - 패턴:
     ```yaml
     run: |
       echo "${{ github.event.issue.title }}"   # 위험
     ```
   - 수정: env 경유
     ```yaml
     env:
       TITLE: ${{ github.event.issue.title }}
     run: echo "${TITLE}"
     ```

### P1 (보안 권장)
4. **외부 action SHA pinning 누락**
   - 패턴: `uses: foo/bar@v1` 또는 `uses: foo/bar@main`
   - 수정: `uses: foo/bar@<full-40-char-sha>  # v1.2.3`
   - 검사: `grep -E 'uses: [^@]+@(main|master|v?[0-9])' .github/workflows/*.yml`

5. **`permissions:` 미명시 또는 과도**
   - 기본 GITHUB_TOKEN permissions 가 repo 설정에 따라 read-all/write-all
   - 워크플로우 레벨에 명시:
     ```yaml
     permissions:
       contents: read     # 최소
       # 필요 시 추가:
       # pull-requests: write   (PR comment 시)
       # packages: write        (ghcr push)
     ```

6. **fork PR 에서 secret 접근 시도**
   - 패턴: `on: pull_request` 에서 `secrets.X` 사용 (fork PR 은 secret 못 받음)
   - 수정: 명시적 fork 분기 또는 `pull_request_target` (위 P0 주의)

### P2 (품질)
7. **`runs-on: ubuntu-latest`**
   - 수정: `ubuntu-24.04` 등 버전 고정

8. **`shell: bash` 미명시**
   - 수정: job-level `defaults.run.shell: bash` 또는 step-level

9. **`set -euo pipefail` 누락**
   - run 의 첫 줄에 명시 (container 환경에서 기본값 보장 안 됨)

10. **`timeout-minutes` 미설정**
    - 무한 hang → runner 점유. job 마다 명시.

11. **`concurrency:` 미명시**
    - 같은 ref 의 중복 run → 자원 낭비. 의도하지 않은 race.

12. **composite action 의 inputs 가 run 에 직접 삽입**
    - injection. env 경유 필수.

13. **deprecated action / API**
    - `actions/setup-node@v3` (node 16, deprecated)
    - `::set-output` syntax → `$GITHUB_OUTPUT`

### P3 (관찰성·운영)
14. **`$GITHUB_STEP_SUMMARY` 미사용**
    - 결과 가시성 없음. 빌드 산출물, 테스트 통계, 회귀 표를 summary 에 기록

15. **artifact retention 무한**
    - 기본 90일. 단기 결과 (PR build) 는 짧게 (`retention-days: 7`)

16. **runbook 부재**
    - 운영 워크플로우 (nightly/release/deploy) 는 runbook 필수

## 3. 검사 도구
1. **actionlint** — 정적 분석 (P1, P2 다수 검출)
   ```bash
   actionlint .github/workflows/*.yml
   ```
2. **shellcheck** — `run:` 블록의 shell 코드
   ```bash
   actionlint -shellcheck=
   ```
3. **gitleaks / trufflehog** — secret 노출 검사
4. **OSSF Scorecard** — repo 전체 보안 점수
5. **codeql action security extended** — workflow 도 분석 가능

## 4. 보고서 형식
```markdown
# Workflow Audit: <repo>

검사 시점: 2026-04-26
대상: .github/workflows/*.yml (40개), .github/actions/* (20개)

## P0 — 즉시 수정 (3건)
1. `vllm_rbln_nightly_e2e.yaml:42` — `pull_request_target` + fork checkout
   - 영향: fork PR 작성자가 GHCR push 권한 획득 가능
   - 수정: ...

## P1 — 보안 권장 (12건)
...

## P2 — 품질 (24건)
...

## 통과 항목
- 모든 workflow 가 `permissions:` 명시 ✓
- 모든 composite action 에 README ✓
```

## 5. 흔한 우회 시도
- "그냥 `secrets: inherit` 으로" → reusable 의 secret 의존성 불투명. 명시적 전달 권장
- "shellcheck 끄자" → 진짜 문제 가린다. 예외는 inline `# shellcheck disable=SC2086`
- "이건 internal repo 라 괜찮음" → 권한 노출 / 실수 위험은 동일

## 관련 자산
- `coding-github-actions.md` rule
- `debugging-workflow` skill (실패 분석)
- `refactoring-workflow` skill (수정 적용)
- `security-auditor` agent (있으면 호출)
