# OMO: oh-mark-openagent

Claude Code를 위한 멀티 에이전트 오케스트레이션 플러그인입니다.

OMO는 복잡한 개발 작업을 전문 에이전트 팀에게 위임하여 체계적으로 수행할 수 있게 합니다. 작업 기획, 구현, 디버깅, 검증, 코드 리뷰까지 소프트웨어 개발의 전체 흐름을 커버합니다.

[opencode](https://github.com/opencode-ai/opencode)와 [oh-my-opencode](https://github.com/anthropics/oh-my-opencode)의 편의 기능을 Claude Code 플러그인으로 그대로 이식하여, 동일한 워크플로우를 플러그인 하나로 사용할 수 있습니다.

> 전체 기능과 유저 플로우에 대한 상세한 설명은 [유저 가이드](docs/user-guide.md)를 참고하세요.

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

OMO는 14개의 스킬 명령어를 제공합니다. 각 명령어는 `/omo:명령어` 형식으로 사용하거나, `#단축키` 패턴으로 빠르게 실행할 수 있습니다.

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

### 탐색 및 디버깅

| 단축키 | 명령어 | 설명 |
|--------|--------|------|
| `#rr` | `/omo:repo-radar [범위]` | 저장소 구조, 기술 스택, 컨벤션을 매핑합니다 |
| `#ds` | `/omo:deep-search <쿼리>` | 심볼, 텍스트, 파일, 임포트, git 이력을 병렬 검색합니다 |
| `#bh` | `/omo:bug-hunt <증상>` | 버그의 원인을 좁혀가며 재현 경로를 찾습니다 |
| `#mcp` | `/omo:mcp-doctor` | MCP 서버 설정 상태를 진단합니다 |

### 사용 예시

```
# 단축키로 빠르게 실행
#ulw 사용자 인증 기능 구현
#bh 로그인 후 세션이 유지되지 않는 문제
#ds getUserProfile 함수 위치
#dr

# 전체 명령어로 실행
/omo:ultrawork 결제 모듈 리팩토링
/omo:repo-radar --deep
/omo:qa-loop npm test
```

## 전문 에이전트

OMO는 11개의 전문 에이전트를 상황에 맞게 자동으로 배치합니다. 스킬을 실행하면 내부적으로 적절한 에이전트가 투입되므로, 사용자가 직접 에이전트를 호출할 필요는 없습니다.

### 오케스트레이션

| 에이전트 | 모델 | 역할 |
|----------|------|------|
| **atlas** | Sonnet | 복잡한 멀티 스텝 계획의 총괄 지휘. 직접 코드를 작성하지 않고 전문가를 조율합니다 |
| **planner-sisyphus** | Sonnet | 인터뷰 방식으로 요구사항을 명확히 하고 실행 가능한 계획을 수립합니다 |
| **critic** | Opus | 실행 계획의 실현 가능성을 검증합니다. 참조 파일이 실제로 존재하는지까지 확인합니다 |

### 구현 및 디버깅

| 에이전트 | 모델 | 역할 |
|----------|------|------|
| **build-integrator** | Sonnet | 시니어 개발자 수준의 멀티 파일 구현을 자율적으로 수행합니다 |
| **bug-hunter** | Sonnet | 최소한의 증거로 장애 원인을 좁혀가며 재현 경로를 제시합니다 |
| **oracle** | Opus | 아키텍처 결정과 난이도 높은 디버깅을 담당합니다. 2회 이상 실패 후 투입됩니다 |

### 탐색 및 검증

| 에이전트 | 모델 | 역할 |
|----------|------|------|
| **repo-librarian** | Haiku | 코드베이스를 빠르게 탐색하고 컨벤션을 파악합니다 |
| **deepsearch** | Haiku | 5가지 이상의 전략을 병렬로 실행하여 코드를 검색합니다 |
| **test-commander** | Haiku | 가장 효율적인 최소 테스트 세트를 선택합니다 |

### 문서 및 미디어

| 에이전트 | 모델 | 역할 |
|----------|------|------|
| **docs-keeper** | Haiku | 문서와 주석에서 불필요한 표현을 정리하고 정확성을 유지합니다 |
| **vision** | Sonnet | 스크린샷, PDF, 다이어그램 등 미디어 파일을 분석합니다 |

## 작업 상태 관리

OMO는 작업 중인 프로젝트의 `.claude/state/` 디렉토리에 상태를 저장합니다.

```
.claude/state/
├── current-task.txt    # 현재 진행 중인 작업
├── tasks/              # 태스크 노트
├── handoffs/           # 인수인계 노트
├── repo-map.md         # 저장소 구조 맵
└── ralph-loop.json     # Ralph Loop 상태 (ralph-loop 사용 시)
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
│   └── plugin.json       # 플러그인 메타데이터
├── skills/               # 14개 스킬 정의
├── agents/               # 11개 전문 에이전트 정의
├── scripts/              # 헬퍼 스크립트
├── templates/            # 태스크 노트, 인수인계 템플릿
├── examples/             # 설정 예시 (hooks, MCP)
├── docs/
│   └── user-guide.md     # 전체 기능 및 유저 플로우 가이드
├── CLAUDE.md             # 개발 매뉴얼
└── README.md
```

## 라이선스

markncompany 내부 사용 전용
