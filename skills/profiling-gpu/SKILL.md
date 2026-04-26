---
name: profiling-gpu
description: >
  NVIDIA GPU 워크로드의 성능을 프로파일링하고 병목을 분석한다. nsight systems(타임라인),
  nsight compute(커널 디테일), DCGM, nvidia-smi, vLLM 내장 프로파일러를 다룬다.
  occupancy, memory coalescing, NCCL 통신, GPUDirect RDMA, roofline 분석 포함.
  사용자가 "GPU 프로파일", "nsight", "ncu", "nsys", "kernel 분석", "occupancy",
  "warp", "memory coalescing", "NCCL", "GPUDirect"를 언급할 때 사용한다.
argument-hint: "[프로파일 대상 또는 시나리오]"
---

ultrathink

## GPU 프로파일링 프레임워크

기존 `profiling-performance` skill의 GPU 도메인 특화 보강. 일반 시스템 프로파일링은 `profiling-performance` 사용.

분석 대상: $ARGUMENTS

### 1. 도구 선택 매트릭스

| 목적 | 도구 | 강점 | 한계 |
|------|------|------|------|
| 전체 타임라인 (CPU+GPU+NCCL+API) | `nsys` (Nsight Systems) | 분산 워크로드 시각화, NVTX 마커 통합 | 커널 내부 디테일 부족 |
| 단일 커널 디테일 | `ncu` (Nsight Compute) | warp/SM/메모리 상세 metric, roofline | 측정 오버헤드 큼, 분산 분석 어려움 |
| 클러스터 모니터링 | `dcgmi` / DCGM exporter | 다중 노드, Prometheus 통합 | sample 간격 1초+ |
| 빠른 점검 | `nvidia-smi dmon`, `nvidia-smi pmon` | 가벼움, 즉시 실행 | metric 종류 제한 |
| 특정 워크로드 내장 | vLLM `--profile`, PyTorch `torch.profiler` | 코드 컨텍스트 매칭 | 외부 도구만큼 깊이 없음 |

### 2. 측정 시작 전 체크

```
- [ ] GPU 모델 / 드라이버 / CUDA 버전 기록 (nvidia-smi, nvcc --version)
- [ ] MIG / MPS 활성화 여부 확인 (multi-tenant 영향)
- [ ] CPU governor (performance vs powersave), HT 상태
- [ ] 백그라운드 GPU 사용자 없음 확인 (다른 process가 SM 점유 시 측정 오염)
- [ ] warmup 별도 실행, 측정 run 분리
- [ ] 3회 이상 측정 후 median 보고
```

### 3. nsys 워크플로우

```bash
# 수집
nsys profile -o report --trace=cuda,nvtx,osrt,nccl --cuda-memory-usage=true \
  --gpu-metrics-device=all python my_workload.py

# 보고서 분석
nsys stats report.nsys-rep --report cuda_gpu_kern_sum,cuda_gpu_mem_time_sum,nccl_sum
nsys-ui report.nsys-rep    # GUI에서 타임라인 확인
```

NVTX 마커 활용:
```python
import torch.cuda.nvtx as nvtx
nvtx.range_push("forward")
out = model(x)
nvtx.range_pop()
```
nsys 타임라인에서 코드 구간을 식별 가능 — 분산 작업 디버깅에 필수.

### 4. ncu 워크플로우 (커널 디테일)

```bash
# 특정 커널만 (전체 캡처는 매우 느림)
ncu --kernel-name regex:flash_attn --launch-skip 5 --launch-count 1 \
    --section SpeedOfLight --section Occupancy --section MemoryWorkloadAnalysis \
    --target-processes all python my_workload.py

# Roofline
ncu --section SpeedOfLight_RooflineChart -o report python my_workload.py
ncu-ui report.ncu-rep
```

핵심 지표:
- **SM occupancy**: 활성 warp 수 / 최대 warp 수. 낮으면 register/shared mem 사용량 점검
- **Compute throughput vs Memory throughput**: roofline 위치 결정
- **L1/L2/HBM hit rate**: 메모리 계층 효율
- **Warp execution efficiency**: divergent branch 영향
- **Memory coalescing**: global load/store가 32-byte sector 단위로 합쳐지는지

### 5. Roofline 분석 절차

```
1. Operational Intensity = FLOPs / Bytes_accessed 계산
2. 이론 peak FLOPS와 peak HBM bandwidth로 roofline 그림
3. 측정 위치가 memory-bound vs compute-bound 판별
4. Memory-bound면: kernel fusion, shared memory 활용, 메모리 access pattern 개선
5. Compute-bound면: tensor core 활용, instruction-level 최적화, occupancy 개선
```

H100/A100/L40S/MI300X 등 device별 spec(`whitepaper`)을 참조. theoretical과 실제 sustained의 갭도 표기.

### 6. NCCL / 분산 통신 분석

- nsys `--trace=nccl`로 collective 호출과 timing 캡처
- `NCCL_DEBUG=INFO`로 ring/tree 토폴로지 로그 수집
- bandwidth: 메시지 크기별 sustained throughput 측정 (`nccl-tests/all_reduce_perf`)
- 동기화 지점 식별: stragger node가 전체 latency 결정 (slowest worker bottleneck)
- GPUDirect RDMA: `nvidia-smi topo -m`로 PCIe/NVLink 토폴로지 확인, NIC와 GPU의 PCIe affinity

### 7. vLLM 특화

```bash
# vLLM 내장 프로파일러
VLLM_TORCH_PROFILER_DIR=./profiles python -m vllm.entrypoints.openai.api_server ...
# 요청 한 번 보낸 후 종료, profiles/에 trace.json 생성

# 또는 nsys + NVTX
nsys profile -t cuda,nvtx,osrt python -m vllm.entrypoints.openai.api_server ...
```

vLLM trace 분석 포인트:
- `Sampler` overhead (CPU bound 가능)
- attention kernel 선택 (flash_attn vs flashinfer vs xformers)
- KV cache 할당/해제로 인한 fragmentation
- TP rank 간 sync 지점 (all-reduce)

### 8. 결과 보고 형식

```
[버전] driver=550.142, CUDA=12.4, GPU=H100-80GB, vLLM=0.6.x@<sha>
[측정] median over N=5 runs, batch=32, seq_len=2048
[결과] sustained throughput=X TFLOPs (peak Y의 Z%), memory-bound
[근거] L2 hit rate=42%, HBM bandwidth=2.8TB/s (peak 3.35TB/s의 84%)
[제안] kernel fusion으로 HBM trip 감소 → 예상 1.3x speedup [추정]
```

## 규칙
- 측정 환경(driver, CUDA, GPU 모델)을 보고 첫 줄에 명시
- 측정값은 3회 이상 median, 단일 run 보고 금지
- "느리다"가 아니라 수치 + roofline 위치로 진단
- 추정과 측정을 `[추정]`/`[측정]`으로 명확히 구분
- 다른 프로세스의 GPU 점유 여부를 측정 전 확인
