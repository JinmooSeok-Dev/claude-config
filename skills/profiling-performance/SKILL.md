---
name: profiling-performance
description: >
  시스템, 애플리케이션, 커널, GPU의 성능을 프로파일링하고 병목을 분석한다.
  latency, throughput, FLOPS, 메모리 대역폭, cache hit rate 등을 다룬다.
  사용자가 "성능 분석", "프로파일링", "병목", "느려", "latency",
  "throughput", "벤치마크", "perf", "nsight"를 언급할 때 사용한다.
argument-hint: "[대상 시스템 또는 코드]"
---

ultrathink

## 성능 프로파일링 프레임워크

$ARGUMENTS에 대해:

### 1. 측정 대상 정의

무엇을 측정할 것인지 먼저 명확히 한다:

| 계층 | 측정 항목 | 도구 |
|------|----------|------|
| **Application** | 응답 시간, QPS, 에러율 | time, cProfile, py-spy, go pprof |
| **Runtime** | GC 빈도, 스레드 경합, 메모리 할당 | tracemalloc, jemalloc, GODEBUG |
| **OS/Kernel** | syscall, context switch, I/O wait | perf, strace, ftrace, bpftrace, eBPF |
| **CPU** | IPC, cache miss, branch miss | perf stat, likwid, vtune |
| **GPU** | SM occupancy, 메모리 대역폭, 커널 시간 | nsight systems, nsight compute, nvprof |
| **Network** | RTT, bandwidth, RDMA 성능 | iperf3, perftest (ib_read_bw), tcpdump |
| **Storage** | IOPS, latency, queue depth | fio, iostat, blktrace |

### 2. 측정 방법론

```
- [ ] 베이스라인 측정 (변경 전 상태)
- [ ] 워크로드 특성 파악 (CPU-bound? I/O-bound? Memory-bound?)
- [ ] 프로파일 수집 (충분한 샘플 확보)
- [ ] 데이터 분석 (핫스팟, 분포, 이상치)
- [ ] 병목 식별 및 근거 제시
```

### 3. 병목 분석 패턴

**Utilization-Saturation-Errors (USE) Method:**
각 리소스(CPU, MEM, DISK, NET, GPU)에 대해:
- Utilization: 얼마나 사용되고 있는가? (%)
- Saturation: 대기열이 쌓이고 있는가?
- Errors: 에러가 발생하고 있는가?

**Roofline Model (compute 분석):**
```
성능(FLOPS) vs Operational Intensity(FLOPS/Byte)

         ___________  peak FLOPS
        /
       /  <-- memory bandwidth bound
      /
     /______________ peak bandwidth
```
- 메모리 대역폭 한계인가, 연산 한계인가?
- 현재 위치에서 이론적 최대까지의 갭

### 4. 결과 보고

- **수치로 보고한다**: "느리다"가 아닌 "p99 latency가 150ms, 목표 대비 3배"
- 병목 원인과 근거 (프로파일 데이터 인용)
- 개선 가능한 지점과 예상 효과
- 추가 측정이 필요한 영역

## 과정 표시
매 단계마다 아래 형식으로 과정을 보여준다:
```
[도구] perf stat -e cache-misses,instructions ./target
[측정] L3 cache miss rate: 12.3% (높음, 일반적 기준 <5%)
[판단] cache miss가 주요 병목 → memory access pattern 분석 필요
[근거] IPC=0.4 (기대치 2.0 대비 낮음) + cache miss 상관관계
```
- 사용하는 도구와 명령어를 먼저 보여준다
- 측정값에 "좋음/나쁨" 기준을 함께 표시한다
- 왜 이 도구를 선택했는지 밝힌다

## 규칙
- 추측하지 않고 측정한다
- 한 번에 하나의 변수만 변경한다
- 환경 조건을 기록한다 (하드웨어, OS, 부하 수준)
- 통계적으로 유의미한 샘플 수를 확보한다
