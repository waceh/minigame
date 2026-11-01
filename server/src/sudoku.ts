import { DurableObject } from 'cloudflare:workers';
import { generate } from './sudoku-engine.ts';

export interface SudokuEnv { SUDOKU: DurableObjectNamespace<SudokuCompetition>; }
type Difficulty = 'easy' | 'normal' | 'hard';
type RecordEntry = { id: string; name: string; difficulty: Difficulty; elapsed: number; completedAt: number };
type Run = { puzzle: number[]; solution: number[]; difficulty: Difficulty; startedAt: number; expiresAt: number; elapsed?: number; completedAt?: number; published?: RecordEntry };
const json = (body: unknown, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
const levels = ['easy', 'normal', 'hard'];
export class SudokuCompetition extends DurableObject<SudokuEnv> {
    private queue: Promise<unknown> = Promise.resolve();
    async fetch(request: Request): Promise<Response> {
        const task = this.queue.then(() => this.handle(request));
        this.queue = task.catch(() => {});
        return task;
    }
    private async handle(request: Request): Promise<Response> {
        const url = new URL(request.url);
        if (url.pathname === '/rankings' && request.method === 'GET') {
            const difficulty = url.searchParams.get('difficulty') || 'normal';
            if (!levels.includes(difficulty)) return json({ message: '난이도를 확인해 주세요.' }, 400);
            return json({ records: (await this.ctx.storage.get<RecordEntry[]>(`ranking:${difficulty}`) || []).slice(0, 10) });
        }
        if (request.method !== 'POST') return json({ message: '지원하지 않는 요청입니다.' }, 405);
        const text = await request.text();
        if (text.length > 2048) return json({ message: '요청이 너무 큽니다.' }, 413);
        let body: Record<string, unknown>;
        try { body = JSON.parse(text); if (!body || typeof body !== 'object' || Array.isArray(body)) throw Error(); }
        catch { return json({ message: '올바르지 않은 요청입니다.' }, 400); }
        // Only internal requests can reach /rankings with POST through the public router.
        if (url.pathname === '/rankings') {
            const record = body as unknown as RecordEntry;
            const key = `ranking:${record.difficulty}`;
            const records = (await this.ctx.storage.get<RecordEntry[]>(key) || []).filter(r => r.id !== record.id);
            records.push(record);
            records.sort((a, b) => a.elapsed - b.elapsed || a.completedAt - b.completedAt || a.id.localeCompare(b.id));
            const rank = records.findIndex(r => r.id === record.id) + 1;
            await this.ctx.storage.put(key, records.slice(0, 100));
            return json({ rank: rank <= 100 ? rank : null, record });
        }
        if (url.pathname === '/start') {
            if (!levels.includes(String(body.difficulty))) return json({ message: '난이도를 확인해 주세요.' }, 400);
            if (await this.ctx.storage.get('run')) return json({ message: '이미 시작된 게임입니다.' }, 409);
            const difficulty = body.difficulty as Difficulty;
            const generated = generate(difficulty);
            const startedAt = Date.now(), expiresAt = startedAt + 24 * 60 * 60 * 1000;
            await this.ctx.storage.put('run', { ...generated, difficulty, startedAt, expiresAt } satisfies Run);
            await this.ctx.storage.setAlarm(expiresAt);
            return json({ puzzle: generated.puzzle, difficulty, startedAt, expiresAt });
        }
        const run = await this.ctx.storage.get<Run>('run');
        if (!run || run.expiresAt <= Date.now()) return json({ message: '게임이 만료됐습니다. 새 온라인 게임을 시작해 주세요.' }, 410);
        if (url.pathname === '/finish') {
            if (!Array.isArray(body.values) || body.values.length !== 81 || !body.values.every((n, i) => Number.isInteger(n) && n === run.solution[i])) return json({ message: '아직 정답이 아닙니다.' }, 400);
            if (run.elapsed === undefined) {
                run.completedAt = Date.now(); run.elapsed = run.completedAt - run.startedAt;
                await this.ctx.storage.put('run', run);
            }
            return json({ elapsed: run.elapsed, completedAt: run.completedAt });
        }
        if (url.pathname === '/publish') {
            if (run.elapsed === undefined || !run.completedAt) return json({ message: '먼저 퍼즐을 완성해 주세요.' }, 409);
            const name = typeof body.name === 'string' ? body.name.trim() : '';
            if (!name || name.length > 20 || /[\u0000-\u001f\u007f]/.test(name)) return json({ message: '이름은 1~20자로 입력해 주세요.' }, 400);
            const record: RecordEntry = run.published || { id: this.ctx.id.toString(), name, difficulty: run.difficulty, elapsed: run.elapsed, completedAt: run.completedAt };
            // Pin the first name before publishing, so retries cannot change an accepted record.
            run.published = record; await this.ctx.storage.put('run', run);
            return this.env.SUDOKU.getByName('leaderboard-v1').fetch(new Request('https://sudoku/rankings', { method: 'POST', body: JSON.stringify(record) }));
        }
        return json({ message: '주소를 확인해 주세요.' }, 404);
    }
    async alarm(): Promise<void> { await this.ctx.storage.deleteAll(); }
}

export async function sudokuRoute(request: Request, env: SudokuEnv): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/api/sudoku/rankings' && request.method === 'GET') {
        return env.SUDOKU.getByName('leaderboard-v1').fetch(new Request(`https://sudoku/rankings${url.search}`));
    }
    if (url.pathname === '/api/sudoku/start' && request.method === 'POST') {
        const token = crypto.randomUUID();
        const response = await env.SUDOKU.getByName(`run:${token}`).fetch(new Request('https://sudoku/start', request));
        const data = await response.json() as object;
        return json(response.ok ? { ...data, token } : data, response.status);
    }
    const match = url.pathname.match(/^\/api\/sudoku\/([a-f0-9-]{36})\/(finish|publish)$/);
    if (match && request.method === 'POST') return env.SUDOKU.getByName(`run:${match[1]}`).fetch(new Request(`https://sudoku/${match[2]}`, request));
    return json({ message: '주소와 요청 방식을 확인해 주세요.' }, 404);
}
