---
name: documenting-workflow
description: 워크플로우 문서화를 표준화한다. YAML 상단 헤더 6필드(Purpose/Trigger/Inputs/Outputs/Owner/Runbook), .github/workflows/README.md 카테고리 인덱스(build/test/release/nightly/utility), composite action README, .github/runbooks/<name>.md 운영 절차를 작성한다. 사용자가 "워크플로우 문서", "workflow README", "이 워크플로우 설명", "runbook"을 언급할 때 사용한다.
---

# Documenting Workflow

워크플로우 자산(YAML, composite action, scripts) 의 일관된 문서화 규칙.

## 1. Workflow YAML 상단 헤더 (필수)
모든 workflow 파일의 `name:` 위에 6필드 헤더 주석:
```yaml
# Purpose:  <한 줄로 이 workflow가 하는 일>
# Trigger:  <push/PR/schedule/dispatch 등 + 조건>
# Inputs:   <none 또는 주요 input 1~3개>
# Outputs:  <none 또는 주요 output (artifact/dispatch)>
# Owner:    @<github-handle> 또는 <team>
# Runbook:  .github/runbooks/<name>.md (있으면)

name: Build & Publish
on:
  push:
    branches: [main]
  pull_request:
```

**헤더의 가치**: 워크플로우 파일을 처음 보는 사람이 30초 안에 핵심 파악.

## 2. `.github/workflows/README.md` (인덱스)
워크플로우 5개 이상이면 인덱스 권장. 카테고리별 분류:
```markdown
# Workflows Index

## Build & Publish
| File | Purpose | Trigger | Owner |
|---|---|---|---|
| [ci.yml](./ci.yml) | PR/push 검증 (lint+test+build) | push, PR | @jinmoo |
| [docker-images-build.yaml](./docker-images-build.yaml) | 컨테이너 빌드·푸시 | push (main), dispatch | @jinmoo |

## Nightly
| File | Purpose | Schedule | Owner |
|---|---|---|---|
| [vllm_rbln_nightly_e2e.yaml](./vllm_rbln_nightly_e2e.yaml) | E2E 회귀 테스트 | 18:00 UTC | @jinmoo |

## Release
| File | Purpose | Trigger | Owner |
|---|---|---|---|
| [torch_rbln_release.yaml](./torch_rbln_release.yaml) | tag → wheel publish | tag `v*` | @jinmoo |

## Benchmark
| File | Purpose | Schedule | Owner |
|---|---|---|---|

## Utility / Reusable (`_<name>.yml`)
| File | Purpose | Caller | Owner |
|---|---|---|---|

## Composite Actions
([../actions/](../actions/) 참조)
```

## 3. Composite Action README (`/.github/actions/<name>/README.md`)
디렉토리마다 README 강제. 구조 (`designing-composite-action` skill 참조):
- 한 줄 설명
- Usage (코드 블록)
- Inputs 표 (Name / Required / Default / Description)
- Outputs 표
- Examples (선택, 복잡한 경우)

## 4. Runbook (`.github/runbooks/<name>.md`)
운영 워크플로우 (nightly, release, deploy, benchmark) 는 runbook 필수. 구조:
```markdown
# Runbook: vllm_rbln_nightly_e2e

## 정상 동작
- **트리거**: 매일 18:00 UTC
- **소요 시간**: ~45분 (정상)
- **산출물**: artifact `nightly-results-<date>` (90일 보존)
- **알림**: 실패 시 #ci-alerts Slack

## 자주 발생하는 실패와 대응

### 1. self-hosted runner offline
**증상**: "No runner matching labels [self-hosted, gpu]"
**확인**: `gh api repos/<owner>/<repo>/actions/runners`
**대응**:
- runner host SSH → `sudo systemctl status actions.runner.<name>`
- 재시작 `sudo systemctl restart actions.runner.<name>`
- 호스트 자체가 죽었으면 인프라팀 호출

### 2. HuggingFace rate limit
**증상**: `429 Too Many Requests` from huggingface.co
**대응**:
- `HF_TOKEN` 갱신 (Settings → Secrets)
- 모델 캐시 사용 (`HF_HOME` 환경변수)

### 3. NPU device 인식 실패
...

## 수동 트리거
\`\`\`bash
gh workflow run vllm_rbln_nightly_e2e.yaml --ref main
gh run watch
\`\`\`

## 에스컬레이션
- 1차: @jinmoo
- 2차: #ci-team

## 관련 문서
- 설계: [docs/nightly-design.md](../../docs/nightly-design.md)
- 워크플로우: [.github/workflows/vllm_rbln_nightly_e2e.yaml](../workflows/vllm_rbln_nightly_e2e.yaml)
```

## 5. 설계 문서 (`docs/<workflow>-design.md`)
복잡한 워크플로우는 설계 문서도 권장 (`writing-design-doc` skill 사용):
- Problem (왜 필요)
- Scenarios (정상/실패 시나리오)
- Design (4계층 분해, 컨트롤/데이터 플로우 다이어그램)
- Alternatives Considered
- ADR

## 6. ADR (`docs/adr/NNNN-<title>.md`)
워크플로우 관련 핵심 결정은 ADR 로:
- "왜 self-hosted runner 인가?" / "왜 monorepo orchestration 인가?" / "왜 cosign attestation 도입했는가?"
- 형식: Status / Context / Decision / Consequences

## 7. 인라인 주석 (선택)
- 명백한 step 은 주석 불필요
- 비명백한 결정 (`# self-hosted runner 가 NPU 접근하므로`, `# fail-fast: false 이유: matrix 독립성`) 만 주석

## 8. 메타데이터 동기화
- workflow 변경 시 README 인덱스 행도 업데이트
- composite action input 추가 시 README 표도 업데이트
- runbook 의 절차가 outdated 안 되도록 변경 commit 에 함께 포함

## 9. 검증
- 헤더 6필드 누락 검사 (간단 grep)
- 인덱스에 누락된 workflow 검사 (스크립트로 가능)
- 운영 워크플로우의 runbook 존재 여부

## 관련 자산
- `coding-github-actions.md` rule
- `documentation.md` rule
- `writing-runbook` skill (단일, CI/일반 도메인 분기)
- `writing-design-doc` skill
- `designing-composite-action` skill (action 디렉토리 README)
