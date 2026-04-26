$ARGUMENTS 새 composite action을 만든다.

## 절차
1. **이름 결정**: 인자가 action 이름. kebab-case 권장
2. **`designing-composite-action` skill 호출**
3. **디렉토리 생성**: `.github/actions/<name>/`
4. **`action.yml` 템플릿** 작성:
   - `name`, `description`
   - `inputs:` (도메인 일반화, required/default 명확)
   - `outputs:` (caller 가 실제 쓰는 것만)
   - `runs.using: composite`
   - 모든 `${{ inputs.* }}` 는 `env:` 블록 경유 (injection 방지)
5. **`README.md` 강제 작성**:
   - 한 줄 설명
   - Usage 코드 블록
   - Inputs 표
   - Outputs 표
6. **검증**: `actionlint .github/actions/<name>/action.yml`

## 산출물
- `.github/actions/<name>/action.yml`
- `.github/actions/<name>/README.md`
- (선택) `.github/actions/<name>/scripts/helper.sh` (action 내부 보조)

## 사용자 확인
- 추출 결정 임계 (재사용 ≥ 2회 + 5줄 이상) 검토
- 호출 측 (어느 워크플로우에서 사용할지) 명시 권장
- secret 필요 시 input 으로 받는 패턴 (composite 는 secrets: 없음)

## 관련
- skills: designing-composite-action / implementing-workflow / refactoring-workflow
- `coding-github-actions.md` rule
