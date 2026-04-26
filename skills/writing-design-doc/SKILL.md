---
name: writing-design-doc
description: 설계 문서(ARCHITECTURE/DESIGN/PROPOSAL)를 Top-down 구조로 작성한다. Executive Summary → Problem(5요소) → User Scenarios(F+NF) → Design/Solution → Architecture(C4) → Key Data Structures/Algorithms → Source Code Analysis → References. 메타데이터 헤더 자동 삽입. 시나리오 역참조 강제. 사용자가 "설계 문서", "design doc", "아키텍처 문서", "architecture.md", "proposal"을 언급할 때 사용한다.
---

# Writing Design Doc

Reference 문서 (ARCHITECTURE / DESIGN / PROPOSAL) 의 Top-down 구조 작성.

## 1. 메타데이터 헤더 (필수)
```markdown
# <문서 제목>

> **검토일**: YYYY-MM-DD · **소유자**: @<github-handle> · **상태**: Draft / Active / Deprecated
> **문서 버전**: 1.0
> **작성 목적**: <한 줄>
> **대상 독자**: 개발자 / 운영자 / 아키텍트
```

## 2. 구조 (각 섹션이 다음 질문에 답함)
1. **Executive Summary** — 핵심 결론, 1페이지 이내
   → _"무슨 문제를 해결하는가?"_
2. **Problem Definition** — 5요소(Who/What/When·Where/Impact/Urgency), 정량적 수치
   → _"이 문제가 어떤 상황에서 발생하는가?"_
3. **User Scenarios** — F (기능) + NF (비기능). Actor → Precondition → Flow → Exception → Postcondition
   → _"이 시나리오들을 해결하려면 어떤 접근이 필요한가?"_
4. **Design / Solution** — Goals/Non-Goals, Alternatives Considered, 선택 근거 (시나리오 역참조)
   → _"이 설계를 어떤 구조로 구현하는가?"_
5. **Architecture** — C4 모델 (Context → Container → Component → Code)
   → _"핵심 병목/핵심 로직은 무엇인가?"_
6. **Key Data Structures / Algorithms** — 선택 이유, 복잡도 분석
   → _"실제 코드에서는 어떻게 구현되어 있는가?"_
7. **Source Code Analysis** — Entry → 핵심 추상화 → Data flow → Critical path (파일:라인)
8. **References** — 1차(논문/공식 문서) / 2차(블로그) 분리

## 3. 섹션 간 연결 규칙
- 각 섹션 **첫 문단**: 앞 섹션과의 연결 명시 ("Problem Definition 의 X 문제가 발생하는 시나리오를 정리한다")
- 각 섹션 **마지막**: 다음 섹션으로의 전환 질문
- Design/Architecture/Algorithm 섹션: **어떤 시나리오의 어떤 요구사항** 으로 이 결정을 내렸는지 역참조 ("(시나리오 2: P99 < 500ms 요구사항)")
- 각 섹션 **자기 완결적 도입부** — 어디서부터 읽어도 맥락 파악

## 4. Problem Statement — 5요소
모두 충족해야 한다. 정량 수치 필수.
```markdown
## Problem Definition

### Who (누구의 문제)
- 워크로드: vLLM 서빙 사용자 N팀, 평균 RPS 1500
- 운영자: oncall 주당 평균 1.5건 응답

### What (무엇이 문제)
- ...

### When/Where (발생 조건)
- ...

### Impact (정량적 영향)
- P99 latency 800ms → SLO(500ms) 초과 일평균 12회
- 월간 GPU 시간 낭비 ≈ 142h ($X)

### Urgency (왜 지금)
- Q3 신규 워크로드 인입 예정 (트래픽 +40%)
```

## 5. User Scenarios — F + NF
### 기능 시나리오 (Functional)
```markdown
### S1. 정상 추론 요청 처리
- **Actor**: 외부 클라이언트
- **Precondition**: 모델 로드 완료, GPU healthy
- **Flow**:
  1. POST /v1/completions
  2. Scheduler 가 batch 큐에 추가
  3. PagedAttention 으로 KV cache 할당
  4. Sampling → response stream
- **Exception**:
  - context length 초과 → 400
  - GPU OOM → 503 + retry-after
- **Postcondition**: KV cache 해제, metric 기록
```

### 비기능 시나리오 (Non-functional)
```markdown
### N1. P99 latency < 500ms 유지 (동시 100 요청)
- 어떤 구조/알고리즘이 이를 보장? → Design 섹션 §4.2
### N2. 무중단 모델 교체
- 어떤 배포 전략? → §4.3 (rolling, canary)
### N3. NPU device 실패 시 자동 복구
- 어떤 health check + restart 전략? → §4.5
```

## 6. Design / Solution
- **Goals** / **Non-Goals** 명확히 분리
- **Alternatives Considered** 필수 — 검토했지만 채택하지 않은 대안 + 이유
- Trade-off 비교 매트릭스 (기준 + 가중치 + 점수)
- ADR 로 핵심 결정 별도 기록 (`docs/adr/NNNN-<title>.md`)

## 7. Architecture — C4 모델
- **Context**: 시스템 외부 의존 (사용자, 외부 서비스)
- **Container**: 배포 단위 (서비스, DB)
- **Component**: 코드 모듈 (controller, scheduler)
- **Code**: 핵심 데이터 구조, 알고리즘
- 다이어그램: **Mermaid 또는 ASCII 박스**. 둘 다 1급 시민 — copy-paste 쉬움

```
┌──────────────────────────────────────────────┐
│  Scheduler                                    │
│   ↓ schedule()                                │
│  Worker Pool ── ── ── KV Cache Manager        │
│   ↓ forward()              ↓ allocate/free    │
│  GPU                       PagedAttention     │
└──────────────────────────────────────────────┘
```

## 8. Source Code Analysis — Entry point → Critical path
- 파일:라인 명시 (`vllm/core/scheduler.py:142` — `_schedule()` 메서드)
- 분석 대상 버전/커밋 명시
- 시퀀스 다이어그램 (Mermaid) 적극 활용

## 9. References
```markdown
## References

### 1차 (논문, 공식 문서)
- Kwon et al. "Efficient Memory Management for Large Language Model Serving with PagedAttention", SOSP 2023, [arXiv:2309.06180](https://arxiv.org/abs/2309.06180)
- vLLM official docs: https://docs.vllm.ai/en/latest/

### 2차 (블로그, 발표)
- ...
```

## 10. 검증 체크리스트
- [ ] 메타데이터 헤더 (검토일/소유자/상태)
- [ ] Executive Summary 1페이지 이내
- [ ] Problem 5요소 + 정량 수치
- [ ] 모든 시나리오가 Problem 으로 추적 가능
- [ ] Goals/Non-Goals 분리
- [ ] Alternatives Considered 포함
- [ ] Design/Architecture 가 시나리오를 역참조
- [ ] References 1차/2차 분리, 접근일 명시

## 관련 자산
- `documentation.md` rule (자동 로드)
- `applying-design-principles` skill
- `designing-architecture` skill (C4, 모듈 경계)
- `verifying-document-facts` skill (작성 후 사실확인)
- `~/.claude/rules/documentation.md` (사용자 reference)
