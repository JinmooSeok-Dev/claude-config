---
name: implementing-workflow
description: 설계된 워크플로우를 실제 YAML/composite action/스크립트로 구현한다. step의 단일 책임, 합성 vs 상속(composite vs reusable), input/output 인터페이스, 실패 격리, 멱등성, retry/timeout 다단계를 가이드한다. 사용자가 "워크플로우 구현", "step 추가", "이 step 어떻게 짜지", "reusable로 빼", "composite action으로 만들어"를 언급할 때 사용한다.
---

# Implementing Workflow

설계 단계가 끝난 워크플로우의 실제 코드를 작성한다.

## 1. Step 단일 책임 원칙
- 한 step 은 한 가지 일만 — name 으로 정확히 표현
- 너무 길어지면 별도 step 으로 분리 (병렬은 안 되지만 가시성 ↑)
- 5줄 이상의 인라인 run 은 별도 스크립트로 추출 (`organizing-workflow-scripts` skill)

```yaml
# 나쁨: 한 step 에 빌드+테스트+푸시
- name: Build, test, push
  run: |
    go build ...
    go test ...
    docker push ...

# 좋음: 분리
- name: Build
  run: go build -o bin/app ./cmd/app
- name: Test
  run: go test -race ./...
- name: Push
  if: github.ref == 'refs/heads/main'
  run: docker push ...
```

## 2. 합성 vs 상속 — 어디로 추출하나?
| 방법 | 사용처 | 인터페이스 | 비고 |
|---|---|---|---|
| **Inline run** | 1회성, 5줄 이내 | env / secrets | 가장 단순 |
| **Composite action** (`.github/actions/<name>/`) | step 묶음 재사용 (≥ 2회) | inputs/outputs | YAML 만, 같은 repo 내 호출 가능 |
| **Reusable workflow** (`.github/workflows/_<name>.yml`) | job(들) 재사용 | inputs/outputs/secrets | matrix·needs 등 풀 기능, 다른 repo 에서도 호출 |
| **별도 스크립트** | 복잡한 로직, 로컬 재현 필요 | env / 인자 | 어디서나 호출, ShellCheck 가능 |

추출 비용 임계: **재사용 ≥ 2회 + 5줄 이상**.

## 3. Input / Output 인터페이스 설계
**원칙**:
- 이름은 **도메인 일반화** (`ghcr_jinmoo_username` ❌ → `ghcr_username` ✅)
- 모든 input 은 사용처가 명확. 안 쓰면 제거
- required 와 optional 명확히, optional 은 합리적 default
- output 은 caller 가 실제로 쓰는 것만

```yaml
# composite action.yml 예
inputs:
  image-tag:
    description: "Image tag to publish"
    required: true
  registry:
    description: "Container registry URL"
    required: false
    default: ghcr.io
outputs:
  digest:
    description: "Pushed image digest"
    value: ${{ steps.push.outputs.digest }}
runs:
  using: composite
  steps:
    - name: Push
      id: push
      shell: bash
      env:
        IMAGE_TAG: ${{ inputs.image-tag }}
        REGISTRY: ${{ inputs.registry }}
      run: |
        set -euo pipefail
        docker push "${REGISTRY}/${IMAGE_TAG}"
        digest=$(docker inspect "${REGISTRY}/${IMAGE_TAG}" --format '{{index .RepoDigests 0}}')
        echo "digest=${digest}" >> "$GITHUB_OUTPUT"
```

## 4. Shell Injection 방지 — env 경유 필수
```yaml
# 나쁨: shell injection 가능
- run: |
    echo "${{ inputs.version }}"
    [[ "${{ inputs.flag }}" == "true" ]] && do_x

# 좋음: env 경유
- env:
    VERSION: ${{ inputs.version }}
    FLAG: ${{ inputs.flag }}
  run: |
    echo "${VERSION}"
    [[ "${FLAG}" == "true" ]] && do_x
```

## 5. 실패 격리 vs Fail-fast
| 상황 | 정책 |
|---|---|
| matrix 변종이 독립적 (Python 3.10/3.11/3.12 테스트) | `fail-fast: false` |
| 빌드 → 테스트 → 배포 (직렬 의존) | 자동 fail-fast (needs 사용) |
| 실험적 step (가시성만 필요) | `continue-on-error: true` + 후속 보고 |
| flaky known-failure | `continue-on-error: true` + 알림 (격리) |

## 6. 멱등성 (rerun-safe)
- 같은 input 으로 두 번 실행 시 같은 결과
- 외부 부수효과: 검사 후 적용 (`if not exists then create`)
- 태그 push 는 한 번만 — `--allow-overwrite` 같은 escape 신중
- artifact 업로드는 같은 이름이면 덮어씀 (의도한 경우만)

## 7. Cache vs Artifact
| 분기 | 사용 |
|---|---|
| 외부 의존성 (build cache) | `actions/cache` — key=hashFiles, restore-keys 로 cascade |
| 빌드 결과물 (run 간 공유) | `actions/upload-artifact` + `actions/download-artifact` |
| 영구 산출물 | GitHub Release |
| docker layer | `cache-from: type=gha`, `cache-to: type=gha,mode=max` |

## 8. Retry — 어디에 적용하나?
- ✅ 네트워크 호출 (curl, gh api): `for i in 1 2 3; do ... && break || sleep $((i*5)); done`
- ✅ 외부 서비스 (GitHub API 일시적 5xx)
- ❌ 빌드 / 테스트 — flake 는 retry 대신 격리 (가시성 보존)
- ❌ deploy — idempotency 보장 안 되면 위험

## 9. Timeout 다단계
```yaml
jobs:
  test:
    timeout-minutes: 30        # job
    steps:
      - name: Long step
        timeout-minutes: 10    # step (job 보다 짧게)
        run: ...
```
+ workflow 자체는 GitHub 기본 6시간 (자동) — 명시적 제어 불가.

## 10. 헤더 주석 (workflow 파일 상단)
```yaml
# Purpose:  push/PR 검증 (lint + test + build)
# Trigger:  push (main), pull_request (any)
# Inputs:   none
# Outputs:  none (artifact 업로드)
# Owner:    @jinmoo
# Runbook:  .github/runbooks/ci.md
name: CI
on:
  ...
```

## 11. 검증 단계
- 로컬: `actionlint .github/workflows/*.yml`
- 로컬 실행: `act -j <job>` (가능 시)
- branch push → 실제 run 확인
- step summary / artifact 검증

## 흔한 함정
- ❌ `runs-on: ubuntu-latest` — 버전 고정 안 됨
- ❌ `actions/checkout@v4` 만 → SHA 또는 major pin 권장
- ❌ secrets 를 echo / step output 으로 노출
- ❌ `${{ }}` 안에 user input 직접 — injection
- ❌ `>` (folded) 사용한 멀티라인 run → 개행 손실
- ❌ `pull_request_target` + fork checkout 조합 (권한 노출)

## 관련 자산
- `designing-workflow` skill — 상위 설계
- `choosing-workflow-pattern` skill — 패턴 카탈로그
- `designing-composite-action` skill — composite action 디테일
- `organizing-workflow-scripts` skill — script 분리
- `coding-github-actions.md` rule
