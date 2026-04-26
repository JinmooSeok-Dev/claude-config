$ARGUMENTS 경로의 LLM 서빙 벤치마크 결과를 표로 정리하고 회귀를 감지한다.

## 입력
- 단일 JSON/CSV 파일 또는 디렉토리 (vLLM/SGLang `benchmark_serving.py`, AIPerf, GuideLLM 결과)
- baseline 지정 시(`--baseline=<path>`) 비교 모드

## 절차

```
- [ ] 1. 입력 파일 형식 식별 (vLLM benchmark_serving / AIPerf / GuideLLM / 사용자 정의)
- [ ] 2. 핵심 지표 추출: TTFT, ITL, TPOT, throughput(req/s, tok/s), p50/p95/p99 latency
- [ ] 3. 측정 환경 메타데이터 추출: model, GPU, batch size, seq_len, concurrency, dtype, vLLM commit
- [ ] 4. 표 생성 (Markdown)
- [ ] 5. baseline이 있으면 회귀 감지 (지표별 % 차이, threshold 5% 기본)
- [ ] 6. Pareto front 추출 (multi-objective: latency vs throughput 등)
- [ ] 7. 결론 + 다음 측정 제안
```

## 출력 형식

```markdown
## 벤치마크 결과: <model> on <GPU>
- **측정 조건**: batch=N, seq_len=M, concurrency=C, dtype=bfloat16, vLLM=<commit>
- **측정 시점**: YYYY-MM-DD HH:MM
- **샘플**: N=K runs, median 보고

| Metric | Value | (vs baseline) |
|--------|------:|--------------:|
| Throughput (tok/s) | 12,345 | +3.2% |
| TTFT p50 (ms) | 87 | -1.5% |
| TTFT p99 (ms) | 412 | +18.0% ⚠️  |
| ITL p50 (ms) | 12.3 | -0.4% |
| TPOT p50 (ms) | 14.1 | -0.2% |
| Request throughput (req/s) | 145 | +2.1% |

### 회귀 감지
- ⚠️  **TTFT p99**: baseline 349ms → 412ms (+18%, threshold 5% 초과)
- 원인 가설: long prompt batching에서 chunked prefill 정책 변화 [추정]

### Pareto front (latency vs throughput)
| Concurrency | Throughput (tok/s) | TTFT p99 (ms) | Pareto? |
|------------:|-------------------:|--------------:|:-------:|
| 8  | 4,200  | 95  | ✓ |
| 16 | 8,100  | 180 | ✓ |
| 32 | 12,345 | 412 | ✓ |
| 64 | 13,200 | 1,200 | × (TTFT 폭발) |

### 다음 측정 제안
1. TTFT p99 회귀 원인 분리: chunked prefill 비활성화로 A/B 측정
2. concurrency 32~64 사이 sweep으로 knee 정확히 식별
```

## 규칙
- 모든 수치에 `[측정]` 출처 명시 (CLAUDE.md Accuracy 규칙)
- 측정 조건 메타데이터 누락 시 "조건 불명, 비교 위험" 경고
- mean만 보고하지 않는다 — p50/p95/p99 모두 포함 (long tail 정보 손실 방지)
- 단일 run 보고 금지 — 최소 3회 median
- baseline 없이 회귀 단정 금지 — "baseline 지정 시 비교 가능" 안내
- 결과 표는 그대로 WORKLOG.md에 붙여넣을 수 있는 Markdown으로 생성
