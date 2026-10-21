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
80개의 발판을 딛고 정상까지 올라가는 충전식 점프 게임입니다. 높이 올라갈수록 발판이 좁아집니다. 충전 중에는 움직일 수 없고, 점프한 뒤에는 방향을 바꿀 수 없습니다. 발판은 아래에서 통과할 수 없으며 실수하면 아래 구간으로 떨어집니다.

**조작법:**
- 이동 및 방향 선택: A/D 또는 좌우 방향키 (모바일은 화면의 ◀ ▶ 버튼)
- 점프: 스페이스를 길게 누른 뒤 떼면 바라보는 방향으로 점프 (모바일은 화면의 ▲ 버튼)
- 다시 시작: R

Godot 4.5 프로젝트 원본은 `jumpking/`에, 웹 빌드는 `jumpking/web/`에 있습니다. 게임을 수정한 뒤에는 Godot에서 프로젝트를 열고 **프로젝트 > 내보내기 > Web**으로 다시 빌드할 수 있습니다. 배포할 때는 `jumpking.html`의 iframe 버전과 `jumpking/web/index.html`의 `GODOT_CONFIG.mainPack` 쿼리 버전을 함께 바꿔 브라우저가 새 게임 파일을 받도록 합니다.

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
