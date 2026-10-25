# 카드 맞추기 서버

Godot 4.5 클라이언트와 Cloudflare Workers + SQLite-backed Durable Objects로 만든 1:1 턴제 카드게임입니다. 기본 구성은 Workers Free에서 사용할 수 있으며 별도의 데이터베이스 상품이나 도메인은 필요하지 않습니다. 무료 한도를 넘으면 서비스가 제한되므로 Cloudflare 대시보드에서 사용량을 확인하세요. 이 프로젝트가 유료 플랜으로 변경하지는 않습니다.

## 로컬 실행

Node.js 22.18 이상이 필요합니다. 저장소 루트에서:

```bash
npm ci --prefix server
npm run dev --prefix server
```

다른 터미널에서 정적 파일 서버를 실행합니다.

```bash
python3 -m http.server 8000
```

`http://localhost:8000/cardduel.html`을 서로 다른 탭 두 개에서 열어 닉네임을 입력하고, 한쪽이 생성한 방 코드로 다른 쪽이 입장합니다. 둘 다 준비하면 게임이 시작됩니다. 같은 탭의 새로고침은 기존 플레이어로 복구됩니다. 테스트할 때 탭 복제 대신 새 탭에서 URL을 여세요. 브라우저의 탭 복제 기능은 sessionStorage를 복제할 수 있습니다.

기본 서버는 `http://127.0.0.1:8787`에 바인딩됩니다. 휴대폰에서도 로컬 테스트하려면 `wrangler dev --ip 0.0.0.0 --port 8787`로 실행하고 `wrangler.jsonc`의 `ALLOWED_ORIGINS`에 개발 PC의 정적 서버 주소(예: `http://192.168.0.10:8000`)를 추가하세요. `js/cardduel/config.js`의 서버 주소도 해당 개발 PC의 8787번 주소로 맞춰야 합니다. 외부 포트 개방 없이 같은 Wi-Fi에서만 테스트하세요.

## 규칙

- 52장, 각자 7장, 같은 무늬 또는 같은 숫자만 낼 수 있습니다.
- 공격·조커 같은 특수 효과는 없습니다.
- 한 장을 받으면 그 차례는 끝납니다. 낼 수 있어도 받기를 선택할 수 있습니다.
- 손패를 먼저 비우면 이깁니다. 덱이 비면 맨 위 카드를 제외한 버린 패를 섞습니다.
- 덱과 재활용 카드가 모두 없어서 양쪽이 연속으로 받기를 못 하면 손패가 적은 쪽이 이기며, 같으면 무승부입니다.
- 둘 다 다시 준비하면 재대전하며 선공이 바뀝니다.
- 단순 연결 끊김은 항복으로 처리하지 않습니다. 명시적으로 나가면 상대 승리입니다.
- 방은 마지막 상태 변경 후 24시간에 만료됩니다. 계정이나 전적은 저장하지 않습니다.

## Cloudflare 무료 배포

1. Cloudflare 계정에 가입하거나 로그인합니다. Workers Free를 유지하세요.
2. 이 폴더에서 Wrangler에 로그인하고 배포합니다.

```bash
cd server
npx wrangler login --scopes account:read user:read workers_scripts:write
npm run deploy
```

배포는 `wrangler.jsonc`의 `new_sqlite_classes` 마이그레이션으로 무료 플랜에 맞는 Durable Object를 생성합니다. 일반 KV-backed Durable Object와 별도 D1 데이터베이스는 사용하지 않습니다.

3. 배포 결과에 표시된 HTTPS 주소를 웹 클라이언트에 연결합니다.

```bash
npm run configure-client -- https://minigame-card-duel.YOUR-SUBDOMAIN.workers.dev
```

4. 저장소의 정적 사이트를 게시합니다. 게임은 `cardduel.html`입니다. Godot는 부모 페이지의 설정을 읽으므로 서버 주소만 바꾸는 경우 Godot를 다시 빌드할 필요가 없습니다.
5. 정적 사이트 주소를 바꾸면 `wrangler.jsonc`의 `ALLOWED_ORIGINS`에도 추가하고 서버를 다시 배포합니다. 기본값은 `https://waceh.github.io`, 로컬 8000번 포트입니다. 별도 도메인을 구매할 필요는 없습니다.

로그인 토큰은 이 저장소나 클라이언트 설정에 넣지 마세요. 공개하는 것은 서버 주소뿐입니다.

## 구조와 프로토콜

- `src/game.ts`: 규칙·셔플·개인별 상태. Godot나 Worker에 의존하지 않는 순수 로직입니다.
- `src/index.ts`: HTTP 방 생성/입장, WebSocket 인증, 상태 저장과 브로드캐스트.
- 방 코드당 Durable Object 1개. 첫 번째 메시지에서 서버가 발급한 세션 토큰으로 인증합니다. 토큰은 URL에 넣지 않습니다.
- `POST /api/rooms`, `POST /api/rooms/:code/join`: `{ "name": "닉네임" }` → `{ "room", "playerId", "token" }`.
- `GET /api/rooms/:code/socket`: WebSocket 연결. 첫 메시지는 `{ "type": "auth", "token": "..." }`.
- 이후 `ready`, `play`, `draw`, `leave`에 `revision`과 고유 `requestId`를 포함합니다. `play`만 정수 `cardId`가 필요합니다.
- 서버가 `state` 메시지로 자신의 손패, 공개 카드, 양쪽 카드 수를 보냅니다. 상대 손패·덱 순서·세션 토큰은 보내지 않습니다.
- 변경 전 revision 검사, 요청 중복 방지, 직렬 처리, 저장 후 전달로 중복 클릭과 동시 요청을 처리합니다.
- WebSocket Hibernation API를 사용합니다. 장기 상태는 메모리 대신 Durable Object 저장소에 기록하며 재접속할 때 복구합니다.
- 25초마다 클라이언트의 `ping`을 보내고 서버 자동 응답으로 `pong`을 받습니다. 재시작·네트워크 단절 시 클라이언트가 점진적으로 재접속합니다.
- 같은 플레이어가 새 연결을 만들면 이전 연결은 4001로 종료됩니다. 방 코드를 아는 사람만 새 좌석으로 입장할 수 있고, 2명이 차면 추가 입장은 거부합니다.

## 검증

```bash
npm run check
npm test
# 위의 로컬 서버를 켜둔 상태에서:
npm run test:integration
```

단위 테스트는 손패 비공개, 소유권·차례·일치 규칙, 요청 중복, 덱 재활용, 완주·재대전 등을 확인합니다. 통합 테스트는 실제 로컬 Durable Object에 HTTP와 두 WebSocket 클라이언트로 연결해 방 입장, 준비, 카드 행동, 손패 비공개, heartbeat, 재접속, 나가기와 정원을 검사합니다.

## Godot 수정 후 빌드

`cardduel/`을 Godot 4.5에서 열어 수정합니다. 웹 런타임은 같은 버전의 `jumpking/web/index.js`·`index.wasm` 등을 공유하여 큰 엔진 파일을 중복 저장하지 않습니다. 카드게임은 자체 PCK만 내보냅니다.

```bash
godot --headless --path cardduel --export-pack Web /ABSOLUTE/PATH/minigame/cardduel/web/index.pck
```

Godot 버전을 바꿀 때는 공유 런타임도 함께 갱신해야 합니다. 배포 시 `cardduel.html`의 iframe·설정 스크립트 버전과 `cardduel/web/index.html`의 PCK 버전을 올리세요. `cardduel/web/index.html`은 공유 런타임용 수동 셸이므로 일반 Web 내보내기로 덮어쓰지 마세요.
