# 기술 문서 작성 규칙

## 문서의 서사(Narrative) 원칙
문서는 하나의 **논리적 스토리**로 읽혀야 한다. 독자가 위에서 아래로 읽으면서 자연스럽게 "왜?" → "어떤 상황에서?" → "그래서 어떻게?" → "구체적으로 어떤 구조로?" → "핵심은 무엇?" 순서로 이해가 깊어져야 한다. 각 섹션은 앞 섹션에서 발생한 질문에 대한 답으로 시작한다.

## 문서 구조 — Top-down 원칙
모든 분석/설계/조사 문서는 다음 순서를 따른다. 각 섹션이 다음 섹션으로 이어지는 **질문**을 함께 표기한다:

1. **Executive Summary** — 핵심 결론, 1페이지 이내
   → _"무슨 문제를 해결하려는 건가?"_
2. **Problem Definition** — 누구의/무엇이/얼마나 심각한 문제인지, 정량적 수치 포함
   → _"이 문제가 실제로 어떤 상황에서 발생하는가?"_
3. **User Scenarios** — Problem에서 도출된 기능/비기능 시나리오 (아래 상세 규칙 참조)
   → _"이 시나리오들을 해결하려면 어떤 접근이 필요한가?"_
4. **Design / Solution** — 시나리오의 요구사항을 충족하는 설계, 대안 비교, 선택 근거
   → _"이 설계를 어떤 구조로 구현하는가?"_
5. **Architecture** — C4 모델 (Context → Container → Component → Code)
   → _"이 구조에서 핵심 병목/핵심 로직은 무엇인가?"_
6. **Key Data Structures / Algorithms** — 선택 이유, 복잡도 분석
   → _"실제 코드에서는 어떻게 구현되어 있는가?"_
7. **Source Code Analysis** — Entry point → 핵심 추상화 → Data flow → Critical path
8. **References** — 1차 자료(논문, 공식 문서) 우선, 2차 자료(블로그) 구분

## 섹션 간 연결 규칙
- 각 섹션의 **첫 문단**에서 앞 섹션과의 연결을 명시한다: "Problem Definition에서 확인한 X 문제가 실제로 발생하는 시나리오를 정리한다"
- 각 섹션의 **마지막**에서 다음 섹션으로의 전환 질문을 자연스럽게 제기한다: "이 시나리오를 충족하려면 어떤 설계가 필요한지 다음 섹션에서 다룬다"
- Design/Architecture/Algorithm 섹션에서는 **어떤 시나리오의 어떤 요구사항** 때문에 이 결정을 내렸는지 역참조한다: "(시나리오 2: P99 < 500ms 요구사항)"
- 독자가 아무 섹션에서 읽기 시작해도 앞뒤 맥락을 파악할 수 있도록 **자기 완결적 도입부**를 각 섹션에 둔다

## User Scenarios — 기능 + 비기능 시나리오 작성 규칙

시나리오는 문서의 **중심축**이다. 이후 Design, Architecture, Algorithm 섹션은 시나리오에서 도출된 요구사항을 해결하는 흐름으로 자연스럽게 이어져야 한다.

### 기능 시나리오 (Functional)
- 각 시나리오에 **핵심 기능**이 반드시 포함되어야 한다
- Actor → Precondition → Flow (핵심 기능 동작) → Exception → Postcondition
- 시나리오에서 다룬 핵심 기능이 이후 Architecture/Algorithm 섹션의 출발점이 된다

### 비기능 시나리오 (Non-Functional)
프로젝트의 **특별하거나 핵심적인** 비기능 요구사항도 시나리오로 작성한다:
- **성능 최적화**: "동시 100 요청 시 P99 latency < 500ms를 유지해야 한다" → 어떤 구조/알고리즘이 이를 보장하는지
- **내부 아키텍처 개선**: "모듈 X를 교체해도 나머지 시스템에 영향이 없어야 한다" → 인터페이스 분리, 계층 구조
- **배포 방식**: "무중단 배포로 GPU 모델을 교체할 수 있어야 한다" → rolling update, canary, blue-green 전략
- **확장성**: "GPU 노드 추가 시 자동으로 inference capacity가 확장되어야 한다" → autoscaling, resource discovery
- **장애 복구**: "NPU device context 실패 시 자동 복구되어야 한다" → health check, restart policy

### 시나리오 → Top-down 분석 연결
시나리오 작성 후, 문서의 나머지는 시나리오를 **역순으로 풀어가는 구조**로 전개한다:

```
[시나리오] "동시 100 요청에서 P99 < 500ms"
    ↓ 이 요구사항을 충족하려면?
[Design] Prefill/Decode disaggregation + KV cache sharing
    ↓ 이 설계를 구현하려면?
[Architecture] Scheduler → Worker pool → KV cache manager 구조
    ↓ 핵심 병목은?
[Algorithm] PagedAttention의 block table 관리, O(1) lookup
    ↓ 실제 코드에서는?
[Source Code] vllm/core/scheduler.py:L142 — _schedule() 메서드
```

각 섹션 시작 시 **어떤 시나리오의 어떤 요구사항을 해결하는지** 명시하여 독자가 맥락을 잃지 않도록 한다.

## Problem → Scenario 연결
- Problem Definition에서 발견된 각 문제를 **하나 이상의 시나리오로 분해**한다
- 모든 시나리오는 Problem Definition의 특정 문제에 **추적 가능(traceable)**해야 한다
- Problem에서 언급되지 않은 시나리오가 있으면 Problem Definition을 보완한다

## Problem Statement — 5가지 요소 필수
- Who (누구의 문제), What (무엇이 문제), When/Where (발생 조건)
- Impact (정량적 영향도), Urgency (왜 지금 해결해야 하는지)

## 수치 및 근거 정확성
- 모든 성능 수치에 **출처 링크** 필수
- 수치는 **최소 2개 출처**로 교차 검증
- 측정 조건 명시: HW/SW 버전, 설정값, 시점
- "X배 빠르다" 주장에는 반드시 baseline 명시
- `[불확실]` 또는 `[추정]` 표기로 확실하지 않은 수치 구분

## 출처 인용 형식
- 본문 내: `([저자, 연도](URL))` 인라인 링크
- References 섹션: 논문/공식 문서/블로그 카테고리 분리
- 접근 날짜(Accessed date) 명시

## 설계 문서
- Goals / Non-Goals 명확히 분리
- Alternatives Considered 필수 포함 (검토했지만 채택하지 않은 대안과 이유)
- Trade-off는 비교 매트릭스 (기준 + 가중치 + 점수)로 표현
- ADR(Architecture Decision Records)로 핵심 결정 기록

## 오픈소스 분석 문서
- 분석 대상 버전/커밋 명시
- 탐색 순서: Entry point → 핵심 추상화 → Data flow → Critical algorithm
- 시퀀스 다이어그램 (Mermaid) 적극 활용
- 핵심 코드 위치 (파일:라인) 명시

## 문서 메타데이터
- 최종 검토일, 검토 주기, 소유자, 상태를 헤더에 포함
- 버전/시점 의존적 내용에는 유효기간 경고 표시
