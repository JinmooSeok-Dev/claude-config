---
name: designing-workflow
description: 새로운 GitHub Actions 워크플로우(또는 CI/CD pipeline)를 처음부터 설계한다. Purpose 명료화, Trigger·Concurrency 결정, 4계층 분해(Trigger → Orchestrator → Reusable → Step), 컨트롤/데이터 플로우, 의존성·관측성·실패 처리를 포함한다. 사용자가 "워크플로우 설계", "CI 새로 만들어야 해", "GitHub Actions 만들어줘", "release 자동화 설계", "nightly 만들어"를 언급할 때 사용한다.
---

# Designing Workflow

새 워크플로우(또는 multi-workflow 셋)를 체계적으로 설계한다. 산출물: ① 설계 문서(또는 ADR) ② workflow YAML 초안 ③ 보조 스크립트·composite action 설계.

## 0. RIDES 원칙 (모든 단계의 기준)
- **R**eproducibility — 로컬에서 재현 가능. 핵심 로직은 별도 스크립트로 분리
- **I**dempotency — 같은 input 으로 같은 결과. rerun-safe
- **D**eterminism — SHA pinning, 도구 버전 lock, runner 버전 고정
- **E**ncapsulation — orchestrator/reusable/composite 역할 분리, secret/vars 흐름 명확
- **S**ecurity — `permissions:` 최소화, fork PR 권한 격리, secret echo 금지

## 1. Purpose 명료화
다음 중 어디에 해당하는가? (한 워크플로우는 하나의 purpose 만)
- **CI** (push/PR 시 검증)
- **CD** (배포)
- **Release** (태그/릴리즈 산출물 생성)
- **Nightly** (정기 회귀 테스트)
- **Benchmark** (성능 측정 + baseline 비교)
- **Sync/Mirror** (cross-repo 동기화)
- **Notification** (실패 시 외부 알림)
- **Multi-project orchestration** (여러 프로젝트 fan-out + 결과 집계)

→ 패턴 카탈로그는 `choosing-workflow-pattern` skill 참조.

## 2. Trigger·Schedule·Concurrency
- **Trigger**: `push` / `pull_request` / `schedule` (cron) / `workflow_dispatch` (수동) / `workflow_call` (reusable) / `repository_dispatch`
- **Schedule** (`cron`): UTC 기준. 레포가 60일 비활성이면 자동 일시 중지 — 활성 유지 plan
- **Concurrency**: 같은 ref 의 중복 실행 방지
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true   # CI 는 보통 true, release 는 false
  ```
- **paths-ignore**: 문서/마크다운 변경은 트리거 안 함 (`**.md`, `docs/**`)

## 3. 4계층 분해
```
[Trigger]                                                 (push/schedule/dispatch)
   ↓
[Orchestrator workflow]    ← 환경 변수/secrets 수집·결정·전달
   ↓ uses: ./.github/workflows/_<name>.yml
[Reusable workflow]        ← 재사용 단위, 자체 input/output, vars 직접 참조 금지
   ↓ uses: ./.github/actions/<name>
[Composite action]         ← step 묶음, env 경유 input 전달
   ↓ run: ...
[Step]                     ← 단일 책임, shell: bash + set -euo pipefail
```

**언제 쪼갤지 결정 기준**:
- 재사용 ≥ 2회 + 5줄 이상 → composite action 또는 reusable
- 같은 input 인터페이스로 여러 곳에서 호출 → reusable
- step 묶음만 추출 → composite action

## 4. 컨트롤 플로우 (job 의존성)
- **needs**: 명시적 dependency
  ```yaml
  build:
    runs-on: ubuntu-24.04
  test:
    needs: build
  publish:
    needs: [build, test]
    if: github.event_name == 'push'
  ```
- **matrix**: fan-out
  ```yaml
  strategy:
    fail-fast: false   # 한 변종 실패해도 나머지 진행
    max-parallel: 4    # runner pool 고려
    matrix:
      python: ["3.10", "3.11", "3.12"]
  ```
- **Skipped job 패턴**: optional 단계는 `if:` 로 skip, dependent 는 `success()` 로 받음 (skipped = success 처리)
- **failure() / always()**: cleanup, notification step

## 5. 데이터 플로우 (값 전달)
- **Step → Step**: `$GITHUB_OUTPUT` (멀티라인은 EOF delimiter)
- **Job → Job**: `outputs:` 선언 → `needs.<job>.outputs.<key>`
- **Workflow → Workflow**: `outputs:` (workflow_call), artifact, repository_dispatch
- **Cross-run**: artifact (단기, 90일), cache (의존성), GitHub release (영구)
- **Env**: `env:` 블록, `$GITHUB_ENV` (shell injection 방지: `${{ inputs.* }}` 는 env 경유)
- **Secrets**: orchestrator 가 결정해서 reusable 에 명시 전달. `inherit` 은 secrets 의존성 불투명하므로 신중

## 6. 의존성 명시
- **외부 action**: SHA pinning 권장 (최소 major version pin) — `actions/checkout@v4` 보다 `actions/checkout@<sha>`
- **도구 버전**: `setup-go@v5` 의 `go-version: 1.22` 정확히, `*` / `latest` 금지
- **container**: digest pinning 권장 — `image: ghcr.io/owner/img@sha256:...`

## 7. 실패 처리 & Rollback
- **Step timeout**: `timeout-minutes` (job 도 필수)
- **Retry**: 네트워크/외부 의존 step 만 (빌드/테스트는 재시도 금지 — flaky 가시성 손실)
- **Cleanup**: `if: always()` 또는 `if: failure()` 로 리소스 정리 (kubectl delete, terraform destroy)
- **Rollback**: 배포 워크플로우는 명시적 rollback step (또는 별도 workflow)
- **`continue-on-error: true`**: 단독 사용 금지 — 후속 step 에서 결과 확인 + 보고 필수

## 8. Observability
- `$GITHUB_STEP_SUMMARY` 에 markdown 결과 기록 (build artifact 위치, 테스트 통계, 회귀 표 등)
- `::notice` / `::warning` / `::error` annotation
- artifact retention 정책 (기본 90일, 단기 결과물은 짧게)
- Slack / Sentry / Notion 알림은 별도 reusable workflow 로
- SARIF 업로드 (보안 스캔 결과 → Code Scanning UI)

## 9. 체크리스트 (설계 완료 전 확인)
- [ ] Purpose 1개로 명료한가?
- [ ] Trigger 와 concurrency 가 의도와 맞는가?
- [ ] 4계층 분해 했는가? (단순 워크플로우는 1~2계층 OK)
- [ ] 모든 외부 action 이 SHA 또는 major pin 인가?
- [ ] permissions: 최소화 했는가?
- [ ] secrets 전달이 명시적인가? (`inherit` 남용 X)
- [ ] timeout 다단계 (step < job < workflow)
- [ ] 실패/취소 시 cleanup 가 있는가?
- [ ] $GITHUB_STEP_SUMMARY 로 결과 가시화?
- [ ] 핵심 로직은 별도 스크립트 / composite action 으로 추출되어 로컬 재현 가능한가?

## 10. 산출물 템플릿
설계가 끝나면 다음을 만든다:
1. **`docs/<workflow>-design.md`** (또는 ADR) — RIDES 5원칙별 설명, 4계층 다이어그램, 인터페이스
2. **`.github/workflows/<name>.yml`** — orchestrator (헤더 주석 6필드: Purpose / Trigger / Inputs / Outputs / Owner / Runbook)
3. **`.github/workflows/_<name>.yml`** (필요 시) — reusable
4. **`.github/actions/<name>/`** (필요 시) — composite + README
5. **`scripts/<name>.sh`** 또는 `.github/scripts/<name>.sh` — 핵심 로직 (`organizing-workflow-scripts` skill 참조)
6. **`.github/runbooks/<name>.md`** (운영 작업이면) — `writing-runbook` skill

## 관련 자산
- `coding-github-actions.md` rule (path-scoped, 자동 로드) — convention/architecture
- `choosing-workflow-pattern` skill — 패턴 카탈로그
- `implementing-workflow` skill — 구체 step 작성
- `organizing-workflow-scripts` skill — script 위치/구조
- `designing-composite-action` skill — composite action 설계
- `documenting-workflow` skill — 헤더/index/runbook
- `~/my_job/ci/` 시리즈 (사용자의 RIDES 상세 reference)
