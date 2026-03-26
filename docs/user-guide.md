# omo 플러그인 v0.2.0 — 전체 기능 및 유저 플로우 가이드

## 1. 설치 및 설정

### 개발자 모드 (소스에서 직접 로드)
```bash
cd claude-oc-omo
claude --plugin-dir .
```

### 마켓플레이스 설치
```bash
./scripts/build-marketplace.sh
claude plugin install -s local omo
```

### Ralph Loop 훅 설정 (ralph-loop 사용 시 필수)
사용할 프로젝트의 `.claude/settings.local.json`에 추가:
```json
{
  "hooks": {
    "Stop": [
      { "matcher": "", "hooks": ["bash scripts/ralph-loop-guard.sh"] }
    ]
  }
}
```

### 로드 확인
```
/reload-plugins
```

---

## 2. 플러그인 구성 요소 전체 현황

### 에이전트 11개

| 에이전트 | 모델 | maxTurns | 역할 | 쓰기 권한 |
|---------|------|:--------:|------|:--------:|
| **oracle** | opus | 14 | 아키텍처 분석, 어려운 디버깅 자문 | 읽기 전용 |
| **critic** | opus | 12 | 플랜 실행 가능성 검증 | 읽기 전용 |
| **planner-sisyphus** | sonnet | 16 | 인터뷰 모드 기획, 실행 계획 분해 | 읽기 전용 |
| **atlas** | sonnet | 24 | 다수 에이전트 조율 오케스트레이터 | 위임만 |
| **build-integrator** | sonnet | 22 | 자율적 다중 파일 구현 | acceptEdits |
| **bug-hunter** | sonnet | 14 | 장애 원인 축소, 재현 경로 제안 | 읽기 전용 |
| **vision** | sonnet | 8 | 스크린샷/PDF/이미지 분석 | 읽기 전용 |
| **repo-librarian** | haiku | 10 | 레포 탐색, 컨벤션 조회 | 읽기 전용 |
| **test-commander** | haiku | 12 | 최소 검증 커맨드 선정 및 실행 | 읽기 전용 |
| **deepsearch** | haiku | 14 | 다전략 병렬 코드베이스 검색 | 읽기 전용 |
| **docs-keeper** | haiku | 12 | 문서/코멘트/프롬프트 위생 | acceptEdits |

### 스킬 14개

모든 스킬은 자동 인터셉트와 `#단축키` 패턴을 지원합니다. `/omo:ultrawork` 대신 `#ulw`만 입력해도 동작합니다.

| 스킬 | 단축키 | 호출 방법 | 설명 |
|------|:------:|----------|------|
| **ultrawork** | `#ulw` | `#ulw <목표>` 또는 `/omo:ultrawork` | 대규모 작업 오케스트레이션 |
| **kickoff-task** | `#kit` | `#kit <목표>` 또는 `/omo:kickoff-task` | 인터뷰 모드 작업 초기화 |
| **ralph-loop** | `#rl` | `#rl <목표>` 또는 `/omo:ralph-loop` | 완료까지 멈추지 않는 시스템 강제 루프 |
| **repo-radar** | `#rr` | `#rr [범위]` 또는 `/omo:repo-radar` | 레포 매핑 + 계층 AGENTS.md |
| **resume-work** | `#rw` | `#rw [목표]` 또는 `/omo:resume-work` | 세션 컨텍스트 복구 |
| **bug-hunt** | `#bh` | `#bh <증상>` 또는 `/omo:bug-hunt` | 장애 트리아지 및 디버깅 |
| **ship-check** | `#sc` | `#sc [범위]` 또는 `/omo:ship-check` | 출시 전 점검 |
| **diff-review** | `#dr` | `#dr [범위]` 또는 `/omo:diff-review` | 5관점 코드 리뷰 |
| **qa-loop** | `#qa` | `#qa [테스트 커맨드]` 또는 `/omo:qa-loop` | 자동 테스트-수정-재테스트 |
| **deep-search** | `#ds` | `#ds <쿼리>` 또는 `/omo:deep-search` | 다전략 병렬 코드 검색 |
| **spawn** | `#sp` | `#sp <목표>` 또는 `/omo:spawn` | 병렬 에이전트 디스패치 |
| **handoff** | `#ho` | `#ho [다음 단계]` 또는 `/omo:handoff` | 구조화된 인수인계 노트 |
| **comment-check** | `#cc` | `#cc [범위]` 또는 `/omo:comment-check` | 코멘트/문서 위생 점검 |
| **mcp-doctor** | `#mcp` | `#mcp` 또는 `/omo:mcp-doctor` | MCP 설정 진단 |

### 스크립트 11개

| 스크립트 | 용도 |
|---------|------|
| `build-marketplace.sh` | 마켓플레이스 배포 번들 빌드 |
| `latest-context.sh` | 현재 세션 컨텍스트 출력 |
| `mcp-doctor.sh` | MCP 설정 진단 |
| `new-task-note.sh` | 새 작업 노트 생성 |
| `statusline.sh` | 셸 프롬프트 상태 표시줄 |
| `ralph-loop-start.sh` | Ralph Loop 초기화 (상태 파일 생성) |
| `ralph-loop-guard.sh` | Stop 훅 — 3단계 상태 머신 |
| `ralph-loop-done.sh` | "작업 완료" 신호 |
| `ralph-loop-verified.sh` | "Oracle 승인" 신호 |
| `ralph-loop-reject.sh` | "Oracle 거부" — 작업 재개 |
| `ralph-loop-cancel.sh` | 루프 강제 취소 |

### 상태 파일 (실행 시 자동 생성)

```
.claude/state/
├── current-task.txt        <- 현재 작업 포인터
├── tasks/                  <- 작업 노트들
├── handoffs/               <- 인수인계 노트들
├── repo-map.md             <- 레포지토리 맵
└── ralph-loop.json         <- Ralph Loop 상태 머신
```

---

## 3. 유저 플로우별 상세 설명

---

### 플로우 A: 자동 인터셉트 — 검색 (deep-search)

**자동 인터셉트 = 사용자가 `/omo:` 명령 없이도 자연어로 발동**

```
사용자: 인증 미들웨어 어디있어?
        ^^^^^^^^^^^^^^^^^^
        모델이 deep-search 스킬 자동 인식
```

**내부 동작:**

```
1) 쿼리 분석
   ├─ Literal: "인증 미들웨어 위치"
   ├─ Actual need: 인증 흐름 수정하려고 시작점 찾는 중
   └─ Success: 파일 경로 + 흐름 설명

2) 5개 전략 병렬 실행 (deepsearch 에이전트, haiku)
   ├─ Symbol search: grep "auth" "middleware" 함수/클래스명
   ├─ Text search: grep "authenticate" "verify" "token"
   ├─ File pattern: glob "**/auth*" "**/middleware*"
   ├─ Import search: grep "import.*auth" "require.*auth"
   └─ Git history: git log --all -- "*auth*"

3) 결과 통합
   ├─ Files:
   │   ├─ /src/middleware/auth.ts — 주요 인증 미들웨어 정의
   │   ├─ /src/routes/index.ts — 미들웨어 적용 위치
   │   └─ /src/utils/jwt.ts — 토큰 검증 유틸리티
   ├─ Answer: "인증 흐름: auth.ts에서 JWT 검증 → routes에서 라우트별 적용"
   └─ Confidence: HIGH
```

---

### 플로우 B: 자동 인터셉트 — 코드 리뷰 (diff-review)

```
사용자: 지금 변경사항 리뷰해줘
        ^^^^^^^^^^^^^^^^^^^^
        모델이 diff-review 스킬 자동 인식
```

**내부 동작:**

```
1) git diff + git diff --cached 수집

2) 5개 관점에서 병렬 리뷰
   ├─ 정확성: 로직 오류, null 처리, 경계 조건
   ├─ 보안: OWASP Top 10, 인젝션, XSS, 인증 우회
   ├─ 성능: N+1 쿼리, 메모리 누수, 무한 루프
   ├─ 유지보수: 네이밍, 죽은 코드, 복잡성
   └─ 스코프: 의도치 않은 변경, 디버그 잔재, TODO

3) 심층 분석 (필요시)
   ├─ oracle (opus): 아키텍처 우려
   ├─ deepsearch (haiku): 변경 코드가 다른 곳에서 어떻게 사용되는지
   └─ test-commander (haiku): 어떤 테스트가 이 변경을 커버해야 하는지

4) 결과
   ├─ Summary: "전반적으로 양호하나 SQL 인젝션 취약점 1건"
   ├─ BLOCKING: auth.js:42 — 사용자 입력이 직접 쿼리에 삽입됨
   ├─ WARNING: utils.js:15 — 사용하지 않는 import
   ├─ NOTE: config.js:8 — 매직 넘버를 상수로 추출 권장
   └─ Missing tests: auth 모듈에 대한 단위 테스트 없음
```

---

### 플로우 C: 자동 인터셉트 — 세션 재개 (resume-work)

```
사용자: 계속해
        ^^^^
        모델이 resume-work 스킬 자동 인식
```

또는: "이어서", "어디까지 했었지?", "아까 하던 거"

**내부 동작:**

```
1) 상태 파일 읽기
   ├─ current-task.txt → "인증 미들웨어 리팩토링"
   ├─ 최신 핸드오프 노트 읽기
   └─ 최신 작업 노트 읽기

2) 워킹 트리 검사
   ├─ git status --short → 2 files modified
   ├─ git diff --stat → auth.ts (+45 -12), routes/index.ts (+8 -3)
   └─ git diff --name-only → 변경 파일 목록

3) (필요시) repo-librarian으로 기능 의도 복원

4) 컨텍스트 복구 요약
   ├─ 진행 중 작업: JWT → 세션 기반 인증 전환
   ├─ 수정된 파일: auth.ts, routes/index.ts
   ├─ 미완성: test-user.js, test-api.js 실패
   ├─ 다음 3가지 액션:
   │   1. src/routes/user.ts에 세션 검증 적용
   │   2. test-user.js 수정
   │   3. npm test로 전체 검증
   └─ 검증 커맨드: npm test
```

---

### 플로우 D: 자동 인터셉트 — 버그 트리아지 (bug-hunt)

```
사용자: 로그인하면 가끔 500 에러가 나
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
        모델이 bug-hunt 스킬 자동 인식
```

또는: "안 돼", "에러 나", "왜 이러지", "버그가 있는 것 같아"

**내부 동작:**

```
1) 증상 재정의
   └─ "로그인 POST /auth/login이 간헐적으로 500 Internal Server Error 반환"

2) bug-hunter 투입 (sonnet)
   ├─ 관련 파일 탐색 (auth 컨트롤러, 미들웨어, DB 연결)
   ├─ 에러 로그 확인
   └─ "간헐적" → 레이스 컨디션 또는 커넥션 풀 고갈 의심

3) test-commander (haiku)로 최소 검증 루프 설계
   └─ "wrk -t4 -c100 -d10s POST /auth/login 으로 부하 재현"

4) 근본 원인 식별 시 → build-integrator (sonnet)에 수정 위임
   └─ 커넥션 풀 크기 5 → 20 + 타임아웃 추가

5) 결과 보고
   ├─ Reproduction: 동시 100 커넥션으로 10초 부하 시 재현
   ├─ Root cause: 커넥션 풀 크기 초과
   ├─ Fix: 풀 크기 20으로 증가 + 커넥션 타임아웃 추가
   ├─ Verification: 부하 테스트 통과
   └─ Uncertainty: 프로덕션 동시 접속 수 미확인
```

---

### 플로우 E: 새 작업 시작하기 (kickoff-task)

```
사용자: /omo:kickoff-task 사용자 인증 기능 추가
```

**내부 동작:**

```
Phase 1 — Discovery
   ├─ CLAUDE.md 읽기 (프로젝트 규칙)
   ├─ 빌드/테스트 스크립트 탐색
   ├─ Explore로 관련 코드 파악
   └─ 테스트 인프라 존재 여부 확인

Phase 2 — Scope Interview (복잡한 목표)
   ├─ "OAuth vs JWT vs 세션 중 어떤 방식?"
   ├─ "어떤 파일은 건드리면 안 되나요?"
   └─ "완료 기준이 뭔가요?"

Phase 3 — Task Note 생성
   ├─ .claude/state/tasks/20260326-사용자-인증.md 생성
   ├─ current-task.txt → 해당 파일 가리킴
   └─ 내용:
       ├─ 목표
       ├─ 가정
       ├─ 스코프 경계 (포함/제외)
       ├─ 대상 파일
       ├─ 테스트 전략
       ├─ 검증 계획
       └─ 다음 액션
```

---

### 플로우 F: 대규모 작업 실행 (ultrawork)

```
사용자: /omo:ultrawork API를 REST에서 GraphQL로 마이그레이션
```

**내부 동작:**

```
Phase 0 — Intent Gate
   └─ 질문? → 답변. 사소한 작업? → 직접 실행. 대규모 → Phase 1.

Phase 1 — Context & Planning
   ├─ 목표 한 문장 재정의
   ├─ CLAUDE.md, .claude/state/ 읽기
   ├─ kickoff-task로 작업 노트 생성
   ├─ Todo 리스트 생성
   ├─ planner-sisyphus (sonnet)로 실행 계획 수립
   │   └─ 의도 분류 → 인터뷰 → 계획 생성 → effort 태깅
   └─ critic (opus)으로 계획 검증 (5단계 이상이면)
       └─ "이 계획을 막힘 없이 실행할 수 있는가?"
       └─ Verdict: GO / GO_WITH_CHANGES / RECONSIDER

Phase 2 — Execution
   ├─ 독립 슬라이스 식별 → spawn으로 최대 3개 병렬 위임
   │   ├─ build-integrator: 스키마 마이그레이션
   │   ├─ build-integrator: 리졸버 구현
   │   └─ build-integrator: 클라이언트 쿼리 변환
   ├─ 버그 발견 → bug-hunter 투입
   ├─ 각 편집 클러스터 후 즉시 검증
   └─ 2회+ 실패 → oracle (opus)에 아키텍처 자문

Phase 3 — Verification & Completion
   ├─ ship-check 실행
   ├─ 검증 실패 → 수정 후 재검증 (멈추지 않음)
   ├─ 컨텍스트 한계 접근 → handoff
   └─ 최종 보고: 결과, 변경 파일, 검증, 리스크
```

**에이전트 체인:**
```
ultrawork
  ├─ planner-sisyphus (sonnet, 계획)
  ├─ critic (opus, 계획 검증)
  ├─ build-integrator x3 (sonnet, 구현, 병렬)
  ├─ bug-hunter (sonnet, 필요시)
  ├─ test-commander (haiku, 검증 전략)
  ├─ oracle (opus, 아키텍처 자문, 필요시)
  └─ docs-keeper (haiku, 문서 정리, 필요시)
```

---

### 플로우 G: 끝까지 완료하는 루프 (ralph-loop)

```
사용자: /omo:ralph-loop 결제 시스템 통합 구현
```

#### G-1. 기본 모드

```
1) ralph-loop-start.sh "결제 시스템 통합"
   → .claude/state/ralph-loop.json (phase: "working")

2) 작업 수행 (Todo 리스트 기반)

3) 에이전트가 멈추려 함
   └─ Stop 훅 발동 (ralph-loop-guard.sh)
       ├─ phase="working" → exit 2 (차단!)
       └─ stdout: "[RALPH LOOP — Iteration 2/100] 계속해라."
       → 에이전트 강제 재개

4) 모든 작업 완료 + 자체 검증 통과
   └─ bash scripts/ralph-loop-done.sh
       → phase: "working" → "verified"

5) 에이전트가 멈추려 함
   └─ Stop 훅: phase="verified" → exit 0 (허용!)
       → 상태 파일 삭제, 루프 종료
```

#### G-2. Oracle 검증 모드

```
사용자: /omo:ralph-loop 결제 시스템 통합 --oracle
```

```
1) ~ 3) 동일 (작업 + 강제 계속)

4) 모든 작업 완료
   └─ bash scripts/ralph-loop-done.sh
       → phase: "working" → "verification_pending"

5) 에이전트가 멈추려 함
   └─ Stop 훅: phase="verification_pending" → exit 2 (차단!)
       stdout: "Oracle을 호출해서 검증받아라"

6) Oracle 호출
   └─ task(subagent_type="oracle", prompt="회의적으로 검토해줘...")
       oracle (opus): "결제 실패 시 롤백 로직이 빠져있다"

7-A) Oracle 거부
   └─ bash scripts/ralph-loop-reject.sh
       → phase: "verification_pending" → "working"
       → 롤백 로직 구현 → 4)로 복귀

7-B) Oracle 승인
   └─ bash scripts/ralph-loop-verified.sh
       → phase: "verification_pending" → "verified"
       → 다음 stop에서 종료 허용
```

**상태 머신:**
```
               ralph-loop-done.sh          ralph-loop-verified.sh
[working] ─────────────────────→ [verification_pending] ──────────────────→ [verified] → 종료
    ^                                      |
    └──────── ralph-loop-reject.sh ────────┘
              (Oracle 거부: 수정 후 재시도)
```

---

### 플로우 H: 자동 테스트-수정 루프 (qa-loop)

```
사용자: /omo:qa-loop npm test
```

```
Cycle 1:
   ├─ npm test → 5 passed, 3 failed
   ├─ 실패 분석 (bug-hunter 필요시 투입)
   └─ 수정 적용 (build-integrator)

Cycle 2:
   ├─ npm test → 7 passed, 1 failed
   └─ 수정 적용

Cycle 3:
   ├─ npm test → 8 passed, 0 failed
   └─ 완료!

에스컬레이션 체인:
   같은 테스트 2회 실패 → bug-hunter (sonnet) 투입
   3사이클 무진전 → oracle (opus) 투입
   스코프 밖 수정 필요 → 중단 + 보고

결과:
   ├─ Test command: npm test
   ├─ Iterations: 3
   ├─ Result: ALL PASS
   ├─ Fixes applied: 3건 (파일 + 설명)
   └─ Remaining failures: 없음
```

---

### 플로우 I: 병렬 에이전트 디스패치 (spawn)

```
사용자: /omo:spawn 3개 서비스(auth, user, payment)의 API 문서 생성
```

```
1) 목표 분해 → 3개 독립 단위

2) 에이전트 배정 → docs-keeper (haiku) x3

3) 병렬 디스패치 (run_in_background=true, 최대 5개)
   ├─ Task(docs-keeper, "auth 서비스 API 문서")
   ├─ Task(docs-keeper, "user 서비스 API 문서")
   └─ Task(docs-keeper, "payment 서비스 API 문서")

4) 결과 수집 + 충돌 검사 + 병합

5) 보고: 에이전트 상태, 결과, 충돌 여부, 잔여 작업
```

---

### 플로우 J: 레포지토리 매핑 (repo-radar)

#### 기본 모드
```
사용자: /omo:repo-radar
```
```
→ repo-librarian (haiku) + deepsearch (haiku) + Explore 병렬 탐색
→ .claude/state/repo-map.md 생성 (50-150줄)
   ├─ 주요 디렉토리 및 용도
   ├─ 기술 스택 및 핵심 의존성
   ├─ 빌드/린트/테스트 엔트리포인트
   ├─ 코드 컨벤션 및 패턴
   ├─ 핫스팟/위험 영역
   └─ 누락/미확인 사항
```

#### 딥 모드
```
사용자: /omo:repo-radar --deep
```
```
기본 매핑 + 계층적 AGENTS.md 생성:
   ├─ 디렉토리별 복잡도 스코어링 (파일 수, 코드 밀도, 모듈 경계)
   ├─ ./AGENTS.md (루트 — 전체 구조, 코드맵, 컨벤션, 커맨드)
   ├─ src/hooks/AGENTS.md (복잡도 높은 하위 디렉토리)
   └─ 자식은 부모 내용 중복 금지, 리뷰 후 트리밍
```

---

### 플로우 K: 출시 전 점검 (ship-check)

```
사용자: /omo:ship-check
```

```
1) 현재 diff 수집

2) test-commander (haiku): 최소 검증 세트 선정 → 실행

3) diff 점검:
   ├─ [OK] 스코프 확장 없음
   ├─ [WARN] config.ts:12에 TODO 남아있음
   ├─ [OK] 문서 일치
   └─ [WARN] createUser()에 테스트 없음

4) 결과:
   ├─ Verification run: npm test PASS, npm run lint PASS
   ├─ Not run: e2e 테스트 (환경 없음)
   ├─ Top risks: TODO 제거, createUser 테스트 추가
   └─ Ship readiness: GO WITH CHANGES
```

---

### 플로우 L: 세션 인수인계 (handoff)

```
사용자: /omo:handoff 인증 미들웨어 리팩토링 중
```

```
→ .claude/state/handoffs/20260326-인증-미들웨어.md 생성
   ├─ Objective: JWT → 세션 기반 인증 전환
   ├─ Status: 미들웨어 변경 완료, 라우트 적용 진행 중
   ├─ Touched files: auth.ts, routes/index.ts
   ├─ Verification run: npm test (6/8 passed)
   ├─ Blockers: test-user.js, test-api.js 실패
   └─ Next step: 라우트별 세션 검증 로직 적용

→ 다음 세션에서 "계속해" → resume-work 자동 인터셉트 → 복구
```

---

## 4. 에이전트 역할 관계도

```
                    ┌─────────────┐
                    │    atlas    │  <- 마스터 오케스트레이터
                    │  (sonnet)   │     복잡한 다단계 계획 조율
                    └──────┬──────┘
                           │ 위임
        ┌──────────┬───────┼───────┬──────────┐
        v          v       v       v          v
   ┌─────────┐ ┌───────┐ ┌────┐ ┌──────┐ ┌───────┐
   │planner- │ │build- │ │bug-│ │test- │ │docs-  │
   │sisyphus │ │integ- │ │hun-│ │comma-│ │keeper │
   │(sonnet) │ │rator  │ │ter │ │nder  │ │(haiku)│
   └────┬────┘ │(sonnet)│ │(s) │ │(haiku)│ │       │
        │      └───────┘ └────┘ └──────┘ └───────┘
   검증 요청
   ┌────v────┐
   │ critic  │  <- 플랜 검증 (실행 가능성)
   │ (opus)  │
   └─────────┘

   ┌─────────┐
   │ oracle  │  <- 최후의 전문가 (2+회 실패 후)
   │ (opus)  │     아키텍처 자문 + Ralph Loop 검증
   └─────────┘

   ┌──────────┐  ┌────────┐  ┌───────────┐
   │deepsearch│  │ vision │  │   repo-   │
   │ (haiku)  │  │(sonnet)│  │ librarian │
   └──────────┘  └────────┘  │  (haiku)  │
   다전략 검색    이미지 분석   └───────────┘
                              레포 탐색
```

---

## 5. 스킬 <-> 에이전트 연동 맵

| 스킬 | 호출하는 에이전트 | 자동 |
|------|-----------------|:----:|
| **deep-search** | deepsearch | O |
| **diff-review** | oracle, deepsearch, test-commander | O |
| **resume-work** | repo-librarian, Explore | O |
| **bug-hunt** | bug-hunter, test-commander, build-integrator | O |
| **ultrawork** | planner-sisyphus, critic, build-integrator, bug-hunter, test-commander, oracle, deepsearch, docs-keeper | X |
| **ralph-loop** | 전체 (작업 성격에 따라) + oracle (검증) | X |
| **kickoff-task** | planner-sisyphus, Explore, repo-librarian | X |
| **qa-loop** | test-commander, bug-hunter, oracle, build-integrator | X |
| **spawn** | 작업에 맞는 전문가 다수 병렬 | X |
| **repo-radar** | repo-librarian, deepsearch, Explore | X |
| **ship-check** | test-commander, docs-keeper | X |
| **handoff** | (단독) | X |
| **comment-check** | docs-keeper | X |
| **mcp-doctor** | (단독) | X |

---

## 6. Ralph Loop 스크립트 관계도

```
ralph-loop-start.sh --생성--> ralph-loop.json
                                    |
                              ralph-loop-guard.sh (Stop 훅)
                                    | 읽기/판단
                    ┌───────────────┼───────────────┐
                    v               v               v
              phase=working   phase=pending    phase=verified
              "계속 해라"     "Oracle 호출해라"  "종료 허용"
              exit 2          exit 2            exit 0
                    |               |
                    v               v
            ralph-loop-done.sh    검증 결과에 따라:
            (working->pending     ├─ ralph-loop-verified.sh
             또는 ->verified)     |  (pending->verified)
                                  └─ ralph-loop-reject.sh
                                     (pending->working)

ralph-loop-cancel.sh --삭제--> ralph-loop.json (강제 종료)
```
