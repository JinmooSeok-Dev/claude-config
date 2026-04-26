$ARGUMENTS 변경된(또는 staged/working tree) 파일에서 민감정보 누출을 검사한다.

## 절차
1. **대상 결정**:
   - 인자 없음: `git diff --staged` + working tree 변경
   - 인자가 경로: 해당 파일/디렉토리 전체
2. **자동 도구 사용** (있으면):
   ```bash
   gitleaks detect --source <path> --no-banner
   trufflehog filesystem <path> --no-update
   ```
3. **휴리스틱 grep** (도구 없을 때):
   - `grep -rE 'AKIA[0-9A-Z]{16}' <path>` (AWS access key)
   - `grep -rE 'ghp_[A-Za-z0-9]{36}' <path>` (GitHub PAT)
   - `grep -rE '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' <path>`
   - `grep -rE 'password[ \t]*=[ \t]*['\''"][^'\''"]+' <path>` (단순 패턴 — false positive 많음)
4. **`.env*`, `*secret*`, `vault.yml` 파일 자체 스캔** — 위치 자체로 위험
5. **commit 직전 확인** (옵션 `--block`): 발견 시 commit 차단 권장

## 결과 형식
```markdown
## Secret Scan: <branch>

### CRITICAL (3건)
1. `config/dev.yaml:12` — AWS access key 패턴
2. `scripts/setup.sh:45` — hardcoded GitHub PAT
3. `.env.example:8` — 실제 값처럼 보임 (placeholder 권장)

### WARNING (2건)
4. `docs/setup.md:120` — password 패턴 (false positive 가능)

## 권장 조치
- 발견된 secret → 즉시 회전 (`gh secret rotate ...`)
- 이력 정리: `git filter-repo` 또는 BFG (이미 push 됐으면 회전이 우선)
```

## 흔한 false positive
- 테스트용 fake key (실제 작동 X)
- 문서의 예시 (placeholder)
- third-party 라이브러리의 예제 코드

## 관련
- `~/.claude/settings.json` permissions.deny 의 `Read(.env*)`, `Read(**/*secret*)`
- `auditing-workflow` skill (CI 영역의 secret echo)
