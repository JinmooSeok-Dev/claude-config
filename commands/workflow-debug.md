$ARGUMENTS 워크플로우 실패 원인을 체계적으로 추적·수정한다.

## 절차
1. **실패 run 식별**:
   - 인자가 run id 면 그대로 사용
   - 인자가 없으면 마지막 실패 run 자동 검색:
     ```bash
     gh run list -L 10 --status failure --json databaseId,conclusion,name,headBranch,createdAt
     ```
2. **로그 수집**:
   ```bash
   gh run view <run-id> --log-failed
   gh run view <run-id> --json jobs --jq '.jobs[] | {name, conclusion}'
   ```
3. **`debugging-workflow` skill 호출** — 가설 분류, 로컬 재현, 수정안
4. **수정 적용**:
   - 가설 1개씩 수정 (multi-change 금지)
   - 로컬 재현 가능한 경우 먼저 검증 후 commit
5. **rerun**:
   ```bash
   gh run rerun <run-id> --failed   # 실패 job 만
   ```
6. **회고 (반복 발생 시)**: runbook 추가 또는 audit 실행

## 빠른 자가 진단 체크
- shell 미명시? (container 환경 → sh)
- `set -euo pipefail` 누락?
- secret 이름 오타?
- 외부 action 버전 deprecation?
- `pull_request_target` + fork?

## 관련
- skills: debugging-workflow / auditing-workflow / refactoring-workflow
- `~/my_job/ci/02-workflow-debugging.md` (사용자 reference)
