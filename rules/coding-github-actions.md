---
paths:
  - ".github/workflows/**"
  - ".github/actions/**"
---

# GitHub Actions / Git Workflow 규칙

## Workflow 파일
- `permissions` 최소 권한 필수 명시
- `runs-on` 버전 고정: `ubuntu-24.04` (`ubuntu-latest` 금지)
- `timeout-minutes` 필수 설정
- `concurrency` 설정으로 중복 실행 방지
- `paths-ignore`로 불필요한 트리거 방지 (`**.md`, `docs/**`)

## Action 보안
- SHA pinning 권장 (최소 major 버전 pin)
- fork PR에서는 secrets 접근 불가를 전제로 설계
- secret은 OIDC 또는 Environment로 관리
- `echo`로 secret 출력 금지

## 재사용
- 중복 로직은 reusable workflow (`workflow_call`) 분리
- 공통 step은 composite action으로 추출

## Cache
- `hashFiles()`로 의존성 기반 cache key
- Docker: `cache-from: type=gha`, `cache-to: type=gha,mode=max`

## Workflow 내 Shell Script 규칙

### shell: bash 필수 — sh vs bash 문제

GitHub Actions의 `run:` step은 **runner OS에 따라 기본 shell이 다르다**:
- `ubuntu-*` runner: 기본 `bash`이지만 `--noprofile --norc` 옵션으로 실행
- `macos-*` runner: 기본 `bash`
- container 내 실행 (`container:` 또는 self-hosted): **`/bin/sh`가 기본**인 경우 많음 (alpine, ubi-minimal 등)

`sh`와 `bash`는 문법이 다르다. **`sh`에서 bash 문법을 쓰면 구문 오류**가 발생한다:

```bash
# bash에서는 정상, sh에서는 구문 오류 (Syntax error)
[[ -f "$file" ]]           # sh: [[: not found
array=(a b c)              # sh: Syntax error: "(" unexpected
echo "${var,,}"            # sh: Bad substitution
if [[ "$a" == "b" ]]; then # sh: ==: unexpected operator
local myvar="hello"        # sh: local은 함수 밖에서 사용 불가 (일부 sh)
echo $((x + 1))            # 일부 sh에서 산술 확장 미지원
read -r -a arr <<< "$str"  # sh: <<<(here string) 미지원
```

**규칙: 모든 `run:` step에 `shell: bash`를 반드시 명시한다.**

```yaml
# 나쁨: shell 미지정 → container 환경에서 /bin/sh로 실행될 수 있음
- name: Check status
  run: |
    [[ -f config.yaml ]] && echo "found"

# 좋음: shell: bash 명시
- name: Check status
  shell: bash
  run: |
    [[ -f config.yaml ]] && echo "found"

# 더 좋음: job 레벨에서 기본 shell 설정
defaults:
  run:
    shell: bash
```

**job-level `defaults.run.shell` 권장** — 매 step마다 반복하지 않아도 됨:
```yaml
jobs:
  build:
    runs-on: ubuntu-24.04
    defaults:
      run:
        shell: bash
    steps:
      - run: echo "이 step은 자동으로 bash로 실행"
```

### runs-on과 shell 환경 주의사항

| runs-on | 기본 shell | bash 위치 | 주의사항 |
|---------|-----------|----------|---------|
| `ubuntu-24.04` | bash | `/usr/bin/bash` | 대부분 안전, 그래도 명시 권장 |
| `self-hosted` | **불확실** | runner 설정에 따라 다름 | `shell: bash` **필수** |
| `container: alpine` | `/bin/sh` (ash) | bash 미설치 | `apk add bash` 필요하거나 sh 호환 문법 사용 |
| `container: ubi9-minimal` | `/bin/sh` | bash 미설치 가능 | `microdnf install bash` 또는 sh 호환 |
| `container: python:3.12-slim` | `/bin/sh` (dash) | bash 설치되어 있음 | `shell: bash` 명시 |

**self-hosted runner**: 팀이 관리하는 runner는 shell 환경이 일정하지 않으므로 `shell: bash`를 **절대 생략하지 않는다**.

### 별도 스크립트 파일 분리
- 복잡한 로직(5줄 이상)은 별도 `.sh` 파일로 분리하고 workflow에서 호출
- 분리하면 **ShellCheck**로 lint 가능, 로컬 테스트 가능
  ```yaml
  - name: Deploy model
    shell: bash
    run: ./scripts/deploy.sh "${{ inputs.model-name }}"
  ```
- `.sh` 파일에는 `#!/usr/bin/env bash` shebang 필수

### 에러 처리
- 모든 `run:` block 시작에 `set -euo pipefail`
- GitHub Actions의 bash는 기본적으로 `set -eo pipefail`을 적용하지만, **container 환경이나 self-hosted에서는 보장되지 않으므로** 항상 명시
  ```yaml
  - name: Validate manifests
    shell: bash
    run: |
      set -euo pipefail
      # 이후 로직
  ```
- pipe 중간 실패 감지가 중요 — `pipefail` 없으면 `cmd1 | cmd2`에서 cmd1 실패를 놓침
- `if: failure()`로 실패 시 정리 step 추가
  ```yaml
  - name: Cleanup on failure
    if: failure()
    run: kubectl delete -f deploy.yaml --ignore-not-found
  ```

### 구문 오류 방지
- **YAML 멀티라인 문자열 주의**: `|`(literal block)과 `>`(folded block) 구분
  ```yaml
  # 좋음: | (개행 유지)
  run: |
    echo "line 1"
    echo "line 2"

  # 나쁨: > (개행이 공백으로 합쳐짐 → 구문 오류)
  run: >
    echo "line 1"
    echo "line 2"
  ```
- **변수 치환 충돌 방지**: shell `$VAR`과 GitHub Actions `${{ }}` 혼용 시 주의
  ```yaml
  # 나쁨: shell 변수가 GitHub Actions에 의해 빈 문자열로 치환됨
  run: |
    for pod in $(kubectl get pods -o name); do
      echo "$pod"
    done

  # 좋음: $를 escape하거나 별도 스크립트 파일로 분리
  run: |
    set -euo pipefail
    pods=$(kubectl get pods -o name)
    for pod in ${pods}; do
      echo "${pod}"
    done
  ```
- **따옴표 이중 escape 주의**: YAML string 안에서 shell 따옴표 사용 시
  ```yaml
  # 나쁨: 따옴표 충돌
  run: echo "value is "$VAR""

  # 좋음: 작은따옴표와 큰따옴표 구분
  run: echo "value is ${VAR}"
  ```

### 환경변수 전달 패턴
- step 간 값 전달은 `$GITHUB_ENV` 또는 `$GITHUB_OUTPUT` 사용
  ```yaml
  - name: Get version
    id: version
    shell: bash
    run: |
      set -euo pipefail
      VERSION=$(cat VERSION)
      echo "version=${VERSION}" >> "${GITHUB_OUTPUT}"

  - name: Use version
    run: echo "Version is ${{ steps.version.outputs.version }}"
  ```
- `$GITHUB_ENV`에 멀티라인 값 저장 시 delimiter 패턴 사용
  ```yaml
  run: |
    {
      echo "CHANGELOG<<EOF"
      git log --oneline -10
      echo "EOF"
    } >> "${GITHUB_ENV}"
  ```

### 조건부 실행과 exit code
- step 실패를 허용하면서 exit code를 캡처할 때
  ```yaml
  - name: Run tests (may fail)
    id: test
    shell: bash
    run: |
      set +e
      make test 2>&1 | tee test-output.log
      echo "exit_code=$?" >> "${GITHUB_OUTPUT}"
    continue-on-error: true

  - name: Report results
    if: steps.test.outputs.exit_code != '0'
    run: echo "Tests failed with code ${{ steps.test.outputs.exit_code }}"
  ```
- `continue-on-error: true` 단독 사용 금지 — 실패를 감추지 않고 후속 step에서 처리

### 흔한 함정
| 함정 | 증상 | 해결 |
|------|------|------|
| `run: >` 사용 | 개행이 공백으로 합쳐져 구문 오류 | `run: \|` 사용 |
| `pipefail` 미설정 | pipe 중간 실패 무시 | `set -euo pipefail` |
| shell 변수에 `${{ }}` 미사용 | Actions context 접근 실패 | `${{ env.VAR }}` 또는 `$VAR` 구분 |
| `${{ }}` 안에서 shell 명령 | 실행 안 됨 | step output/env로 분리 |
| `echo ::set-output` | deprecated (2024.10+) | `$GITHUB_OUTPUT` 사용 |
| 멀티라인 output | 잘림/깨짐 | EOF delimiter 패턴 |
| `if:` 조건에서 따옴표 누락 | 타입 비교 오류 | `if: steps.x.outputs.y == 'value'` |

## Workflow Architecture Principles

### 역할 구분: 오케스트레이터 vs Reusable

| 역할 | 대상 | 핵심 책임 |
|------|------|----------|
| **오케스트레이터** | 직접 trigger되는 workflow (`schedule`, `push`, `workflow_dispatch`) | 모든 환경 변수/secrets를 수집하여 reusable에 명시적으로 전달 |
| **Reusable workflow** (`workflow_call`) | `_` prefix 권장 | 자신의 로직에 필요한 모든 것을 input으로 받음. `vars.*` 직접 참조 금지 |
| **Composite action** | `.github/actions/` 하위 | 동일 원칙. `env:` block을 통해 input 전달 |

### Reusable / Composite Action 인터페이스 규칙

**`vars.*` / `secrets.*` 직접 참조 금지** — reusable은 어떤 환경에서 호출될지 모른다. 오케스트레이터가 필요한 값을 input으로 결정하고 전달한다:

```yaml
# 나쁨: reusable 내부에서 repository variable 직접 참조
env:
  VM_IP: ${{ inputs.vm_ip || vars.EXT_WORKER2_VM_IP }}  # vars.*는 오케스트레이터에서 처리

# 좋음: oker스트레이터가 fallback까지 해결해서 전달
# (오케스트레이터에서) vm_ip: ${{ needs.install.outputs.vm_ip || vars.EXT_WORKER2_VM_IP }}
# (reusable에서)      VM_IP: ${{ inputs.vm_ip }}
```

**Input 설계 원칙:**
- 이름은 도메인 일반화 — 특정 인물/환경에 coupling 금지 (`ghcr_jinmoo_username` ❌ → `ghcr_username` ✅)
- required vs optional 구분 명확히, optional에는 합리적인 default
- 불필요한 input 금지 — 로직에 실제로 쓰이는 것만

**Output 설계 원칙:**
- caller가 실제로 사용하는 값만 output으로 노출
- 내부 디버그 값, 중간 결과는 output 불필요

**Shell injection 방지** — composite action의 `run:` 블록에서 `${{ inputs.* }}`를 직접 삽입하지 않고 `env:` block을 통해 환경변수로 전달:

```yaml
# 나쁨: shell injection 가능
- run: |
    echo "${{ inputs.version }}"
    [[ "${{ inputs.flag }}" == "true" ]] && do_something

# 좋음: env block을 통한 안전한 전달
- env:
    VERSION: ${{ inputs.version }}
    FLAG: ${{ inputs.flag }}
  run: |
    echo "${VERSION}"
    [[ "${FLAG}" == "true" ]] && do_something
```

### 오케스트레이터의 책임: 통합 의존성 관리

오케스트레이터는 **한 곳에서 모든 환경 의존성을 해결**하고 downstream에 명시적으로 전달한다. `vars.*`, cluster 선택, kubeconfig 출처 결정은 모두 오케스트레이터 레벨에서 처리한다:

```yaml
jobs:
  test:
    uses: ./.github/workflows/_integration-test.yml
    with:
      vm_ip: ${{ needs.install.outputs.vm_ip || vars.EXT_WORKER2_VM_IP }}  # 오케스트레이터가 결정
      kubeconfig_artifact_run_id: ${{ needs.install.result == 'success' && github.run_id || '' }}
      notify_slack: false     # 오케스트레이터가 자체 notify 처리 시 false
    secrets:
      KUBECONFIG_B64: ${{ secrets.EXT_WORKER2_KUBECONFIG_B64 }}  # 어떤 secret 쓸지 오케스트레이터가 결정
      HF_TOKEN: ${{ secrets.HF_TOKEN }}
```

`secrets: inherit`은 편리하지만 reusable의 secrets 의존성이 불투명해진다. 명시적 전달을 권장하나, 많은 secrets가 필요한 경우 `secrets: inherit` + reusable 내 명시적 `secrets:` 선언으로 타협한다.

### Skipped Job을 활용한 선택적 실행 패턴

`if:` 조건으로 job을 skip하면 dependent job의 `success()`에서 skipped를 success로 처리한다. 이를 이용해 optional 단계를 구현한다:

```yaml
install:
  if: inputs.provision_sno       # false → skipped (treated as success by dependents)
  uses: ./.github/workflows/_sno-lifecycle.yml

test:
  needs: [prepare, install]      # install이 skipped여도 test는 실행됨
  env:
    # skipped job의 outputs는 빈 값 → || 로 fallback
    VM_IP: ${{ needs.install.outputs.vm_ip || vars.EXT_VM_IP }}

setup-cluster-access:
  with:
    kubeconfig-b64: ${{ secrets.EXT_KUBECONFIG_B64 }}   # static mode fallback
    kubeconfig-artifact-run-id: ${{ needs.install.result == 'success' && github.run_id || '' }}
    # install 성공 → dynamic mode, skipped/failed → static mode
```

## Git 규칙
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:` prefix
- Squash merge 권장 (깔끔한 main history)
- Branch protection: required reviews, status checks
