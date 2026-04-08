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

## Kustomize
- base/overlays 구조, components/로 cross-cutting concern 분리
- `namePrefix` 보다 `labels`로 환경 구분

## 검증 도구
- yamllint, kube-linter, kubeconform, pluto (deprecated API 탐지)
