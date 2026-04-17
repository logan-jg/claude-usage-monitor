# Claude Code 사용량 메뉴바 트래커 (macOS)

Status: **코드 작성 완료, 빌드 블록 중** (2026-04-17)
Blocker: macOS 26.2 SDK 가 Swift 6.1+ 요구하는데 Command Line Tools 16.4 의 Swift 는 5.10. 해결: `sudo softwareupdate -i "Command Line Tools for Xcode 26.4-26.4.1"` (920MB).
App bundle id: `com.logan.ClaudeUsageMonitor`
Project path: `~/workspace/claude_tracker/`

---

## Context

사용자는 Claude Code (Pro/Max 구독) 작업 중 현재 5시간 세션 / 7일 주간 사용량 한도를 확인하려고 매번 Claude Code 안에서 `/usage` 슬래시 커맨드를 호출하거나 설정 화면을 열어야 해서 불편함. 목표는 macOS 메뉴바에 상주하는 SwiftUI 네이티브 앱을 만들어서 창 하나 띄워두면 실시간(주기적 폴링)으로 사용량을 보여주는 것.

## 중요한 변경 사항 (플랜 승인 후)

원본 플랜은 두 가지 데이터 소스를 합쳐 보여주려 했음:
1. `claude -p "/usage"` 파싱 → 서버 % 값
2. 로컬 JSONL 파싱 → 보조 토큰 통계

**검증 결과 `/usage` 는 비대화형 모드(`-p`, `stream-json` 모두)에서 `"/usage isn't available in this environment."` 로 하드 블록됨.** 사용자와 재협의 후 **로컬 JSONL 전용**으로 결정.

대신 사용자가 플랜(Pro / Max 5x / Max 20x / Custom)을 설정에서 선택하면, 해당 플랜의 예상 달러 예산에 대해 로컬에서 추정한 비용으로 % 바를 표시함.

## 데이터 흐름 (확정)

```
Timer (30s) ─► UsageMonitor ─► TranscriptParser ─► ~/.claude/projects/**/*.jsonl
                  │                   │
                  │                   └─► 모델별 토큰 합산 + 5h/7d 윈도우 필터
                  │                   └─► ModelPricing 테이블로 추정 비용 계산
                  ▼
               TokenStats ──► MenuBarExtra (아이콘 + Popover)
```

## 기술 선택

- **SwiftUI + `MenuBarExtra`**, macOS 14+
- **Xcode 설치 불필요** — Xcode Command Line Tools + SPM 로 빌드, Makefile 로 `.app` 번들 조립
- 외부 의존성 0
- 샌드박스 OFF (홈 디렉터리 JSONL 접근)

## 디렉터리 구조

```
~/workspace/claude_tracker/
├── Package.swift                     # SPM 매니페스트
├── Makefile                          # build / bundle / run / install
├── Resources/Info.plist              # LSUIElement=true, bundle metadata
├── PLAN.md                           # 이 문서
├── README.md
├── Sources/ClaudeUsageMonitor/
│   ├── main.swift                    # @main, MenuBarExtra 정의
│   ├── Models/
│   │   ├── ModelPricing.swift        # 모델별 가격표
│   │   └── TokenStats.swift          # TokenCounts, WindowStats, TokenStats
│   ├── Services/
│   │   ├── TranscriptParser.swift
│   │   ├── UsageMonitor.swift        # @Observable, Timer
│   │   └── LaunchAtLoginService.swift  # (optional)
│   └── Views/
│       ├── MenuBarLabel.swift
│       ├── PopoverView.swift
│       ├── UsageBarView.swift
│       └── SettingsView.swift
└── Tests/ClaudeUsageMonitorTests/
    ├── TranscriptParserTests.swift
    └── Fixtures/*.jsonl
```

## 구현 순서 (작업 목록 = task list)

1. ✅ 프로젝트 스캐폴드 (Package.swift, Makefile, Info.plist, .gitignore, README.md)
2. ✅ Models/TokenStats + Pricing 테이블 + PlanBaseline
3. ✅ Services/TranscriptParser + 테스트 (fixture JSONL 포함)
4. ✅ Services/UsageMonitor (@Observable + Timer)
5. ✅ MenuBarExtra 앱 골격 (App.swift) + MenuBarLabel + PopoverView + UsageBarView + Formatters
6. ✅ SettingsView + 플랜 선택 + @AppStorage
7. ⏸️ **[BLOCKED]** make build + 스모크 테스트 — **Command Line Tools 26.4.1 업데이트 필요** (Swift 5.10 ↔ macOS 26.2 SDK 불일치)
8. ⏳ (선택) LaunchAtLoginService

## 모델 가격표 (추정치)

USD per 1M tokens. UI 에서는 "estimated" 라벨 붙여 표시.

| Model | Input | Output | Cache Read | Cache Write 5m | Cache Write 1h |
|-------|-------|--------|------------|----------------|----------------|
| Opus 4.x | 15.00 | 75.00 | 1.50 | 18.75 | 30.00 |
| Sonnet 4.x | 3.00 | 15.00 | 0.30 | 3.75 | 6.00 |
| Haiku 4.5 | 1.00 | 5.00 | 0.10 | 1.25 | 2.00 |

## 검증 방법

- 단위 테스트: Fixture JSONL 로 TranscriptParser 통과
- 수동 검증:
  1. `make run` → 메뉴바에 게이지 아이콘, Dock에는 없음
  2. 아이콘 클릭 → 팝오버에 5h/7d 토큰 합계·추정 비용·모델 breakdown
  3. 최근 claude 사용 직후 토큰 수가 실제 사용량과 얼추 일치 확인
  4. 30초 후 자동 갱신 (Last updated 변경)
  5. 설정에서 플랜 선택 → 진행률 바 % 값 변경
- 장시간 안정성: 1시간 이상 켜두고 메모리/CPU 확인 (평상시 CPU < 1%)

## 위험 요소 / 열린 질문

- ✅ `/usage` 비대화형 불가 → 로컬 JSONL 전용으로 확정
- ⚠️ 가격표가 Anthropic 공식 업데이트로 바뀔 수 있음 → "estimated" 라벨로 기대치 관리
- ⚠️ 플랜별 달러 예산 기준이 공식 수치가 아님 → Custom 옵션 제공
- ⚠️ macOS 14+ 필요 (MenuBarExtra + @Observable). 구형 기기 지원 안 함.

## 빌드 / 실행

```bash
cd ~/workspace/claude_tracker
make           # build + bundle → build/ClaudeUsageMonitor.app
make run       # 빌드 후 앱 실행
make install   # /Applications 에 복사
make test      # 단위 테스트
make clean
```
