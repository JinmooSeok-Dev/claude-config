$ARGUMENTS 워크플로우의 중복/복잡도를 줄이는 리팩토링 제안.

## 절차
1. **대상 결정**: 인자(파일 또는 디렉토리), 없으면 `.github/workflows/` 전체
2. **`refactoring-workflow` skill 호출** — 중복 탐지 (step·job·인라인 shell)
3. **추출 후보 카테고리화**:
   - **composite action 후보**: 같은 step 묶음 ≥ 2회 + 5줄 이상
   - **reusable workflow 후보**: 같은 job 패턴 (matrix·needs)
   - **스크립트 분리 후보**: 인라인 shell ≥ 5줄, 로컬 재현 필요
4. **각 후보의 비용/이득** 표시:
   - 추출 후 호출 측 변경 횟수
   - 인터페이스 정의 (input/output)
   - 가독성 변화 (indirection 비용)
5. **추출 시 표준 적용**:
   - 도메인 일반화 input naming
   - env 경유 injection 방지
   - README 강제 (`designing-composite-action`)
6. **실행은 사용자 동의 후** — 한 후보씩 PR

## 안티패턴 — 추출 거부
- 1회만 사용
- 곧 삭제 예정
- 입력 5개 중 4개가 항상 같음 (추상화 실패)
- 도메인 너무 좁음

## 관련
- skills: refactoring-workflow / designing-composite-action / implementing-workflow
- `coding-github-actions.md` rule
