---
paths:
  - "**/playbooks/**"
  - "**/roles/**"
  - "**/inventories/**"
  - "**/ansible.cfg"
  - "**/*playbook*.yml"
  - "**/*ansible*.yml"
---

# Ansible 코딩 규칙

## Task
- 모든 task에 `name` 필수 — 동사로 시작
- FQCN 사용 필수: `ansible.builtin.copy` (not `copy`)
- 전용 모듈 우선, `command`/`shell` 최소화
- `command`/`shell` 사용 시 `creates`, `changed_when` 필수
- `changed_when: false` — 정보 조회용 task에 적용

## 변수
- role prefix 사용: `nginx_port`, `redis_port` (충돌 방지)
- `defaults/main.yml` — 사용자 오버라이드 가능한 변수
- `vars/main.yml` — 내부 상수
- 파일 mode는 항상 string: `mode: "0644"` (not `mode: 0644`)

## 시크릿
- `ansible-vault` 암호화 필수
- `vault_` prefix 패턴: vault.yml에 `vault_db_password`, vars.yml에서 참조
- Vault password VCS 커밋 금지

## 멱등성
- 같은 playbook 여러 번 실행해도 결과 동일해야 함
- `block/rescue` > `ignore_errors: true`

## 문법
- `loop` 사용 (`with_*` 레거시 금지)
- `when: result is changed` (not `when: result|changed`)
- `true`/`false` 사용 (`yes`/`no` 금지)

## 테스트
- Molecule로 role 테스트
- ansible-lint profile `production`
