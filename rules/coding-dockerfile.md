---
paths:
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/Containerfile"
  - "**/.dockerignore"
---

# Dockerfile / Containerfile 코딩 규칙

## 베이스 이미지
- 태그 고정 (`latest` 금지) — digest pinning 권장 (`@sha256:...`)
- 운영용은 distroless / UBI minimal / `*-slim` 우선
- 빌드용 vs 런타임용 구분 — multi-stage 로 런타임 최소화
- 파이썬: `python:3.X-slim`, Go: `golang:1.X` (build) → `gcr.io/distroless/static` (runtime)

## 멀티 스테이지
```dockerfile
FROM golang:1.22 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/app ./cmd/app

FROM gcr.io/distroless/static:nonroot
COPY --from=builder --chown=nonroot:nonroot /out/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

## 캐시 효율
- `COPY` 는 변경 빈도 낮은 것부터 (의존성 → 소스 코드)
- 의존성 매니페스트(`go.mod`/`requirements.txt`/`package.json`) 먼저 복사 + 설치
- BuildKit cache mount 활용:
  ```dockerfile
  RUN --mount=type=cache,target=/root/.cache/go-build \
      --mount=type=cache,target=/go/pkg/mod \
      go build ...
  ```

## 보안
- **non-root 실행**: `USER 1000:1000` 또는 distroless `:nonroot`
- secret 은 `--mount=type=secret` 으로 주입, layer 에 남기지 않기
- `apt-get` 사용 시 `--no-install-recommends` + 같은 RUN 에서 cache 정리:
  ```dockerfile
  RUN apt-get update && apt-get install -y --no-install-recommends pkg \
      && rm -rf /var/lib/apt/lists/*
  ```
- `ADD` 보다 `COPY` (URL 다운로드는 명시적 `RUN curl`)
- `chmod 777` / `chown root` 금지

## 메타데이터
- `LABEL org.opencontainers.image.{source,version,licenses,revision}`
- `HEALTHCHECK` 정의 (간단한 `CMD curl -f localhost:PORT/health`)
- `EXPOSE <port>` (문서적, 강제 아님)

## .dockerignore (필수)
- `.git/`, `*.md`, `node_modules/`, `__pycache__/`, `.venv/`, `dist/`, `*.log`
- 컨텍스트 크기 줄이고 불필요한 invalidation 방지

## 흔한 함정
- `COPY . .` 만 쓰면 매 빌드 cache miss — 의존성 매니페스트 먼저 복사
- `ENV PYTHONUNBUFFERED=1` 누락 → log buffering
- `WORKDIR` 미설정 → root 에 파일 떨어짐
- shell form `CMD app` vs exec form `CMD ["app"]` — exec form 우선 (signal forwarding)
- `latest` 태그 → reproducibility 손상

## 검증
- `docker build` + `docker scout cves <image>` (또는 `trivy image`)
- `hadolint Dockerfile`
