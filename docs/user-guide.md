# omo 플러그인 — 상세 유저 플로우 가이드

> 스킬 목록, 에이전트 소개, 설치 방법 등 기본 정보는 [README](../README.md)를 참고하세요.
> 이 문서는 각 기능의 **내부 동작과 유저 플로우**를 상세히 설명합니다.

---

## 1. 플러그인 내부 구성

### Ralph Loop 훅 설정

`#sw` (setup-wizard)를 실행하면 자동으로 등록됩니다. 수동 설정이 필요한 경우:
```json
{
  "hooks": {
    "Stop": [
      { "matcher": "", "hooks": ["bash scripts/ralph-loop-guard.sh"] }
    ]
  }
}
```

### 스크립트 37개

| 스크립트 | 용도 |
|---------|------|
| `build-marketplace.sh` | 마켓플레이스 배포 번들 빌드 (plugin.json에서 버전 동적 추출) |
| `latest-context.sh` | 현재 세션 컨텍스트 출력 |
| `mcp-doctor.sh` | MCP 설정 진단 |
| `new-task-note.sh` | 새 작업 노트 생성 |
| `statusline.sh` | 셸 프롬프트 상태 표시줄 |
| `ralph-loop-start.sh` | Ralph Loop 초기화 (jq 우선, grep 폴백) |
| `ralph-loop-guard.sh` | Stop 훅 — 3단계 상태 머신 |
| `ralph-loop-done.sh` | "작업 완료" 신호 |
| `ralph-loop-verified.sh` | "Oracle 승인" 신호 |
| `ralph-loop-reject.sh` | "Oracle 거부" — 작업 재개 |
| `ralph-loop-cancel.sh` | 루프 강제 취소 |
| `ensure-hooks.sh` | Stop 훅 자동 등록 |
| `check-version.sh` | plugin.json ↔ marketplace.json 버전 일관성 검증 |
| `log-task-event.sh` | 태스크 이력 기록 (생성/완료/취소) |
| `write-briefing.sh` | 에이전트 브리핑 문서 작성 |
| `read-briefings.sh` | 최근 N개 브리핑 읽기 |
| `release.sh` | 릴리스 자동화 (테스트→빌드→태그→push) |
| `escalation-check.sh` | 브리핑의 Confidence/Escalation 파싱 |
| `notify.sh` | OS 알림 (macOS osascript / Linux notify-send) |
| `validate-schema.sh` | 플러그인 구조 + 프론트매터 스키마 검증 |

### 상태 파일 (실행 시 자동 생성)

```
.claude/state/
├── current-task.txt        <- 현재 작업 포인터
├── tasks/                  <- 작업 노트들
├── handoffs/               <- 인수인계 노트들
├── briefings/              <- 에이전트 간 브리핑 문서
├── memory/                 <- 크로스세션 프로젝트 지식
│   ├── conventions.md      <- repo-librarian이 기록
│   ├── decisions.md        <- oracle이 기록
│   ├── failures.md         <- bug-hunter가 기록
│   └── index.md            <- 자동 생성 인덱스
├── task-history.log        <- 태스크 이력 로그
├── repo-map.md             <- 레포지토리 맵
├── ralph-loop.json         <- Ralph Loop 상태 머신
└── boulder.json            <- Boulder 크로스세션 태스크 상태
```

---

## 2. 유저 플로우별 상세 설명

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

2) 5개 전략 병렬 실행 (deepsearch 에이전트, sonnet)
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
   ├─ 최신 작업 노트 읽기
   ├─ 최신 브리핑 읽기 (.claude/state/briefings/)
   └─ 메모리 인덱스 읽기 (.claude/state/memory/index.md)

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

2) 메모리 확인
   └─ .claude/state/memory/failures.md에서 유사 실패 패턴 검색

3) bug-hunter 투입 (sonnet)
   ├─ 관련 파일 탐색 (auth 컨트롤러, 미들웨어, DB 연결)
   ├─ 에러 로그 확인
   └─ "간헐적" → 레이스 컨디션 또는 커넥션 풀 고갈 의심

4) test-commander (haiku)로 최소 검증 루프 설계
   └─ "wrk -t4 -c100 -d10s POST /auth/login 으로 부하 재현"

5) 근본 원인 식별 시 → build-integrator (sonnet)에 수정 위임
   └─ 커넥션 풀 크기 5 → 20 + 타임아웃 추가

6) 결과 보고
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
   ├─ 메모리 읽기 (컨벤션, 과거 결정 참조)
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
   ├─ 메모리 인덱스 + 최근 브리핑 읽기 (있으면)
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

## 3. 에이전트 역할 관계도

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
        │      └───┬───┘ └────┘ └──────┘ └───────┘
   검증 요청       │ 2+회 실패
   ┌────v────┐  ┌──v──────────────┐
   │ critic  │  │build-integrator-│ <- 에스컬레이션
   │ (opus)  │  │heavy (opus)     │
   └────┬────┘  └─────────────────┘
        │ 간단한 플랜
   ┌────v──────┐
   │critic-lite│ <- 4단계 이하 플랜 경량 검증
   │ (sonnet)  │
   └───────────┘

   ┌─────────┐     ┌────────────┐
   │ oracle  │ <── │oracle-lite │ <- 첫 시도 빠른 분석
   │ (opus)  │     │ (sonnet)   │    LOW confidence시 에스컬레이션
   └─────────┘     └────────────┘
   아키텍처 자문 + Ralph Loop 검증

   ┌──────────┐  ┌────────┐  ┌───────────┐  ┌──────────────┐
   │deepsearch│  │ vision │  │   repo-   │  │repo-librarian│
   │ (haiku)  │  │(sonnet)│  │ librarian │  │  -deep       │
   └──────────┘  └────────┘  │  (haiku)  │  │  (sonnet)    │
   다전략 검색    이미지 분석   └───────────┘  └──────────────┘
                              레포 탐색       심화 기능 추적

   ┌──────────────┐  ┌──────────┐  ┌────────────────┐
   │perf-analyst  │  │security- │  │migration-      │
   │  (sonnet)    │  │auditor   │  │specialist      │
   └──────────────┘  │(sonnet)  │  │(sonnet)        │
   성능 분석          └──────────┘  └────────────────┘
                     보안 감사       마이그레이션 실행

   ┌──────────────┐  ┌──────────┐
   │test-generator│  │memory-   │
   │  (sonnet)    │  │keeper    │
   └──────────────┘  │(haiku)   │
   테스트 자동 생성    └──────────┘
                     메모리 관리
```

---

## 4. 스킬 <-> 에이전트 연동 맵

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
| **setup-wizard** | (단독, 스크립트 호출) | X |
| **self-test** | (단독, 스크립트 호출) | X |
| **retro** | memory-keeper | X |
| **perf-check** | perf-analyst | X |
| **dep-audit** | (단독, 패키지 매니저 호출) | X |
| **migrate** | migration-specialist, planner-sisyphus, critic, build-integrator, bug-hunter | X |
| **pr-review** | security-auditor, test-commander | X |
| **onboard** | repo-librarian, repo-librarian-deep | X |
| **tool-check** | (단독) | X |

---

## 5. Ralph Loop 스크립트 관계도

> v1.0부터 모든 Ralph Loop 스크립트는 `jq`를 우선 사용하며, `jq`가 없으면 `grep+cut`으로 폴백합니다.
> 특수문자가 포함된 태스크 설명도 안전하게 처리됩니다.

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

---

## 6. v1.0 신규 플로우

---

### 플로우 M: 초기 설정 (setup-wizard)

```
사용자: #sw
```

```
1) 환경 점검
   ├─ skills/, agents/ 접근 가능 확인
   ├─ ensure-hooks.sh 실행 → Stop 훅 자동 등록
   ├─ mcp-doctor.sh 실행 → MCP 설정 상태
   └─ .claude/state/ 디렉토리 존재 확인

2) 자동 수정
   ├─ Stop 훅 미등록 → 자동 등록
   ├─ .claude/state/ 미존재 → 생성 (tasks/, handoffs/ 포함)
   └─ MCP 플레이스홀더 → 구체적 교체 안내

3) 결과 보고
   | Component | Status | Action taken |
   |-----------|--------|-------------|
   | Stop hook | OK     | Auto-registered |
   | State dir | OK     | Created        |
   | MCP       | WARN   | Placeholders   |

4) --full 모드 (선택)
   ├─ repo-radar 실행 → 레포 맵 생성
   ├─ task-history.log 초기화
   └─ 초기 태스크 노트 생성
```

---

### 플로우 N: 플러그인 자가 검증 (self-test)

```
사용자: #st
```

```
1) 구조 검증 → plugin.json, marketplace.json, 디렉토리 존재
2) 버전 일관성 → plugin.json ↔ marketplace.json 비교
3) 스킬 검증 → 23개 SKILL.md 프론트매터 필수 필드 + 이름 일치
4) 에이전트 검증 → 20개 .md 프론트매터 + 유효 모델명
5) 스크립트 검증 → 20개 .sh shebang + 실행 권한 + bash -n

결과:
   omo self-test results
   =====================
   Plugin version: 1.0.0
   Structure:      PASS
   Versions:       PASS
   Skills (23):    PASS
   Agents (20):    PASS
   Scripts (20):   PASS
   Overall: PASS
```

---

### 플로우 O: 회고 분석 (retro)

```
사용자: #re
```

```
1) 증거 수집
   ├─ task-history.log 읽기
   ├─ current-task.txt + 작업 노트
   ├─ 핸드오프 노트
   ├─ ralph-loop.json (있으면)
   └─ 최근 브리핑들

2) 패턴 분석
   ├─ 에이전트 사용 빈도
   ├─ 반복 실패 / 재시도
   ├─ ralph-loop 반복 횟수
   └─ 스코프 변경 / 블로커

3) 회고 생성
   Session Retrospective
   =====================
   Task: API 마이그레이션
   Agents used: planner, build-integrator x3, bug-hunter
   What went well: 병렬 실행으로 3개 슬라이스 동시 처리
   Bottlenecks: DB 스키마 변경에서 2회 실패
   Recommendations: 스키마 변경은 단독 슬라이스로 분리

4) 메모리 업데이트 제안 (사용자 확인 후 기록)
```

---

### 플로우 P: 성능 분석 (perf-check)

```
사용자: #pc
```

```
1) 스코프 식별 → git diff 또는 지정 범위
2) perf-analyst (sonnet) 투입
   ├─ O(n²) 중첩 루프 탐지
   ├─ 무한 성장 배열/맵 탐지
   ├─ 동기 I/O, N+1 쿼리 탐지
   ├─ 번들 크기 영향 분석
   └─ 메모리 누수 패턴 탐지

3) 결과:
   [HIGH] src/api/users.ts:42
   Pattern: 중첩 루프 — O(n²) users × roles
   Impact: 1000명 이상에서 응답 지연
   Fix: Map으로 roles를 사전 인덱싱
```

---

### 플로우 Q: 의존성 감사 (dep-audit)

```
사용자: #da
```

```
1) 생태계 감지 → package.json, pyproject.toml, go.mod 등
2) 감사 도구 실행 → npm audit / pip-audit / govulncheck
3) 신규 의존성 검사 → git diff에서 추가된 의존성 분석
4) 결과:
   Dependency Audit
   ================
   Ecosystem: Node.js
   Vulnerabilities: 2 (high: 1, moderate: 1)
   New: lodash@4.17.21 (safe), axios@1.6.0 (safe)
```

---

### 플로우 R: 마이그레이션 (migrate)

```
사용자: #mg React 18에서 19로 업그레이드
```

```
1) 영향 분석
   ├─ migration-specialist가 deprecated API 스캔
   ├─ repo-librarian이 아키텍처 매핑
   └─ 영향 파일 수, 브레이킹 체인지 목록

2) 마이그레이션 계획
   ├─ planner-sisyphus로 단계별 계획
   ├─ 독립 슬라이스로 분할
   └─ critic으로 계획 검증

3) 실행 (슬라이스별)
   ├─ build-integrator로 패턴 변환
   ├─ 슬라이스별 검증
   └─ 실패 시 bug-hunter 투입

4) 전체 검증 → 테스트 + deprecated API 잔존 확인
```

---

### 플로우 S: PR 리뷰 (pr-review)

```
사용자: #pr 42
```

```
1) PR 컨텍스트 수집
   ├─ gh pr view 42
   ├─ gh pr diff --stat
   └─ gh pr checks (CI 상태)

2) diff 분석 → 변경 분류 (기능/버그/리팩토링/테스트/문서)

3) 5개 관점 병렬 리뷰
   ├─ 정확성, 보안, 성능, 유지보수성, 스코프

4) 결과:
   PR Review: #42 — Add payment webhook handler
   Verdict: REQUEST_CHANGES
   Critical: webhook secret 하드코딩 (보안)
   Suggestion: 에러 핸들링 추가
```

---

### 플로우 T: 온보딩 가이드 (onboard)

```
사용자: #ob
```

```
1) repo-radar 실행 → 구조/스택 파악
2) 메모리 읽기 → 축적된 컨벤션/결정 참조
3) 개발 워크플로우 식별 → 설치, 실행, 테스트, 빌드, 배포
4) 가이드 생성:
   Project Onboarding Guide
   ========================
   Overview: Express.js 기반 결제 API 서버
   Tech Stack: TypeScript, Express, PostgreSQL, Redis
   Getting Started: npm install → .env 설정 → npm run dev
   Key Files: src/server.ts, src/routes/, src/models/
   Conventions: camelCase, barrel exports, jest 테스트
```

---

### 플로우 U: 도구 점검 (tool-check)

```
사용자: #tc
```

```
1) 레포 스캔 → 어떤 도구가 필요한지 탐지
2) 설치 여부 확인 → command -v, --version
3) 결과:
   | Tool | Required | Installed | Version  |
   |------|----------|-----------|----------|
   | node | yes      | yes       | v20.11.0 |
   | jq   | yes      | no        | -        |
   | gh   | yes      | yes       | 2.40.0   |

   Missing: jq → brew install jq
```

---

## 7. 브리핑 프로토콜

에이전트가 작업 완료 시 `.claude/state/briefings/`에 구조화된 문서를 남기고, 다음 에이전트가 이를 컨텍스트로 소비합니다.

```
planner-sisyphus ──브리핑──→ critic ──브리핑──→ build-integrator
     (계획 수립)                (검증)               (구현)
```

### 브리핑 구조

```markdown
# Agent Briefing
Agent: planner-sisyphus
Task: payment-webhook
Date: 2026-03-26T07:30:00Z

## Summary
결제 웹훅 핸들러 구현 계획 수립 완료. 3단계 슬라이스로 분할.

## Key findings
- 기존 webhook 인프라 없음, 새로 구축 필요
- Express 라우터 패턴 사용 중

## Metadata
- Confidence: HIGH
- Escalation: none
- Next agent: critic
```

### 관련 스크립트

| 스크립트 | 역할 |
|---------|------|
| `write-briefing.sh` | 에이전트명 + 슬러그로 브리핑 파일 생성 |
| `read-briefings.sh` | 최근 N개 브리핑 읽기 (필터 가능) |
| `escalation-check.sh` | Confidence/Escalation 필드 파싱 → 에스컬레이션 필요 여부 판단 |

---

## 8. 크로스세션 메모리

세션이 끝나도 프로젝트 지식이 축적되어 다음 세션에서 더 나은 추천을 제공합니다.

```
.claude/state/memory/
├── conventions.md    repo-librarian이 발견한 코딩 컨벤션
├── decisions.md      oracle이 기록한 아키텍처 결정
├── failures.md       bug-hunter가 기록한 반복 실패 패턴
└── index.md          자동 생성 인덱스
```

### 쓰기 권한

| 에이전트 | 기록 대상 |
|---------|----------|
| repo-librarian | conventions.md |
| oracle | decisions.md |
| bug-hunter | failures.md |

### 읽기 (Phase 1에서 자동)

ultrawork, resume-work, kickoff-task, bug-hunt 실행 시 메모리 인덱스를 자동으로 참조합니다.

### 항목 신뢰도

```
[provisional]  첫 발견 — 아직 미검증
[confirmed]    3회 이상 재확인
[stale]        30일 이상 미재확인
```

---

## 9. 에스컬레이션 래더

복잡도에 따라 자동으로 상위 티어 에이전트로 전환합니다.

```
Haiku (빠름, 저비용) → Sonnet (균형) → Opus (최고 추론)
```

### 변형 에이전트 전환 조건

| 기본 | 변형 | 전환 조건 |
|------|------|----------|
| critic (opus) | critic-lite (sonnet) | 플랜 4단계 이하 |
| oracle (opus) | oracle-lite (sonnet) | 첫 시도, LOW confidence시 에스컬레이션 |
| build-integrator (sonnet) | build-integrator-heavy (opus) | 2회 실패 후 |
| repo-librarian (haiku) | repo-librarian-deep (sonnet) | 복잡한 기능 추적 |

### 에스컬레이션 판단

모든 에이전트가 출력 끝에 메타데이터를 포함합니다:

```
Confidence: HIGH|MEDIUM|LOW
Escalation: none|recommended
```

`escalation-check.sh`가 브리핑에서 이 필드를 파싱하여 자동 에스컬레이션 여부를 판단합니다.

---

## 10. 오케스트레이션 패턴

자주 사용되는 에이전트 체인 패턴입니다.

### Plan-Review-Execute

```
planner-sisyphus → critic → build-integrator
   (계획)           (검증)     (구현)
```

### Search-Analyze-Fix

```
deepsearch → bug-hunter → build-integrator
  (탐색)       (분석)        (수정)
```

### Test-Diagnose-Fix-Retest

```
test-commander → bug-hunter → build-integrator → test-commander
   (테스트)        (진단)        (수정)            (재검증)
```

### 에스컬레이션 체인

```
critic-lite ──LOW──→ critic (opus)
oracle-lite ──LOW──→ oracle (opus)
build-integrator ──2회 실패──→ build-integrator-heavy (opus)
repo-librarian ──부족──→ repo-librarian-deep (sonnet)
```
