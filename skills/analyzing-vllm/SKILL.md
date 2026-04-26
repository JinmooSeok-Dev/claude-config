---
name: analyzing-vllm
description: >
  vLLM 오픈소스의 내부 구조, scheduler, executor, attention backend, distributed/parallel
  로직을 코드 기반으로 분석한다. 사용자가 "vLLM", "PagedAttention", "scheduler", "executor",
  "engine", "vllm 내부", "vllm 분석", "vllm 코드"를 언급할 때 사용한다.
argument-hint: "[분석 대상: scheduler / engine / attention / distributed / 기타 키워드]"
---

ultrathink

## vLLM 분석 프레임워크

vLLM은 빠르게 변하는 코드베이스이므로 **분석 전에 commit hash 또는 release tag를 반드시 명시**한다.
분석 대상: $ARGUMENTS

### 0. 사전 확인 (필수)

```
[버전] git -C <vllm-path> rev-parse --short HEAD
[버전] git -C <vllm-path> describe --tags --abbrev=0
```

분석 결과 보고 시 항상 "기준 commit/tag"를 첫 줄에 표기한다. 다른 시점의 코드와 혼동 방지.

### 1. Top-down 코드 위치 맵

| 계층 | 경로 | 핵심 추상화 |
|-----|------|-----------|
| Entry (HTTP) | `vllm/entrypoints/openai/api_server.py`, `vllm/entrypoints/api_server.py` | OpenAI 호환 endpoint, `/v1/chat/completions` |
| Engine | `vllm/engine/async_llm_engine.py`, `vllm/v1/engine/` | `AsyncLLMEngine`, `LLMEngine`, request lifecycle |
| Scheduler | `vllm/core/scheduler.py`, `vllm/v1/core/sched/` | continuous batching, preemption, priority |
| Block / KV manager | `vllm/core/block_manager.py`, `vllm/v1/core/kv_cache_manager.py` | PagedAttention block table, prefix caching |
| Worker / Executor | `vllm/worker/`, `vllm/executor/` | TP/PP/EP 분산 실행, forward pass orchestration |
| Attention backend | `vllm/attention/backends/` (`flash_attn`, `xformers`, `triton`, `flashinfer`) | backend selection, kernel dispatch |
| Distributed | `vllm/distributed/parallel_state.py`, `vllm/distributed/communication_op.py` | TP/PP/EP group, all-reduce, broadcast |
| Model | `vllm/model_executor/models/` | 모델별 forward 구현 (llama, qwen, mixtral 등) |
| Quantization | `vllm/model_executor/layers/quantization/` | GPTQ, AWQ, FP8, INT4 |
| Sampler | `vllm/model_executor/layers/sampler.py` | top-k/p, temperature, beam search |

### 2. 분석 절차

```
- [ ] 0. 분석 대상 commit/tag 확인 + 보고에 명시
- [ ] 1. Entry point에서 시작 (어디서 요청을 받는가)
- [ ] 2. AsyncLLMEngine까지 데이터 흐름 추적
- [ ] 3. Scheduler가 어떤 정책으로 batch를 구성하는지 확인
- [ ] 4. Worker/Executor에서 forward 호출 경로
- [ ] 5. Attention backend dispatch + 실제 kernel 호출 위치
- [ ] 6. Distributed 통신 발생 지점 (all-reduce, all-gather)
- [ ] 7. KV cache block 할당/해제 시점
- [ ] 8. 결과 sampling + response 반환 경로
```

### 3. v0 vs v1 구분

vLLM은 v1 엔진(`vllm/v1/`)으로 점진 전환 중. 분석 시 둘을 혼동하지 않는다:
- v0: `vllm/engine/`, `vllm/core/scheduler.py` (legacy, 일부 시나리오에서 여전히 사용)
- v1: `vllm/v1/engine/`, `vllm/v1/core/sched/` (chunked prefill, 더 단순한 scheduler 등)
- 분석 대상이 v0인지 v1인지 코드 import 경로로 판별 후 표시

### 4. 외부 검증 (필수)

소스만으로 추론하지 않고 다음으로 교차 검증:
- `gh search code --repo vllm-project/vllm "<symbol>"` — 사용처 확인
- WebFetch로 PR 또는 issue 본문 확인 — 변경 의도 파악
- vLLM 공식 docs (`docs.vllm.ai`)
- 관련 논문 — PagedAttention (Kwon et al., 2023), Continuous batching (Yu et al., 2022)

추론은 `[추정]`, 코드 확인은 `[확인]` 태그 (CLAUDE.md Accuracy 규칙).

### 5. 출력 구조

분석 결과는 다음 순서로 보고:

1. **버전 / 분석 범위**: commit hash, 분석 대상 범위
2. **요약**: 핵심 동작 3~5줄
3. **데이터 흐름**: Mermaid 시퀀스 다이어그램 (entry → engine → scheduler → worker → kernel)
4. **핵심 코드 위치**: 파일:라인 형식 (`vllm/core/scheduler.py:142`)
5. **알고리즘**: 시간/공간 복잡도, 핵심 자료구조
6. **References**: 논문, PR, issue 링크

## 자주 혼동하는 지점

- **continuous batching**: scheduler가 매 step마다 batch 재구성 (Orca 논문 패턴)
- **chunked prefill**: 긴 prompt를 작은 chunk로 나눠 decode와 병렬 처리 — v1에서 기본
- **prefix caching**: 동일 prefix를 가진 요청 간 KV cache 공유 (`vllm/core/block_manager.py`의 `evictor`)
- **speculative decoding**: draft model이 토큰 추측, target model이 검증 (`vllm/spec_decode/`)
- **PP vs TP vs EP**: pipeline / tensor / expert parallel — `parallel_state.py`에서 group 정의
- **MoE의 EP**: expert parallel은 모델별 구현이 다양 — Mixtral과 DeepSeek 다름

## 규칙
- commit hash 명시 없이 코드 위치 주장 금지
- "최근 변경"은 `git log -- <path>`로 실제 확인 후 인용
- 추측한 동작은 `[추정]`, 확인한 동작은 `[확인]` 표기
- 핵심 알고리즘은 논문/PR로 역추적
