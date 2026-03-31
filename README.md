# OMO: oh-mark-openagent

## Quick Start (English)

```bash
# 1. Register the marketplace
/plugin marketplace add https://github.com/speson/omo

# 2. Install the plugin
/plugin install omo

# 3. Restart Claude Code, then run setup wizard
#sw
```

After setup, try these commands:

| Shortcut | What it does |
|----------|-------------|
| `#ulw <goal>` | Plan-execute-verify workflow for large tasks |
| `#rl <goal>` | Persistent loop that won't stop until done |
| `#bh <symptom>` | Hunt down bugs from symptoms |
| `#dr` | Multi-perspective code review on current diff |
| `#rr` | Map your repository structure |

See the full [User Guide](docs/user-guide.md) for details.

---

Claude Code를 위한 멀티 에이전트 오케스트레이션 플러그인입니다.

OMO는 **결과물의 품질과 속도를 토큰 효율보다 우선**합니다. 더 많은 토큰을 소비하더라도 병렬 에이전트 실행, 다각도 검증, 조기 에스컬레이션을 통해 더 좋은 결과를 더 빠르게 제공합니다.

복잡한 개발 작업을 전문 에이전트 팀에게 위임하여 체계적으로 수행할 수 있게 합니다. 작업 기획, 구현, 디버깅, 검증, 코드 리뷰까지 소프트웨어 개발의 전체 흐름을 커버합니다.

[opencode](https://github.com/opencode-ai/opencode)와 [oh-my-opencode](https://github.com/anthropics/oh-my-opencode)의 편의 기능을 Claude Code 플러그인으로 그대로 이식하여, 동일한 워크플로우를 플러그인 하나로 사용할 수 있습니다.

> 전체 기능과 유저 플로우에 대한 상세한 설명은 [유저 가이드](docs/user-guide.md)를 참고하세요.

## 핵심 원칙

- **적극적 병렬화** — 순차 실행 대신 여러 전문가를 동시에 투입합니다.
- **깊은 조사 후 실행** — `deepsearch` + `repo-librarian`을 병렬로 돌려 컨텍스트를 충분히 파악한 후 작업합니다.
- **다각도 검증** — `diff-review` (5관점 병렬 리뷰) + `ship-check` + `test-commander`를 함께 사용합니다.
- **조기 에스컬레이션** — 첫 실패 후 바로 `oracle`을 투입합니다. 3단계 이상의 계획에는 `critic`을 사용합니다.
- **전문가 우선** — 인라인 분석 대신 전용 에이전트(`bug-hunter`, `security-auditor`, `perf-analyst`)에게 위임합니다.
- **중복 허용** — 두 에이전트가 같은 코드를 다른 관점에서 검토하면, 그것은 낭비가 아니라 신뢰도 향상입니다.

## 설치 방법

### 1. 마켓플레이스 등록

```
/plugin marketplace add https://github.com/speson/omo
```

### 2. 플러그인 설치

```
/plugin install omo
```

설치 후 Claude Code를 재시작하세요.

## 스킬 명령어

OMO는 24개의 스킬 명령어를 제공합니다. 각 명령어는 `/omo:명령어` 형식으로 사용하거나, `#단축키` 패턴으로 빠르게 실행할 수 있습니다.

### 단축키 사용법

모든 스킬은 `#단축키` 패턴을 통한 자동 인터셉트를 지원합니다. Claude Code 채팅창에 `#단축키`를 입력하면 해당 스킬이 자동으로 실행됩니다. 긴 명령어를 외울 필요 없이 짧은 단축키만으로 동일한 기능을 사용할 수 있습니다.

```
# 긴 명령어 대신
/omo:ultrawork 사용자 인증 기능 구현

# 단축키로 동일하게 실행
#ulw 사용자 인증 기능 구현
```

### 작업 실행

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#ulw` | `/omo:ultrawork <목표>` | 대규모 작업을 기획-실행-검증 3단계로 체계적으로 수행합니다 |
| `#rl` | `/omo:ralph-loop <목표>` | 작업이 100% 완료될 때까지 멈추지 않는 실행 루프입니다 |
| `#sp` | `/omo:spawn <목표>` | 독립적인 여러 작업을 병렬로 에이전트에게 분배합니다 |

### 작업 관리

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#kit` | `/omo:kickoff-task <목표>` | 인터뷰 형식으로 작업 범위를 정의하고 태스크 노트를 생성합니다 |
| `#rw` | `/omo:resume-work [목표]` | 중단된 작업의 컨텍스트를 복구하고 이어서 진행합니다 |
| `#ho` | `/omo:handoff [다음단계]` | 작업 중단 시 인수인계 노트를 작성합니다 |

### 코드 품질

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#dr` | `/omo:diff-review [범위]` | 정확성, 보안, 성능, 유지보수성, 범위 5가지 관점에서 코드를 리뷰합니다 |
| `#sc` | `/omo:ship-check [범위]` | 배포 전 최종 검증을 수행하고 리스크를 평가합니다 |
| `#cc` | `/omo:comment-check [범위]` | 주석과 문서에서 불필요한 AI 표현을 제거합니다 |
| `#qa` | `/omo:qa-loop [테스트명령]` | 테스트 실패 시 자동으로 수정-재실행을 최대 5회 반복합니다 |
| `#va` | `/omo:verify-all [범위]` | ship-check + diff-review를 병렬 실행하여 다각도 검증합니다 |

### 탐색 및 디버깅

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#rr` | `/omo:repo-radar [범위]` | 저장소 구조, 기술 스택, 컨벤션을 매핑합니다 |
| `#ds` | `/omo:deep-search <쿼리>` | 심볼, 텍스트, 파일, 임포트, git 이력을 병렬 검색합니다 |
| `#bh` | `/omo:bug-hunt <증상>` | 버그의 원인을 좁혀가며 재현 경로를 찾습니다 |
| `#mcp` | `/omo:mcp-doctor` | MCP 서버 설정 상태를 진단합니다 |

### 배포

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#rel` | `/omo:release <버전>` | 전체 릴리즈 파이프라인 (커밋, 푸시, 태그, GitHub 릴리즈, 마켓플레이스) |

### 설정

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#sw` | `/omo:setup-wizard [--full]` | 훅 등록, MCP 설정, 상태 디렉토리를 자동 감지하고 구성합니다 |

### 분석 및 감사

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#re` | `/omo:retro` | ultrawork/ralph-loop 후 회고 분석 — 에이전트 사용 패턴, 병목, 개선 제안 |
| `#pc` | `/omo:perf-check [범위]` | 성능 영향 분석 — O(n²) 패턴, 번들 크기, 무한 데이터 구조 감지 |
| `#da` | `/omo:dep-audit [범위]` | 의존성 보안 감사 — npm audit/pip-audit + 신규 의존성 교차 검증 |

### 마이그레이션 및 리뷰

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#mg` | `/omo:migrate <대상>` | 프레임워크/API/언어 버전 마이그레이션 오케스트레이션 |
| `#pr` | `/omo:pr-review [PR번호]` | GitHub PR 전체 리뷰 — diff 분석 + CI 상태 + 다각도 코드 리뷰 |
| `#ob` | `/omo:onboard [포커스]` | 프로젝트 온보딩 가이드 자동 생성 |
| `#tc` | `/omo:tool-check` | 외부 도구 의존성 탐지 및 설치 안내 |

### 사용 예시

```
# 단축키로 빠르게 실행
#ulw 사용자 인증 기능 구현
#bh 로그인 후 세션이 유지되지 않는 문제
#ds getUserProfile 함수 위치
#dr
#rel 1.7.0

# 전체 명령어로 실행
/omo:ultrawork 결제 모듈 리팩토링
/omo:repo-radar --deep
/omo:qa-loop npm test
```

## 전문 에이전트

OMO는 20개의 전문 에이전트를 상황에 맞게 자동으로 배치합니다. 스킬을 실행하면 내부적으로 적절한 에이전트가 투입되므로, 사용자가 직접 에이전트를 호출할 필요는 없습니다.

### 오케스트레이션

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **atlas** | Sonnet | 복잡한 멀티 스텝 계획의 총괄 지휘. 팀 기반 조율 지원 |
| **planner-sisyphus** | Sonnet | 인터뷰 방식으로 요구사항을 명확히 하고 실행 가능한 계획을 수립합니다 |
| **critic** | Opus | 실행 계획의 실현 가능성을 검증합니다. 3단계 이상 계획에 자동 투입 |

### 구현 및 디버깅

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **build-integrator** | Sonnet | 시니어 개발자 수준의 멀티 파일 구현을 자율적으로 수행합니다 |
| **bug-hunter** | Sonnet | 최소한의 증거로 장애 원인을 좁혀가며 재현 경로를 제시합니다 |
| **oracle** | Opus | 아키텍처 결정과 난이도 높은 디버깅을 담당합니다. 첫 실패 후 투입됩니다 |

### 탐색 및 검증

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **repo-librarian** | Sonnet | 코드베이스를 빠르게 탐색하고 컨벤션을 파악합니다 |
| **deepsearch** | Sonnet | 5가지 이상의 전략을 병렬로 실행하여 코드를 검색합니다 |
| **test-commander** | Sonnet | 가장 효율적인 최소 테스트 세트를 선택합니다 |

### 문서 및 미디어

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **docs-keeper** | Sonnet | 문서와 주석에서 불필요한 표현을 정리하고 정확성을 유지합니다 |
| **vision** | Sonnet | 스크린샷, PDF, 다이어그램 등 미디어 파일을 분석합니다 |

### 분석 및 메모리

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **perf-analyst** | Sonnet | 성능 분석 전문가 — O(n²) 패턴, 메모리 누수, 번들 크기 영향을 감지합니다 |
| **memory-keeper** | Sonnet | 크로스세션 메모리 관리 — 프로젝트 지식을 인덱싱하고 부실 항목을 정리합니다 |

### 보안 및 테스트

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **security-auditor** | Sonnet | OWASP Top 10, 시크릿 감지, 인증 플로우를 분석합니다 |
| **test-generator** | Sonnet | 변경 코드 기반으로 엣지 케이스 테스트를 자동 생성합니다 |
| **migration-specialist** | Sonnet | 패턴 기반 대량 코드 변환을 실행하고 검증합니다 |

### 동적 모델 선택 (에이전트 변형)

복잡도에 따라 자동으로 상위/하위 티어 에이전트를 선택합니다.

| 에이전트 | 기본 모델 | 역할 |
|----------|-----------|------|
| **critic-lite** | Sonnet | 간단한 플랜(4단계 이하) 경량 검토 |
| **oracle-lite** | Sonnet | 첫 시도 빠른 기술 분석. 복잡하면 oracle로 에스컬레이션 |
| **build-integrator-heavy** | Opus | build-integrator 실패 후 투입되는 고급 구현 에이전트 |
| **repo-librarian-deep** | Sonnet | 복잡한 기능 추적을 위한 심화 탐색 에이전트 |

### 모델 커스터마이징

에이전트 모델은 `.omo/config.json`의 `categories` 설정으로 프로젝트별로 변경할 수 있습니다. 자세한 내용은 [설정 문서](docs/config.md)를 참고하세요.

```bash
bash scripts/init-config.sh          # 기본 설정 생성
bash scripts/apply-config.sh         # 모델 변경 적용
```

## 설정 시스템

OMO는 `.omo/config.json`으로 프로젝트별 설정을 관리합니다.

| 섹션 | 주요 설정 |
|------|----------|
| `categories` | 에이전트 카테고리별 모델 지정 (7개 카테고리) |
| `ralph-loop` | 최대 반복 횟수, Oracle 검증 기본값 |
| `spawn` | 최대 동시 에이전트 수 |
| `boulder` | 크로스세션 태스크 영속성 활성화/비활성화, 최대 시도 횟수 |
| `teams` | 에이전트 팀 조율, 자동 에스컬레이션, 완료 알림 |
| `disabled_skills` | 비활성화할 스킬 목록 |

자세한 내용은 [설정 문서](docs/config.md)를 참고하세요.

## 훅 시스템

OMO는 7개의 Claude Code 라이프사이클 훅을 `hooks/hooks.json`으로 자동 등록합니다.

| 훅 이벤트 | 스크립트 | 용도 |
|-----------|----------|------|
| `Stop` | `ralph-loop-guard.sh` | Ralph Loop 중 조기 종료 차단 |
| `SessionStart` | `session-context-hook.sh` | 세션 시작 시 Boulder 태스크 컨텍스트 자동 주입 |
| `Notification` | `idle-resume-hook.sh` | 유휴 상태에서 Boulder 태스크 재개 넛지 |
| `SubagentStop` | `subagent-stop-hook.sh` | 서브에이전트 완료 시 자동 에스컬레이션 판단 |
| `TeammateIdle` | `teammate-idle-hook.sh` | 팀원 유휴 시 대기 태스크 할당 제안 |
| `TaskCompleted` | `task-completed-hook.sh` | 태스크 완료 시 OS 알림 + 차단 해제 확인 |
| `PreCompact` | `pre-compact-hook.sh` | 컴팩션 전 핵심 상태 보존 |

플러그인 설치 시 자동 등록됩니다. 수동 등록이 필요한 경우 `bash scripts/ensure-hooks.sh`를 실행하세요.

## Boulder (크로스세션 태스크 영속성)

Boulder는 세션이 끊겨도 태스크 상태를 보존합니다. `#ulw`, `#rl`, `#rw`, `#ho` 스킬에 통합되어 있으며, 세션 재시작 시 자동으로 이전 태스크를 복원합니다.

| 스크립트 | 용도 |
|---------|------|
| `boulder-init.sh "목표"` | 영속 태스크 초기화 |
| `boulder-attempt.sh <결과>` | 시도 기록 (working/interrupted/failed/completed) |
| `boulder-check.sh` | 재개 가능 여부 확인 |
| `boulder-complete.sh` | 태스크 완료 처리 |
| `boulder-status.sh` | 현재 상태 출력 |

`.omo/config.json`에서 `boulder.enabled: false`로 비활성화할 수 있습니다.

## 에이전트 팀

Atlas와 Spawn은 Claude Code의 TeamCreate/SendMessage API를 활용한 멀티 에이전트 조율을 지원합니다. `.omo/config.json`에서 `teams.enabled: true` 설정 시:

- Atlas가 3개 이상 태스크가 있는 계획에 영속 팀을 생성합니다.
- Spawn이 fire-and-forget 대신 팀 기반 디스패치를 사용합니다.
- 서브에이전트 반복 실패 시 자동으로 oracle 에스컬레이션합니다.
- 팀 태스크 완료 시 OS 알림을 보냅니다.

## 작업 상태 관리

OMO는 작업 중인 프로젝트의 `.claude/state/` 디렉토리에 상태를 저장합니다.

```
.claude/state/
├── current-task.txt    # 현재 진행 중인 작업
├── tasks/              # 태스크 노트
├── handoffs/           # 인수인계 노트
├── briefings/          # 에이전트 간 브리핑 문서
├── memory/             # 크로스세션 프로젝트 지식
│   ├── conventions.md  # 코딩 컨벤션
│   ├── decisions.md    # 아키텍처 결정
│   ├── failures.md     # 반복 실패 패턴
│   └── index.md        # 자동 생성 인덱스
├── task-history.log    # 태스크 이력 로그
├── repo-map.md         # 저장소 구조 맵
├── ralph-loop.json     # Ralph Loop 상태 머신
└── boulder.json        # Boulder 크로스세션 태스크 상태
```

이 상태 파일들 덕분에 세션이 끊기거나 기기를 변경해도 `#rw` (resume-work)로 이전 작업을 이어서 진행할 수 있습니다.

## 권장 설정: LSP 코드 인텔리전스

Claude Code는 공식 LSP 플러그인을 제공합니다. 설치하면 파일 편집 시 자동으로 타입 에러와 문법 오류를 감지하고, 정의 이동/참조 찾기 등 IDE 수준의 코드 탐색이 가능해집니다.

### LSP 바이너리 설치

```bash
# TypeScript / JavaScript
npm i -g typescript-language-server typescript

# Java
brew install jdtls

# Python
npm i -g pyright
```

### Claude Code에서 LSP 플러그인 설치

```
/plugin install typescript-lsp@claude-plugins-official
/plugin install jdtls-lsp@claude-plugins-official
/plugin install pyright-lsp@claude-plugins-official
```

설치 후 별도 설정 없이 Claude가 코드 편집 시 자동으로 진단 결과를 받고, 에러가 발생하면 즉시 수정합니다.

## 프로젝트 구조

```
omo/
├── .claude-plugin/
│   ├── plugin.json       # 플러그인 메타데이터
│   └── marketplace.json  # 마켓플레이스 등록 정보
├── .omo/
│   └── config.json       # 프로젝트별 설정 (선택)
├── skills/               # 27개 스킬 정의
├── agents/               # 20개 전문 에이전트 정의
├── scripts/              # 40개 헬퍼 스크립트
├── hooks/
│   └── hooks.json        # 7개 라이프사이클 훅 등록
├── templates/            # 태스크 노트, 인수인계 템플릿
├── examples/             # 설정 예시 (hooks, MCP, boulder, config)
├── tests/
│   └── backtest.sh       # 종합 테스트 스위트 (483개 테스트)
├── docs/
│   ├── user-guide.md     # 전체 기능 및 유저 플로우 가이드
│   ├── config.md         # 설정 시스템 문서
│   └── hooks.md          # 훅 시스템 문서
├── CLAUDE.md             # 개발 매뉴얼
└── README.md
```

## 라이선스

markncompany 내부 사용 전용
