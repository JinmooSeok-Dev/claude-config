---
name: verifying-simulator-numerics
description: >
  Simulator의 수치 계산(메모리, 성능, 병렬화 오버헤드)과 알고리즘 로직을
  공식 소스코드와 문서 기반으로 엄밀하게 검증한다.
  vLLM/SGLang/PyTorch/NVIDIA/AMD/lmsys 소스코드, 논문, 기술 블로그의
  벤치마크 및 성능 실험 분석 결과를 반드시 참조하며,
  추론이나 추정이 아닌 실제 소스코드 확인을 원칙으로 한다.
  사용자가 "수치 검증", "공식 확인", "계산 맞는지", "소스코드 확인",
  "실제 값", "엄밀하게", "알고리즘 검증"을 언급할 때 사용한다.
argument-hint: "[검증 대상: memory/performance/parallelism/overhead/algorithm/all]"
---

ultrathink

## Simulator 수치 계산 검증 프로세스

$ARGUMENTS에 대해:

### 0. 변경 감지 (git diff 기반)

검증 전 최근 변경사항을 먼저 파악한다:

```bash
# 최근 커밋 대비 engine/ 변경 확인
git diff HEAD -- src/engine/llm-dist-sim/

# 스테이징 영역 포함
git diff --cached -- src/engine/llm-dist-sim/

# 변경된 함수 목록 (함수 단위 diff)
git diff HEAD -U0 -- src/engine/llm-dist-sim/ | grep -E "^[+-].*function|^[+-].*export|^[+-].*const.*="
```

변경이 감지되면 해당 함수만 집중 검증한다. 변경이 없으면 전체 검증을 수행한다.

### 1. 검증 대상 식별

검증 카테고리별 대상 함수와 공식:

| 카테고리 | 대상 함수 | 위치 | 검증할 공식 |
|----------|----------|------|------------|
| **Memory** | `getModelMemoryGb` | `engine/llm-dist-sim/memory.ts` | model_weight / (TP x PP), MoE: expert분리 |
| **Memory** | `getKvCacheUsageGb` | `engine/llm-dist-sim/memory.ts` | 2 x layers/PP x max(1,kv_heads/TP) x head_dim x dtype x seq x batch |
| **Memory** | `getActivationMemoryGb` | `engine/llm-dist-sim/memory.ts` | batch x seq x hidden x 2 + FFN (MoE: activeExperts/EP) |
| **Memory** | `calculateMemoryBreakdown` | `engine/llm-dist-sim/memory.ts` | total = model + kv + activation + overhead |
| **Performance** | `calculatePrefillTimeMs` | `engine/llm-dist-sim/performance.ts` | 2 x active_params x tokens / (FLOPS x eff x TP) |
| **Performance** | `calculateDecodeTimeMs` | `engine/llm-dist-sim/performance.ts` | (model_bytes/TP + kv_bytes) / (mem_BW x eff) / batch |
| **Parallelism** | `calculateTpOverhead` | `engine/llm-dist-sim/parallelism.ts` | NVLink vs PCIe efficiency |
| **Parallelism** | `calculatePpOverhead` | `engine/llm-dist-sim/parallelism.ts` | bubble = (pp-1)/(pp+ubatch-1) |
| **Parallelism** | `calculateEpOverhead` | `engine/llm-dist-sim/parallelism.ts` | Standard(All-to-All) vs Wide-EP |
| **Parallelism** | PCP/DCP 관련 | `engine/llm-dist-sim/parallelism.ts` | context parallelism 오버헤드 |
| **Constants** | 모든 상수 | `engine/llm-dist-sim/constants.ts` | FLOPS, bandwidth, overhead 값 |
| **Validation** | 구성 검증 | `engine/llm-dist-sim/validation.ts` | layer/head/expert divisibility |

### 2. vLLM 소스 매핑 테이블

Simulator 함수와 대응하는 vLLM 소스 파일:

| Simulator 함수 | vLLM 대응 소스 | 비고 |
|---------------|---------------|------|
| `getModelMemoryGb` | `vllm/config.py:ModelConfig` | 모델 파라미터 계산 |
| `getKvCacheUsageGb` | `vllm/worker/worker.py` | `_calculate_kv_cache_blocks()` |
| `calculatePrefillTimeMs` | `vllm/model_executor/` | compute-bound 공식 |
| `calculateDecodeTimeMs` | `vllm/model_executor/` | memory-bound 공식 |
| `calculateTpOverhead` | `vllm/distributed/` | TP all-reduce 통신 |
| `calculatePpOverhead` | `vllm/executor/` | PP bubble ratio |
| `calculateEpOverhead` | `vllm/model_executor/layers/fused_moe/` | MoE all-to-all |
| PCP (Prefill-Context) | `vllm/distributed/parallel_state.py` | context parallel group |
| DCP (Decode-Context) | `vllm/distributed/parallel_state.py` | chunked prefill context |
| GPU profiles | NVIDIA 데이터시트 | FLOPS, bandwidth, VRAM |

### 3. 공식 소스 확인 (필수)

**반드시 아래 순서로 확인한다. 추론/추정으로 대체하지 않는다.**

#### 3-1. vLLM 소스코드 (최우선)
```
[확인] vLLM GitHub: https://github.com/vllm-project/vllm
[파일] vllm/config.py — model parameter 계산, head divisibility 검증
[파일] vllm/distributed/parallel_state.py — ParallelConfig, world_size, rank 결정
[파일] vllm/model_executor/layers/ — attention, linear 레이어별 메모리
[파일] vllm/worker/worker.py — GPU 메모리 프로파일링
[파일] vllm/core/block_manager.py — KV cache block 관리
[파일] vllm/model_executor/layers/fused_moe/ — MoE 전문가 라우팅, EP 통신
```

vLLM 소스 확인 방법:
- `gh api repos/vllm-project/vllm/contents/{path}` (작은 파일)
- WebFetch로 raw GitHub URL 접근
- 검색: `gh search code --repo vllm-project/vllm "{keyword}"`
- Task tool로 Explore agent 투입 (대규모 조사 시)

#### 3-2. NVIDIA 공식 스펙 (디바이스 수치)
```
[확인] GPU 스펙: NVIDIA 데이터시트 또는 공식 블로그
[항목] VRAM 용량, Memory Bandwidth, FLOPS (FP16/BF16/FP8)
[항목] NVLink bandwidth, PCIe bandwidth
[주의] Marketing FLOPS vs Effective FLOPS 구분 필수
```

#### 3-3. PyTorch/NCCL (통신 오버헤드)
```
[확인] NCCL All-Reduce, All-to-All 알고리즘별 복잡도
[확인] PyTorch distributed 통신 패턴
[주의] 이론적 복잡도 vs 실측 latency 차이 표기
```

#### 3-4. 학술 논문/벤치마크 (경험적 상수)
```
[확인] Megatron-LM 논문 — TP/PP 효율
[확인] DeepSpeed 논문 — ZeRO, MoE 통신
[확인] FlashAttention 논문 — memory-efficient attention
[주의] 경험적 상수는 [경험적] 태그를 반드시 붙인다
```

**병렬 조사:**
여러 소스를 동시에 확인해야 할 때 Task tool로 Explore agent를 병렬 투입한다.
예: vLLM 소스 조사 agent + NVIDIA 스펙 확인 agent를 동시 실행.

### 4. 검증 수행

각 공식에 대해 아래 형식으로 검증한다:

```
[공식] getKvCacheUsageGb: 2 x (L/PP) x max(1, KVH/TP) x HD x dtype x seq x batch / 1024^3
[소스] vllm/worker/worker.py:_calculate_kv_cache_blocks() -> Line 234
[원본] num_kv_heads = model_config.get_num_kv_heads(parallel_config)
       -> 내부적으로 max(1, num_kv_heads // tp_size) 사용
[비교] 우리 구현과 일치 / 불일치
[차이점] (불일치 시) 우리: X, vLLM: Y, 이유: Z
[조치] (불일치 시) 수정 필요 / 의도적 단순화 (사유 기록)
```

### 5. 상수 값 검증

`constants.ts`의 모든 상수에 대해:

| 상수 | 현재 값 | 출처 | 신뢰도 |
|------|--------|------|--------|
| `COMPUTE_EFFICIENCY` | 0.55 | ? | [확인 필요] |
| `MEMORY_EFFICIENCY` | 0.80 | ? | [확인 필요] |
| `TP_OVERHEAD_PER_GPU` | 0.15 | ? | [확인 필요] |
| ... | ... | ... | ... |

**신뢰도 등급:**
- **공식 확인**: vLLM/NVIDIA/논문에서 직접 확인된 값
- **경험적 추정**: 벤치마크 기반이나 환경에 따라 다를 수 있음
- **출처 불명**: 출처를 찾지 못함, 검증 필요

### 6. 검증 체크리스트

검증 완료 시 아래 체크리스트를 채운다:

```markdown
## 검증 체크리스트 — [날짜]

### 대상
- [ ] 변경 감지 (git diff) 완료
- [ ] 변경된 함수 목록 확인

### 소스 확인
- [ ] vLLM 소스코드 확인 (버전/commit: _______)
- [ ] NVIDIA 스펙 확인 (해당 시)
- [ ] 논문/문서 확인 (해당 시)

### 검증 결과
- [ ] 모든 공식 비교 완료
- [ ] 불일치 항목 목록화
- [ ] 상수 값 출처 확인

### 알고리즘 검증
- [ ] Performance Metric 알고리즘 검증 (TTFT/ITL/TPS/E2E)
- [ ] Memory Layout 알고리즘 검증 (weight/KV/activation/MoE)
- [ ] 벤치마크 데이터 대조 (vLLM/SGLang/lmsys)
- [ ] 가정 유효성 확인 (compute-bound/memory-bound 분기)

### 후속 조치
- [ ] 불일치 수정 적용
- [ ] docs/research-references.md 업데이트
- [ ] 코드 주석에 출처 추가
- [ ] 테스트 통과 확인
```

### 7. 알고리즘 검증 (Performance Metric / Memory Layout)

수치 상수뿐 아니라, **알고리즘 자체**(계산 로직, 분기 조건, 모델링 가정)가 실제 시스템과 일치하는지 검증한다.

#### 7-1. Performance Metric 알고리즘 검증

| Metric | Simulator 알고리즘 | 검증 대상 | 참조 소스 |
|--------|-------------------|----------|----------|
| **TTFT** (Time To First Token) | prefill compute-bound: `2 × params × tokens / (FLOPS × eff × TP)` | compute-bound 가정이 유효한지, batch size 영향 | vLLM `benchmarks/`, SGLang `bench_serving.py`, lmsys Chatbot Arena 지표 |
| **ITL** (Inter-Token Latency) | decode memory-bound: `(model_bytes/TP + kv_bytes) / (BW × eff) / batch` | memory-bound 가정, KV cache 크기 반영, batching 효과 | vLLM `engine/async_llm_engine.py`, NVIDIA FasterTransformer 분석 |
| **TPS** (Tokens Per Second) | `1000 / ITL × batch` | batch scaling linearity 가정 | SGLang `server.py`, lmsys benchmark 결과 |
| **E2E Latency** | `TTFT + output_tokens × ITL + PP_overhead + comm_overhead` | 오버헤드 합산 모델, 파이프라인 겹침 고려 여부 | Megatron-LM 논문 Fig.4, DeepSpeed Inference 논문 |
| **TP Overhead** | NVLink bandwidth 기반 all-reduce 시간 | ring vs tree 알고리즘 선택, message size 의존성 | NCCL `src/collectives/`, PyTorch `distributed/` |
| **PP Overhead** | bubble ratio `(pp-1)/(pp+μbatch-1)` | micro-batch 수 결정 로직, interleaved scheduling 여부 | Megatron-LM 논문 Eq.2, vLLM `executor/` |
| **EP Overhead** | All-to-All 통신 시간 | expert capacity factor, load balancing | vLLM `fused_moe/`, DeepSpeed-MoE 논문, Megablocks |

**확인 포인트:**
```
[알고리즘] TTFT = 2 × active_params × seq_len / (peak_FLOPS × compute_eff × TP)
[가정 검증] "prefill은 항상 compute-bound" → 맞는가?
  [확인] vLLM profiling: seq_len < 128일 때 memory-bound 가능
  [확인] AMD MI300X: HBM bandwidth가 높아 crossover point가 다름
  [확인] SGLang RadixAttention: prefix caching으로 실제 compute 량 감소
[벤치마크] lmsys Chatbot Arena TTFT 분포 vs simulator 예측 비교
[판정] seq_len > 256에서 유효, 짧은 시퀀스는 [의도적 단순화]
```

#### 7-2. Memory Layout 알고리즘 검증

| 항목 | Simulator 알고리즘 | 검증 대상 | 참조 소스 |
|------|-------------------|----------|----------|
| **Model Weight** | `params × dtype_bytes / (TP × PP)` | 레이어별 분할 방식 (column/row parallel), embedding 처리 | vLLM `model_executor/models/`, PyTorch `ColumnParallelLinear` |
| **KV Cache** | `2 × (L/PP) × max(1, KVH/TP) × HD × dtype × seq × batch` | GQA/MQA head 분할, PagedAttention block 크기 | vLLM `core/block_manager.py`, `attention/backends/` |
| **Activation** | `batch × seq × hidden × factor` | FlashAttention recomputation, checkpoint 영향 | FlashAttention 논문 Table 1, vLLM `attention/backends/flash_attn.py` |
| **MoE Memory** | shared params + (expert_params / EP) | expert 분할 전략, shared expert 처리 | vLLM `fused_moe/layer.py`, DeepSeek-V2 논문 |
| **Overhead** | CUDA context + fragmentation | 실제 CUDA context 크기, PyTorch allocator 동작 | PyTorch `c10/cuda/`, NVIDIA CUDA Programming Guide |

**확인 포인트:**
```
[알고리즘] KV Cache per GPU = 2 × (layers/PP) × max(1, kv_heads/TP) × head_dim × dtype × seq × batch
[구현 차이] vLLM은 PagedAttention 사용 → block 단위 할당, 우리는 연속 메모리 가정
  [확인] vllm/core/block_manager_v2.py: block_size=16, 슬롯 단위 관리
  [확인] SGLang: RadixAttention, 트리 구조 KV cache
  [확인] AMD ROCm: PagedAttention 구현 차이 (hip backend)
[벤치마크] vLLM benchmark_throughput.py → 실제 GPU 메모리 사용량 vs simulator 예측
[판정] 총량 수준에서 ±5% 이내면 OK, block fragmentation은 [의도적 단순화]
```

#### 7-3. 외부 참조 소스 매핑

알고리즘 검증 시 반드시 아래 소스를 확인한다:

| 소스 | 용도 | 확인 방법 |
|------|------|----------|
| **vLLM** (`vllm-project/vllm`) | 핵심 추론 엔진 구현 | `gh search code --repo vllm-project/vllm`, WebFetch |
| **SGLang** (`sgl-project/sglang`) | RadixAttention, chunked prefill, 대안 구현 | `gh search code --repo sgl-project/sglang` |
| **PyTorch** (`pytorch/pytorch`) | distributed, NCCL 바인딩, memory allocator | `gh search code --repo pytorch/pytorch` |
| **NVIDIA** (데이터시트, 블로그) | GPU 스펙, CUDA 프로그래밍 가이드, TensorRT-LLM | WebSearch, WebFetch |
| **AMD** (ROCm 문서) | MI300X 스펙, HIP 호환성, 대역폭 차이 | WebSearch |
| **lmsys** (`lm-sys/FastChat`) | Chatbot Arena 벤치마크, 실측 latency 데이터 | `gh search code --repo lm-sys/FastChat`, WebFetch |
| **Megatron-LM** (논문 + 코드) | TP/PP/EP 효율 공식, micro-batch scheduling | 논문 Table/Figure 참조 |
| **DeepSpeed** (논문 + 코드) | ZeRO, MoE 통신, inference 최적화 | 논문 + `microsoft/DeepSpeed` |
| **FlashAttention** (논문 + 코드) | attention 메모리 최적화, IO-aware 알고리즘 | `Dao-AILab/flash-attention` |

**병렬 조사 전략:**
```
# 알고리즘 검증 시 3개 agent 병렬 투입 예시
Task 1 (Explore): "vLLM의 prefill latency 계산 로직과 scheduler 동작 분석"
Task 2 (Explore): "SGLang의 RadixAttention과 chunked prefill이 TTFT에 미치는 영향 조사"
Task 3 (Explore): "NVIDIA/AMD GPU의 실제 compute/memory throughput 벤치마크 데이터 수집"
```

#### 7-4. 알고리즘 검증 리포트 형식

```
## 알고리즘 검증: [함수명] — [날짜]

### Simulator 구현
- 알고리즘: [수식/로직 설명]
- 가정: [어떤 조건을 전제로 하는지]

### 참조 구현 비교
| 소스 | 구현 방식 | 차이점 |
|------|----------|--------|
| vLLM | [실제 구현] | [차이 설명] |
| SGLang | [실제 구현] | [차이 설명] |

### 벤치마크 대조
| 조건 | Simulator 예측 | 실측(출처) | 오차 |
|------|---------------|-----------|------|
| [설정] | [값] | [값(출처)] | [%] |

### 판정
- 일치 / 허용 가능한 단순화 / 수정 필요
- [사유]
```

### 8. 결과 기록

검증 결과를 `docs/research-references.md`에 추가한다:

```markdown
## [날짜] [카테고리] 검증

### 검증 항목
- ...

### 확인된 소스
- [링크] 설명

### 발견된 불일치
- ...

### 적용된 수정
- ...
```

## 규칙

1. **추론 금지**: "아마 이렇게 동작할 것이다"는 허용하지 않는다. 소스코드를 직접 확인한다.
2. **출처 필수**: 모든 수치에 출처를 명시한다. 출처가 없으면 [출처 불명]으로 표기한다.
3. **경험적 상수 표기**: 벤치마크 기반 상수는 [경험적] 태그와 함께 측정 조건을 기록한다.
4. **불일치 즉시 보고**: vLLM 소스와 불일치 발견 시 사용자에게 즉시 알린다.
5. **버전 명시**: 참조한 vLLM 버전(commit hash 또는 release tag)을 기록한다.
6. **단순화 사유 기록**: 의도적 단순화는 그 이유를 코드 주석과 문서에 모두 기록한다.
7. **vLLM 구현 우선**: simulator 로직은 반드시 vLLM의 실제 구현을 반영해야 한다. 공식을 임의로 만들지 않는다.
8. **계산 로직 중앙화**: 모든 수치 계산은 engine/ 내에서만 구현. UI/game에서 수식을 직접 작성하지 않는다.
9. **변경 기반 검증**: git diff로 변경된 부분만 집중 검증하여 효율을 높인다.

## 과정 표시

```
[대상] memory.ts:getModelMemoryGb — Dense model weight per GPU
[변경 감지] git diff -> memory.ts:L42-L58 변경됨
[공식] total_params x 1e9 x dtype_bytes / 1024^3 / (TP x PP)
[소스 확인] vllm/config.py:get_num_params() -> Line 156
[비교] 우리=total/(TP x PP), vLLM=total/(TP x PP) -> 일치
[주의] vLLM은 embedding layer를 별도 처리 — 우리는 단순화 [의도적]
```

## 프로젝트 내 관련 파일

- `src/engine/llm-dist-sim/` — 검증 대상 계산 로직
- `src/engine/llm-dist-sim/constants.ts` — 검증 대상 상수
- `src/adapters/llm-dist-sim/` — 얇은 adapter (위임만)
- `src/ports/simulator.ts` — interface 정의
- `docs/research-references.md` — 검증 결과 기록
- `llm-dist-sim/` — Python 원본 (TS 포팅 시 참조)
