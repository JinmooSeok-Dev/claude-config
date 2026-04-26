---
paths:
  - "**/*.sh"
  - "**/*.bash"
---

# Shell Script 코딩 규칙

## 필수 헤더
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

## 구조
- `readonly SCRIPT_DIR`, `SCRIPT_NAME` 선언
- `log()`, `warn()`, `die()` 함수 정의 (stderr 출력)
- `trap cleanup EXIT` + `trap 'die ...' INT TERM`
- `usage()` + `parse_args()` + `main()` 구조
- `main "$@"` 로 시작

## 변수
- 항상 큰따옴표: `"${var}"`
- 기본값: `: "${NAMESPACE:=default}"`
- 상수: `readonly MAX_RETRIES=3`
- 함수 내: `local` 키워드 사용

## 조건문
- `[[ ]]` 사용 (`[ ]` 대신)
- 명령 존재 확인: `command -v kubectl &>/dev/null || die "kubectl required"`

## 금지 사항
- `sudo` 사용 금지 — 필요 시 스크립트 실행 자체를 root로 하거나 별도 권한 설정
- `eval` 사용 금지
- backtick `` `cmd` `` 금지 → `$(cmd)`
- 변수 미인용 금지
- 에러를 stdout 출력 금지 → `>&2`
- 하드코딩 `/tmp/myfile` 금지 → `mktemp`

## K8s 스크립트 패턴
- `kubectl wait --for=condition=ready`
- JSON 파싱은 `jq` 사용
- 민감정보는 환경변수로만 전달

## Workflow/CI 환경에서의 Shell

shell script를 GitHub Actions 등 workflow에서 호출할 때의 추가 규칙:

- 스크립트는 **독립 실행 가능**해야 함 — workflow 없이 로컬에서도 테스트 가능
- 환경변수 의존성을 스크립트 시작부에 명시적으로 검증
  ```bash
  : "${MODEL_NAME:?ERROR: MODEL_NAME is required}"
  : "${NAMESPACE:?ERROR: NAMESPACE is required}"
  ```
- exit code를 명확히 정의 — 0(성공), 1(일반 오류), 2(사용법 오류)
- stdout은 결과 데이터만, stderr는 로그/에러만 — workflow에서 stdout을 캡처할 수 있도록
- 긴 명령의 중간 실패를 pipe로 숨기지 않음
  ```bash
  # 나쁨: curl 실패를 jq가 숨김
  curl -s "$URL" | jq '.status'

  # 좋음: 각 단계를 분리하거나 pipefail로 보호
  response=$(curl -sf "$URL") || die "API call failed"
  echo "${response}" | jq '.status'
  ```
- workflow에서 전달받는 인자는 반드시 인용: `"$1"`, `"${INPUT_VALUE}"`

## jq 활용 패턴
- 빈 결과 감지는 `--exit-status`(`-e`): `kubectl get ... -o json | jq -e '.items[0]'`
- raw 출력은 `-r`: `jq -r '.metadata.name'`
- 멀티라인 변수 → JSON 안전 주입: `jq -n --arg msg "$multiline" '{message: $msg}'`
- 복잡한 query는 함수형으로 분해: `jq 'def healthy: .status == "Ready"; .items[] | select(healthy)'`
- 파이프 안의 jq 실패를 놓치지 않도록 `set -o pipefail` 필수
- 시간 비교: `jq '... | select(.metadata.creationTimestamp | fromdate > now - 3600)'`

## 색상 / 로그 helper
색상은 stderr가 터미널일 때만 활성화 (CI/파이프 환경에서 escape 코드 노출 방지):
```bash
if [[ -t 2 ]]; then
  readonly C_RED=$'\033[31m' C_YELLOW=$'\033[33m' C_GREEN=$'\033[32m' C_RESET=$'\033[0m'
else
  readonly C_RED='' C_YELLOW='' C_GREEN='' C_RESET=''
fi

log()  { printf '%s[INFO]%s  %s\n' "${C_GREEN}"  "${C_RESET}" "$*" >&2; }
warn() { printf '%s[WARN]%s  %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
die()  { printf '%s[FATAL]%s %s\n' "${C_RED}"    "${C_RESET}" "$*" >&2; exit 1; }
```

## Retry with backoff
재시도 대상은 멱등 명령으로 한정한다 (POST 같은 비멱등 호출에 사용 금지):
```bash
retry() {
  local max="${1:-5}" delay="${2:-2}" attempt=1
  shift 2
  until "$@"; do
    if (( attempt >= max )); then
      die "after ${max} attempts: $*"
    fi
    warn "attempt ${attempt}/${max} failed, retrying in ${delay}s: $*"
    sleep "${delay}"
    delay=$(( delay * 2 ))      # exponential backoff
    attempt=$(( attempt + 1 ))
  done
}

# 사용 예
retry 5 2 kubectl wait --for=condition=Ready pod/foo --timeout=30s
retry 3 1 curl -fsS "${URL}/health"
```

## 검증
- ShellCheck 필수 통과
- 복잡한 스크립트(50줄 이상)는 별도 `.sh` 파일로 분리하여 lint 가능하게
