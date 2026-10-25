import { DurableObject } from 'cloudflare:workers';
import { applyAction, createRoom, GameError, joinRoom, newPlayer, normalizeName, viewFor, type RoomState } from './game.ts';
interface Env { ROOMS: DurableObjectNamespace<CardRoom>; ALLOWED_ORIGINS: string; }
type Attachment = { playerId: string | null };
const json = (data: unknown, status = 200) => Response.json(data, { status, headers: { 'Cache-Control': 'no-store' } });
function failure(error: unknown): Response {
  if (error instanceof GameError) return json({ error: error.code, message: error.message }, error.code === 'NOT_FOUND' ? 404 : error.code === 'ROOM_FULL' ? 409 : 400);
  return json({ error: 'SERVER_ERROR', message: '서버에서 잠시 문제가 생겼어요. 다시 접속해 주세요.' }, 500);
}
async function readBody(request: Request): Promise<Record<string, unknown>> {
  if (Number(request.headers.get('Content-Length')) > 1024) throw new GameError('INVALID_BODY', '요청이 너무 큽니다.');
  const text = await request.text();
  if (text.length > 1024) throw new GameError('INVALID_BODY', '요청이 너무 큽니다.');
  try { const body = JSON.parse(text); if (body && typeof body === 'object' && !Array.isArray(body)) return body; } catch {}
  throw new GameError('INVALID_BODY', '올바르지 않은 요청입니다.');
}
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const allowed = env.ALLOWED_ORIGINS.split(',').map(v => v.trim());
    if (origin && !allowed.includes(origin)) return json({ error: 'ORIGIN_DENIED', message: '허용되지 않은 게임 주소입니다.' }, 403);
    const cors = (response: Response) => {
      if (response.status === 101) return response;
      const headers = new Headers(response.headers);
      if (origin) headers.set('Access-Control-Allow-Origin', origin);
      headers.set('Vary', 'Origin');
      headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Content-Type');
      return new Response(response.body, { status: response.status, headers });
    };
    if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }));
    try {
      const url = new URL(request.url);
      if (url.pathname === '/health' && request.method === 'GET') return cors(json({ ok: true, game: 'card-duel', protocol: 1 }));
      if (url.pathname === '/api/rooms' && request.method === 'POST') {
        const body = await readBody(request);
        normalizeName(body.name);
        const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        const bytes = crypto.getRandomValues(new Uint8Array(8));
        const code = [...bytes].map(v => alphabet[v % alphabet.length]).join('');
        return cors(await env.ROOMS.getByName(code).fetch(new Request('https://room/init', { method: 'POST', body: JSON.stringify({ name: body.name, code }) })));
      }
      const match = url.pathname.match(/^\/api\/rooms\/([A-Z2-9]{8})\/(join|socket)$/);
      if (!match) return cors(json({ error: 'NOT_FOUND', message: '주소를 확인해 주세요.' }, 404));
      const [code, operation] = match.slice(1);
      if (operation === 'join' && request.method === 'POST') {
        const body = await readBody(request);
        normalizeName(body.name);
        return cors(await env.ROOMS.getByName(code).fetch(new Request('https://room/join', { method: 'POST', body: JSON.stringify(body) })));
      }
      if (operation === 'socket' && request.method === 'GET' && request.headers.get('Upgrade')?.toLowerCase() === 'websocket') {
        return await env.ROOMS.getByName(code).fetch(new Request('https://room/socket', request));
      }
      return cors(json({ error: 'METHOD_NOT_ALLOWED', message: '지원하지 않는 요청입니다.' }, 405));
    } catch (error) { return cors(failure(error)); }
  },
} satisfies ExportedHandler<Env>;

export class CardRoom extends DurableObject<Env> {
  private state?: RoomState;
  private queue: Promise<unknown> = Promise.resolve();
  private authTimers = new Map<WebSocket, ReturnType<typeof setTimeout>>();
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => { this.state = await ctx.storage.get<RoomState>('room'); });
    // Protocol heartbeat is handled without waking the object or charging duration.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }
  private serial<T>(operation: () => Promise<T>): Promise<T> {
    const task = this.queue.then(operation);
    this.queue = task.catch(() => {});
    return task;
  }
  private room(): RoomState {
    if (!this.state || this.state.phase === 'expired' || this.state.expiresAt <= Date.now()) throw new GameError('NOT_FOUND', '방이 없거나 만료됐어요. 새 방을 만들어 주세요.');
    return this.state;
  }
  private async commit(state: RoomState): Promise<void> {
    await this.ctx.storage.transaction(async storage => {
      await storage.put('room', state);
      await storage.setAlarm(state.phase === 'expired' ? Date.now() + 1000 : state.expiresAt);
    });
    this.state = state;
  }
  private attachment(ws: WebSocket): Attachment { return ws.deserializeAttachment() || { playerId: null }; }
  private connected(): Set<string> {
    return new Set(this.ctx.getWebSockets().filter(ws => ws.readyState === WebSocket.OPEN).map(ws => this.attachment(ws).playerId).filter((id): id is string => !!id));
  }
  private broadcast(): void {
    const state = this.state;
    if (!state) return;
    const online = this.connected();
    for (const ws of this.ctx.getWebSockets()) {
      const playerId = this.attachment(ws).playerId;
      if (!playerId || ws.readyState !== WebSocket.OPEN) continue;
      try { ws.send(JSON.stringify(viewFor(state, playerId, online))); } catch { ws.close(1000, 'Session ended'); }
    }
  }
  async fetch(request: Request): Promise<Response> {
    return this.serial(async () => {
      try {
        const path = new URL(request.url).pathname;
        if (path === '/init') {
          if (this.state) throw new GameError('ROOM_FULL', '방 생성이 겹쳤어요. 다시 만들어 주세요.');
          const body = await readBody(request);
          const player = newPlayer(normalizeName(body.name));
          await this.commit(createRoom(String(body.code), player));
          return json({ room: this.state!.code, playerId: player.id, token: player.token }, 201);
        }
        const state = this.room();
        if (path === '/join') {
          const body = await readBody(request);
          const player = newPlayer(normalizeName(body.name));
          await this.commit(joinRoom(state, player));
          this.broadcast();
          return json({ room: state.code, playerId: player.id, token: player.token }, 201);
        }
        if (path === '/socket') {
          if (this.ctx.getWebSockets().length >= 8) return json({ error: 'TOO_MANY_CONNECTIONS', message: '잠시 후 다시 접속해 주세요.' }, 429);
          const pair = new WebSocketPair();
          const [client, server] = Object.values(pair);
          this.ctx.acceptWebSocket(server);
          server.serializeAttachment({ playerId: null } satisfies Attachment);
          this.authTimers.set(server, setTimeout(() => { this.authTimers.delete(server); if (!this.attachment(server).playerId) server.close(1008, 'Authentication required'); }, 10000));
          return new Response(null, { status: 101, webSocket: client });
        }
        return json({ error: 'NOT_FOUND' }, 404);
      } catch (error) { return failure(error); }
    });
  }
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    return this.serial(async () => {
      try {
        if (typeof message !== 'string' || message.length > 2048) { ws.close(1009, 'Invalid message'); return; }
        let action: Record<string, unknown>;
        try { action = JSON.parse(message); } catch { throw new GameError('INVALID_ACTION', '메시지를 읽지 못했어요.'); }
        if (!action || typeof action !== 'object') throw new GameError('INVALID_ACTION', '올바르지 않은 요청입니다.');
        const state = this.room();
        const playerId = this.attachment(ws).playerId;
        if (!playerId) {
          const player = action.type === 'auth' && typeof action.token === 'string' ? state.players.find(p => p.token === action.token && !p.left) : undefined;
          if (!player) { ws.close(1008, 'Invalid session'); return; }
          clearTimeout(this.authTimers.get(ws) ?? null); this.authTimers.delete(ws);
          for (const old of this.ctx.getWebSockets()) if (old !== ws && this.attachment(old).playerId === player.id) old.close(4001, 'Connected elsewhere');
          ws.serializeAttachment({ playerId: player.id } satisfies Attachment);
          this.broadcast(); return;
        }
        if (action.type === 'leave') {
          await this.commit(applyAction(state, playerId, action));
          ws.send(JSON.stringify({ type: 'left' }));
          ws.close(1000, 'Left room'); this.broadcast(); return;
        }
        await this.commit(applyAction(state, playerId, action));
        this.broadcast();
      } catch (error) {
        const body = error instanceof GameError ? { type: 'error', code: error.code, message: error.message } : { type: 'error', code: 'SERVER_ERROR', message: '잠시 후 다시 시도해 주세요.' };
        if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(body));
        if (body.code === 'NOT_FOUND') ws.close(4004, 'Room expired');
        else this.broadcast();
      }
    });
  }
  async webSocketClose(ws: WebSocket): Promise<void> {
    clearTimeout(this.authTimers.get(ws) ?? null); this.authTimers.delete(ws);
    this.broadcast();
  }
  async webSocketError(ws: WebSocket): Promise<void> { ws.close(1011, 'Connection error'); }
  async alarm(): Promise<void> {
    return this.serial(async () => {
      if (this.state && this.state.expiresAt > Date.now() && this.state.phase !== 'expired') { await this.ctx.storage.setAlarm(this.state.expiresAt); return; }
      for (const ws of this.ctx.getWebSockets()) ws.close(4004, 'Room expired');
      await this.ctx.storage.deleteAll(); this.state = undefined;
    });
  }
}
