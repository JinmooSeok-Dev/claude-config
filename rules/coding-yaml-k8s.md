---
paths:
  - "**/*.yaml"
  - "**/*.yml"
  - "**/kustomization.*"
  - "**/Chart.yaml"
---

# YAML / Kubernetes / OpenShift 코딩 규칙

## YAML 기본
- indent 2 spaces, sequence도 동일
- `yes`/`no`/`on`/`off` 사용 금지 → `true`/`false`
- 줄 길이 150자 이내

## Kubernetes Manifest
- 표준 label 체계: `app.kubernetes.io/{name,instance,version,component,part-of,managed-by}`
- resource requests 반드시 설정, GPU는 requests=limits 동일
- securityContext 기본: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`
- 이미지 태그 고정 (`latest` 금지), digest 또는 고정 버전
- readiness + liveness probe 필수
- namespace 하드코딩 금지 → Kustomize/Helm으로 주입

## OpenShift
- `DeploymentConfig` 사용 금지 → 표준 `Deployment` 사용
- SCC는 `restricted-v2` 우선, 커스텀 SCC 최소화

## KServe
- GPU workload는 `RawDeployment` 모드 (scale-to-zero 비실용적)
- vLLM 서빙 시 `/health` endpoint으로 probe 설정
- PVC 기반 모델 저장소로 pull 시간 단축

## vLLM / LLM 서빙 패턴
- `runtimeClassName: nvidia` 또는 `nvidia-cdi` 명시 (NVIDIA Container Toolkit 모드에 맞춰서)
- `nvidia.com/gpu` requests=limits 동일, 부분 GPU(MIG) 사용 시 `nvidia.com/mig-1g.10gb` 같은 specific resource 명시
- `shm` 부족 방지: `emptyDir` + `medium: Memory` + `sizeLimit: 16Gi` 마운트(`/dev/shm`) — NCCL/torch.distributed에서 필수
- `terminationGracePeriodSeconds: 600` 이상 (대형 모델 정상 종료 시간 확보)
- `startupProbe` 필수 — 모델 로딩 시간(수십 초 ~ 수 분) 보호. `failureThreshold * periodSeconds > 모델 로딩 시간`
- KServe 패턴: `InferenceService.spec.predictor.model.storageUri: "pvc://<pvc-name>/<path>"`

## KubeVirt VM
- `domain.cpu`: `cores` + `dedicatedCpuPlacement: true` 조합으로 cpu pinning
- 노드 사전 설정 필수: `cpu-manager-policy=static`, `topology-manager-policy=single-numa-node`
- VFIO 디바이스 패스스루: `domain.devices.hostDevices[].name`은 `KubeVirt.spec.configuration.permittedHostDevices`에 사전 등록
- 대용량 VM은 `hugepages: pageSize: 1Gi` 활용 (노드 부팅 인자 `hugepagesz=1G hugepages=N` 사전 설정)
- `evictionStrategy: LiveMigrate`는 패스스루 VM에 적용 불가 → `None` 또는 `External`
- VM readiness는 게스트 agent 또는 TCP probe로 (HTTP probe는 게스트 응답에 의존)
- vCPU 64 초과 + VFIO 결합 시 SeaBIOS/SMM 이슈 가능 — `firmware: bootloader: efi`로 OVMF 사용

## Multus / SR-IOV
- `NetworkAttachmentDefinition`은 namespace-scoped — VM/Pod와 동일 namespace 또는 default에 배치
- Pod의 `k8s.v1.cni.cncf.io/networks` annotation으로 secondary network 첨부. 형식: `<namespace>/<nad-name>` 또는 `<nad-name>`
- SR-IOV: `SriovNetworkNodePolicy`로 VF 생성 → `SriovNetwork`로 NAD 자동 생성 → Pod에서 resource 요청
- RDMA: `rdma/hca` resource 동시 요청, `securityContext.capabilities.add: ["IPC_LOCK"]` 필수
- DRA(Dynamic Resource Allocation) 사용 시 `resourceClaims`로 GPU/NIC attach (legacy device plugin과 혼용 주의)

## Kustomize
- base/overlays 구조, components/로 cross-cutting concern 분리
- `namePrefix` 보다 `labels`로 환경 구분

## 검증 도구
- yamllint, kube-linter, kubeconform, pluto (deprecated API 탐지)
