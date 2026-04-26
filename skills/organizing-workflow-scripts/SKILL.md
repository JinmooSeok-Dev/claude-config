---
name: organizing-workflow-scripts
description: 워크플로우에서 호출할 스크립트의 위치(.github/scripts/ vs scripts/ vs tools/), 파일명, shebang/에러 처리, 입력 검증, exit code, stdout/stderr 분리, 로컬 단독 실행 가능성을 가이드한다. Python 스크립트의 PEP 723 inline 의존성 선언도 포함. 사용자가 "스크립트 어디 둘지", "scripts 정리", "이거 별도 파일로", "workflow 스크립트 분리"를 언급할 때 사용한다.
---

# Organizing Workflow Scripts

워크플로우에서 호출하는 스크립트의 **위치 / 명명 / 구조 / 검증** 가이드.

## 1. 위치 결정 — 3계층
| 위치 | 용도 | 특징 |
|---|---|---|
| `.github/scripts/` | **Workflow 전용** | repo 외부에서 호출 안 됨. workflow context 가정 OK ($GITHUB_*, gh CLI) |
| `scripts/` | **로컬 + CI 양쪽** | 개발자가 직접 실행 가능. ShellCheck/bats 검증 가능. workflow context 의존 X (env 인자로 받음) |
| `tools/` (또는 `bin/`) | **개발자 유틸** | 빌드/배포 외 보조 (codegen, manifest 동기화 등) |

**결정 가이드**:
- workflow 만에서 호출 + GH context 의존 → `.github/scripts/`
- 로컬에서도 재현해야 함 / 디버깅 필요 → `scripts/` (강력 권장 — `debugging-workflow` 의 1순위)
- 일반 개발 보조 → `tools/`

## 2. 파일명 컨벤션
- **kebab-case + 동사-명사**: `compute-docker-tag.sh`, `parse-perf-metrics.py`, `resolve-bake-targets.sh`
- 확장자: `.sh` (bash), `.py` (python), `.go` (single-file go via `go run`)
- snake_case 도 허용 (Python ecosystem 관습) — repo 안에서 일관성 유지

## 3. Bash 스크립트 표준 헤더
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# 입력 검증 (envvar 의무화)
: "${MODEL_NAME:?MODEL_NAME is required}"
: "${NAMESPACE:=default}"   # default 허용
: "${TIMEOUT:=300}"

log()  { echo "[$(date +%H:%M:%S)] $*" >&2; }
warn() { echo "[$(date +%H:%M:%S)] WARN: $*" >&2; }
die()  { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }

main() {
  log "Starting ${SCRIPT_NAME}"
  # 핵심 로직
  echo "${result}"   # stdout = 결과만
}

main "$@"
```

핵심:
- 모든 envvar 입력은 `:?` 또는 `:=` 로 명시 검증/기본값
- log 는 stderr (`>&2`), 결과 데이터는 stdout
- exit code: 0 (성공), 1 (일반 오류), 2 (사용법 오류)

## 4. Python 스크립트 — PEP 723 (inline 의존성)
```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "httpx>=0.27",
#     "pydantic>=2",
# ]
# ///

"""Parse performance metrics."""
from __future__ import annotations
import os
import sys
import json

NAMESPACE = os.environ.get("NAMESPACE", "default")
MODEL_NAME = os.environ.get("MODEL_NAME") or sys.exit("MODEL_NAME required")

def main() -> int:
    ...
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

→ workflow 에서 `uv run scripts/parse-perf-metrics.py` 또는 직접 실행 (uv 가 자동 의존성 설치)

## 5. workflow 호출 패턴
```yaml
- name: Compute docker tag
  id: tag
  shell: bash
  env:
    REF: ${{ github.ref }}
    SHA: ${{ github.sha }}
  run: |
    set -euo pipefail
    tag=$(./scripts/compute-docker-tag.sh)
    echo "tag=${tag}" >> "$GITHUB_OUTPUT"

- name: Use tag
  run: echo "Tag is ${{ steps.tag.outputs.tag }}"
```

**원칙**:
- input 은 `env:` 블록으로 (shell injection 방지)
- 결과는 stdout 캡처 후 `$GITHUB_OUTPUT` 에 쓰기
- 스크립트는 `chmod +x` 또는 `bash scripts/<name>.sh` 로 호출

## 6. 로컬 단독 실행 — 디버깅 핵심
```bash
# CI 와 동일하게 envvar 세팅
export REF=refs/heads/feat/x
export SHA=abc1234567890
./scripts/compute-docker-tag.sh
# → 같은 결과여야 함
```

**핵심**: 워크플로우 없이도 동작해야 한다. GitHub context 직접 참조 (`${{ github.* }}`) 금지 — env 로 받기.

## 7. 검증 (CI 권장)
- `shellcheck scripts/*.sh .github/scripts/*.sh`
- `bats tests/*.bats` (bats-core 로 단위 테스트)
- Python: `ruff check scripts/`, `mypy scripts/`

## 8. 흔한 함정
- ❌ `${{ github.event.head_commit.message }}` 직접 shell 에 → injection
- ❌ stdout 에 로그 + 결과 혼합 → workflow 에서 캡처 깨짐
- ❌ `set -e` 만 (pipefail 없음) → pipe 중간 실패 무시
- ❌ 절대경로 (`/Users/...`) — repo 어디서든 동작해야
- ❌ 같은 파일 안에서 변수 재선언 (`local` 누락)
- ❌ Python 의존성을 `requirements.txt` 로만 → 다른 머신에서 깨짐. PEP 723 inline 권장

## 9. 디렉토리 인덱스 (`scripts/README.md`)
3개 이상의 스크립트 두면 README 권장:
```markdown
# Scripts

| Script | Purpose | Inputs (env) | Output |
|---|---|---|---|
| compute-docker-tag.sh | git ref → tag | REF, SHA | stdout: tag |
| parse-perf-metrics.py | bench JSON 파싱 | INPUT_FILE | stdout: csv |
```

## 관련 자산
- `coding-shell.md` rule (path-scoped, 자동 로드)
- `coding-github-actions.md` rule
- `implementing-workflow` skill — workflow 에서 호출
- `debugging-workflow` skill — 로컬 재현
