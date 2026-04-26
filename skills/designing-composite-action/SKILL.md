---
name: designing-composite-action
description: 새 composite action을 설계하고 작성한다. 디렉토리 1개=action 1개, action.yml 메타데이터, input naming 도메인 일반화, env 경유 injection 방지, 외부 action SHA pinning, README 강제(사용 예 + I/O 표), 추출 결정 기준(재사용 ≥ 2회 + 5줄 이상)을 가이드한다. 사용자가 "composite action", "재사용 action 만들어", "이 step 추출", "action.yml"을 언급할 때 사용한다.
---

# Designing Composite Action

여러 step 을 묶어 재사용하는 composite action 설계·구현.

## 1. 추출 결정 — 만들어야 하나?
| 조건 | 결론 |
|---|---|
| 동일 step 묶음이 **2회 이상** 등장 | ✅ 추출 권장 |
| 5줄 이상의 인라인 run | ✅ 추출 (또는 별도 스크립트) |
| 단일 repo 내 사용 | composite action OK |
| 다른 repo 에서도 호출 필요 | reusable workflow 또는 published action |
| matrix / needs / multi-job 필요 | reusable workflow (composite 는 step 만) |
| 1회용 / 곧 삭제 예정 | 인라인 유지 |

## 2. 디렉토리 구조
```
.github/actions/<name>/
├── action.yml          # 필수
├── README.md           # 강제 (사용 예 + I/O 표)
└── scripts/            # 선택 (action 내부에서만 쓰는 스크립트)
    └── helper.sh
```

**1 action = 1 디렉토리**. 절대 한 디렉토리에 여러 `action.yml` 두지 말 것.

## 3. `action.yml` 템플릿
```yaml
name: 'Compute Docker Tag'
description: 'Compute a deterministic Docker tag from git ref and SHA'

inputs:
  registry:
    description: 'Container registry URL (default: ghcr.io)'
    required: false
    default: 'ghcr.io'
  image-name:
    description: 'Image name (without registry)'
    required: true
  ref:
    description: 'Git ref (default: github.ref)'
    required: false
    default: ${{ github.ref }}

outputs:
  tag:
    description: 'Computed tag'
    value: ${{ steps.compute.outputs.tag }}
  full-image:
    description: 'Full image reference (registry/name:tag)'
    value: ${{ steps.compute.outputs.full-image }}

runs:
  using: composite
  steps:
    - name: Compute tag
      id: compute
      shell: bash
      env:
        REGISTRY: ${{ inputs.registry }}
        IMAGE_NAME: ${{ inputs.image-name }}
        REF: ${{ inputs.ref }}
        SHA: ${{ github.sha }}
      run: |
        set -euo pipefail
        tag="${REF##*/}-${SHA:0:7}"
        full="${REGISTRY}/${IMAGE_NAME}:${tag}"
        echo "tag=${tag}" >> "$GITHUB_OUTPUT"
        echo "full-image=${full}" >> "$GITHUB_OUTPUT"
```

## 4. Input 설계 원칙
- **이름은 도메인 일반화** — 특정 인물/환경 coupling 금지:
  - ❌ `ghcr_jinmoo_username` → ✅ `ghcr_username` 또는 `registry-username`
  - ❌ `ext_worker2_vm_ip` → ✅ `vm-ip`
- **kebab-case** (action 관습), 또는 snake_case 일관성 (repo 내 통일)
- **required vs optional 명확**, optional 은 합리적 default
- **불필요한 input 금지** — 실제 로직에 안 쓰면 제거
- **secret 은 input 으로 받음** — composite action 자체는 `secrets:` 키워드 없음 (reusable workflow 와 다름)
  ```yaml
  inputs:
    registry-token:
      description: 'Registry auth token'
      required: true
  ```
  caller 가 `with: registry-token: ${{ secrets.GHCR_TOKEN }}` 로 전달

## 5. Output 설계 원칙
- caller 가 실제로 쓰는 것만
- 내부 디버그 값 / 중간 결과는 output 불필요 (artifact 또는 step summary 활용)
- value 는 `steps.<id>.outputs.<key>` 참조

## 6. Shell Injection 방지 — env 경유 필수
```yaml
# 나쁨: shell injection 가능
- shell: bash
  run: |
    echo "${{ inputs.user-input }}"
    [[ "${{ inputs.flag }}" == "true" ]] && do_x

# 좋음: env 경유
- shell: bash
  env:
    USER_INPUT: ${{ inputs.user-input }}
    FLAG: ${{ inputs.flag }}
  run: |
    echo "${USER_INPUT}"
    [[ "${FLAG}" == "true" ]] && do_x
```

## 7. 외부 action 호출 — SHA pinning
composite action 내부에서 다른 action 호출 시:
```yaml
runs:
  using: composite
  steps:
    - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
    - uses: actions/setup-go@cdcb360043...                               # v5.0.0
```
재현성·보안 모두 SHA pinning 권장.

## 8. README.md (강제)
디렉토리에 `README.md` 가 없으면 **fail** (lint 또는 hook 으로). 최소 형식:
```markdown
# Compute Docker Tag

git ref + SHA 로 결정적인 docker tag 와 full image 참조를 계산한다.

## Usage

\`\`\`yaml
- uses: ./.github/actions/compute-docker-tag
  with:
    image-name: my-app
  id: tag
- run: docker push ${{ steps.tag.outputs.full-image }}
\`\`\`

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `registry` | no | `ghcr.io` | Container registry URL |
| `image-name` | yes | — | Image name (no registry) |
| `ref` | no | `${{ github.ref }}` | Git ref |

## Outputs

| Name | Description |
|---|---|
| `tag` | Computed tag |
| `full-image` | `<registry>/<image-name>:<tag>` |

## Examples

(추가 사용 예)
```

## 9. 호출 측 (caller)
```yaml
- name: Compute image tag
  id: tag
  uses: ./.github/actions/compute-docker-tag
  with:
    image-name: my-app

- name: Push
  env:
    FULL: ${{ steps.tag.outputs.full-image }}
  run: docker push "${FULL}"
```

## 10. 검증
- `actionlint .github/actions/<name>/action.yml`
- 실제 호출 후 step output 확인
- README 가 input/output 과 sync 되는지 (수동 또는 lint)

## 흔한 함정
- ❌ `${{ inputs.* }}` 를 run 에 직접 — env 경유 안 하면 injection
- ❌ secret 을 run 의 stdout 으로 echo
- ❌ output value 에 `${{ steps.x.outputs.y }}` 가 아닌 직접 표현 — composite 는 step output 만 expose
- ❌ 외부 action `@main` 또는 `@master` (mutable)
- ❌ README 누락 — 사용 방법 모름

## 관련 자산
- `coding-github-actions.md` rule
- `implementing-workflow` skill — caller 측 사용
- `documenting-workflow` skill — README 표준
- `refactoring-workflow` skill — 추출 결정
