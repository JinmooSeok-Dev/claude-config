---
name: refactoring-workflow
description: 중복 step·job·action을 탐지하고 composite action 또는 reusable workflow로 추출한다. 추출 비용/이득 비교(재사용 ≥ 2회 + 5줄 이상), 인터페이스 도메인 일반화, 호환성 유지 변경 등을 가이드한다. 사용자가 "워크플로우 정리", "중복 step 합쳐", "리팩토링", "reusable로 빼", "composite로 추출"을 언급할 때 사용한다.
---

# Refactoring Workflow

기존 워크플로우의 중복·복잡도를 줄이는 리팩토링.

## 1. 중복 탐지
### 1-1. 같은 step 묶음 (composite action 후보)
- 여러 workflow / 여러 job 에 같은 step 시퀀스
- shell 스크립트 본문이 동일 (또는 변수만 다름)
- 검출: `grep -A 5 "name: <step name>"` 또는 diff 도구

### 1-2. 같은 job 패턴 (reusable workflow 후보)
- matrix · 다단계 step 조합이 여러 워크플로우에서 반복
- input/output 만 다름

### 1-3. 인라인 shell 의 5줄 이상 (스크립트 후보)
- `organizing-workflow-scripts` skill 적용

## 2. 추출 결정 — 비용 vs 이득
| 추출 후 |  이득 | 비용 |
|---|---|---|
| **수정 한 곳** | high | — |
| **테스트 한 번** | high | 별도 테스트 셋업 |
| **호출 측 가독성** | medium | indirection (한 번 더 들어가서 봐야) |
| **인터페이스 변경 시 호출자 모두 수정** | (단점) | inputs 추가/제거 매번 캐스케이드 |

**임계**: 재사용 ≥ 2회 + 5줄 이상 → 추출. 1회면 인라인 유지.

## 3. 추출 단계 (composite action 예)
1. **추출 대상 식별** — 어느 step 묶음을 뺄지
2. **인터페이스 정의** — 입력 변하는 부분만 input, 나머지는 고정
3. **이름 도메인 일반화** — `ghcr_jinmoo_username` ❌ → `registry-username` ✅
4. **`.github/actions/<name>/action.yml` 작성** (`designing-composite-action` skill)
5. **README.md 추가** (강제)
6. **호출 측 1곳 부터 교체** — 결과 동일한지 확인 (run 비교)
7. **나머지 호출 측 일괄 교체**
8. **(가능하면) 호환성 위해 한 step 이름 유지**

## 4. 추출 단계 (reusable workflow 예)
1. 같은 패턴 job 셋 식별
2. **`.github/workflows/_<name>.yml`** 작성 (prefix `_` 권장)
   ```yaml
   name: _Build and Test
   on:
     workflow_call:
       inputs:
         go-version:
           required: true
           type: string
       outputs:
         coverage:
           value: ${{ jobs.build.outputs.coverage }}
       secrets:
         GHCR_TOKEN:
           required: true
   jobs:
     build:
       runs-on: ubuntu-24.04
       outputs:
         coverage: ${{ steps.test.outputs.coverage }}
       steps:
         ...
   ```
3. 호출 측 변경:
   ```yaml
   jobs:
     ci:
       uses: ./.github/workflows/_build-and-test.yml
       with:
         go-version: '1.22'
       secrets:
         GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
   ```
4. 모든 caller 가 vars/secrets 를 명시 전달하도록 (orchestrator 책임)

## 5. 인터페이스 정리 — 자주 나오는 개선
- **input 이름 도메인 일반화** (위 §3)
- **불필요한 input 제거** — 호출 측에서 항상 같은 값 전달하면 default 로
- **fallback chain 을 orchestrator 로 이동** — reusable 안에서 `vars.*` 직접 참조 금지
  ```yaml
  # 나쁨 (reusable 안)
  env:
    VM_IP: ${{ inputs.vm_ip || vars.EXT_VM_IP }}

  # 좋음 (orchestrator 가 결정)
  test:
    uses: ./.github/workflows/_test.yml
    with:
      vm_ip: ${{ needs.install.outputs.vm_ip || vars.EXT_VM_IP }}
  ```
- **secret injection-safe** — `${{ inputs.* }}` 를 run 에 직접 X. env 경유.

## 6. 호환성 유지 변경
- **새 input 추가**: default 있으면 기존 caller 영향 X
- **input 제거**: caller 모두 수정 후 제거
- **input rename**: 한 번에 양쪽 alias 두지 말고 캐스케이드 PR
- **output 추가**: 안전
- **output 제거**: caller 사용처 확인 후 제거

## 7. 검증
- 추출 전후 같은 input 으로 같은 output 인지 (실제 run 비교)
- step summary / artifact 비교
- 시간 차이 측정 (composite/reusable 호출 오버헤드는 보통 무시 가능)

## 8. 흔한 함정
- ❌ 너무 일찍 추출 (1회 사용) → premature abstraction
- ❌ input 이 너무 많음 (10개+) → 추상화 실패. 책임 너무 큼
- ❌ 추출했는데 호출 측에서 매번 다른 값 전달 → 추상화 의미 없음
- ❌ 한 번에 여러 곳 변경 → bisect 어려움
- ❌ README 누락 → 추출했지만 사용법 불명

## 9. 안티패턴 — 추출하지 말아야 할 경우
- 한 번만 쓰임
- 곧 삭제 예정인 워크플로우
- 도메인이 너무 좁음 (다른 곳에서 절대 안 쓰일)
- 인터페이스 정의가 너무 어색함 (입력 5개 중 4개가 항상 같음 → 추상화 실패 신호)

## 관련 자산
- `designing-composite-action` skill — 새 action 설계
- `implementing-workflow` skill — 호출 측 작성
- `auditing-workflow` skill — 리팩토링 후 보안 점검
- `coding-github-actions.md` rule
