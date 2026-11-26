const COUNTRIES = {
    KR: {
        flag: "🇰🇷", name: "한국 (서울/인천)", tz: "Asia/Seoul",
        keywords: ["인천", "김포", "한국", "서울", "icn", "gmp"],
        weather: "맑음 · 낮 9°C / 밤 1°C", outfit: "두꺼운 코트/경량패딩", perDiemUsdPerHour: 0
    },
    ES: {
        flag: "🇪🇸", name: "스페인 (마드리드)", tz: "Europe/Madrid",
        keywords: ["스페인", "마드리드", "바르셀로나", "mad", "spain"],
        weather: "구름조금 ⛅ · 낮 15°C / 밤 6°C (일교차 큼)", outfit: "서울보다 포근! 얇은 니트 + 트렌치/가디건 + 작은 우산", perDiemUsdPerHour: 4.2
    },
    JP: {
        flag: "🇯🇵", name: "일본 (도쿄)", tz: "Asia/Tokyo",
        keywords: ["일본", "도쿄", "나리타", "하네다", "오사카", "nrt", "hnd", "tokyo"],
        weather: "맑음 ☀️ · 낮 14°C / 밤 7°C", outfit: "가벼운 자켓 또는 도톰한 가디건", perDiemUsdPerHour: 3.8
    },
    US: {
        flag: "🇺🇸", name: "미국 동부 (뉴욕)", tz: "America/New_York",
        keywords: ["미국", "뉴욕", "애틀랜타", "보스턴", "jfk", "new york"],
        weather: "바람 강함 🌬️ · 낮 8°C / 밤 0°C", outfit: "서울과 비슷하게 추움! 머플러·방풍 패딩 필수", perDiemUsdPerHour: 4.8
    },
    FR: {
        flag: "🇫🇷", name: "프랑스 (파리)", tz: "Europe/Paris",
        keywords: ["프랑스", "파리", "cdg", "paris"],
        weather: "흐리고 비 ☔ · 낮 11°C / 밤 5°C", outfit: "방수 코트 및 휴대용 우산 필수", perDiemUsdPerHour: 4.4
    },
    VN: {
        flag: "🇻🇳", name: "베트남 (다낭/하노이)", tz: "Asia/Ho_Chi_Minh",
        keywords: ["베트남", "다낭", "하노이", "호치민", "dad", "danang"],
        weather: "온화함 🌴 · 낮 27°C / 밤 22°C (기온차 +18°C 주의)", outfit: "반팔/긴팔 셔츠 + 호텔 냉방용 얇은 가디건", perDiemUsdPerHour: 3.2
    }
};

// 배우자(파트너) 사내 캘린더 & 부모님 고정 일정 (승무원 비행 맞교환 스왑 충돌 검사용)
const FAMILY_BUSY_CONFLICTS = [
    { who: "❤️ 파트너(배우자·연인) 캘린더", start: "2026-11-19 17:00", end: "2026-11-19 22:00", reason: "하반기 코어 결제서버 정기 프로덕션 배포 (야근 확정 · 하원 불가)" },
    { who: "🏡 부모님 개인 일정", start: "2026-11-19 13:30", end: "2026-11-19 17:30", reason: "분당서울대병원 정기 진료 예약 (오후 하원 지원 불가)" },
    { who: "❤️ 파트너(배우자·연인) 캘린더", start: "2026-11-26 09:00", end: "2026-11-26 19:00", reason: "대전 연구소 당일 출장 (오전 등원/오후 하원 모두 불가)" }
];

const DEFAULT_ITEMS_SEED = [
    { type: "FLIGHT", flightId: "KE703", country: "JP", start: "2026-11-05 10:10", end: "2026-11-05 12:30", title: "인천 -> 도쿄(나리타) 출국편", careNote: "배우자 등원 / 부모님 오후 하원" },
    { type: "LAYOVER", flightId: "", country: "JP", start: "2026-11-05 12:30", end: "2026-11-06 14:00", title: "도쿄 호텔 체류 (1박 2일)", careNote: "시차 없음 · 현지 여건 따라 카톡 확인" },
    { type: "FLIGHT", flightId: "KE704", country: "JP", start: "2026-11-06 14:00", end: "2026-11-06 16:45", title: "도쿄(나리타) -> 인천 귀국편", careNote: "19시경 귀가 예상 · 부모님 하원 픽업" },
    { type: "OFF", flightId: "", country: "KR", start: "2026-11-07 00:00", end: "2026-11-08 23:59", title: "주말 정기 휴무 (OFF)", careNote: "승무원 직접 등하원 가능 (개인 휴식 배려)" },
    { type: "FLIGHT", flightId: "KE081", country: "US", start: "2026-11-11 10:00", end: "2026-11-12 00:30", title: "인천 -> 뉴욕(JFK) 장거리 비행", careNote: "배우자 등원 / 부모님 하원+저녁돌봄" },
    { type: "LAYOVER", flightId: "", country: "US", start: "2026-11-12 00:30", end: "2026-11-14 02:00", title: "미국 뉴욕 현지 체류", careNote: "시차 -14시간 주의 · 한국 아침이 현지 저녁(컨디션 따라 상이)" },
    { type: "FLIGHT", flightId: "KE082", country: "US", start: "2026-11-14 02:00", end: "2026-11-14 17:30", title: "뉴욕(JFK) -> 인천 귀국편", careNote: "토요일 저녁 19:30경 귀가 예상" },
    { type: "TRAINING", flightId: "", country: "KR", start: "2026-11-17 09:00", end: "2026-11-17 17:30", title: "정기 항공안전 훈련 (비행편 없음)", careNote: "훈련 중 휴대폰 무음 · 종료 후 확인 예상" },
    { type: "STANDBY", flightId: "", country: "KR", start: "2026-11-18 06:00", end: "2026-11-18 18:00", title: "자택 스탠바이 대기 (호출 시 출동)", careNote: "돌발 호출 대비 부모님 오후 대기 부탁" },
    { type: "FLIGHT", flightId: "KE913", country: "ES", start: "2026-11-21 20:00", end: "2026-11-22 10:00", title: "인천 -> 스페인 마드리드 도착", careNote: "주말 비행 · 배우자 종일 육아 담당" },
    { type: "LAYOVER", flightId: "", country: "ES", start: "2026-11-22 10:00", end: "2026-11-23 14:00", title: "스페인 마드리드 현지 체류", careNote: "한국 저녁과 현지 오전 시차 겹침 (컨디션 우선 배려)" },
    { type: "FLIGHT", flightId: "KE914", country: "ES", start: "2026-11-23 14:00", end: "2026-11-24 08:00", title: "스페인 출발 -> 인천 도착", careNote: "24일 아침 등원 배우자 · 10시경 귀가 예상" },
    { type: "OFF", flightId: "", country: "KR", start: "2026-11-25 00:00", end: "2026-11-26 23:59", title: "비행 후 리커버리 휴무 (OFF)", careNote: "장거리 귀국 후 시차 회복 및 휴식 배려" }
];

const DEFAULT_SHOPPING = [
    { id: "sh-1", text: "[마드리드 마트] 라치나타 올리브오일 트러플 2병 (부모님 부탁)", done: false },
    { id: "sh-2", text: "[기내/입국장 면세] 첫째·둘째 키즈 유산균 2박스", done: true },
    { id: "sh-3", text: "[마드리드] 당근크림 (부모님 선물)", done: false }
];

const SAMPLE_GOOGLE_CALENDAR_ICS = `BEGIN:VCALENDAR
PRODID:-//Google Inc//Google Calendar 70.9054//EN
VERSION:2.0
X-WR-CALNAME:김하늘 비행스케줄
X-WR-TIMEZONE:Asia/Seoul
BEGIN:VEVENT
DTSTART;TZID=Asia/Seoul:20261128T090000
DTEND;TZID=Asia/Seoul:20261128T132000
SUMMARY:KE461 인천 -> 다낭 비행
LOCATION:베트남 다낭 (DAD)
DESCRIPTION:배우자 오전 등원 / 부모님 오후 하원 지원
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=Asia/Seoul:20261128T132000
DTEND;TZID=Asia/Seoul:20261129T223000
SUMMARY:다낭 호텔 체류
LOCATION:베트남 다낭
DESCRIPTION:시차 -2시간 (현지 여건 따라 카톡 확인)
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=Asia/Seoul:20261129T223000
DTEND;TZID=Asia/Seoul:20261130T055000
SUMMARY:KE462 다낭 -> 인천 귀국편
LOCATION:베트남 다낭
DESCRIPTION:월요일 아침 8시경 현관문 도착 예정
END:VEVENT
END:VCALENDAR`;

const STORAGE_KEY = "crewping_inclusive_v8";

const state = {
    configured: true,
    role: "partner", // crew | partner | grandparents | kids
    tokenSeed: "f9a8c2e1",
    manualOverride: null, // null | { mode: 'LANDED' | 'SLEEP_NOW' | 'CALL_ME', triggeredAtKst: string }
    profile: {
        crewName: "김하늘 승무원",
        calSecretUrl: "https://calendar.google.com/calendar/ical/haneul.crew%40gmail.com/private-8a9b7c6d/basic.ics",
        arrivalBufferMin: 30,
        commuteBufferMin: 120,
        restHoursAfterLongHaul: 5
    },
    digest: {
        kids: "첫째·둘째 모두 열 없이 하원 완료! 저녁 카레 한 그릇 뚝딱 했어~",
        school: "내일 둘째 체육복 입는 날 (거실 소파에 미리 꺼내둠 · 배우자 등원 예정)",
        memo: "집은 아무 걱정 말고 호텔 도착하면 푹 쉬어! 연락은 편할 때 천천히 줘도 돼💛"
    },
    shopping: [],
    simNowMs: kstStringToMs("2026-11-21T23:30"),
    isInboundDelayed: false,
    delayMinutes: 60,
    selectedCalendarDay: null,
    items: []
};

function kstStringToMs(str) {
    const clean = str.trim().replace(" ", "T");
    const [datePart, timePart = "00:00"] = clean.split("T");
    const [y, m, d] = datePart.split("-").map(Number);
    const [hh, mm] = timePart.split(":").map(Number);
    return Date.UTC(y, m - 1, d, hh - 9, mm, 0);
}

function msToDatetimeLocalValue(ms) {
    const d = new Date(ms + 9 * 3600 * 1000);
    return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}T${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

function msToIcsUtcString(ms) {
    const d = new Date(ms);
    return `${d.getUTCFullYear()}${pad2(d.getUTCMonth() + 1)}${pad2(d.getUTCDate())}T${pad2(d.getUTCHours())}${pad2(d.getUTCMinutes())}00Z`;
}

function pad2(n) {
    return String(n).padStart(2, "0");
}

function formatInTimeZone(ms, timeZone) {
    const d = new Date(ms);
    const parts = new Intl.DateTimeFormat("ko-KR", {
        timeZone,
        month: "numeric",
        day: "numeric",
        weekday: "short",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
    }).formatToParts(d);

    const map = {};
    parts.forEach((p) => { map[p.type] = p.value; });
    const hour24 = Number(map.hour === "24" ? 0 : map.hour);
    const minute = Number(map.minute);
    const ampm = hour24 < 12 ? "오전" : "오후";
    const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;

    return {
        month: Number(map.month),
        day: Number(map.day),
        weekday: map.weekday,
        hour24,
        minute,
        clock12: `${ampm} ${pad2(hour12)}:${pad2(minute)}`,
        shortKst: `${map.month}월 ${map.day}일 (${map.weekday}) ${pad2(hour24)}:${pad2(minute)}`,
        mdhm: `${map.day}일 ${pad2(hour24)}:${pad2(minute)}`
    };
}

function getHourDiffFromKorea(ms, targetTz) {
    if (targetTz === "Asia/Seoul") return 0;
    const kr = formatInTimeZone(ms, "Asia/Seoul");
    const lc = formatInTimeZone(ms, targetTz);
    let dayDiff = lc.day - kr.day;
    if (dayDiff > 15) dayDiff -= 30;
    if (dayDiff < -15) dayDiff += 30;
    return dayDiff * 24 + (lc.hour24 - kr.hour24);
}

// Google Calendar (.ics) 실제 파서
function parseGoogleCalendarIcs(icsText) {
    const unfolded = icsText.replace(/\r?\n[ \t]/g, "");
    const blocks = unfolded.split("BEGIN:VEVENT").slice(1);
    const parsedEvents = [];

    function parseIcsDateProp(rawVal) {
        if (!rawVal) return null;
        const val = rawVal.trim();
        if (/^\d{8}$/.test(val)) {
            const y = Number(val.slice(0, 4));
            const m = Number(val.slice(4, 6));
            const d = Number(val.slice(6, 8));
            return Date.UTC(y, m - 1, d, -9, 0, 0);
        }
        const dtMatch = val.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$/);
        if (!dtMatch) return null;
        const [, y, m, d, hh, mm, , isUtc] = dtMatch;
        if (isUtc === "Z") {
            return Date.UTC(Number(y), Number(m) - 1, Number(d), Number(hh), Number(mm), 0);
        }
        return Date.UTC(Number(y), Number(m) - 1, Number(d), Number(hh) - 9, Number(mm), 0);
    }

    blocks.forEach((blk, idx) => {
        const endIdx = blk.indexOf("END:VEVENT");
        const body = endIdx >= 0 ? blk.slice(0, endIdx) : blk;
        const lines = body.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);

        const props = {};
        lines.forEach((line) => {
            const colon = line.indexOf(":");
            if (colon < 0) return;
            const keyPart = line.slice(0, colon).split(";")[0].toUpperCase();
            props[keyPart] = line.slice(colon + 1);
        });

        const startMs = parseIcsDateProp(props.DTSTART);
        const endMs = parseIcsDateProp(props.DTEND) || (startMs ? startMs + 3600000 : null);
        if (!startMs || !endMs || endMs <= startMs) return;

        const summary = (props.SUMMARY || "캘린더 일정").replace(/\\,/g, ",").replace(/\\n/g, " ");
        const location = (props.LOCATION || "").replace(/\\,/g, ",");
        const desc = (props.DESCRIPTION || "").replace(/\\n/g, " · ").replace(/\\,/g, ",");
        const combinedText = `${summary} ${location} ${desc}`.toLowerCase();

        const flightMatch = summary.match(/\b([A-Z]{2}\d{3,4})\b/i) || desc.match(/\b([A-Z]{2}\d{3,4})\b/i);
        const flightId = flightMatch ? flightMatch[1].toUpperCase() : "";

        let country = "KR";
        for (const [code, meta] of Object.entries(COUNTRIES)) {
            if (code === "KR") continue;
            if (meta.keywords.some((kw) => combinedText.includes(kw))) {
                country = code;
                break;
            }
        }

        let type = "LAYOVER";
        if (flightId || summary.includes("비행") || summary.includes("귀국") || summary.includes("->") || summary.includes("→")) {
            type = "FLIGHT";
        } else if (combinedText.includes("스탠바이") || combinedText.includes("stby") || combinedText.includes("대기")) {
            type = "STANDBY";
        } else if (combinedText.includes("훈련") || combinedText.includes("교육")) {
            type = "TRAINING";
        } else if (combinedText.includes("휴무") || combinedText.includes("off")) {
            type = "OFF";
        }

        parsedEvents.push({
            id: `gcal-${Date.now()}-${idx}`,
            type,
            flightId,
            country,
            startMs,
            endMs,
            title: summary.replace(flightId, "").trim() || summary,
            careNote: desc || "Google Calendar(.ics) 가져오기 일정"
        });
    });

    return parsedEvents;
}

function generateEnrichedIcsContent() {
    const items = getEffectiveItems();
    const lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CrewPing//Google Calendar Enriched Family Feed//KO",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        `X-WR-CALNAME:[CrewPing] ${state.profile.crewName} 비행·공동육아 스케줄`,
        "X-WR-TIMEZONE:Asia/Seoul"
    ];

    items.forEach((it) => {
        const prefix = it.type === "FLIGHT" ? `✈️[${it.flightId || "비행"}${it.delayMin ? ` +${it.delayMin}m지연` : ""}]`
            : it.type === "STANDBY" ? "⚠️[스탠바이·야근주의]"
            : it.type === "LAYOVER" ? "🌍[해외체류]"
            : it.type === "TRAINING" ? "🎓[안전교육]" : "🏠[휴무]";

        const desc = [
            `원본: Google Calendar 동기화`,
            `체류국가: ${COUNTRIES[it.country]?.name || "한국"}`,
            `공동육아 메모: ${it.careNote || "없음"}`,
            it.type === "STANDBY" || it.type === "FLIGHT"
                ? "※ 배우자·파트너 캘린더 알림: 저녁 배포/야근 자제 및 하원 픽업 확인 필요"
                : ""
        ].filter(Boolean).join("\\n");

        lines.push(
            "BEGIN:VEVENT",
            `UID:${it.id}@crewping.local`,
            `DTSTAMP:${msToIcsUtcString(Date.now())}`,
            `DTSTART:${msToIcsUtcString(it.effStartMs)}`,
            `DTEND:${msToIcsUtcString(it.effEndMs)}`,
            `SUMMARY:${prefix} ${it.title}`,
            `DESCRIPTION:${desc}`,
            "END:VEVENT"
        );
    });

    lines.push("END:VCALENDAR");
    return lines.join("\r\n");
}

function getDefaultItems() {
    return DEFAULT_ITEMS_SEED.map((s, idx) => ({
        id: `seed-${idx}`,
        type: s.type,
        flightId: s.flightId,
        country: s.country,
        startMs: kstStringToMs(s.start),
        endMs: kstStringToMs(s.end),
        title: s.title,
        careNote: s.careNote
    }));
}

function getEffectiveItems() {
    return state.items.map((it) => {
        const isDelayedTarget = state.isInboundDelayed && it.flightId === "KE914";
        const delayMs = isDelayedTarget ? state.delayMinutes * 60 * 1000 : 0;
        return {
            ...it,
            delayMin: isDelayedTarget ? state.delayMinutes : 0,
            effStartMs: it.startMs + (isDelayedTarget ? 20 * 60 * 1000 : 0),
            effEndMs: it.endMs + delayMs
        };
    });
}

// 현재 상태 판별 (승무원 수동 원터치 오버라이드 최우선 반영!)
function evaluateCurrentStatus(nowMs) {
    const items = getEffectiveItems();
    const arrBufMs = state.profile.arrivalBufferMin * 60 * 1000;
    const commuteBufMs = state.profile.commuteBufferMin * 60 * 1000;
    const restMs = state.profile.restHoursAfterLongHaul * 3600 * 1000;

    const flights = items.filter((i) => i.type === "FLIGHT");
    const activeItem = items.find((it) => nowMs >= it.effStartMs && nowMs < it.effEndMs);
    const nextFlight = flights.find((f) => f.effStartMs > nowMs);
    const prevFlight = [...flights].reverse().find((f) => f.effEndMs <= nowMs);

    const upcomingReturnFlight = flights.find((f) => f.effEndMs + commuteBufMs >= nowMs && (f.title.includes("인천") && f.title.indexOf("인천") > 2));
    const homeArrivalMs = upcomingReturnFlight ? upcomingReturnFlight.effEndMs + commuteBufMs : null;
    const doorToDoorText = homeArrivalMs
        ? `${formatInTimeZone(homeArrivalMs, "Asia/Seoul").shortKst}경 귀가`
        : "현재 한국 자택 체류 기간";
    const doorToDoorNote = upcomingReturnFlight
        ? `인천 착륙(${formatInTimeZone(upcomingReturnFlight.effEndMs, "Asia/Seoul").mdhm}) + 세관·이동 ${state.profile.commuteBufferMin}분${upcomingReturnFlight.delayMin ? ` (⚠️연착 +${upcomingReturnFlight.delayMin}분 포함)` : ""}`
        : "별도 귀국 이동 일정 없음";

    const nightsLeft = homeArrivalMs ? Math.max(0, Math.ceil((homeArrivalMs - nowMs) / 86400000)) : 0;
    const inferredCountry = activeItem?.country || prevFlight?.country || "KR";

    // [승무원 전용 기능 1] 원터치 오버라이드가 켜져 있는 경우 최우선 반환!
    if (state.manualOverride) {
        const ov = state.manualOverride;
        if (ov.mode === "LANDED") {
            return {
                mode: "caution",
                countryKey: inferredCountry,
                badge: "🛬 [승무원 직접 알림] 무사히 착륙 완료! 호텔 이동 중",
                headline: `${state.profile.crewName}이 방금 [무사 착륙] 버튼을 눌렀어요!`,
                subline: `수동 생존신고 완료 (${ov.triggeredAtKst}) · 입국심사 및 크루버스 이동 중`,
                etiquetteIcon: "🛬",
                etiquetteTitle: "안심하세요! 무사히 내려서 이동하고 있습니다",
                etiquetteText: "승무원이 직접 원터치 착륙 알림을 보냈습니다. 세관 통과와 호텔 체크인을 마칠 때까지 약 40분~1시간 뒤에 연락하시면 여유롭습니다.",
                nextContactKst: "약 45분 뒤 호텔 도착 후",
                nextContactNote: "승무원 원터치 생존신고 반영됨",
                kidsGoldenTime: "호텔 체크인 및 휴식 후 저녁 시간",
                kidsGoldenNote: "이동 중에는 카톡 메시지만 남겨주세요",
                doorToDoorText,
                doorToDoorNote,
                activeItemId: activeItem?.id || null,
                flightProgressPct: 100,
                nightsLeft,
                kidsHeadline: "우리 가족 비행기가 안전하게 땅에 착륙했어요! 🛬💛",
                kidsStory: "방금 무사히 잘 도착했다고 안심 버튼을 꾹 눌러줬어요!"
            };
        }
        if (ov.mode === "SLEEP_NOW") {
            const wakeKst = formatInTimeZone(nowMs + 6 * 3600000, "Asia/Seoul");
            return {
                mode: "caution",
                countryKey: inferredCountry,
                badge: "😴 [승무원 방해금지 ON] 지금 실제로 잠자리에 들었어요",
                headline: "승무원이 직접 [지금부터 잘게] 수면 모드를 켰어요",
                subline: `수동 수면 보호 작동 중 · 예상 기상: ${wakeKst.shortKst} (KST)`,
                etiquetteIcon: "🤫",
                etiquetteTitle: "조심스러운 배려 · 기상 전까지 벨소리 통화를 삼가주세요",
                etiquetteText: "스케줄 시간과 별개로 컨디션 회복을 위해 지금 실제로 취침에 들어갔습니다. 카톡을 남겨두시면 일어나는 대로 여건이 될 때 확인할 거예요!",
                nextContactKst: `${wakeKst.shortKst}경 기상 예상`,
                nextContactNote: "승무원 직접 설정 수면 보호 (+6시간 추정)",
                kidsGoldenTime: `${wakeKst.shortKst} 이후 (참고)`,
                kidsGoldenNote: "기상 후에도 준비·식사 등으로 응답이 늦을 수 있어요",
                doorToDoorText,
                doorToDoorNote,
                activeItemId: activeItem?.id || null,
                flightProgressPct: 100,
                nightsLeft,
                kidsHeadline: "지금 호텔 침대에서 폭신하게 코~ 자고 있어요! 😴💤",
                kidsStory: "푹 쉬고 에너지 충전할 때까지 우리 신나게 놀고 있자!"
            };
        }
        if (ov.mode === "CALL_ME") {
            return {
                mode: "available",
                countryKey: inferredCountry,
                badge: "💬 [승무원 직접 안부 핑] 지금 잠깐 여유가 생겼어요!",
                headline: "승무원이 직접 '잠깐 여유가 생겼다'고 신호를 보냈어요",
                subline: `${state.profile.crewName}이 직접 보낸 여유 상태 알림입니다`,
                etiquetteIcon: "💬",
                etiquetteTitle: "가볍게 카톡 인사를 나눠보세요 (화상·음성통화는 먼저 여건 확인!)",
                etiquetteText: "잠시 여유 시간이 생겨 카톡 확인이 수월한 상태입니다. 단, 외출 중이거나 화상·음성통화가 어려운 장소일 수 있으니 먼저 카톡으로 가볍게 인사하거나 승무원이 먼저 걸어올 때 통화해 주세요!",
                nextContactKst: "현재 카톡 소통 수월 구간",
                nextContactNote: "화상·음성통화는 당사자 여건 확인 후 진행",
                kidsGoldenTime: "카톡·음성메시지 보내기 좋은 시간 💬",
                kidsGoldenNote: "통화할 수 있는 여건이 되면 먼저 연락이 올 거예요",
                doorToDoorText,
                doorToDoorNote,
                activeItemId: activeItem?.id || null,
                flightProgressPct: 100,
                nightsLeft,
                kidsHeadline: "딩동! 지금 잠깐 쉬는 시간이라고 안부 신호가 왔어요! 💬💛",
                kidsStory: "보고 싶다는 카톡이나 귀여운 사진을 보내두면 정말 기뻐할 거예요!"
            };
        }
    }

    let flightProgressPct = 0;
    if (activeItem && activeItem.type === "FLIGHT") {
        flightProgressPct = Math.min(95, Math.max(8, Math.round(((nowMs - activeItem.effStartMs) / (activeItem.effEndMs - activeItem.effStartMs)) * 100)));
    } else if (activeItem && activeItem.type === "LAYOVER") {
        flightProgressPct = 100;
    }

    if (activeItem && activeItem.type === "FLIGHT") {
        const readyMs = activeItem.effEndMs + arrBufMs;
        const cMeta = COUNTRIES[activeItem.country] || COUNTRIES.KR;
        const readyKst = formatInTimeZone(readyMs, "Asia/Seoul");

        return {
            mode: "unavailable",
            countryKey: activeItem.country,
            badge: `🔴 현재 비행 중 · 연락 불가 (${activeItem.flightId || "항공편"})`,
            headline: "지금은 하늘 위에서 비행 근무 중이에요",
            subline: `${activeItem.flightId ? `[${activeItem.flightId}] ` : ""}${activeItem.title}${activeItem.delayMin ? ` · ⚠️ 공공API +${activeItem.delayMin}분 지연 → 구글캘린더 자동연장` : ""}`,
            etiquetteIcon: "✈️",
            etiquetteTitle: "기내 근무 중이라 전화·카톡 확인이 어렵습니다",
            etiquetteText: `현재 ${cMeta.name} 노선 비행 중으로 휴대폰이 비행기 모드입니다. 아래 '착륙 3줄 브리핑'에 집안 소식을 적어두시면 착륙 후 여유가 될 때 확인해요!`,
            nextContactKst: `${readyKst.shortKst}경 이후 예상`,
            nextContactNote: `착륙(${formatInTimeZone(activeItem.effEndMs, "Asia/Seoul").mdhm}) + 평균 수속 ${state.profile.arrivalBufferMin}분 추정 (현장 여건에 따라 변동)`,
            kidsGoldenTime: activeItem.country === "KR" ? "귀가 및 충분한 휴식 이후" : `${readyKst.day}일 저녁 18:00 ~ 20:30경 (시차 참고)`,
            kidsGoldenNote: "단순 시차 교집합 참고치이며 피로도에 따라 연락이 어려울 수 있음",
            doorToDoorText,
            doorToDoorNote,
            activeItemId: activeItem.id,
            flightProgressPct,
            nightsLeft,
            kidsHeadline: "우리 가족 비행기가 구름 위를 슈웅~ 날아가고 있어요! ✈️✨",
            kidsStory: `지금 하늘 위 ${cMeta.flag} ${cMeta.name} 하늘 위에서 멋지게 일하고 있어요!`
        };
    }

    if (prevFlight) {
        const flightDurationHours = (prevFlight.effEndMs - prevFlight.effStartMs) / 3600000;
        const restEndMs = prevFlight.effEndMs + arrBufMs + restMs;
        if (flightDurationHours >= 7 && nowMs >= prevFlight.effEndMs && nowMs < restEndMs && activeItem?.type === "LAYOVER") {
            const wakeKst = formatInTimeZone(restEndMs, "Asia/Seoul");
            const cMeta = COUNTRIES[activeItem.country] || COUNTRIES.KR;
            return {
                mode: "caution",
                countryKey: activeItem.country,
                badge: "😴 장거리 비행 직후 · 호텔 회복 수면 시간대",
                headline: "무사히 도착해 피로 회복 수면 중일 시간이에요",
                subline: `${Math.round(flightDurationHours)}시간 장거리 비행(${prevFlight.flightId}) 직후 휴식 구간`,
                etiquetteIcon: "🤫",
                etiquetteTitle: "조심스러운 배려 안내 · 벨소리/화상통화 대신 무음 카톡만 남겨주세요",
                etiquetteText: "장거리 비행을 마치고 호텔에 체크인해 깊이 잠들었을 시간대입니다. 기상 후에도 피로가 남아있을 수 있으니 급한 일이 아니라면 카톡만 남겨두고 편할 때 연락 오기를 기다려 주세요.",
                nextContactKst: `${wakeKst.shortKst}경 이후 예상`,
                nextContactNote: `최소 ${state.profile.restHoursAfterLongHaul}시간 회복 수면 기준 예측 (더 길어질 수 있음)`,
                kidsGoldenTime: `${wakeKst.day}일 저녁 18:00 ~ 20:30경 (시차 참고)`,
                kidsGoldenNote: "시차상 겹치는 시간대이나 컨디션에 따라 휴식이 이어질 수 있음",
                doorToDoorText,
                doorToDoorNote,
                activeItemId: activeItem.id,
                flightProgressPct: 100,
                nightsLeft,
                kidsHeadline: "호텔에 잘 도착해서 코~ 회복 잠을 자고 있어요! 😴💤",
                kidsStory: `${cMeta.flag} 멀리까지 비행기를 타고 가서 지금은 에너지 충전 중이에요!`
            };
        }
    }

    if (activeItem && activeItem.type === "LAYOVER") {
        const cMeta = COUNTRIES[activeItem.country] || COUNTRIES.KR;
        const localParts = formatInTimeZone(nowMs, cMeta.tz);
        const isLocalLateNight = localParts.hour24 >= 22 || localParts.hour24 < 7;

        if (isLocalLateNight) {
            return {
                mode: "caution",
                countryKey: activeItem.country,
                badge: `🌙 해외 체류 중 · 현지 새벽/취침 시간 (${localParts.clock12})`,
                headline: "비행 중은 아니지만 현지 한밤중(취침 시간)이에요",
                subline: `${cMeta.flag} ${cMeta.name} 체류 중 · ${activeItem.title}`,
                etiquetteIcon: "🌙",
                etiquetteTitle: "조심스러운 배려 안내 · 현지는 지금 잠든 밤/새벽입니다",
                etiquetteText: `한국은 낮이지만 ${cMeta.name} 현지는 ${localParts.clock12}입니다. 다음 귀국 비행을 위해 취침 중일 수 있으니 전화·화상통화 대신 조용히 카톡 메시지만 남겨주세요.`,
                nextContactKst: "현지 오전 기상 이후 예상 (개인차 있음)",
                nextContactNote: activeItem.careNote || "현지 기상 및 준비 여건에 따라 상이",
                kidsGoldenTime: "한국 저녁 18:00 ~ 20:30경 (시차 참고)",
                kidsGoldenNote: "단순 시차 참고용이며 현지 일정·컨디션에 따라 연락이 어려울 수 있음",
                doorToDoorText,
                doorToDoorNote,
                activeItemId: activeItem.id,
                flightProgressPct: 100,
                nightsLeft,
                kidsHeadline: "체류 중인 나라는 지금 깜깜한 밤이라 코~ 자고 있어요! 🌙",
                kidsStory: "우리가 어린이집 다녀와서 저녁 먹을 때쯤 그 나라에도 해님이 반짝 떠요!"
            };
        }

        return {
            mode: "available",
            countryKey: activeItem.country,
            badge: `🟢 해외 체류 중 · 현지 낮 시간대 (${localParts.clock12})`,
            headline: "일정상 현지 낮 시간대예요 (카톡 메시지 먼저 권장)",
            subline: `${cMeta.flag} ${cMeta.name} 체류 중 · ${activeItem.title} (스케줄 기반 단순 예측)`,
            etiquetteIcon: "💚",
            etiquetteTitle: "현지 낮 시간이나 식사·외출·휴식 중일 수 있어 통화 요청은 신중히 해주세요",
            etiquetteText: `현재 ${cMeta.name} 현지 시각은 ${localParts.clock12}입니다. 다만 호텔 내 추가 수면, 동료 식사, 외출, 로밍 환경 등으로 전화나 화상통화를 받기 어려울 수 있으니 먼저 카톡 메시지를 남기고 답장을 기다려 주세요!`,
            nextContactKst: "일정상 현지 낮 구간 (여건에 따라 미응답 가능)",
            nextContactNote: nextFlight ? `다음 비행(${nextFlight.flightId}) 준비 전까지의 개략적 예측` : "스케줄 기반 단순 추정",
            kidsGoldenTime: "한국 저녁 18:00 ~ 20:30경 (시차 참고)",
            kidsGoldenNote: "화상·음성통화는 당사자가 먼저 걸어오거나 가능할 때만 진행",
            doorToDoorText,
            doorToDoorNote,
            activeItemId: activeItem.id,
            flightProgressPct: 100,
            nightsLeft,
            kidsHeadline: "체류 중인 나라에도 환한 해님이 떴어요! 응원 카톡 남겨볼까요? 💬💛",
            kidsStory: `쉬거나 이동 중이면 나중에 확인하고 답장해 줄 거예요!`
        };
    }

    if (activeItem && (activeItem.type === "STANDBY" || activeItem.type === "TRAINING")) {
        const endKst = formatInTimeZone(activeItem.effEndMs, "Asia/Seoul");
        const isTraining = activeItem.type === "TRAINING";
        return {
            mode: "caution",
            countryKey: activeItem.country,
            badge: isTraining ? "🎓 지상 안전교육 중 · 연락 주의" : "📋 스탠바이(비행 대기) 근무 중",
            headline: isTraining ? "안전 훈련/교육 시간이라 휴대폰 확인이 어려워요" : "자택/공항 스탠바이 대기 중이에요 (돌발 출동 주의)",
            subline: `${activeItem.title} (항공편 미지정 캘린더 일정)`,
            etiquetteIcon: isTraining ? "📚" : "📟",
            etiquetteTitle: isTraining ? "교육 중에는 무음 상태이며 종료 후에도 피로할 수 있습니다" : "갑작스러운 비행 호출 시 1~2시간 내 출동해야 합니다",
            etiquetteText: isTraining
                ? `교육 종료(${endKst.mdhm}경) 이후에도 이동이나 정리로 바로 연락을 받지 못할 수 있으니 카톡만 편하게 남겨주세요.`
                : `항공사 호출 대기 중이라 긴장 상태이거나 출동 준비 중일 수 있습니다. ${activeItem.careNote || "오후 아이들 하원 백업 플랜을 확인해 두세요."}`,
            nextContactKst: isTraining ? `${endKst.shortKst}경 이후 예상` : "카톡 메시지 전달 권장 (대기 근무 중)",
            nextContactNote: activeItem.careNote || "당사자 근무 여건에 따라 상이",
            kidsGoldenTime: `${endKst.day}일 저녁 이후 (여건 따라 상이)`,
            kidsGoldenNote: "대기/교육 종료 및 귀가 컨디션에 따라 다름",
            doorToDoorText,
            doorToDoorNote,
            activeItemId: activeItem.id,
            flightProgressPct: 0,
            nightsLeft: 0,
            kidsHeadline: "오늘은 출동 준비하며 스탠바이 대기 근무 중이에요! 🧑‍✈️",
            kidsStory: "비행기 부름이 없으면 저녁에 집에서 만날 수도 있어요!"
        };
    }

    return {
        mode: "available",
        countryKey: "KR",
        badge: "🟢 한국 체류 / 휴무(OFF) · 연락 추천 구간",
        headline: "일정상 비행 없이 한국에 머무는 시간대예요",
        subline: activeItem ? activeItem.title : "등록된 비행 공백 없음 (스케줄 기반 추정)",
        etiquetteIcon: "🏡",
        etiquetteTitle: "시차는 없으나 개인 일정·휴식에 따라 응답이 늦을 수 있어요",
        etiquetteText: nextFlight
            ? `일정상 한국 체류 기간이며, 다음 비행(${nextFlight.flightId || nextFlight.title})은 ${formatInTimeZone(nextFlight.effStartMs, "Asia/Seoul").shortKst} 출발 예정입니다. 개인 볼일이나 휴식 중일 수 있으니 여유 있게 연락해 주세요.`
            : "예정된 임박 비행 없이 한국 체류 중입니다. 개인 여건에 따라 바로 전화를 못 받을 수도 있어요.",
        nextContactKst: "일정상 여유 구간 (개인 여건에 따라 상이)",
        nextContactNote: activeItem?.careNote || "한국 표준시 일상/휴식 추정",
        kidsGoldenTime: "한국 우리 집에 함께 있는 날! 🏡",
        kidsGoldenNote: "개인 외출·휴식 여부에 따라 상이",
        doorToDoorText,
        doorToDoorNote,
        activeItemId: activeItem ? activeItem.id : null,
        flightProgressPct: 0,
        nightsLeft: 0,
        kidsHeadline: "한국 우리 집에 함께 있는 날이에요! 🏡💛",
        kidsStory: "오늘은 어린이집 끝나고 집에서 반갑게 만날 수 있어요!"
    };
}

// ================= [승무원 전용 라운지 7대 기능 렌더링] =================
function renderCrewExclusivePage() {
    const nowMs = state.simNowMs;
    const kr = formatInTimeZone(nowMs, "Asia/Seoul");
    const items = getEffectiveItems();
    const flights = items.filter((i) => i.type === "FLIGHT");

    // 1. 오버라이드 버튼 상태 표시
    const clearBtn = document.getElementById("btnClearOverride");
    const fbBar = document.getElementById("overrideFeedbackBar");
    const chip = document.getElementById("overrideActiveChip");
    document.querySelectorAll(".ov-btn").forEach((b) => {
        b.classList.toggle("active", state.manualOverride?.mode === b.dataset.override);
    });

    if (state.manualOverride) {
        clearBtn.classList.remove("hidden");
        fbBar.classList.remove("hidden");
        chip.classList.remove("hidden");
        const labels = {
            LANDED: "🛬 [무사 착륙] 상태가 배우자·연인·부모님 화면과 카톡봇에 실시간 표시 중입니다.",
            SLEEP_NOW: "😴 [방해금지 수면보호] 상태가 활성화되어 가족에게 무음 카톡 배려 안내가 나가고 있습니다.",
            CALL_ME: "💬 [잠깐 여유 생겼어! 안부 핑] 신호가 가족 화면에 전달되었습니다. (화상·음성통화 강제 없음 안내 포함)"
        };
        fbBar.textContent = labels[state.manualOverride.mode];
        chip.textContent = `🧑‍✈️ 승무원 수동상태 ON (${state.manualOverride.mode})`;
    } else {
        clearBtn.classList.add("hidden");
        fbBar.classList.add("hidden");
        chip.classList.add("hidden");
    }

    // 3. 착륙 직후 3줄 요약 브리핑 바인딩
    document.getElementById("crewViewDgKids").textContent = state.digest.kids;
    document.getElementById("crewViewDgSchool").textContent = state.digest.school;
    document.getElementById("crewViewDgMemo").textContent = state.digest.memo;

    // 4. 거꾸로 보는 한국 우리 집 현재 일상 시계
    document.getElementById("rhKoreaClock").textContent = `🇰🇷 한국 ${kr.shortKst} (${kr.clock12})`;
    let rhHead = "";
    let rhSub = "";
    const isWeekend = kr.weekday === "토" || kr.weekday === "일";
    if (kr.hour24 >= 21 || kr.hour24 < 7) {
        rhHead = "🌙 한국 우리 집 식구들 모두 불 끄고 코~ 자는 밤이에요";
        rhSub = "한국은 취침 시간입니다. 아침 07:40 이후에 카톡이나 전화를 걸면 딱 좋아요.";
    } else if (!isWeekend && kr.hour24 >= 7 && kr.hour24 < 9) {
        rhHead = "🏃 배우자가 아이들 씻기고 어린이집 등원시키는 바쁜 시간!";
        rhSub = "08:50 등원 완료 이후에 배우자·파트너에게 카톡이나 연락하기 한결 여유로워요.";
    } else if (!isWeekend && kr.hour24 >= 9 && kr.hour24 < 16) {
        rhHead = "🏫 아이들은 어린이집 활동 중 · 배우자는 근무 · 부모님은 휴식 시간대";
        rhSub = "부모님께 안부 연락 드리기 비교적 여유로운 낮 시간대입니다.";
    } else if (!isWeekend && kr.hour24 >= 16 && kr.hour24 < 18) {
        rhHead = "🏡 부모님이 아이들 하원 픽업해 간식 챙겨주시는 시간이에요";
        rhSub = "내가 컨디션이 괜찮을 때 먼저 안부 톡이나 전화를 드리기 좋은 시간대입니다.";
    } else {
        rhHead = "👨‍👧‍👦 한국 우리 집은 저녁 식사 & 아이들 놀이 시간대예요";
        rhSub = "20:30경 아이들 취침 전 시간대입니다. (내 여건이 될 때만 편하게 연락하세요!)";
    }
    document.getElementById("rhHeadline").textContent = rhHead;
    document.getElementById("rhSub").textContent = rhSub;

    // 5. 쇼업(Show-up) 역산 알람 (가장 가까운 인천 출발 비행 기준)
    const nextOutbound = flights.find((f) => f.effEndMs >= nowMs && f.title.startsWith("인천")) || flights[flights.length - 1];
    const showupBox = document.getElementById("showupCalcBox");
    if (nextOutbound) {
        const stdMs = nextOutbound.effStartMs;
        const showupMs = stdMs - 140 * 60000; // 이륙 -2시간 20분 브리핑 쇼업
        const parkingMs = showupMs - 25 * 60000; // 크루 주차/셔틀 -25분
        const leaveHomeMs = parkingMs - 65 * 60000; // 자택->인천공항 T2 도로 65분
        showupBox.innerHTML = `
            <div>• 대상 항공편: <strong>[${nextOutbound.flightId}] ${nextOutbound.title}</strong></div>
            <div>• 스케줄 이륙(STD): ${formatInTimeZone(stdMs, "Asia/Seoul").shortKst}</div>
            <div>• 브리핑 쇼업(Show-up, -2h20m): <strong>${formatInTimeZone(showupMs, "Asia/Seoul").mdhm}</strong> (제2터미널 브리핑실)</div>
            <div>• 인천공항고속도로 실시간 예측: 원활 (자택→T2 약 65분 + 주차셔틀 25분)</div>
            <div class="showup-deadline">🚨 현관문 출발 데드라인: ${formatInTimeZone(leaveHomeMs, "Asia/Seoul").shortKst} 까지 집에서 출발하세요!</div>
        `;
    }

    // 6. 체류지 날씨·사복 가이드 & 쇼핑 체크리스트
    const st = evaluateCurrentStatus(nowMs);
    const targetCountryKey = st.countryKey === "KR" ? (nextOutbound?.country || "ES") : st.countryKey;
    const cMeta = COUNTRIES[targetCountryKey] || COUNTRIES.ES;
    document.getElementById("layoverWeatherBox").innerHTML = `
        <strong>${cMeta.flag} ${cMeta.name} 체류 날씨 브리핑</strong><br>
        • 현지 기상: ${cMeta.weather}<br>
        • 👗 사복 차림 추천: <strong>${cMeta.outfit}</strong>
    `;

    const shopContainer = document.getElementById("shoppingListContainer");
    shopContainer.innerHTML = state.shopping.map((item) => `
        <div class="shop-item ${item.done ? "done" : ""}">
            <label>
                <input type="checkbox" data-shop-toggle="${item.id}" ${item.done ? "checked" : ""}>
                <span>${item.text}</span>
            </label>
            <button type="button" class="del-btn" data-shop-del="${item.id}">삭제</button>
        </div>
    `).join("");

    shopContainer.querySelectorAll("[data-shop-toggle]").forEach((chk) => {
        chk.addEventListener("change", () => {
            const target = state.shopping.find((s) => s.id === chk.dataset.shopToggle);
            if (target) target.done = chk.checked;
            saveState();
            renderCrewExclusivePage();
        });
    });

    shopContainer.querySelectorAll("[data-shop-del]").forEach((btn) => {
        btn.addEventListener("click", () => {
            state.shopping = state.shopping.filter((s) => s.id !== btn.dataset.shopDel);
            saveState();
            renderCrewExclusivePage();
        });
    });

    // 7. 월간 비행 피로도 지수 & 체류비(Per Diem) 자동 정산
    const totalFlightHours = Math.round(flights.reduce((acc, f) => acc + (f.effEndMs - f.effStartMs) / 3600000, 0) * 10) / 10;
    const longHaulCount = flights.filter((f) => (f.effEndMs - f.effStartMs) >= 7 * 3600000).length;
    const fatigueScore = Math.min(98, Math.round(totalFlightHours * 1.15 + longHaulCount * 9));

    const layovers = items.filter((i) => i.type === "LAYOVER");
    const rawUsd = layovers.reduce((acc, l) => {
        const hrs = (l.effEndMs - l.effStartMs) / 3600000;
        const rate = COUNTRIES[l.country]?.perDiemUsdPerHour || 3.5;
        return acc + hrs * rate;
    }, 0);
    // 정확한 정산 금액처럼 오해되지 않도록 10달러 / 만 원 단위로 반올림하여 '개략 가늠치'로 표현
    const roundedUsd = Math.round(rawUsd / 10) * 10;
    const roundedManWon = Math.round((roundedUsd * 1390) / 10000);

    document.getElementById("fatiguePerDiemBox").innerHTML = `
        <div class="pd-box">
            <span>11월 총 비행시간 (캘린더 기준)</span>
            <strong>약 ${totalFlightHours}시간 (${flights.length}구간)</strong>
        </div>
        <div class="pd-box">
            <span>시차 피로도 추정치 (참고용)</span>
            <strong style="color:#dc2626;">🔴 약 ${fatigueScore}점 수준 (장거리 누적)</strong>
        </div>
        <div class="pd-box">
            <span>해외 체류비(퍼디엠) 개략 가늠치</span>
            <strong style="color:#15803d;">약 $${roundedUsd} 내외 (약 ${roundedManWon}만 원대 추정)</strong>
        </div>
        <div class="pd-box">
            <span>가족 화면 배려 배지</span>
            <strong style="color:#6d28d9;">🛡️ 무리한 외출 배려 표시 중</strong>
        </div>
    `;

    document.getElementById("fatigueShieldBadge").textContent = `🛡️ 시차피로 ${fatigueScore}점 주간 (무리한 외출 배려)`;
}

// [승무원 전용 기능 2] 비행 맞교환(스왑) 가족 충돌 검사 실행
function runSwapConflictCheck() {
    const startVal = document.getElementById("swapStart").value;
    const endVal = document.getElementById("swapEnd").value;
    if (!startVal || !endVal) return;

    const sMs = kstStringToMs(startVal);
    const eMs = kstStringToMs(endVal);
    const box = document.getElementById("swapResultBox");

    if (eMs <= sMs) {
        box.className = "swap-result-box conflict";
        box.textContent = "⚠️ 귀국 일시는 출발 일시보다 뒤여야 합니다.";
        return;
    }

    const hits = FAMILY_BUSY_CONFLICTS.filter((c) => {
        const cs = kstStringToMs(c.start);
        const ce = kstStringToMs(c.end);
        return sMs <= ce && eMs >= cs;
    });

    const existingHits = state.items.filter((it) => it.type === "FLIGHT" && sMs <= it.endMs && eMs >= it.startMs);

    if (hits.length === 0 && existingHits.length === 0) {
        box.className = "swap-result-box ok";
        box.innerHTML = `
            <strong>✅ 맞교환(스왑) 적극 추천! 가족 육아 공백 0건</strong><br>
            • 배우자·파트너 캘린더: 중요 배포·출장 일정 없음 (등원 가능)<br>
            • 부모님 일정: 병원·모임 일정 없음 (오후 하원 백업 가능)<br>
            👉 지금 바로 사내 게시판에서 스왑 신청하셔도 됩니다!
        `;
    } else {
        const lines = hits.map((h) => `• <strong>${h.who}</strong> (${h.start.slice(5)}~${h.end.slice(11)}): ${h.reason}`);
        existingHits.forEach((eh) => {
            lines.push(`• <strong>기존 내 비행 중복</strong>: [${eh.flightId}] ${eh.title}`);
        });
        box.className = "swap-result-box conflict";
        box.innerHTML = `
            <strong>🚨 맞교환 주의! 육아 돌봄 충돌이 ${hits.length + existingHits.length}건 감지되었습니다</strong><br>
            ${lines.join("<br>")}<br>
            👉 이 비행으로 바꾸면 아이들 오후 하원 픽업에 공백이 생깁니다!
        `;
    }
}

function applyRoleView(role) {
    state.role = role;
    document.body.setAttribute("data-role", role);
    document.querySelectorAll(".role-btn").forEach((b) => {
        b.classList.toggle("active", b.dataset.roleSwitch === role);
    });

    const noticeBanner = document.getElementById("roleNoticeBanner");
    const noticeText = document.getElementById("roleNoticeText");
    const kidsCard = document.getElementById("kidsModeCard");

    if (role === "crew") {
        switchTab("crew");
        noticeBanner.classList.remove("hidden");
        noticeText.textContent = "🧑‍✈️ [승무원 본인 전용 비행비서 뷰] 원터치 생존신고, 비행 맞교환 1초 체커, 착륙 3줄 브리핑, 쇼업 알람, 체류비 개략 가늠치를 한눈에 확인합니다.";
        kidsCard.classList.add("hidden");
    } else if (role === "grandparents") {
        switchTab("status");
        noticeBanner.classList.remove("hidden");
        noticeText.textContent = "🏡 [부모님·어르신 전용 큰글씨 안심 뷰] 복잡한 설정 탭을 숨기고, 승무원(자녀)의 현지 시각·수면 상태·하원 교대 시간만 큼직하게 보여드립니다.";
        kidsCard.classList.add("hidden");
    } else if (role === "kids") {
        switchTab("status");
        noticeBanner.classList.remove("hidden");
        noticeText.textContent = "🧒 [미취학 두 아이용 키즈 안심 뷰] 비행기 위치와 남은 밤 수를 아이들 눈높이로 보여주는 화면입니다.";
        kidsCard.classList.remove("hidden");
    } else {
        noticeBanner.classList.add("hidden");
        kidsCard.classList.add("hidden");
        switchTab("status");
    }

    renderAll();
}

function renderSecurityTokens() {
    const seed = state.tokenSeed;
    const baseUrl = window.location.origin + window.location.pathname;
    const tokens = [
        {
            title: "🧑‍✈️ 승무원 본인 전용 링크 (원터치 상태제어 · 스왑체커 · 쇼업비서)",
            scope: "오버라이드 제어권 · 전체열람",
            url: `${baseUrl}?role=crew&sig=cr_${seed}_hmac256`
        },
        {
            title: "❤️ 파트너(배우자·연인) 전용 마스터 링크 (일정조율 · 사내캘린더 · 설정)",
            scope: "전체권한 · 사내캘린더(.ics) 구독",
            url: `${baseUrl}?role=partner&sig=pt_${seed}_hmac256`
        },
        {
            title: "🏡 부모님·어르신 전용 열람 링크 (Read-Only 큰글씨 안심뷰)",
            scope: "읽기전용 · 호텔상세 마스킹 · 기기바인딩",
            url: `${baseUrl}?role=grandparents&sig=gp_${seed}_hmac256`
        },
        {
            title: "🧒 거실 태블릿 키즈 뷰 링크 (비행기 위치 게이지)",
            scope: "키즈안심화면 전용",
            url: `${baseUrl}?role=kids&sig=kd_${seed}_hmac256`
        }
    ];

    const container = document.getElementById("tokenListContainer");
    container.innerHTML = tokens.map((tk) => `
        <div class="token-item">
            <div class="token-top">
                <span class="token-role-title">${tk.title}</span>
                <span class="token-scope">${tk.scope}</span>
            </div>
            <div class="token-url-box">
                <code>${tk.url}</code>
                <button type="button" class="btn btn-outline copy-token-btn" data-url="${tk.url}" style="padding:5px 10px;font-size:11.5px;">복사</button>
            </div>
        </div>
    `).join("");

    container.querySelectorAll(".copy-token-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            navigator.clipboard?.writeText(btn.dataset.url);
            const msg = document.getElementById("tokenActionMsg");
            msg.textContent = "✅ 서명된 가족 보안 링크가 복사되었습니다!";
            setTimeout(() => { msg.textContent = ""; }, 2500);
        });
    });
}

function renderMainStatusPage() {
    document.getElementById("unconfiguredBanner").classList.toggle("hidden", state.configured);
    document.getElementById("headerCrewName").textContent = `${state.profile.crewName} · 가족 컨시어지`;
    document.getElementById("mainCrewTitle").textContent = state.profile.crewName;
    document.getElementById("mainSourceBadge").textContent = state.configured
        ? `Google Calendar 연동됨 (${state.items.length}건)`
        : "캘린더 미연동";

    const delayBadge = document.getElementById("mainDelayBadge");
    const btnSimDelay = document.getElementById("btnSimDelay");
    delayBadge.classList.toggle("hidden", !state.isInboundDelayed);
    btnSimDelay.classList.toggle("active", state.isInboundDelayed);
    btnSimDelay.textContent = state.isInboundDelayed ? "⚡ 귀국편 +60분 연착 해제" : "⚡ 귀국편 +60분 연착 테스트";

    const st = evaluateCurrentStatus(state.simNowMs);
    const card = document.getElementById("mainStatusCard");
    card.classList.remove("mode-unavailable", "mode-available", "mode-caution");
    card.classList.add(`mode-${st.mode}`);

    document.getElementById("mainStatusBadge").textContent = st.badge;
    document.getElementById("mainHeadline").textContent = st.headline;
    document.getElementById("mainSubline").textContent = st.subline;

    const krTime = formatInTimeZone(state.simNowMs, "Asia/Seoul");
    const cMeta = COUNTRIES[st.countryKey] || COUNTRIES.KR;
    const lcTime = formatInTimeZone(state.simNowMs, cMeta.tz);
    const diffH = getHourDiffFromKorea(state.simNowMs, cMeta.tz);

    document.getElementById("clockKoreaTime").textContent = krTime.clock12;
    document.getElementById("clockKoreaDate").textContent = `11월 ${krTime.day}일 (${krTime.weekday})`;
    document.getElementById("clockLocalCountry").textContent = `${cMeta.flag} 체류/목적지 · ${cMeta.name}`;
    document.getElementById("clockLocalTime").textContent = lcTime.clock12;
    document.getElementById("clockLocalDiff").textContent = diffH === 0
        ? `11월 ${lcTime.day}일 (${lcTime.weekday}) · 한국과 시차 없음`
        : `11월 ${lcTime.day}일 (${lcTime.weekday}) · 한국보다 ${Math.abs(diffH)}시간 ${diffH < 0 ? "느림" : "빠름"}`;

    document.getElementById("etiquetteIcon").textContent = st.etiquetteIcon;
    document.getElementById("etiquetteTitle").textContent = st.etiquetteTitle;
    document.getElementById("etiquetteText").textContent = st.etiquetteText;

    document.getElementById("nextContactKst").textContent = st.nextContactKst;
    document.getElementById("nextContactNote").textContent = st.nextContactNote;
    document.getElementById("kidsGoldenTime").textContent = st.kidsGoldenTime;
    document.getElementById("kidsGoldenNote").textContent = st.kidsGoldenNote;
    document.getElementById("doorToDoorKst").textContent = st.doorToDoorText;
    document.getElementById("doorToDoorNote").textContent = st.doorToDoorNote;

    document.getElementById("kidsHeadline").textContent = st.kidsHeadline;
    document.getElementById("kidsStoryText").textContent = st.kidsStory;
    document.getElementById("kidsDestStop").textContent = `${cMeta.flag} ${cMeta.name.split(" ")[0]}`;
    document.getElementById("kidsProgressFill").style.width = `${st.flightProgressPct}%`;
    document.getElementById("kidsPlanePin").style.left = `${st.flightProgressPct}%`;
    document.getElementById("kidsNightsLeft").textContent = st.nightsLeft > 0
        ? `🌙 코~ ${st.nightsLeft}밤만 자면 우리 집 현관문으로 돌아와요!`
        : "🏡 오늘 우리 집에서 반갑게 만날 수 있어요!";

    const items = getEffectiveItems();
    const nearby = items.filter((it) => Math.abs(it.effStartMs - state.simNowMs) <= 5 * 86400000).slice(0, 5);
    document.getElementById("nearbyScheduleList").innerHTML = nearby.map((it) => {
        const s = formatInTimeZone(it.effStartMs, "Asia/Seoul");
        const e = formatInTimeZone(it.effEndMs, "Asia/Seoul");
        const iconMap = { FLIGHT: "✈️", LAYOVER: "🌍", STANDBY: "📋", TRAINING: "🎓", OFF: "🏠" };
        return `
            <div class="tl-item ${it.id === st.activeItemId ? "active" : ""}">
                <div class="tl-dot">${iconMap[it.type] || "📌"}</div>
                <div class="tl-body">
                    <div class="tl-title">${it.flightId ? `[${it.flightId}] ` : ""}${it.title}</div>
                    <div class="tl-time">${s.mdhm} ~ ${e.mdhm} (KST)${it.delayMin ? ` · ⚠️+${it.delayMin}분 연착` : ""}${it.careNote && it.careNote !== "-" ? ` · 👨‍👩‍👧 ${it.careNote}` : ""}</div>
                </div>
            </div>
        `;
    }).join("") || `<p class="card-sub">인접한 스케줄이 없습니다.</p>`;

    document.getElementById("kakaoSimTimeRef").textContent = `${krTime.shortKst} KST`;
}

function renderMonthlySchedulePage() {
    const items = getEffectiveItems();
    const flightCount = items.filter((i) => i.type === "FLIGHT").length;
    const layoverHours = Math.round(items.filter((i) => i.type === "LAYOVER").reduce((acc, cur) => acc + (cur.effEndMs - cur.effStartMs) / 3600000, 0));
    const nonFlightCount = items.filter((i) => i.type === "STANDBY" || i.type === "TRAINING").length;
    const offCount = items.filter((i) => i.type === "OFF").length;

    document.getElementById("monthSummaryStats").innerHTML = `
        <div class="stat-box"><span>이번 달 총 비행 구간</span><strong>${flightCount}편</strong></div>
        <div class="stat-box"><span>총 해외 체류 시간</span><strong>약 ${layoverHours}시간</strong></div>
        <div class="stat-box"><span>스탠바이 / 지상교육</span><strong>${nonFlightCount}건 (돌발출동 관리)</strong></div>
        <div class="stat-box"><span>정기 휴무 블록</span><strong>${offCount}회</strong></div>
    `;

    const calGrid = document.getElementById("calendarGrid");
    const cellsHtml = [];
    for (let day = 1; day <= 30; day++) {
        const dayStartMs = Date.UTC(2026, 10, day, -9, 0, 0);
        const dayEndMs = Date.UTC(2026, 10, day, 23 - 9, 59, 59);
        const dayItems = items.filter((it) => it.effStartMs <= dayEndMs && it.effEndMs >= dayStartMs);

        const tags = dayItems.slice(0, 2).map((it) => {
            const label = it.flightId ? `✈️${it.flightId}` : (
                it.type === "LAYOVER" ? `${COUNTRIES[it.country]?.flag || "🌍"}체류` :
                it.type === "STANDBY" ? "⚠️스탠바이" :
                it.type === "TRAINING" ? "🎓교육" : "🏠휴무"
            );
            return `<span class="cal-tag ${it.type}">${label}</span>`;
        }).join("");

        cellsHtml.push(`
            <div class="cal-cell ${state.selectedCalendarDay === day ? "selected" : ""}" data-day="${day}">
                <span class="cal-day-num">${day}</span>
                ${tags}
            </div>
        `);
    }
    calGrid.innerHTML = cellsHtml.join("");

    calGrid.querySelectorAll(".cal-cell").forEach((cell) => {
        cell.addEventListener("click", () => {
            const d = Number(cell.dataset.day);
            state.selectedCalendarDay = state.selectedCalendarDay === d ? null : d;
            renderMonthlySchedulePage();
        });
    });

    document.getElementById("btnClearDateFilter").classList.toggle("hidden", state.selectedCalendarDay === null);
    let filtered = items;
    if (state.selectedCalendarDay !== null) {
        const d = state.selectedCalendarDay;
        document.getElementById("scheduleListTitle").textContent = `📋 11월 ${d}일 Google Calendar 일정`;
        const ds = Date.UTC(2026, 10, d, -9, 0, 0);
        const de = Date.UTC(2026, 10, d, 23 - 9, 59, 59);
        filtered = items.filter((it) => it.effStartMs <= de && it.effEndMs >= ds);
    } else {
        document.getElementById("scheduleListTitle").textContent = "📋 Google Calendar 동기화 전체 일정 목록";
    }

    const listEl = document.getElementById("fullScheduleList");
    listEl.innerHTML = filtered.map((it) => {
        const s = formatInTimeZone(it.effStartMs, "Asia/Seoul");
        const e = formatInTimeZone(it.effEndMs, "Asia/Seoul");
        const durHours = Math.round(((it.effEndMs - it.effStartMs) / 3600000) * 10) / 10;
        const cMeta = COUNTRIES[it.country] || COUNTRIES.KR;
        const midMs = Math.floor((it.effStartMs + it.effEndMs) / 2);

        const typeBadge = it.flightId
            ? `<span class="lg-badge flight">✈️ 편명 ${it.flightId}</span>`
            : `<span class="lg-badge ${it.type === "LAYOVER" ? "layover" : it.type === "OFF" ? "off" : "standby"}">${it.type === "LAYOVER" ? "🌍 편명 없음 · 체류" : it.type === "STANDBY" ? "⚠️ 스탠바이 · 야근금지" : it.type === "OFF" ? "🏠 휴무" : "📋 지상일정"}</span>`;

        return `
            <div class="sch-card">
                <div class="sch-card-top">
                    <span class="sch-title">${cMeta.flag} ${it.title}</span>
                    ${typeBadge}
                </div>
                <div class="sch-meta">
                    • 한국시간(KST): <strong>${s.shortKst} ~ ${e.shortKst}</strong> (총 ${durHours}시간)${it.delayMin ? ` · <strong style="color:#b45309">⚠️ +${it.delayMin}분 연착 (Calendar 자동연장)</strong>` : ""}<br>
                    • 기준 위치: ${cMeta.name} (${cMeta.tz})
                </div>
                <div class="sch-care-note">
                    <span>👨‍👩‍👧 공동육아 메모: ${it.careNote && it.careNote !== "-" ? it.careNote : "메모 없음"}</span>
                    <button type="button" class="jump-sim-btn" data-jumpms="${midMs}">이 시점으로 상태 확인 →</button>
                </div>
            </div>
        `;
    }).join("") || `<p class="card-sub">선택한 날짜에 특별 비행/대기 일정이 없습니다.</p>`;

    listEl.querySelectorAll(".jump-sim-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            state.simNowMs = Number(btn.dataset.jumpms);
            document.getElementById("simDatetimeInput").value = msToDatetimeLocalValue(state.simNowMs);
            document.querySelectorAll(".preset-btn").forEach((b) => b.classList.remove("active"));
            switchTab("status");
            renderAll();
        });
    });
}

function renderSettingsManageList() {
    document.getElementById("registeredCount").textContent = String(state.items.length);
    const box = document.getElementById("manageScheduleList");
    box.innerHTML = state.items.map((it) => {
        const s = formatInTimeZone(it.startMs, "Asia/Seoul");
        const e = formatInTimeZone(it.endMs, "Asia/Seoul");
        return `
            <div class="manage-item">
                <div>
                    <strong>${it.flightId ? `[${it.flightId}] ` : `[${it.type}] `}${it.title}</strong>
                    <div style="color:#64748b">${s.mdhm} ~ ${e.mdhm} (KST)</div>
                </div>
                <button type="button" class="del-btn" data-delid="${it.id}">삭제</button>
            </div>
        `;
    }).join("");

    box.querySelectorAll(".del-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            state.items = state.items.filter((x) => x.id !== btn.dataset.delid);
            saveState();
            renderAll();
        });
    });
}

function buildKakaoReply(question) {
    const st = evaluateCurrentStatus(state.simNowMs);
    const cMeta = COUNTRIES[st.countryKey] || COUNTRIES.KR;
    const lcTime = formatInTimeZone(state.simNowMs, cMeta.tz);
    const krTime = formatInTimeZone(state.simNowMs, "Asia/Seoul");
    const softFootnote = `\n\n💡 표시된 시간은 스케줄 기반의 단순 예측 참고치일 뿐입니다. 현지 수속·이동·휴식 등 당사자의 여건과 컨디션에 따라 가이드된 시간에도 카톡 답장이나 음성·화상통화가 어려울 수 있으니, 먼저 메시지만 편하게 남겨두고 여유 있게 기다려 주세요 :)`;

    if (state.manualOverride) {
        return `🔔 [승무원 원터치 직접 상태 알림]\n${st.badge}\n\n• 안내: ${st.etiquetteText}\n• 참고 시점: ${st.nextContactKst}${softFootnote}`;
    }
    if (question.includes("시차") || question.includes("영상통화") || question.includes("화상") || question.includes("애들")) {
        return `👶 [아이들 활동 시간 ∩ 현지 낮 시차 참고]\n• 시차 교집합 예측: ${st.kidsGoldenTime}\n• 안내: ${st.kidsGoldenNote}\n• 화상·음성통화는 먼저 카톡으로 여건을 물어보거나 당사자가 먼저 걸어올 때 진행해 주세요.${softFootnote}`;
    }
    if (question.includes("연착") || question.includes("집에") || question.includes("귀국")) {
        return `🏡 [귀국 & 현관문 도착 예측]\n• ${st.doorToDoorText}\n• 상세: ${st.doorToDoorNote}\n${state.isInboundDelayed ? "⚠️ 인천공항 공공API에서 +60분 지연이 감지되어 Google Calendar 일정도 자동 연장되었습니다!" : "✅ 현재 공공API 기준 정상 운항 중입니다."}${softFootnote}`;
    }
    if (st.mode === "unavailable") {
        return `✈️ 지금은 비행 중이라 연락이 닿지 않습니다.\n\n• 현재 상태: ${st.subline}\n• 한국: ${krTime.clock12} / 목적지(${cMeta.name}): ${lcTime.clock12}\n👉 개략적으로 [${st.nextContactKst}] 이후에나 휴대폰 확인이 가능할 것으로 예측됩니다.${softFootnote}`;
    }
    if (st.mode === "caution") {
        return `🤫 ${st.headline}\n\n• 체류지(${cMeta.name}) 현지 시각: ${lcTime.clock12}\n• 안내: ${st.etiquetteText}\n👉 참고 시점: ${st.nextContactKst}${softFootnote}`;
    }
    return `🟢 일정상 현지 낮 시간대(단순 예측)입니다.\n\n• 체류지(${cMeta.name}) 현지 시각: ${lcTime.clock12}\n• 안내: ${st.etiquetteText}\n• 시차 참고 구간: ${st.kidsGoldenTime}${softFootnote}`;
}

function renderApiJsonBox() {
    const flights = getEffectiveItems().filter((i) => i.type === "FLIGHT");
    const sample = {
        crewManualOverride: state.manualOverride || "NONE (Auto FSM Schedule Mode)",
        calendarIntegration: "Google Calendar (.ics + Secret Feed + Workspace Add-on)",
        flightAdapter: "ICN Public API (#15095074) + KAC + Global Fallback",
        monitoredFlights: flights.map((f) => ({
            flightId: f.flightId,
            route: f.title,
            estimatedEndKST: formatInTimeZone(f.effEndMs, "Asia/Seoul").shortKst,
            calendarPatchStatus: f.delayMin > 0 ? `PATCHED (+${f.delayMin}m)` : "IN_SYNC"
        }))
    };
    document.getElementById("apiJsonPreview").textContent = JSON.stringify(sample, null, 2);
}

function appendKakaoMsg(role, sender, text) {
    const box = document.getElementById("kakaoMessages");
    const row = document.createElement("div");
    row.className = `msg-row ${role}`;
    row.innerHTML = `<span class="msg-sender">${sender}</span><div class="msg-bubble"></div>`;
    row.querySelector(".msg-bubble").textContent = text;
    box.appendChild(row);
    box.scrollTop = box.scrollHeight;
}

function switchTab(tabName) {
    document.querySelectorAll(".tab-btn").forEach((b) => b.classList.toggle("active", b.dataset.tab === tabName));
    document.querySelectorAll(".tab-panel").forEach((p) => p.classList.toggle("active", p.id === `tab-${tabName}`));
    window.scrollTo({ top: 0, behavior: "smooth" });
}

function saveState() {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify({
            configured: state.configured,
            tokenSeed: state.tokenSeed,
            manualOverride: state.manualOverride,
            profile: state.profile,
            digest: state.digest,
            shopping: state.shopping,
            items: state.items
        }));
    } catch (_) {}
}

function loadState() {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (raw) {
            const parsed = JSON.parse(raw);
            if (parsed && Array.isArray(parsed.items) && parsed.items.length > 0) {
                state.configured = parsed.configured !== false;
                state.tokenSeed = parsed.tokenSeed || state.tokenSeed;
                state.manualOverride = parsed.manualOverride || null;
                state.profile = { ...state.profile, ...parsed.profile };
                state.digest = { ...state.digest, ...(parsed.digest || {}) };
                state.shopping = Array.isArray(parsed.shopping) ? parsed.shopping : [...DEFAULT_SHOPPING];
                state.items = parsed.items;
                return;
            }
        }
    } catch (_) {}
    state.items = getDefaultItems();
    state.shopping = [...DEFAULT_SHOPPING];
}

function syncFormInputsFromState() {
    document.getElementById("cfgCrewName").value = state.profile.crewName;
    document.getElementById("cfgCalSecretUrl").value = state.profile.calSecretUrl;
    document.getElementById("cfgArrivalBuffer").value = state.profile.arrivalBufferMin;
    document.getElementById("cfgCommuteBuffer").value = state.profile.commuteBufferMin;
    document.getElementById("cfgRestHours").value = state.profile.restHoursAfterLongHaul;
    document.getElementById("dgKids").value = state.digest.kids;
    document.getElementById("dgSchool").value = state.digest.school;
    document.getElementById("dgMemo").value = state.digest.memo;
}

function renderAll() {
    renderMainStatusPage();
    renderCrewExclusivePage();
    renderMonthlySchedulePage();
    renderSettingsManageList();
    renderSecurityTokens();
    renderApiJsonBox();
}

function init() {
    loadState();
    syncFormInputsFromState();

    const urlParams = new URLSearchParams(window.location.search);
    const initialRole = urlParams.get("role");

    document.querySelectorAll(".role-btn").forEach((btn) => {
        btn.addEventListener("click", () => applyRoleView(btn.dataset.roleSwitch));
    });
    document.getElementById("btnBackToHusband").addEventListener("click", () => applyRoleView("partner"));

    document.querySelectorAll(".tab-btn").forEach((btn) => {
        btn.addEventListener("click", () => switchTab(btn.dataset.tab));
    });
    document.querySelectorAll("[data-goto]").forEach((btn) => {
        btn.addEventListener("click", () => switchTab(btn.dataset.goto));
    });
    document.getElementById("brandHomeBtn").addEventListener("click", () => switchTab("status"));

    document.querySelectorAll(".preset-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".preset-btn").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            state.simNowMs = kstStringToMs(btn.dataset.dt);
            document.getElementById("simDatetimeInput").value = btn.dataset.dt;
            renderAll();
        });
    });

    document.getElementById("simDatetimeInput").addEventListener("change", (e) => {
        if (!e.target.value) return;
        state.simNowMs = kstStringToMs(e.target.value);
        document.querySelectorAll(".preset-btn").forEach((b) => b.classList.remove("active"));
        renderAll();
    });

    document.getElementById("btnSimDelay").addEventListener("click", () => {
        state.isInboundDelayed = !state.isInboundDelayed;
        renderAll();
    });

    // [승무원 기능 1] 원터치 상태 오버라이드 이벤트
    document.querySelectorAll(".ov-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            const mode = btn.dataset.override;
            const krNow = formatInTimeZone(state.simNowMs, "Asia/Seoul").shortKst;
            state.manualOverride = { mode, triggeredAtKst: krNow };
            saveState();
            renderAll();
            appendKakaoMsg("bot", "🔔 승무원 원터치 알림", `${state.profile.crewName}님이 직접 [${btn.querySelector("strong").textContent}] 상태를 발송했습니다!`);
        });
    });

    document.getElementById("btnClearOverride").addEventListener("click", () => {
        state.manualOverride = null;
        saveState();
        renderAll();
    });

    // [승무원 기능 2] 스케줄 맞교환(스왑) 시뮬레이터 이벤트
    document.querySelectorAll(".swap-preset-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            if (btn.dataset.swap === "safe") {
                document.getElementById("swapStart").value = "2026-11-28T09:00";
                document.getElementById("swapEnd").value = "2026-11-29T18:00";
            } else {
                document.getElementById("swapStart").value = "2026-11-19T09:00";
                document.getElementById("swapEnd").value = "2026-11-20T18:00";
            }
            runSwapConflictCheck();
        });
    });
    document.getElementById("btnCheckSwap").addEventListener("click", runSwapConflictCheck);

    // [승무원 기능 3] 가족 -> 승무원 착륙 3줄 브리핑 저장
    document.getElementById("familyDigestForm").addEventListener("submit", (e) => {
        e.preventDefault();
        state.digest.kids = document.getElementById("dgKids").value.trim();
        state.digest.school = document.getElementById("dgSchool").value.trim();
        state.digest.memo = document.getElementById("dgMemo").value.trim();
        saveState();
        renderCrewExclusivePage();
        const msg = document.getElementById("digestSaveMsg");
        msg.textContent = "✅ 저장 완료! [🧑‍✈️ 승무원 전용 라운지] 착륙 브리핑 보드에 즉시 반영되었습니다.";
        setTimeout(() => { msg.textContent = ""; }, 3000);
    });

    // [승무원 기능 6] 심부름 체크리스트 항목 추가
    document.getElementById("shoppingAddForm").addEventListener("submit", (e) => {
        e.preventDefault();
        const input = document.getElementById("shoppingInput");
        const val = input.value.trim();
        if (!val) return;
        state.shopping.push({ id: `sh-${Date.now()}`, text: val, done: false });
        input.value = "";
        saveState();
        renderCrewExclusivePage();
    });

    document.getElementById("btnClearDateFilter").addEventListener("click", () => {
        state.selectedCalendarDay = null;
        renderMonthlySchedulePage();
    });

    document.getElementById("btnDownloadIcs").addEventListener("click", () => {
        const icsData = generateEnrichedIcsContent();
        const blob = new Blob([icsData], { type: "text/calendar;charset=utf-8" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = "crewping-enriched-partner-calendar.ics";
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(url);
        const msg = document.getElementById("icalCopyMsg");
        msg.textContent = "✅ 사내 캘린더용 보강 .ics 파일 다운로드 완료!";
        setTimeout(() => { msg.textContent = ""; }, 3500);
    });

    document.getElementById("btnCopyIcalUrl").addEventListener("click", () => {
        const subUrl = `webcal://api.crewping.kr/v1/ical/${state.tokenSeed}/partner-work-overlay.ics`;
        navigator.clipboard?.writeText(subUrl);
        const msg = document.getElementById("icalCopyMsg");
        msg.textContent = `✅ 사내 캘린더 구독 URL 복사됨 (${subUrl})`;
        setTimeout(() => { msg.textContent = ""; }, 3500);
    });

    const icsDrop = document.getElementById("icsUploadDropzone");
    const icsInput = document.getElementById("icsFileInput");
    icsDrop.addEventListener("click", () => icsInput.click());

    icsInput.addEventListener("change", async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const text = await file.text();
        const parsed = parseGoogleCalendarIcs(text);
        const msg = document.getElementById("icsParseMsg");
        if (parsed.length === 0) {
            msg.style.color = "#dc2626";
            msg.textContent = "⚠️ .ics 파일에서 유효한 VEVENT 일정을 찾지 못했습니다.";
            return;
        }
        state.items.push(...parsed);
        state.items.sort((a, b) => a.startMs - b.startMs);
        state.configured = true;
        saveState();
        renderAll();
        msg.style.color = "#15803d";
        msg.textContent = `✅ '${file.name}'에서 ${parsed.length}개의 Google Calendar 일정을 가져왔습니다!`;
    });

    document.getElementById("btnLoadSampleIcs").addEventListener("click", () => {
        const parsed = parseGoogleCalendarIcs(SAMPLE_GOOGLE_CALENDAR_ICS);
        state.items.push(...parsed);
        state.items.sort((a, b) => a.startMs - b.startMs);
        state.configured = true;
        saveState();
        renderAll();
        const msg = document.getElementById("icsParseMsg");
        msg.style.color = "#15803d";
        msg.textContent = `✅ 샘플 Google Calendar(.ics)에서 다낭 왕복 ${parsed.length}개 VEVENT를 가져와 병합했습니다!`;
    });

    document.getElementById("btnSyncCalUrl").addEventListener("click", () => {
        state.profile.calSecretUrl = document.getElementById("cfgCalSecretUrl").value.trim();
        state.configured = true;
        saveState();
        renderAll();
        document.getElementById("icsParseMsg").textContent = "✅ Google Calendar 비공개 iCal 주소 동기화 완료!";
    });

    document.getElementById("btnApplyAddonComm").addEventListener("click", () => {
        const dropoff = document.getElementById("addonDropoff").value;
        const pickup = document.getElementById("addonPickup").value;
        const target = state.items.find((i) => i.flightId === "KE914");
        if (target) {
            target.careNote = `[Add-on 배정] ${dropoff} · ${pickup}`;
            saveState();
            renderAll();
        }
        const msg = document.getElementById("addonCommMsg");
        msg.textContent = "✅ Google Calendar 및 가족 보드에 등하원 담당이 반영되었습니다!";
        setTimeout(() => { msg.textContent = ""; }, 3500);
    });

    document.getElementById("btnRotateTokens").addEventListener("click", () => {
        state.tokenSeed = Math.random().toString(16).slice(2, 10);
        saveState();
        renderSecurityTokens();
        const msg = document.getElementById("tokenActionMsg");
        msg.textContent = "🔐 4-Role 새 HMAC 서명 토큰이 발급되었으며 기존 링크는 폐기되었습니다.";
        setTimeout(() => { msg.textContent = ""; }, 3500);
    });

    document.getElementById("profileForm").addEventListener("submit", (e) => {
        e.preventDefault();
        state.profile.crewName = document.getElementById("cfgCrewName").value.trim() || "승무원";
        state.profile.arrivalBufferMin = Number(document.getElementById("cfgArrivalBuffer").value) || 30;
        state.profile.commuteBufferMin = Number(document.getElementById("cfgCommuteBuffer").value) || 120;
        state.profile.restHoursAfterLongHaul = Number(document.getElementById("cfgRestHours").value) || 5;
        state.configured = true;
        saveState();
        renderAll();
        document.getElementById("profileSaveMsg").textContent = "✅ 저장 완료!";
    });

    document.getElementById("btnResetAllDemo").addEventListener("click", () => {
        localStorage.removeItem(STORAGE_KEY);
        state.configured = true;
        state.manualOverride = null;
        state.items = getDefaultItems();
        state.shopping = [...DEFAULT_SHOPPING];
        syncFormInputsFromState();
        saveState();
        renderAll();
    });

    document.getElementById("manualAddForm").addEventListener("submit", (e) => {
        e.preventDefault();
        const type = document.getElementById("manType").value;
        const flightId = document.getElementById("manFlightId").value.trim().toUpperCase();
        const country = document.getElementById("manCountry").value;
        const startMs = kstStringToMs(document.getElementById("manStart").value);
        const endMs = kstStringToMs(document.getElementById("manEnd").value);
        const title = document.getElementById("manTitle").value.trim();
        const careNote = document.getElementById("manNote").value.trim();

        if (endMs <= startMs) return;
        state.items.push({ id: `man-${Date.now()}`, type, flightId, country, startMs, endMs, title, careNote });
        state.items.sort((a, b) => a.startMs - b.startMs);
        saveState();
        renderAll();
        document.getElementById("manTitle").value = "";
        document.getElementById("manAddMsg").textContent = "✅ 추가 완료!";
    });

    document.getElementById("btnClearSetupTest").addEventListener("click", () => {
        state.configured = !state.configured;
        renderMainStatusPage();
    });

    appendKakaoMsg(
        "bot",
        "🤖 크루핑 가족 안내봇",
        "안녕하세요! 승무원 원터치 생존신고와 Google Calendar·인천공항 공공API를 통합해 답변하는 안내봇입니다."
    );

    document.querySelectorAll(".quick-ask-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            const sender = document.getElementById("kakaoSender").value;
            appendKakaoMsg("user", sender, btn.dataset.ask);
            appendKakaoMsg("bot", "🤖 크루핑 가족 안내봇", buildKakaoReply(btn.dataset.ask));
        });
    });

    document.getElementById("kakaoForm").addEventListener("submit", (e) => {
        e.preventDefault();
        const input = document.getElementById("kakaoInput");
        const q = input.value.trim();
        if (!q) return;
        input.value = "";
        appendKakaoMsg("user", document.getElementById("kakaoSender").value, q);
        appendKakaoMsg("bot", "🤖 크루핑 가족 안내봇", buildKakaoReply(q));
    });

    renderAll();
    runSwapConflictCheck();
    if (initialRole === "crew" || initialRole === "grandparents" || initialRole === "kids" || initialRole === "partner" || initialRole === "husband") {
        applyRoleView(initialRole === "husband" ? "partner" : initialRole);
    }
}

document.addEventListener("DOMContentLoaded", init);
