---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tftest.hcl"
---

# Terraform 코딩 규칙

## 파일 구조
- `main.tf` (리소스), `variables.tf`, `outputs.tf`, `versions.tf`, `locals.tf`, `data.tf`
- Provider 설정은 root module에서만 (`providers.tf`)
- Child module은 provider 직접 설정 금지
- 500줄 초과 시 리소스 유형별 분리 (`network.tf`, `iam.tf`)

## 명명 규칙
- 모든 이름 snake_case
- 리소스 이름에 리소스 타입 반복 금지: `aws_instance.web` (not `aws_instance.aws_instance_web`)
- boolean 변수: `enable_`/`is_`/`has_` prefix
- 모든 변수에 `type`과 `description` 필수

## State 관리
- Remote state + state locking 필수
- 환경/서비스 단위 state 분리
- `.tfstate` VCS 커밋 절대 금지
- `.terraform.lock.hcl`은 반드시 커밋

## 보안
- `sensitive = true`로 시크릿 마스킹
- tfvars에 시크릿 금지 → 환경변수 또는 vault
- `*.tfvars`, `*.tfstate`, `.terraform/` gitignore

## 리소스
- `for_each` > `count` (조건부 리소스)
- implicit dependency 우선, `depends_on` 최소화
- `provisioner` 사용 회피 → Ansible/cloud-init

## Version
- `required_version`에 상한 설정: `>= 1.9.0, < 2.0.0`
- Provider: pessimistic constraint `~> 5.40`
- `default_tags`를 provider level에서 설정

## 검증 파이프라인
- `terraform fmt -check` → `terraform validate` → `tflint` → `checkov` → `terraform test`
