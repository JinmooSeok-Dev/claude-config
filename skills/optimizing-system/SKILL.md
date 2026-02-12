---
name: optimizing-system
description: >
  시스템, 알고리즘, 코드, 인프라를 최적화한다. 성능 튜닝, 리소스 효율화,
  알고리즘 개선, 커널 파라미터 튜닝, GPU 최적화, 분산 시스템 최적화를 다룬다.
  사용자가 "최적화", "튜닝", "빠르게", "효율", "개선",
  "스케일", "리소스 절약"을 언급할 때 사용한다.
argument-hint: "[최적화 대상]"
---

ultrathink

## 최적화 프레임워크

$ARGUMENTS에 대해:

### 1. 현재 상태 측정 (Before)

최적화 전에 반드시 측정한다:
- 현재 성능 수치 (latency, throughput, 메모리, 비용 등)
- 목표 수치 (SLO/SLA 또는 사용자 기대)
- 갭: 현재 vs 목표

> 필요하면 `/profiling-performance` 스킬을 먼저 실행한다.

### 2. 최적화 방향 분류

**어떤 유형의 최적화인가?**

| 유형 | 전략 | 예시 |
|------|------|------|
| **알고리즘** | 복잡도 개선 O(n²)→O(n log n) | 정렬, 탐색, 그래프 알고리즘 |
| **데이터 구조** | 접근 패턴에 맞는 자료구조 | hash map, B-tree, skip list |
| **메모리** | 할당 감소, locality 개선 | pooling, arena, SoA vs AoS |
| **병렬화** | 동시성 활용 | threading, SIMD, GPU offload |
| **I/O** | 비동기, 배치, 캐싱 | async I/O, prefetch, mmap |
| **GPU/커널** | occupancy, memory coalescing | 타일링, shared mem, warp 최적화 |
| **분산 시스템** | 통신 최소화, 파이프라이닝 | TP/PP/DP, gradient compression |
| **인프라** | 리소스 배치, 스케줄링 | node affinity, bin packing |

### 3. 최적화 적용

```
- [ ] 가장 큰 병목부터 공략한다 (Amdahl's Law)
- [ ] 한 번에 하나의 변경만 적용한다
- [ ] 변경 후 즉시 측정한다
- [ ] 성능 향상이 없으면 롤백한다
- [ ] 코드 가독성과의 트레이드오프를 평가한다
```

**Amdahl's Law 체크:**
```
전체 실행시간 중 최적화 대상이 차지하는 비율이 p일 때,
최대 가능 개선 = 1 / (1 - p)

예: 전체의 10%를 차지하는 부분을 10배 빠르게 해도
    전체 개선은 최대 1.11배 → 의미 없을 수 있음
```

### 4. 결과 보고 (After)

| 지표 | Before | After | 개선율 |
|------|--------|-------|--------|
| ... | ... | ... | ...% |

- 어떤 변경이 어떤 효과를 냈는가 (인과 관계)
- 트레이드오프 (복잡도 증가, 메모리 사용 등)
- 추가 최적화 여지

## 과정 표시
매 단계마다 아래 형식으로 과정을 보여준다:
```
[분석] 전체 실행시간 100ms 중 행렬곱이 72ms (72%) 차지
[방법] Amdahl's Law: 이 부분을 2배 빠르게 하면 전체 1.56배 개선
[전략] GEMM → cuBLAS 호출로 교체 (GPU offload)
[적용] before: np.dot(A,B) → after: torch.mm(A_gpu, B_gpu)
[결과] 72ms → 8ms, 전체 100ms → 36ms (2.78배 개선)
```
- 병목 비율(%)과 Amdahl 효과를 먼저 보여준다
- 왜 이 최적화를 선택했는지 대안과 비교한다
- before/after 수치를 명확히 대비한다

## 규칙
- 추측 기반 최적화 금지 — 반드시 프로파일 데이터에 근거
- premature optimization 경고: 병목이 아닌 곳을 최적화하지 않는다
- 최적화로 인한 코드 복잡도 증가를 명시한다
- before/after 수치를 반드시 비교한다
