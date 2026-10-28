# 🎮 미니게임 모음

브라우저에서 즐기는 미니게임 모음집입니다. HTML5 캔버스 게임과 Godot 게임을 함께 담고 있습니다.

👉 **[지금 바로 플레이하기](https://waceh.github.io/minigame/)**

## 🎯 게임 목록

### 1. 서바이벌 게임
몬스터를 처치하고 레벨업하며 생존하는 로그라이크 액션 게임

**주요 기능:**
- 3가지 캐릭터 선택 (각 캐릭터마다 고유 특성)
- 3가지 난이도 (이지/노멀/하드)
- 웨이브 시스템 (총 20 웨이브)
- 5/10/15/20 웨이브마다 보스 등장
- 레벨업 시 무기/스탯 강화 선택
- 경험치 오브 수집 및 체력 아이템 드롭

**조작법:**
- 이동: 방향키 또는 WASD
- 일시정지/재개: 스페이스
- 레벨업 강화 선택: 1, 2, 3 키

### 2. 사다리 타기
번호를 골라 공을 굴려 결과를 확인하는 사다리 타기 게임

**주요 기능:**
- 라인 개수 설정 (3~10개)
- 가로선 개수 설정 (4~15개)
- 당첨칸 커스터마이징
- 공 애니메이션으로 결과 확인

**사용법:**
1. 라인/가로선 개수를 선택하고 "사다리 만들기"
2. 하단의 당첨칸에 원하는 텍스트 입력
3. 캔버스 상단의 번호를 클릭하여 공 굴리기

### 3. 룰렛 뽑기
이름을 입력하고 룰렛을 돌려 당첨자를 뽑는 게임

**주요 기능:**
- 쉼표 또는 줄바꿈으로 여러 항목 입력
- `이름*개수` 형식으로 중복 입력 가능 (예: `수박*2`)
- 룰렛 회전 애니메이션
- 당첨자 표시

**사용 예시:**
```
사과, 배, 귤, 수박
```
또는
```
수박*2, 키위*2, 귤*2
```

### 4. 하늘 발판 (Godot)
80개의 발판을 딛고 정상까지 올라가는 충전식 점프 게임입니다. 짧은 점프와 최대 충전을 섞어야 하는 코스이며, 최소 16px의 작은 발판과 중간 발판을 건너뛸 수 있는 지름길 5곳이 있습니다. 금색으로 표시한 발판은 지름길의 착지점입니다. 구간마다 좌우 동선이 바뀌고 높이 올라갈수록 발판이 좁아집니다. 충전 중에는 움직일 수 없고, 점프한 뒤에는 방향을 바꿀 수 없습니다. 발판은 아래에서 통과할 수 없으며 실수하면 아래 구간으로 떨어집니다.

**조작법:**
- 이동 및 방향 선택: A/D 또는 좌우 방향키 (모바일은 왼쪽 조이스틱)
- 점프: 스페이스를 길게 누른 뒤 떼면 바라보는 방향으로 점프 (모바일은 화면의 ▲ 버튼)
- 다시 시작: R

**모바일 플레이:**
- 상단 바 없이 게임 페이지가 화면 전체 높이를 사용합니다. 높이·메뉴는 옆에 표시하고, 가로 화면에서는 게임 양옆에 조이스틱과 점프 버튼을 배치합니다.
- 세로 화면에서는 더 높은 구간을 보여주고, 터치 버튼을 아래에 배치합니다.
- 조이스틱을 조금 밀면 천천히 걷고 끝까지 밀면 빠르게 걷습니다. 충전 중에는 방향만 바뀌며, 점프 후의 가로 속도는 조이스틱 기울기와 관계없이 일정합니다.
- 점프 버튼 위에서 충전 상태를 확인할 수 있습니다. 손가락을 버튼 밖으로 옮겨도 떼는 순간 점프합니다.
- 메뉴를 열거나 다른 앱으로 전환하면 일시정지하며, 진행 중인 충전은 취소합니다.
- 지원 브라우저에서는 메뉴의 **홈 화면에 설치**로 설치할 수 있습니다. iPhone은 Safari 공유 메뉴의 **홈 화면에 추가**를 사용합니다.
- 최초 온라인 실행으로 게임 파일 캐시가 완료되면 홈 화면에서 오프라인 실행할 수 있습니다. 브라우저가 저장 공간을 정리하면 다시 온라인으로 실행해야 합니다.

Godot 4.5 프로젝트 원본은 `jumpking/`에, 웹 빌드는 `jumpking/web/`에 있습니다. 게임을 수정한 뒤에는 Godot에서 프로젝트를 열고 **프로젝트 > 내보내기 > Web**으로 다시 빌드할 수 있습니다. 배포할 때는 다음 버전을 함께 올려 브라우저가 새 게임 파일을 받도록 합니다.
- `jumpking.html`의 iframe·CSS·JS 쿼리 버전
- `jumpking/web/index.html`의 `GODOT_CONFIG.mainPack` (`index.pck?v=1.3.4`; Godot 내보내기 후 다시 설정)
- `jumpking-sw.js`의 `VERSION`

설치용 웹 매니페스트는 `jumpking.webmanifest`, 오프라인 캐시는 `jumpking-sw.js`에서 관리합니다. Godot 자체 PWA 내보내기는 끈 상태로 유지합니다. 업데이트는 진행 중인 게임을 중단하지 않고 게임 탭을 모두 닫은 뒤 다음 실행에 적용됩니다.

브라우저 UI와 Godot는 같은 출처의 `minigameCommand` 콜백 및 출처·프레임을 확인하는 상태 메시지로 연결됩니다. `jumpking/web/index.html`을 직접 열면 기존 Godot 터치 버튼을 사용합니다.

**검증:** Godot 4.5에서 `godot --headless --path jumpking --script tests/mobile_controls_test.gd`로 충전 취소·일시정지·재개 후 점프를 검사할 수 있습니다. 다른 `jumpking/tests/*_test.gd`도 동일한 방법으로 실행합니다.

### 5. 카드 맞추기 · 1:1 (Godot)
친구와 방 코드 또는 초대 링크로 만나는 턴제 카드게임입니다. 각자 7장으로 시작해 무늬나 숫자를 맞추고 먼저 손패를 비우면 승리합니다. 재대전과 같은 탭에서의 재접속을 지원합니다.

- 화면: `cardduel.html`, Godot 프로젝트: `cardduel/`
- 서버: `server/` — Cloudflare Workers + SQLite Durable Objects
- 로컬 실행: `npm ci --prefix server` → `npm run dev --prefix server`, 정적 서버도 켠 뒤 `http://localhost:8000/cardduel.html`에 접속합니다.
- 인터넷 대전은 Cloudflare 계정 로그인과 서버 배포 후 사용할 수 있습니다. 설정·배포·테스트는 [서버 안내](server/README.md)를 참고하세요.

### 6. 스타 편대 (Godot)
갤러그 스타일의 세로 우주 슈팅게임입니다. 적 편대가 급강하하며 공격하고, 4웨이브마다 보스가 등장합니다. 생명 3개로 도전하며 최고 점수를 기기에 저장합니다.

- 실행: `starfighter.html`, 원본: `starfighter/`
- 이동: 방향키 또는 WASD, 모바일은 화면 드래그. 탄환은 자동 발사합니다.
- P 아이템: 10초간 3방향 강화 사격. 일시정지: P / Esc 또는 오른쪽 위 버튼.
- 시작·재도전: Enter / Space 또는 화면 터치.
- 웹 빌드: Godot 4.5에서 `godot --headless --path starfighter --export-pack Web /절대경로/minigame/starfighter/web/index.pck`
- 웹 셸은 `jumpking/web/`의 Godot 4.5 런타임을 공유합니다. `starfighter/web/index.html`은 수동 셸이므로 덮어쓰지 마세요.
- 글꼴: Noto Sans KR, 라이선스 `starfighter/OFL.txt`.

### 7. 블록 아일랜드 (Godot 3D)
블록 지형과 나무가 있는 작은 섬을 탐험하는 1인칭 크리에이티브 샌드박스입니다. 7종 블록을 캐고 쌓고, 나무에서 얻은 목재로 장비를 제작할 수 있습니다. 월드·목재·장비 내구도는 이 브라우저/기기에 자동 저장됩니다. 몬스터와 멀티플레이는 없습니다.

- 실행: `blockworld.html`, Godot 4.5 원본: `blockworld/`
- PC: WASD/방향키 이동, 마우스 이동으로 시점 회전(시작 시 포인터 고정, Esc 해제), Space 점프, Shift 달리기.
- 좌클릭을 누르고 채굴, 우클릭 쌓기, 숫자 1–7 또는 휠로 블록 선택. 사거리 6블록. 나무 설치는 목재 1개를 소비하고, 나머지 블록은 무제한입니다.
- C 또는 제작 메뉴에서 나무 도끼(목재 3), 칼(2), 삽(2), 곡괭이(3)를 제작합니다. E 또는 상단 장비 버튼으로 맨손/보유 장비를 교체합니다.
- 도끼는 나무, 칼은 잎, 삽은 잔디·흙·모래, 곡괭이는 돌·벽돌을 한 번에 캡니다. 장비는 블록 60개를 캐면 부서져 다시 제작해야 합니다.
- Esc/Tab 메뉴, F 시작점 복귀. 메뉴에서 수동 저장도 가능합니다.
- 모바일: 왼쪽 아래 드래그 이동, 오른쪽 드래그 시점, 채굴·쌓기·점프 버튼. 가로 화면 권장. 메뉴에서 터치 조작을 켤 수 있습니다.
- 48×48 지형을 12×12 구역으로 나눠 노출된 면만 메시·충돌로 생성합니다. 건축 높이는 24, 바닥은 보호됩니다. 바다 아래로 떨어지면 시작점으로 돌아옵니다.
- Godot 검증: `godot --headless --path blockworld --script tests/world_test.gd`
- 웹 빌드: `godot --headless --path blockworld --export-pack Web /절대경로/minigame/blockworld/web/index.pck`
- `jumpking/web/`의 Godot 4.5 런타임을 공유합니다. 수동 웹 셸은 덮어쓰지 마세요. 글꼴 라이선스: `blockworld/OFL.txt`.

### 8. 스카이로드 (Godot 3D)

고전 우주 도로 게임에서 영감을 받은 3D 점프 러너입니다. 우주복을 입은 시바견이 작은 원반형 우주선을 타고 달리며, 결승선에서는 앞모습 세레머니를 보여줍니다. 좌우로 조종하고 속도를 조절하며 틈과 장애물을 넘으세요. 빛나는 발사 타일을 밟으면 초고속으로 높이 솟아 긴 공백을 건넌 뒤 착지합니다. 연료와 산소를 채우는 타일을 밟고 세 코스를 완주하면 됩니다.

- 실행: `skyroad.html`, Godot 4.5 원본: `skyroad/`
- PC: 좌우 방향키/A·D 이동, 위아래 방향키/W·S 가속·감속, Space 점프, R 다시 시작, Esc 일시정지.
- 모바일: 왼쪽 가상 조이스틱을 기울여 이동, 오른쪽 가속·감속·점프 버튼.
- 테스트: `godot --headless --path skyroad --script tests/track_test.gd`
- 웹 빌드: `godot --headless --path skyroad --export-pack Web /절대경로/minigame/skyroad/web/index.pck`
- 웹 런타임은 `jumpking/web/`의 Godot 4.5 파일을 공유합니다. 한글 글꼴 라이선스는 `skyroad/OFL.txt`에 있습니다.

## 🚀 실행 방법

### 로컬 실행
1. 저장소를 클론합니다
```bash
git clone <repository-url>
cd minigame
```

2. 로컬 서버를 실행합니다
```bash
# Python이 설치된 경우
python -m http.server 8000

# Node.js가 설치된 경우
npx http-server
```

3. 브라우저에서 `http://localhost:8000`으로 접속

### GitHub Pages로 온라인 플레이
GitHub Pages를 활성화하면 별도의 서버 없이 온라인에서 바로 플레이할 수 있습니다.

**설정 방법:**
1. GitHub 저장소의 **Settings** 탭으로 이동
2. 왼쪽 메뉴에서 **Pages** 선택
3. **Source** 섹션에서:
   - Branch: `main` 선택
   - Folder: `/ (root)` 선택
4. **Save** 버튼 클릭

설정 후 몇 분 내에 `https://<username>.github.io/<repository-name>/`에서 접속 가능합니다.

## 📁 프로젝트 구조

```
minigame/
├── index.html              # 메인 페이지 (게임 선택 메뉴)
├── survival.html           # 서바이벌 게임
├── ladder.html             # 사다리 타기
├── roulette.html           # 룰렛 뽑기
├── jumpking.html           # Godot 게임 페이지
├── jumpking/               # 하늘 발판 Godot 프로젝트 및 웹 빌드
├── css/
│   ├── main.css           # 메인 페이지 스타일
│   └── style.css          # 게임 공통 스타일
├── js/
│   ├── survival/          # 서바이벌 게임 로직
│   │   ├── config.js     # 게임 설정 및 상수
│   │   ├── state.js      # 게임 상태 관리
│   │   ├── items.js      # 아이템 시스템
│   │   ├── weapons.js    # 무기 시스템
│   │   ├── monsters.js   # 몬스터 시스템
│   │   ├── levelup.js    # 레벨업 시스템
│   │   ├── draw.js       # 렌더링
│   │   ├── game-loop.js  # 게임 루프
│   │   └── main.js       # 초기화 및 이벤트
│   ├── ladder/
│   │   └── ladder.js     # 사다리 타기 로직
│   └── roulette/
│       └── roulette.js   # 룰렛 뽑기 로직
└── img/                   # 이미지 리소스
```

## 🛠️ 기술 스택

- HTML5 Canvas
- Godot 4.5 (Web 내보내기)
- Vanilla JavaScript (ES6+)
- CSS3

## 📝 라이선스

하늘 발판의 한글 글꼴은 [Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr)을 사용하며, 라이선스는 `jumpking/fonts/OFL.txt`에 있습니다.

이 프로젝트는 개인 학습 및 포트폴리오 목적으로 제작되었습니다.
