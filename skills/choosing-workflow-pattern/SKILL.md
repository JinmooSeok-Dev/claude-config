---
name: choosing-workflow-pattern
description: 워크플로우 작성 시 적합한 패턴(Build & Publish / Nightly / Benchmark / Release / Notification / Sync / Long-running self-hosted / Multi-project orchestration)을 선택한다. 각 패턴의 적용 시점, 안티패턴, 출구 조건을 가이드한다. 사용자가 "어떤 패턴이 맞을까", "어떻게 구성하지", "이런 워크플로우 필요한데", "release 자동화", "nightly", "benchmark"를 언급할 때 사용한다.
---

# Choosing Workflow Pattern

목적·제약에 맞는 워크플로우 패턴을 선택한다. 각 패턴마다 **언제 쓸지 / 핵심 step / 안티패턴 / 출구 조건**.

## 1. Build & Publish (CI/CD 기본)
**언제**: push/PR 마다 빌드 → 테스트 → (main 만) artifact/이미지 publish
**핵심 step**:
```
checkout → setup tool → cache → build → test → (조건부) publish
```
**Cache 키**: `hashFiles('go.sum')` / `hashFiles('package-lock.json')` / `hashFiles('uv.lock')`
**안티패턴**: 모든 PR 에서 push 까지 수행 → ghcr 오염
**출구**: artifact 보존 (PR=7일, main=90일), digest 출력 → 후속 deploy 워크플로우 input

## 2. Nightly Test (matrix fan-out + aggregate)
**언제**: 시간 오래 걸리거나 외부 자원 필요한 회귀 테스트 (E2E, integration)
**핵심**:
- `schedule: cron: '0 18 * * *'` (UTC)
- `matrix:` 로 환경/버전 fan-out
- 각 leaf job 은 결과를 artifact 로 업로드
- 마지막 aggregate job 이 모든 artifact 다운로드 → 통합 보고서 → Slack
**안티패턴**:
- 60일 무업데이트 → cron 자동 정지. workflow_dispatch 도 함께 두기
- 일부 matrix 실패 시 전체 stop → `fail-fast: false` 필수
**출구**: `$GITHUB_STEP_SUMMARY` + Slack thread + 실패한 matrix 의 artifact 보존

## 3. Benchmark (warm-up → measure → compare baseline)
**언제**: 성능 회귀 자동 감지
**핵심**:
1. 환경 fix (GPU/CPU pin, freq lock, NUMA 고정)
2. warm-up runs (cache/JIT 안정화) — 결과 버림
3. measure runs ≥ 3회, **median + p50/p95/p99**
4. baseline 비교 (이전 run artifact 또는 main 의 결과)
5. threshold 초과 (예: p99 +5%) → workflow fail
6. 결과를 markdown 표 + plot 으로 step summary
**안티패턴**:
- shared runner 에서 측정 → noise. self-hosted dedicated 권장
- 단일 run 측정 → 분산 무시
- baseline 없이 절대값만 → trend 못 봄
**출구**: 결과 artifact + `bench-summarize` command 로 표 정리 + 회귀 시 Slack

## 4. Release (tag → notes → artifact → publish)
**언제**: `v*` 태그 push 또는 수동 dispatch
**핵심**:
1. semver 검증 (tag 형식)
2. CHANGELOG 생성 (`git log` 또는 `release-please`)
3. artifact 빌드 (멀티 플랫폼은 matrix)
4. signature/attestation (cosign, sigstore, SBOM)
5. GitHub Release 생성 + artifact 첨부
6. registry push (ghcr/docker hub) — digest pinning
7. 다른 repo 에 dispatch (모노레포가 아닌 경우)
**안티패턴**:
- main 에 직접 commit + tag 동시 → race
- `cancel-in-progress: true` → release 중간 취소 위험. **release 는 false**
- pre-release vs stable 미구분
**출구**: GitHub Release URL + digest + 후속 deploy dispatch

## 5. Notification (failure aggregation)
**언제**: 다른 워크플로우의 실패를 외부(Slack/Sentry/Notion)에 알림
**핵심**:
- `workflow_run` 트리거 (다른 워크플로우 완료 시)
- `if: ${{ github.event.workflow_run.conclusion == 'failure' }}`
- 실패 step / 로그 일부 / artifact 링크 추출
- Slack thread 로 묶기 (같은 ref 는 같은 thread)
**안티패턴**:
- 각 워크플로우에 직접 Slack 호출 → 중복 + secret 분산
- 너무 자세한 알림 → 노이즈
**출구**: 별도 reusable workflow `_notify-slack.yml` + composite action `sentry-report`

## 6. Sync / Mirror (cross-repo)
**언제**: 다른 repo 에 PR 생성 / mirror push / artifact 동기화
**핵심**:
- PAT (또는 GitHub App) 으로 다른 repo 권한 (기본 GITHUB_TOKEN 은 같은 repo 만)
- `peter-evans/create-pull-request` 또는 직접 `gh pr create`
- 충돌 처리: 동일 branch 가 있으면 force-push 인가, append commit 인가?
**안티패턴**:
- PAT 만료/회전 미감지 → 어느 날 조용히 실패
- mirror 가 양방향 → 무한 루프
**출구**: 생성된 PR URL 출력 + 알림

## 7. Long-running on Self-hosted (heartbeat + dead-runner detection)
**언제**: 자체 GPU/NPU runner 에서 1시간+ 실행 (벤치, 학습, E2E)
**핵심**:
- self-hosted runner labeling (`runs-on: [self-hosted, gpu, atom-ext]`)
- heartbeat: N분마다 `$GITHUB_STEP_SUMMARY` 업데이트 또는 별도 metric push
- timeout 보수적 (job timeout 90분 권장)
- runner 죽으면 → `actions/runner` 의 OS 서비스 재시작 trigger
- artifact 는 중간 결과도 주기적으로 업로드 (retention 짧게)
**안티패턴**:
- timeout 무한대 → runner 영구 점유
- workspace 정리 안 함 → disk 가득 (next job 실패)
**출구**: 결과 artifact + cleanup step + `if: always()`

## 8. Multi-project Orchestration (dispatch fan-out + status polling)
**언제**: 여러 repo 의 워크플로우를 한 번에 띄우고 결과 집계 (사용자의 fsw-integration 류)
**핵심**:
- 오케스트레이터 워크플로우가 `gh workflow run --repo <owner/repo>` 로 fan-out
- run id 캡처 → polling: `gh run watch <id>` 또는 주기 `gh run view <id> --json conclusion`
- timeout (각 child 별, 전체 별)
- 모든 child 결과 집계 → 통합 보고서
- secret/vars 는 오케스트레이터에서 모두 결정 (reusable 원칙)
**안티패턴**:
- child 실패 → orchestrator 도 즉시 실패 (다른 child 정리 안 됨). `continue-on-error: true` + 후속 집계
- polling 간격 1초 → API rate limit
- secrets 를 child 에 그대로 forward → 권한 노출
**출구**: 모든 child 의 run URL + 통합 결과 markdown

---

## 패턴 결정 가이드 (Decision Tree)
```
주기적 자동 실행?  ── yes ── 성능 측정?         ── yes ── #3 Benchmark
   │                          │
   no                          no ── #2 Nightly
   │
태그 기반 산출물? ── yes ── #4 Release
   │
다른 repo 영향? ── yes ── 단순 알림? ── yes ── #5 Notification
   │                       │
   no                       no  ── 산출물 sync? ── yes ── #6 Sync
   │                                              │
push/PR 시 검증?               ── yes ── #1 Build & Publish
   │
긴 실행 + 전용 runner? ── yes ── #7 Long-running self-hosted
   │
여러 repo 통합? ── yes ── #8 Multi-project orchestration
```

## 안티패턴 — 모든 패턴 공통
- ❌ `runs-on: ubuntu-latest` (버전 고정 안 됨, breaking change 노출)
- ❌ external action `@main` 또는 `@master` (mutable)
- ❌ secrets 를 PR 본문/이슈로 echo
- ❌ `${{ }}` 안에 사용자 입력 (issue title, PR body) 직접 삽입 → injection
- ❌ `pull_request_target` 에서 fork 코드 checkout (권한 노출)
- ❌ shell 미명시 (container 환경에서 sh 가 기본)
- ❌ `set -euo pipefail` 누락 (pipe 중간 실패 무시)

## 관련 자산
- `designing-workflow` skill — 설계 절차
- `implementing-workflow` skill — step 구체 작성
- `auditing-workflow` skill — 보안 점검
- `coding-github-actions.md` rule
