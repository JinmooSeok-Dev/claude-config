$ARGUMENTS 워크플로우(또는 .github/ 전체)의 보안·품질을 점검한다.

## 절차
1. **대상 결정**:
   - 인자가 파일 경로면 해당 파일만
   - 인자가 디렉토리면 그 안의 워크플로우 전체
   - 인자 없으면 `.github/workflows/*.y*ml` + `.github/actions/*/action.yml` 전체
2. **`auditing-workflow` skill 호출** — P0/P1/P2/P3 체크 항목
3. **자동 도구 실행 (가능 시)**:
   ```bash
   actionlint <file...>
   shellcheck <hook-scripts>
   ```
4. **결과 보고서 작성**:
   - P0 (즉시 수정): `pull_request_target` + fork checkout, secret echo, untrusted input injection
   - P1 (보안): SHA pinning 누락, permissions 과도, fork PR + secret
   - P2 (품질): runs-on latest, shell 미명시, set -euo 누락, timeout 누락
   - P3 (운영): step summary 미사용, retention 무한, runbook 부재
5. **각 항목**: 파일:라인 + 영향 + 수정안 1개씩

## 산출물
- 보고서 markdown (사용자에게 표시 + 옵션 `--output <path>` 시 파일 저장)
- 즉시 수정 가능한 항목은 별도 PR 제안

## 사용자 확인
- P0 항목은 fix PR 작성 권장 (자동 X, 사용자 동의 후)
- 보안 관련 사항은 `security-auditor` agent 추가 호출 가능

## 관련
- `coding-github-actions.md` rule
- skills: auditing-workflow / refactoring-workflow / debugging-workflow
