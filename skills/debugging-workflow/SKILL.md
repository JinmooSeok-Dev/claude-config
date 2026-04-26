---
name: debugging-workflow
description: GitHub Actions 워크플로우 실패 원인을 체계적으로 추적하고 수정한다. gh CLI로 로그 수집, 실패 step의 shell/env/inputs 분석, 로컬 재현, 가설별 수정안 도출, rerun까지 안내한다. 사용자가 "워크플로우 실패", "actions 에러", "CI 실패", "왜 빨갛게 됐어", "workflow 디버깅"을 언급할 때 사용한다.
---

# Debugging Workflow

체계적인 워크플로우 실패 분석. 산출물: 가설 → 수정 → 검증.

## 0. 출발점 — 어떤 run 인가?
필요 정보:
- repo (owner/name)
- 실패한 run 의 URL 또는 run id
- 워크플로우 파일 경로

명시 안 됐으면:
```bash
# 마지막 실패 run 자동 식별
gh run list --repo <owner/name> --status failure -L 5
gh run view <run-id> --log-failed   # 실패 step 로그만
```

## 1. 로그 수집 (1차 신호)
```bash
gh run view <run-id>                  # 요약 (어느 job/step 실패)
gh run view <run-id> --log-failed     # 실패 step 의 stdout/stderr
gh run view <run-id> --json conclusion,jobs --jq '.jobs[] | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure")]}'
```

artifact 가 있으면 다운로드:
```bash
gh run download <run-id> --dir /tmp/run-<id>
```

## 2. 실패 분류 (가설 좁히기)
| 증상 | 가설 | 확인 |
|---|---|---|
| `command not found` | 도구 미설치 / PATH 누락 | step 의 `setup-*` 액션 확인 |
| `Permission denied` | secret 누락 / RBAC | `permissions:`, secret 이름 매칭 |
| `Input required and not supplied: X` | 누락 또는 `${{ }}` evaluation 빈 값 | orchestrator 가 `vars.*`/`secrets.*` 결정했는지 |
| YAML syntax error | indent / `>` vs `\|` / 따옴표 | `actionlint` 로컬 실행 |
| shell 문법 오류 (`[[: not found`, `Bad substitution`) | container 가 sh 기본 | `shell: bash` 명시 |
| `Resource not accessible by integration` | GITHUB_TOKEN 권한 부족 | `permissions:` 에 해당 권한 |
| `Run was canceled` | concurrency cancel-in-progress | 의도한 패턴인지 |
| 타임아웃 | step / job / workflow timeout | 어느 레벨인지 step summary 확인 |
| flaky (재실행하면 통과) | 외부 의존 / race / rate limit | retry 패턴 후보 |

## 3. 로컬 재현 시도
재현 가능성은 **수정 가능성의 90%**. 가능하면 항상.

### 3-1. 핵심 로직이 별도 스크립트인 경우
```bash
# 환경변수 세팅 (workflow 의 env 와 동일하게)
export INPUT_X=...
export GITHUB_REF=...
./scripts/<failed-script>.sh
```

### 3-2. 인라인 run 인 경우 (재현 어려움)
- 별도 스크립트로 추출해서 재현 (refactoring opportunity)
- `act` 로 로컬 실행 시도:
  ```bash
  act -j <job-id> --container-architecture linux/amd64
  ```
  주의: self-hosted runner / matrix 일부는 `act` 가 한계

### 3-3. container 환경 차이
shell 문법 오류면 container image 확인:
```bash
docker run --rm <image> sh -c 'which bash; bash --version'
```

## 4. 가설 검증 — 자주 나오는 fix
- **shell 미명시** → job-level `defaults.run.shell: bash` 또는 step-level `shell: bash`
- **`vars.*` 가 빈 값** → orchestrator 에서 fallback chain (`${{ inputs.x \|\| vars.X \|\| 'default' }}`)
- **secret 이름 오타** → repo Settings > Secrets 에서 실제 키 확인
- **action 버전 deprecation** → `node 16` actions deprecated (2024.10 이후) → `@v4` 등 최신
- **`pull_request_target` + fork checkout** → 보안 위험. `pull_request` 로 변경 또는 fork 차단
- **`$GITHUB_OUTPUT` 멀티라인 깨짐** → EOF delimiter 패턴
  ```bash
  {
    echo "result<<EOF"
    cat result.txt
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
  ```
- **timeout 상향만으로 해결 시도** → 근본 원인(외부 의존, 큰 파일) 먼저 보기
- **flaky** → retry 가 답이 아닐 수 있음. flake 격리 (별도 job + `continue-on-error: true` + 알림)

## 5. 수정 적용
1. 가설 1개씩 수정 (multiple change → 어떤 것이 fix 였는지 모름)
2. 로컬에서 재검증 (가능하면)
3. branch push → run 결과 확인
4. 수정 commit message 는 `fix(workflow): <name> — <원인 한 줄>`

## 6. rerun 옵션
- 일부 job 만: `gh run rerun <run-id> --failed`
- 전체: `gh run rerun <run-id>`
- 다른 input 으로: workflow_dispatch 면 `gh workflow run`

## 7. 회고 (반복 발생 방지)
실패 패턴이 반복되면:
- runbook 추가 (`writing-runbook` skill)
- 감지 hook 추가 (`auditing-workflow` skill 의 결과 적용)
- 핵심 로직 별도 스크립트 분리 → 로컬 재현 가능

## 흔한 실수
- ❌ 로그 한 부분만 보고 결론 — 항상 실패 step 의 **전체** stderr 읽기
- ❌ "재실행하면 됨" 으로 종결 — flaky 는 격리해서 가시화
- ❌ timeout 늘리기로 해결 — 근본 원인 우회
- ❌ secret 권한을 넓혀서 해결 — 최소 권한 원칙 위배

## 관련 자산
- `coding-github-actions.md` rule (흔한 함정 표 포함)
- `auditing-workflow` skill (보안/품질 점검)
- `refactoring-workflow` skill (중복/추출)
- `~/my_job/ci/02-workflow-debugging.md` (사용자의 깊은 reference)
