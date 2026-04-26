$ARGUMENTS 새 ADR(Architecture Decision Record) 를 생성한다.

## 절차
1. **번호 결정**: `docs/adr/` (또는 `docs/adrs/`) 의 기존 파일 스캔 → 다음 번호 (4자리 zero-padded, 예: `0042`)
2. **제목**: 인자가 ADR 제목 (kebab-case 권장 — `0042-use-helm-over-kustomize.md`)
3. **템플릿 작성**:

```markdown
# ADR-NNNN: <제목>

> **상태**: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
> **결정일**: YYYY-MM-DD
> **소유자**: @<handle>

## Context
무엇이 결정을 요구하는가? (배경, 제약, 이해관계자)

## Decision
무엇을 결정했는가? (한 문장 + 상세)

## Consequences
이 결정의 결과:
- 긍정적: ...
- 부정적: ...
- 중립: ...

## Alternatives Considered
검토했지만 채택하지 않은 대안:
- A. <대안 1> — 거부 이유
- B. <대안 2> — 거부 이유

## References
- 관련 이슈: #...
- 관련 PR: #...
- 관련 문서: [<path>](...)
```

4. **인덱스 업데이트**: `docs/adr/README.md` 가 있으면 행 추가
5. **상태 변경 안내**: 다른 ADR 을 supersede 하면 그 ADR 의 상태도 업데이트 권장

## 사용자 확인
- 디렉토리 위치 (`docs/adr/` vs `docs/adrs/` vs 다른 곳)
- 번호 충돌 (parallel work 가능성)
- Status — 새 ADR 은 보통 `Proposed` 시작

## 관련
- skills: applying-design-principles / writing-design-doc / designing-architecture
- `documentation.md` rule
