$ARGUMENTS 새 runbook 을 작성한다. 도메인 자동 분기.

## 절차
1. **대상 결정**: 인자가 runbook 대상 이름
2. **도메인 감지**:
   - `.github/workflows/<name>.yml` 존재 → CI 워크플로우 → `.github/runbooks/<name>.md`
   - K8s 워크로드 (Deployment/StatefulSet 이름) → `docs/runbooks/<service>.md`
   - 일반 인프라 → `docs/runbooks/<infra>.md`
3. **`writing-runbook` skill 호출** — 표준 구조 적용
4. **수집할 정보** (사용자에게 질문 또는 자동 추출):
   - 정상 동작 (트리거, 빈도, 소요 시간, 산출물, 알림)
   - 자주 발생하는 실패 (운영자 경험 / 과거 incident 회고)
   - 수동 트리거 명령
   - 에스컬레이션 (1차/2차)
   - 관련 문서 링크
5. **검증**: 명령 placeholder 가 명확한지, rollback 절차 포함되었는지

## 산출물
- `<runbooks-dir>/<name>.md`
- 인덱스 (`docs/runbooks/README.md`) 업데이트 제안

## 관련
- skills: writing-runbook / writing-operational-doc / documenting-workflow
- `documentation.md` rule
