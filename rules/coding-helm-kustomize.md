---
paths:
  - "**/Chart.yaml"
  - "**/values.yaml"
  - "**/values.schema.json"
  - "**/kustomization.yaml"
  - "**/kustomization.yml"
  - "helm/**"
  - "charts/**"
  - "deploy/**"
---

# Helm Chart / Kustomize 코딩 규칙

## Helm Chart 구조
- `Chart.yaml`: `apiVersion: v2`, `appVersion` 과 `version` 분리 (전자=앱, 후자=차트)
- `values.yaml`: 기본값 + **모든 키 주석 1줄 설명**
- `values.schema.json`: JSON Schema 로 타입/required 강제 (helm 3.6+)
- `templates/_helpers.tpl`: named templates 한 곳에 — `{{ include "chart.fullname" . }}`
- `templates/NOTES.txt`: 설치 후 사용자 안내

## Helm 명명 컨벤션
- `{{ include "chart.fullname" . }}` 일관 사용 (release 명 prefix)
- label: `app.kubernetes.io/name`, `instance`, `version`, `managed-by: Helm`
- selector 는 `name + instance` 만 사용 (immutable)

## Helm Lint·검증
- `helm lint` (CI 필수)
- `helm template <release> . | kubeconform -strict -summary`
- `helm template <release> . | kube-linter lint -`
- 차트 변경 시 `helm template` diff 체크

## Kustomize 구조
- `base/` (공통) + `overlays/<env>/` (환경별 차이)
- `components/` (cross-cutting 기능: monitoring/security overlay)
- `kustomization.yaml` 의 `resources:` 는 디렉토리 또는 파일 명시, 와일드카드 금지
- 환경 차이는 **patch (json/strategic merge)** 또는 **components** 로

## namespace 처리
- 매니페스트 `metadata.namespace` 하드코딩 금지
- Kustomize: `kustomization.yaml` `namespace: <env>` 로 주입
- Helm: `{{ .Release.Namespace }}` 또는 별도 `--namespace`

## values 설계
- 환경별 차이는 `values-<env>.yaml` 로 분리 — base values 와 합산
- secret 은 values 에 두지 말 것 → `existingSecret` 참조 패턴
- resource 기본값: requests = limits 동일 (GPU/메모리 OOM 방지)
- replica 는 환경별 override 허용

## CRD 처리
- chart 에 CRD 포함 시 `crds/` 디렉토리 (helm 이 별도 처리)
- CRD 업그레이드는 `helm upgrade` 가 처리하지 않음 → `kubectl apply -f crds/` 별도

## 흔한 함정
- `nameOverride` / `fullnameOverride` 누락 → release 명 충돌
- `imagePullSecrets` 환경별 다른데 base 에 하드코딩
- Kustomize `commonLabels` 가 selector 까지 변경 → immutable 충돌
- Helm hook (`pre-install`/`post-upgrade`) 무한 대기 — `weight` + `timeout` 명시
- `tpl` 함수 중첩 — 가독성 ↓, 가능하면 `_helpers.tpl` 로

## 검증 도구 체크리스트
- `helm lint` / `helm template ... | kubeconform`
- `kustomize build overlays/<env> | kubeconform`
- `kube-linter lint <chart-or-overlay>`
- `pluto detect <output>` (deprecated API 탐지)
