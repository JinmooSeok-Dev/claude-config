$ARGUMENTS 새 GitHub Actions 워크플로우를 설계 + 작성한다.

## 절차
1. **Purpose 명료화** — 사용자에게 다음 중 하나로 구분 요청 (모르면 질문):
   - CI / CD / Release / Nightly / Benchmark / Notification / Sync / Multi-project orchestration
2. **`designing-workflow` skill 호출** — 4계층 분해, 컨트롤·데이터 플로우, 의존성, 관측성
3. **`choosing-workflow-pattern` skill 참조** — 적합한 패턴의 핵심 step / 안티패턴
4. **`implementing-workflow` skill 로 YAML 초안 생성**
5. **헤더 6필드** 자동 삽입 (Purpose / Trigger / Inputs / Outputs / Owner / Runbook)
6. **검증**: `actionlint <new-file>` 권장
7. **인덱스 업데이트**: `.github/workflows/README.md` 가 있으면 새 행 추가 제안

## 산출물
- `.github/workflows/<name>.yml` (또는 `_<name>.yml` for reusable)
- 필요 시 `.github/actions/<name>/` 신설
- 필요 시 `scripts/<name>.sh` 또는 `.github/scripts/<name>.sh`
- 운영 워크플로우면 `.github/runbooks/<name>.md` 작성 권장 (`writing-runbook` skill)

## 기본 가정
- `runs-on: ubuntu-24.04` (버전 고정)
- `permissions: contents: read` (필요 시 추가)
- `concurrency` 명시 (release 외 `cancel-in-progress: true`)
- `timeout-minutes` job 마다 명시
- 외부 action SHA pinning

## 사용자 확인 포인트
- Purpose 가 모호하면 질문
- secret 또는 self-hosted runner 가 필요하면 명시 확인
- 처음 작성 시 dry-run (push 전 PR) 권장

## 관련
- `coding-github-actions.md` rule (자동 로드)
- skills: designing-workflow / choosing-workflow-pattern / implementing-workflow / documenting-workflow
