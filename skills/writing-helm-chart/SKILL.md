---
name: writing-helm-chart
description: Helm Chart 또는 Kustomize 매니페스트를 작성·리뷰한다. Chart.yaml/values.yaml/values.schema.json, _helpers.tpl, base/overlays/components 구조, helm lint + kubeconform + kube-linter 검증, namespace 주입, CRD 분리 처리를 가이드한다. 사용자가 "helm chart", "values.yaml", "kustomize", "kustomization", "Chart.yaml", "helm 작성"을 언급할 때 사용한다.
---

# Writing Helm Chart / Kustomize

Helm 또는 Kustomize 로 K8s 매니페스트를 패키징할 때 따를 표준.

## 1. Helm Chart 구조
```
mychart/
├── Chart.yaml             # apiVersion: v2 + appVersion + version 분리
├── values.yaml            # 기본값 + 모든 키 주석
├── values.schema.json     # JSON Schema 강제 (helm 3.6+)
├── templates/
│   ├── _helpers.tpl       # named templates
│   ├── deployment.yaml
│   ├── service.yaml
│   └── NOTES.txt          # 설치 후 사용자 안내
└── crds/                  # CRD (helm 이 별도 처리)
```

**`Chart.yaml`**:
- `apiVersion: v2`
- `appVersion`: 앱 버전 (이미지 태그)
- `version`: 차트 버전 — 둘 분리

## 2. 명명 규칙
- `{{ include "chart.fullname" . }}` 일관 사용 (release prefix)
- label: `app.kubernetes.io/{name,instance,version,managed-by: Helm}`
- selector 는 `name + instance` 만 사용 (immutable)

## 3. values 설계
- 모든 키에 1줄 주석 (왜 / 기본값 의미)
- 환경별 차이는 `values-<env>.yaml` 분리 — base values 와 합산
- secret 은 values 에 두지 말 것 → `existingSecret` 참조 패턴
- resource 기본값: requests = limits 동일 (GPU/메모리 OOM 방지)
- replica 는 환경별 override 허용

## 4. Kustomize 구조
```
deploy/
├── base/
│   ├── kustomization.yaml      # resources: 명시
│   ├── deployment.yaml
│   └── service.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml  # patches, namespace
│   └── prod/
└── components/                  # cross-cutting (monitoring, security)
```

- `kustomization.yaml` 의 `resources:` 는 디렉토리 또는 파일 명시, 와일드카드 금지
- 환경 차이는 **patch (json/strategic merge)** 또는 **components**
- `commonLabels` 는 selector 까지 변경 → immutable 충돌 주의

## 5. Namespace 처리
- 매니페스트 `metadata.namespace` 하드코딩 금지
- Kustomize: `kustomization.yaml` `namespace: <env>` 로 주입
- Helm: `{{ .Release.Namespace }}` 또는 별도 `--namespace`

## 6. 검증 (CI 필수)
```bash
# Helm
helm lint mychart/
helm template myrelease mychart/ | kubeconform -strict -summary
helm template myrelease mychart/ | kube-linter lint -

# Kustomize
kustomize build overlays/dev | kubeconform -strict -summary
kustomize build overlays/dev | kube-linter lint -

# 공통
pluto detect <output>   # deprecated API 탐지
```

## 7. CRD 처리 (Helm)
- `crds/` 디렉토리 (helm 이 별도 처리)
- **CRD 업그레이드는 `helm upgrade` 가 처리하지 않음** → `kubectl apply -f crds/` 별도 단계 필요
- chart 가 CRD 와 CR 을 동시 포함하면 install 시 race — `pre-install` hook 으로 CRD 먼저

## 8. Helm Hooks
- `pre-install`/`post-upgrade` 등 사용 시 `weight` + `timeout` 명시 (무한 대기 방지)
- hook 은 멱등성 보장 어려움 — 가능하면 controller 패턴으로 대체

## 9. 흔한 함정
- `nameOverride` / `fullnameOverride` 누락 → release 명 충돌
- `imagePullSecrets` 환경별 다른데 base 에 하드코딩
- Kustomize `commonLabels` 가 selector 까지 변경 → immutable 충돌
- `tpl` 함수 중첩 — 가독성 ↓, 가능하면 `_helpers.tpl` 로
- Helm 으로 CRD upgrade 시도 (조용히 skip) — 별도 `kubectl apply`

## 10. 작성 체크리스트
- [ ] `Chart.yaml` apiVersion v2 + appVersion/version 분리
- [ ] `values.yaml` 모든 키 주석
- [ ] `values.schema.json` 으로 타입 강제
- [ ] `_helpers.tpl` 의 fullname 사용
- [ ] label 표준 (`app.kubernetes.io/*`)
- [ ] resource requests/limits
- [ ] `helm lint` + `kubeconform` 통과
- [ ] CRD 별도 처리 (있으면)

## 관련
- `coding-yaml-k8s.md` rule (K8s 매니페스트 일반 + 보안)
- `designing-workflow` skill (chart publish CI)
