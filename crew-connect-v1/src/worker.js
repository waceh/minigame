/**
 * CrewPing v1 — Cloudflare Workers 실서버 백엔드
 * - Static Assets : ./public 모바일 웹 서빙
 * - Workers KV    : 승무원 프로필·일정·원터치 상태·심부름 메모 동기화 + 승무원 전용 PIN 해시 보호
 * - Cron Trigger  : 30분마다 Google Calendar 비공개 .ics + 인천공항 공공API(#15095074) 조회 후 KV 갱신
 * - Kakao Webhook : POST /api/kakao/skill (카카오 i 오픈빌더 v2.0 자동응답)
 */

const ICN_API_BASE = "https://apis.data.go.kr/B551177/StatusOfPassengerFlightsDSOdp";

const COUNTRIES_KEYWORDS = {
    ES: ["스페인", "마드리드", "바르셀로나", "mad", "spain"],
    JP: ["일본", "도쿄", "나리타", "하네다", "오사카", " 후쿠오카", "삿포로", "nrt", "hnd", "kix"],
    US: ["미국", "뉴욕", "애틀랜타", "로스앤젤레스", "샌프란시스코", "시애틀", "jfk", "lax", "sfo", "atl"],
    FR: ["프랑스", "파리", "cdg"],
    VN: ["베트남", "다낭", "하노이", "호치민", "나트랑", "푸꾸옥", "dad", "han", "sgn"]
};

export default {
    async fetch(request, env) {
        const url = new URL(request.url);

        if (request.method === "OPTIONS") {
            return new Response(null, { status: 204, headers: corsHeaders() });
        }

        const clientToken = (request.headers.get("X-Crew-Auth") || "").trim();

        // 1. 실시간 상태 조회 API (모바일 웹 진입 시 호출)
        if (url.pathname.startsWith("/api/crew/") && request.method === "GET") {
            const parts = url.pathname.split("/").filter(Boolean); // ["api", "crew", ":slug"]
            const slug = sanitizeSlug(parts[2] || env.DEFAULT_CREW_SLUG || "default");
            const record = await getCrewRecord(env, slug);
            return jsonResponse(toClientPayload(record, clientToken));
        }

        // 2. 승무원 본인 확인(PIN 검증) API
        if (url.pathname.startsWith("/api/crew/") && url.pathname.endsWith("/auth") && request.method === "POST") {
            const parts = url.pathname.split("/").filter(Boolean);
            const slug = sanitizeSlug(parts[2] || env.DEFAULT_CREW_SLUG || "default");
            const body = await request.json().catch(() => ({}));
            const record = await getCrewRecord(env, slug);

            if (!record.isConfigured || !record.pinHash) {
                return jsonResponse({ ok: false, error: "아직 초기 등록이 완료되지 않았습니다." }, 400);
            }

            const candidateHash = await hashPin(slug, body.pin || "");
            if (candidateHash !== record.pinHash) {
                return jsonResponse({ ok: false, error: "비밀번호가 일치하지 않습니다." }, 401);
            }

            return jsonResponse({
                ok: true,
                token: record.pinHash,
                data: toClientPayload(record, record.pinHash)
            });
        }

        // 3. 초기 설정 / 승무원 상태·일정 동기화 / 가족 공유 메모 저장 API
        if (url.pathname.startsWith("/api/crew/") && url.pathname.endsWith("/sync") && request.method === "POST") {
            const parts = url.pathname.split("/").filter(Boolean);
            const slug = sanitizeSlug(parts[2] || env.DEFAULT_CREW_SLUG || "default");
            const body = await request.json().catch(() => ({}));
            const record = await getCrewRecord(env, slug);

            // 3-A. 가족 공유 페이지에서의 안전한 공용 메모(심부름·중요일정) 전용 업데이트
            if (body.familyMemoOnly === true) {
                if (!record.isConfigured) {
                    return jsonResponse({ ok: false, error: "먼저 승무원 초기 설정이 필요합니다." }, 400);
                }
                if (Array.isArray(body.shopping)) record.shopping = body.shopping.slice(0, 100);
                if (Array.isArray(body.busyEvents)) record.busyEvents = body.busyEvents.slice(0, 100);
                record.updatedAt = new Date().toISOString();
                await saveCrewRecord(env, slug, record);
                return jsonResponse({ ok: true, data: toClientPayload(record, clientToken) });
            }

            // 3-B. 최초 접속 초기 설정 (아직 미등록 상태일 때만 허용)
            if (!record.isConfigured || !record.pinHash) {
                const crewName = String(body.crewName || "").trim();
                const rawPin = String(body.newPin || "").trim();
                if (!crewName) {
                    return jsonResponse({ ok: false, error: "승무원 이름(호칭)을 입력해 주세요." }, 400);
                }
                if (rawPin.length < 4) {
                    return jsonResponse({ ok: false, error: "본인 확인용 비밀번호를 4자리 이상 입력해 주세요." }, 400);
                }

                record.isConfigured = true;
                record.crewName = crewName;
                record.pinHash = await hashPin(slug, rawPin);
                record.icsUrl = typeof body.icsUrl === "string" ? body.icsUrl.trim() : "";
                record.airportDriveMin = Number(body.airportDriveMin) || 60;
                record.override = null;
                record.items = Array.isArray(body.items) ? body.items : [];
                record.shopping = [];
                record.busyEvents = [];

                let pulledCount = 0;
                if (record.icsUrl && record.icsUrl.startsWith("http")) {
                    const pulled = await fetchAndParseRemoteIcs(record.icsUrl);
                    if (pulled.length > 0) {
                        record.items = pulled;
                        pulledCount = pulled.length;
                    }
                }

                const nowIso = new Date().toISOString();
                record.syncedAt = nowIso;
                record.updatedAt = nowIso;
                await saveCrewRecord(env, slug, record);

                return jsonResponse({
                    ok: true,
                    token: record.pinHash,
                    pulledCount,
                    data: toClientPayload(record, record.pinHash)
                });
            }

            // 3-C. 이미 등록된 프로필 수정 -> 반드시 승무원 본인 인증 토큰(X-Crew-Auth) 일치 필요
            if (!clientToken || clientToken !== record.pinHash) {
                return jsonResponse({ ok: false, error: "승무원 본인 인증이 필요합니다." }, 403);
            }

            // 전체 데이터 초기화 요청
            if (body.resetAll === true) {
                await deleteCrewRecord(env, slug);
                const empty = createEmptyRecord();
                return jsonResponse({ ok: true, reset: true, data: toClientPayload(empty, "") });
            }

            // 비밀번호 변경 요청
            if (typeof body.newPin === "string" && body.newPin.trim().length >= 4) {
                record.pinHash = await hashPin(slug, body.newPin.trim());
            }

            if (typeof body.crewName === "string" && body.crewName.trim()) {
                record.crewName = body.crewName.trim();
            }
            if (typeof body.icsUrl === "string") {
                record.icsUrl = body.icsUrl.trim();
            }
            if (typeof body.airportDriveMin === "number") {
                record.airportDriveMin = body.airportDriveMin;
            }
            if ("override" in body) {
                record.override = body.override;
            }
            if (Array.isArray(body.items)) {
                record.items = body.items;
            }
            if (Array.isArray(body.shopping)) {
                record.shopping = body.shopping;
            }
            if (Array.isArray(body.busyEvents)) {
                record.busyEvents = body.busyEvents;
            }

            let pulledCount = 0;
            if (body.pullIcsNow && record.icsUrl && record.icsUrl.startsWith("http")) {
                const pulled = await fetchAndParseRemoteIcs(record.icsUrl);
                if (pulled.length > 0) {
                    record.items = pulled;
                    pulledCount = pulled.length;
                }
            }

            record.updatedAt = new Date().toISOString();
            await saveCrewRecord(env, slug, record);

            return jsonResponse({
                ok: true,
                token: record.pinHash,
                pulledCount,
                data: toClientPayload(record, record.pinHash)
            });
        }

        // 4. 카카오 i 오픈빌더 챗봇 스킬 웹훅 엔드포인트 (v2.0 규격)
        if (url.pathname === "/api/kakao/skill" && request.method === "POST") {
            const slug = sanitizeSlug(url.searchParams.get("crew") || env.DEFAULT_CREW_SLUG || "default");
            const body = await request.json().catch(() => ({}));
            const utterance = String(body?.userRequest?.utterance || "");
            const record = await getCrewRecord(env, slug);
            const summaryText = utterance.includes("일정")
                ? buildKakaoScheduleReply(record)
                : buildKakaoSimpleReply(record);

            return jsonResponse({
                version: "2.0",
                template: {
                    outputs: [{ simpleText: { text: summaryText } }],
                    quickReplies: [
                        { label: "지금 상태 확인", action: "message", messageText: "지금 연락해도 될까?" },
                        { label: "이번 달 비행 일정", action: "message", messageText: "다음 비행 일정 알려줘" }
                    ]
                }
            });
        }

        // 5. 정적 모바일 웹 파일(./public) 서빙
        return env.ASSETS.fetch(request);
    },

    // 30분 주기 자동 스케줄러 ("*/30 * * * *")
    async scheduled(_event, env, ctx) {
        ctx.waitUntil(syncAllCrews(env));
    }
};

function sanitizeSlug(raw) {
    return String(raw || "default").toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 32) || "default";
}

async function hashPin(slug, pin) {
    const data = new TextEncoder().encode(`crewping-v1:${slug}:${String(pin).trim()}`);
    const digest = await crypto.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(digest))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}

function createEmptyRecord() {
    return {
        isConfigured: false,
        crewName: "",
        pinHash: "",
        icsUrl: "",
        airportDriveMin: 60,
        override: null,
        items: [],
        shopping: [],
        busyEvents: [],
        syncedAt: null,
        updatedAt: null
    };
}

function toClientPayload(record, clientToken) {
    const hasPin = Boolean(record.pinHash);
    const authValid = Boolean(hasPin && clientToken && clientToken === record.pinHash);
    return {
        isConfigured: Boolean(record.isConfigured),
        hasPin,
        authValid,
        crewName: record.crewName || "",
        // 비공개 구글 캘린더 주소는 본인 인증된 승무원에게만 내려주고 가족 공개 API에서는 마스킹
        icsUrl: authValid ? (record.icsUrl || "") : "",
        hasIcsUrl: Boolean(record.icsUrl),
        airportDriveMin: Number(record.airportDriveMin) || 60,
        override: record.override || null,
        items: Array.isArray(record.items) ? record.items : [],
        shopping: Array.isArray(record.shopping) ? record.shopping : [],
        busyEvents: Array.isArray(record.busyEvents) ? record.busyEvents : [],
        syncedAt: record.syncedAt || null,
        updatedAt: record.updatedAt || null
    };
}

async function getCrewRecord(env, slug) {
    if (!env.CREW_KV) {
        return createEmptyRecord();
    }
    const existing = await env.CREW_KV.get(`crew:${slug}`, "json");
    if (existing && typeof existing === "object") {
        return existing;
    }
    return createEmptyRecord();
}

async function saveCrewRecord(env, slug, record) {
    if (env.CREW_KV) {
        await env.CREW_KV.put(`crew:${slug}`, JSON.stringify(record));
    }
}

async function deleteCrewRecord(env, slug) {
    if (env.CREW_KV) {
        await env.CREW_KV.delete(`crew:${slug}`);
    }
}

async function syncAllCrews(env) {
    if (!env.CREW_KV) return;
    const listRes = await env.CREW_KV.list({ prefix: "crew:" });

    for (const key of listRes.keys) {
        const record = await env.CREW_KV.get(key.name, "json");
        if (!record || !record.isConfigured) continue;

        if (record.icsUrl && record.icsUrl.startsWith("http")) {
            const pulled = await fetchAndParseRemoteIcs(record.icsUrl);
            if (pulled.length > 0) {
                record.items = pulled;
            }
        }

        // 임박 비행(T-6h ~ 착륙+3h)에 대해서만 인천공항 공공API(#15095074) 호출
        if (env.DATA_GO_KR_API_KEY && Array.isArray(record.items)) {
            const now = Date.now();
            for (const it of record.items) {
                if (it.type !== "FLIGHT" || !it.flightId) continue;
                if (now < it.startMs - 6 * 3600000 || now > it.endMs + 3 * 3600000) continue;

                const info = await fetchIncheonFlightStatus(env.DATA_GO_KR_API_KEY, it.flightId);
                if (info && info.estimatedMs) {
                    const diffMin = Math.round((info.estimatedMs - it.endMs) / 60000);
                    if (diffMin >= 15) {
                        it.delayMin = diffMin;
                        it.endMs = info.estimatedMs;
                    }
                }
            }
        }

        record.syncedAt = new Date().toISOString();
        await env.CREW_KV.put(key.name, JSON.stringify(record));
    }
}

async function fetchAndParseRemoteIcs(icsUrl) {
    try {
        const res = await fetch(icsUrl, { headers: { "User-Agent": "CrewPing-Worker/1.1" } });
        if (!res.ok) return [];
        const text = await res.text();
        return extractEventsFromIcs(text);
    } catch (_) {
        return [];
    }
}

async function fetchIncheonFlightStatus(serviceKey, flightId) {
    for (const op of ["getPassengerArrivalsDSOdp", "getPassengerDeparturesDSOdp"]) {
        const apiUrl = `${ICN_API_BASE}/${op}?serviceKey=${encodeURIComponent(serviceKey)}&type=json&flight_id=${encodeURIComponent(flightId)}`;
        const res = await fetch(apiUrl).catch(() => null);
        if (!res || !res.ok) continue;
        const data = await res.json().catch(() => null);
        const item = data?.response?.body?.items?.[0];
        if (item && item.estimatedDateTime) {
            const s = String(item.estimatedDateTime);
            if (/^\d{12}$/.test(s)) {
                const ms = Date.UTC(+s.slice(0, 4), +s.slice(4, 6) - 1, +s.slice(6, 8), +s.slice(8, 10) - 9, +s.slice(10, 12), 0);
                return { remark: item.remark || "", estimatedMs: ms };
            }
        }
    }
    return null;
}

function extractEventsFromIcs(icsText) {
    const unfolded = icsText.replace(/\r?\n[ \t]/g, "");
    const blocks = unfolded.split("BEGIN:VEVENT").slice(1);
    const out = [];

    for (let idx = 0; idx < blocks.length; idx++) {
        const body = blocks[idx].split("END:VEVENT")[0];
        const summary = (body.match(/SUMMARY[^:]*:(.+)/)?.[1] || "").trim().replace(/\\,/g, ",");
        const loc = (body.match(/LOCATION[^:]*:(.+)/)?.[1] || "").trim().replace(/\\,/g, ",");
        const desc = (body.match(/DESCRIPTION[^:]*:(.+)/)?.[1] || "").trim().replace(/\\n/g, " ");
        const dtStart = (body.match(/DTSTART[^:]*:(\d{8}(?:T\d{6}Z?)?)/)?.[1] || "").trim();
        const dtEnd = (body.match(/DTEND[^:]*:(\d{8}(?:T\d{6}Z?)?)/)?.[1] || "").trim();
        if (!dtStart) continue;

        const startMs = parseCompactDate(dtStart);
        const endMs = dtEnd ? parseCompactDate(dtEnd) : startMs + 3600000;
        if (endMs <= startMs) continue;

        const fm = summary.match(/\b([A-Z]{2}\d{3,4})\b/i);
        const flightId = fm ? fm[1].toUpperCase() : "";
        const full = `${summary} ${loc} ${desc}`.toLowerCase();

        let country = "KR";
        for (const [code, kws] of Object.entries(COUNTRIES_KEYWORDS)) {
            if (kws.some((k) => full.includes(k))) {
                country = code;
                break;
            }
        }

        let type = "LAYOVER";
        if (flightId || summary.includes("비행") || summary.includes("->") || summary.includes("→")) type = "FLIGHT";
        else if (full.includes("스탠바이") || full.includes("대기")) type = "STANDBY";
        else if (full.includes("휴무") || full.includes("off")) type = "OFF";

        out.push({
            id: `gcal-${idx}-${startMs}`,
            type,
            flightId,
            country,
            startMs,
            endMs,
            title: summary.replace(flightId, "").trim() || summary,
            note: desc
        });
    }
    out.sort((a, b) => a.startMs - b.startMs);
    return out;
}

function parseCompactDate(v) {
    if (/^\d{8}$/.test(v)) {
        return Date.UTC(+v.slice(0, 4), +v.slice(4, 6) - 1, +v.slice(6, 8), -9, 0, 0);
    }
    const m = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/);
    if (!m) return Date.now();
    return m[7] === "Z"
        ? Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], 0)
        : Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4] - 9, +m[5], 0);
}

function buildKakaoSimpleReply(record) {
    if (!record || !record.isConfigured) {
        return "📋 아직 승무원 정보와 비행 일정이 등록되지 않았어요.\n승무원 전용 관리 페이지에서 초기 등록을 완료하면 상태 안내가 시작됩니다.";
    }
    const name = record.crewName || "승무원";
    if (record.override === "SLEEP") {
        return `😴 현재 ${name}님이 취침·휴식 모드를 켜두었어요.\n카톡 메시지를 남겨두시면 기상 후 여건이 될 때 확인합니다 ❤️`;
    }
    if (record.override === "LANDED") {
        return `🛬 ${name}님이 무사히 착륙해 이동 중입니다!\n수속과 이동을 마친 뒤 여유가 될 때 연락드릴게요.`;
    }
    if (record.override === "FREE") {
        return `💬 ${name}님이 지금 잠깐 여유가 생겼다고 신호를 보냈어요!\n가볍게 카톡 인사를 남겨보세요 (통화는 여건에 따라 어려울 수 있어요).`;
    }
    if (!Array.isArray(record.items) || record.items.length === 0) {
        return `🗓️ 현재 ${name}님의 등록된 비행 일정이 없습니다.\n새 스케줄이 연동되기 전이니 편하게 카톡으로 안부를 남겨보세요 ❤️`;
    }
    const now = Date.now();
    const active = record.items.find((f) => f.type === "FLIGHT" && now >= f.startMs && now <= f.endMs);
    if (active) {
        return `✈️ 현재 ${name}님은 [${active.flightId || active.title}] 비행 근무 중이라 연락이 어렵습니다.\n착륙 및 수속 이후 개략적인 확인이 가능하며, 현지 사정에 따라 응답이 늦을 수 있어요 ❤️`;
    }
    return `🌤️ 현재 ${name}님은 비행 중인 구간이 아닙니다.\n다만 현지 시각·휴식·이동 여건에 따라 답장이나 음성·화상통화가 어려울 수 있으니 먼저 편하게 카톡만 남겨주세요 ❤️`;
}

function formatKstShort(ms) {
    const d = new Date(ms + 9 * 3600000);
    const pad2 = (n) => String(n).padStart(2, "0");
    const wk = ["일", "월", "화", "수", "목", "금", "토"][d.getUTCDay()];
    return `${d.getUTCMonth() + 1}.${pad2(d.getUTCDate())}(${wk}) ${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

function buildKakaoScheduleReply(record) {
    if (!record || !record.isConfigured) {
        return "📋 아직 승무원 정보와 비행 일정이 등록되지 않았어요.";
    }
    const name = record.crewName || "승무원";
    const now = Date.now();
    const upcoming = (record.items || []).filter((it) => it.endMs >= now).slice(0, 5);
    if (upcoming.length === 0) {
        return `🗓️ 현재 ${name}님의 예정된 향후 일정이 없습니다.`;
    }
    const lines = upcoming.map((it) => {
        const icon = it.type === "FLIGHT" ? "✈️" : it.type === "LAYOVER" ? "🌍" : it.type === "OFF" ? "🏠" : "📋";
        const label = it.flightId ? `[${it.flightId}] ${it.title}` : it.title;
        return `${icon} ${formatKstShort(it.startMs)} ${label}`;
    });
    return `📅 ${name}님 예정 일정 (한국시간 기준)\n\n${lines.join("\n")}\n\n※ 스케줄 변동이나 지연에 따라 실제 시간은 달라질 수 있어요 ❤️`;
}

function corsHeaders() {
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, X-Crew-Auth"
    };
}

function jsonResponse(obj, status = 200) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: {
            "content-type": "application/json;charset=utf-8",
            ...corsHeaders()
        }
    });
}
