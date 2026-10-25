export type Phase = 'waiting' | 'playing' | 'finished' | 'expired';
export interface Player {
  id: string;
  token: string;
  name: string;
  ready: boolean;
  left: boolean;
  hand: number[];
  requests: string[];
}
export interface RoomState {
  code: string;
  phase: Phase;
  players: Player[];
  deck: number[];
  discard: number[];
  turn: number;
  revision: number;
  round: number;
  winnerId: string | null;
  reason: string | null;
  passes: number;
  lastEvent: string;
  expiresAt: number;
}
export class GameError extends Error {
  code: string;
  constructor(code: string, message: string) { super(message); this.code = code; }
}
export function normalizeName(value: unknown): string {
  if (typeof value !== 'string') throw new GameError('INVALID_NAME', '닉네임을 입력하세요.');
  const name = value.replace(/[\p{Cc}\p{Cf}]/gu, '').trim();
  if (!name || [...name].length > 16) throw new GameError('INVALID_NAME', '닉네임은 1~16자로 입력하세요.');
  return name;
}
export function shuffle<T>(values: T[], random: () => number = secureRandom): T[] {
  const copy = [...values];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}
function secureRandom(): number { return crypto.getRandomValues(new Uint32Array(1))[0] / 0x100000000; }
export function newPlayer(name: string): Player {
  return { id: crypto.randomUUID(), token: crypto.randomUUID() + crypto.randomUUID(), name: normalizeName(name), ready: false, left: false, hand: [], requests: [] };
}
export function createRoom(code: string, player: Player, now = Date.now()): RoomState {
  return { code, phase: 'waiting', players: [player], deck: [], discard: [], turn: 0, revision: 1, round: 0, winnerId: null, reason: null, passes: 0, lastEvent: '친구를 기다리고 있어요.', expiresAt: now + 86400000 };
}
export function joinRoom(state: RoomState, player: Player): RoomState {
  if (state.phase !== 'waiting' || state.players.length >= 2) throw new GameError('ROOM_FULL', '이미 게임 중이거나 가득 찬 방입니다.');
  const next = structuredClone(state);
  next.players.push(player);
  next.players.forEach(p => p.ready = false);
  next.revision++;
  next.lastEvent = `${player.name} 님이 입장했어요. 두 분 모두 준비해 주세요.`;
  return next;
}
export function canPlay(card: number, top: number): boolean {
  return Math.floor(card / 13) === Math.floor(top / 13) || card % 13 === top % 13;
}
function startRound(state: RoomState, random?: () => number): void {
  const deck = shuffle(Array.from({ length: 52 }, (_, i) => i), random);
  for (const p of state.players) { p.hand = deck.splice(0, 7); p.ready = false; }
  state.discard = [deck.pop()!];
  state.deck = deck;
  state.phase = 'playing';
  state.turn = state.round % 2;
  state.round++;
  state.winnerId = null;
  state.reason = null;
  state.passes = 0;
  state.lastEvent = `${state.players[state.turn].name} 님부터 시작합니다.`;
}
export function applyAction(state: RoomState, playerId: string, input: unknown, random?: () => number): RoomState {
  if (!input || typeof input !== 'object') throw new GameError('INVALID_ACTION', '올바르지 않은 요청입니다.');
  const action = input as Record<string, unknown>;
  const index = state.players.findIndex(p => p.id === playerId && !p.left);
  if (index < 0) throw new GameError('UNAUTHORIZED', '입장 정보를 확인해 주세요.');
  if (typeof action.requestId !== 'string' || !/^[\w-]{8,80}$/.test(action.requestId)) throw new GameError('INVALID_ACTION', '요청 번호가 없습니다.');
  if (state.players[index].requests.includes(action.requestId)) return state;
  if (action.revision !== state.revision) throw new GameError('STALE_STATE', '게임 상태를 갱신했어요. 다시 선택해 주세요.');
  const next = structuredClone(state);
  const player = next.players[index];
  if (action.type === 'ready') {
    if (!['waiting', 'finished'].includes(next.phase) || next.players.some(p => p.left)) throw new GameError('NOT_WAITING', '지금은 준비할 수 없습니다.');
    player.ready = !player.ready;
    next.lastEvent = `${player.name} 님이 ${player.ready ? '준비했어요.' : '준비를 취소했어요.'}`;
    if (next.players.length === 2 && next.players.every(p => p.ready)) startRound(next, random);
  } else if (action.type === 'leave') {
    player.left = true;
    if (next.phase === 'playing') {
      next.phase = 'finished'; next.winnerId = next.players[1 - index].id; next.reason = 'left';
      next.lastEvent = `${player.name} 님이 나가 게임이 끝났어요.`;
    } else if (next.phase === 'waiting') {
      next.players.splice(index, 1);
      next.players.forEach(p => p.ready = false);
      next.lastEvent = `${player.name} 님이 나갔어요. 새 친구를 초대하세요.`;
    }
    if (next.players.every(p => p.left)) next.phase = 'expired';
  } else {
    if (next.phase !== 'playing') throw new GameError('NOT_PLAYING', '게임이 시작되지 않았습니다.');
    if (next.turn !== index) throw new GameError('NOT_YOUR_TURN', '상대방 차례입니다.');
    if (action.type === 'play') {
      const card = action.cardId;
      if (typeof card !== 'number' || !Number.isInteger(card) || !player.hand.includes(card)) throw new GameError('INVALID_CARD', '손에 없는 카드입니다.');
      if (!canPlay(card, next.discard.at(-1)!)) throw new GameError('ILLEGAL_CARD', '같은 무늬 또는 같은 숫자의 카드를 내세요.');
      player.hand.splice(player.hand.indexOf(card), 1);
      next.discard.push(card);
      next.passes = 0;
      next.lastEvent = `${player.name} 님이 카드를 냈어요.`;
      if (!player.hand.length) {
        next.phase = 'finished'; next.winnerId = player.id; next.reason = 'empty_hand';
        next.lastEvent = `${player.name} 님이 손패를 모두 비웠어요!`;
      }
    } else if (action.type === 'draw') {
      if (!next.deck.length && next.discard.length > 1) {
        const top = next.discard.pop()!;
        next.deck = shuffle(next.discard, random); next.discard = [top];
      }
      const card = next.deck.pop();
      if (card !== undefined) {
        player.hand.push(card); next.passes = 0;
        next.lastEvent = `${player.name} 님이 카드 한 장을 가져갔어요.`;
      } else {
        next.passes++;
        next.lastEvent = '가져올 카드가 없어 차례를 넘겼어요.';
        if (next.passes >= 2) {
          const [a, b] = next.players;
          next.phase = 'finished'; next.reason = 'blocked';
          next.winnerId = a.hand.length === b.hand.length ? null : a.hand.length < b.hand.length ? a.id : b.id;
          next.lastEvent = '덱이 소진되어 손패가 적은 쪽이 이깁니다.';
        }
      }
    } else throw new GameError('INVALID_ACTION', '지원하지 않는 행동입니다.');
    if (next.phase === 'playing') next.turn = 1 - index;
  }
  player.requests.push(action.requestId);
  player.requests = player.requests.slice(-32);
  next.revision++;
  next.expiresAt = Date.now() + 86400000;
  return next;
}
export function viewFor(state: RoomState, playerId: string, online: Set<string> = new Set()) {
  const me = state.players.find(p => p.id === playerId && !p.left);
  if (!me) throw new GameError('UNAUTHORIZED', '유효한 입장 정보가 없습니다.');
  return {
    type: 'state', room: state.code, phase: state.phase, revision: state.revision, round: state.round,
    you: me.id, hand: [...me.hand], topCard: state.discard.at(-1) ?? null,
    deckCount: state.deck.length, turn: state.phase === 'playing' ? state.players[state.turn].id : null,
    winnerId: state.winnerId, reason: state.reason, lastEvent: state.lastEvent,
    players: state.players.map(p => ({ id: p.id, name: p.name, ready: p.ready, left: p.left, connected: online.has(p.id), cardCount: p.hand.length })),
  };
}
