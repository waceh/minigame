const COUNTRIES = {
    KR: {
        flag: "🇰🇷", name: "한국", tz: "Asia/Seoul",
        keywords: ["인천", "김포", "한국", "서울", "제주", "부산", "icn", "gmp"],
        weather: "맑음 · 일교차 유의", outfit: "계절에 맞는 가벼운 겉옷 챙기기", rateUsd: 0
    },
    JP: {
        flag: "🇯🇵", name: "일본", tz: "Asia/Tokyo",
        keywords: ["일본", "도쿄", "나리타", "하네다", "오사카", "후쿠오카", "삿포로", "nrt", "hnd", "kix"],
        weather: "대체로 맑음 ☀️ · 한국과 기온 비슷", outfit: "가벼운 자켓 또는 가디건", rateUsd: 3.5
    },
    VN: {
        flag: "🇻🇳", name: "베트남", tz: "Asia/Ho_Chi_Minh",
        keywords: ["베트남", "다낭", "하노이", "호치민", "나트랑", "푸꾸옥", "dad", "han", "sgn"],
        weather: "온화·다습 🌴 · 낮 27°C 내외", outfit: "통풍 잘되는 복장 + 실내 냉방용 얇은 가디건", rateUsd: 3.2
    },
    US: {
        flag: "🇺🇸", name: "미국동부", tz: "America/New_York",
        keywords: ["미국", "뉴욕", "애틀랜타", "보스턴", "워싱턴", "jfk", "atl", "iad"],
        weather: "바람 선선함 🌬️ · 일교차 큼", outfit: "방풍 외투 및 레이어드 복장", rateUsd: 4.8
    },
    ES: {
        flag: "🇪🇸", name: "스페인", tz: "Europe/Madrid",
        keywords: ["스페인", "마드리드", "바르셀로나", "mad", "bcn", "spain"],
        weather: "구름조금 ⛅ · 건조하고 일교차 큼", outfit: "니트+트렌치/자켓 및 보습제·작은 우산", rateUsd: 4.2
    },
    FR: {
        flag: "🇫🇷", name: "프랑스", tz: "Europe/Paris",
        keywords: ["프랑스", "파리", "cdg"],
        weather: "구름많음 ☁️ · 간헐적 비 예보", outfit: "방수 코트 및 휴대용 우산", rateUsd: 4.3
    }
};

const params = new URLSearchParams(window.location.search);
const SLUG = (params.get("crew") || "default").toLowerCase().replace(/[^a-z0-9_-]/g, "") || "default";
const IS_CREW_ROUTE = params.get("mode") === "crew";
const IS_HTTP = window.location.protocol.startsWith("http");

const LOCAL_DATA_KEY = `crewping_v2_data_${SLUG}`;
const AUTH_TOKEN_KEY = `crewping_v2_auth_${SLUG}`;

const state = {
    loading: true,
    isConfigured: false,
    hasPin: false,
    isCrewAuthenticated: false,
    authToken: "",
    crewName: "",
    icsUrl: "",
    airportDriveMin: 60,
    override: null,
    isDelayed: false,
    delayMin: 45,
    filter: "all",
    activeTab: "status",
    simMs: null, // null이면 항상 실시간 Date.now() 사용!
    pendingOnboardItems: [],
    items: [],
    shopping: [],
    busyEvents: []
};

function pad(n) {
    return String(n).padStart(2, "0");
}

function getNowMs() {
    return state.simMs !== null ? state.simMs : Date.now();
}

function kstToMs(str) {
    const clean = str.trim().replace(" ", "T");
    const [dPart, tPart = "00:00"] = clean.split("T");
    const [y, m, d] = dPart.split("-").map(Number);
    const [hh, mm] = tPart.split(":").map(Number);
    return Date.UTC(y, m - 1, d, hh - 9, mm, 0);
}

function msToLocalInput(ms) {
    const d = new Date(ms + 9 * 3600000);
    return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

function formatTz(ms, tz) {
    const parts = new Intl.DateTimeFormat("ko-KR", {
        timeZone: tz,
        month: "numeric",
        day: "numeric",
        weekday: "short",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
    }).formatToParts(new Date(ms));

    const m = {};
    parts.forEach((p) => { m[p.type] = p.value; });
    const h24 = Number(m.hour === "24" ? 0 : m.hour);
    const min = Number(m.minute);
    const ampm = h24 < 12 ? "오전" : "오후";
    const h12 = h24 % 12 === 0 ? 12 : h24 % 12;

    return {
        month: Number(m.month),
        day: Number(m.day),
        weekday: m.weekday,
        h24,
        clock12: `${ampm} ${pad(h12)}:${pad(min)}`,
        dateLabel: `${m.month}월 ${m.day}일 (${m.weekday})`,
        shortRange: `${m.month}.${pad(m.day)}(${m.weekday}) ${pad(h24)}:${pad(min)}`,
        dayTime: `${m.day}일(${m.weekday}) ${ampm} ${h12}:${pad(min)}`
    };
}

function getDiffHours(ms, tz) {
    if (tz === "Asia/Seoul") return 0;
    const kr = formatTz(ms, "Asia/Seoul");
    const lc = formatTz(ms, tz);
    let dd = lc.day - kr.day;
    if (dd > 15) dd -= 30;
    if (dd < -15) dd += 30;
    return dd * 24 + (lc.h24 - kr.h24);
}

function getEffectiveItems() {
    const flights = state.items.filter((i) => i.type === "FLIGHT");
    const sampleDelayTargetId = flights[flights.length - 1]?.id;
    return state.items.map((it) => {
        const apiDelay = Number(it.delayMin) || 0;
        const simDelay = state.isDelayed && it.id === sampleDelayTargetId ? state.delayMin : 0;
        const totalDelay = simDelay || apiDelay;
        return {
            ...it,
            effDelayMin: totalDelay,
            effStartMs: it.startMs + (simDelay ? 15 * 60000 : 0),
            effEndMs: it.endMs + (simDelay ? simDelay * 60000 : 0)
        };
    });
}

function evaluateStatus(nowMs) {
    const items = getEffectiveItems();
    const flights = items.filter((i) => i.type === "FLIGHT");
    const active = items.find((i) => nowMs >= i.effStartMs && nowMs < i.effEndMs);
    const prevFlight = [...flights].reverse().find((f) => f.effEndMs <= nowMs);
    const nextReturn = flights.find((f) => f.effEndMs + 120 * 60000 >= nowMs && (f.title.includes("인천") || f.title.includes("김포")) && !f.title.startsWith("인천") && !f.title.startsWith("김포"));

    const homeReturnText = nextReturn
        ? `${formatTz(nextReturn.effEndMs + 120 * 60000, "Asia/Seoul").dayTime}경`
        : "";

    const countryKey = active?.country || prevFlight?.country || "KR";

    if (state.override === "LANDED") {
        return {
            theme: "amber",
            dotColor: "#f59e0b",
            pill: "방금 착륙 · 이동 중",
            emoji: "🛬",
            headline: "무사히 착륙해 이동하고 있어요",
            route: "승무원이 직접 [잘 내렸어] 알림을 보냈어요",
            countryKey,
            nextCheck: "약 40분~1시간 뒤 호텔 도착 후 예상",
            homeReturnText,
            guide: "입국 심사와 이동 중이라 정신없을 수 있어요. 안부 카톡만 편하게 남겨두세요."
        };
    }
    if (state.override === "SLEEP") {
        const wake = formatTz(nowMs + 6 * 3600000, "Asia/Seoul");
        return {
            theme: "amber",
            dotColor: "#f59e0b",
            pill: "취침 · 휴식 중",
            emoji: "😴",
            headline: "지금 잠자리에 들어 쉬고 있어요",
            route: "승무원이 직접 [이제 잘게] 모드를 켰어요",
            countryKey,
            nextCheck: `${wake.dayTime}경 이후 예상`,
            homeReturnText,
            guide: "피로 회복을 위해 자는 중이에요. 전화벨 대신 무음 카톡 메시지만 남겨주세요."
        };
    }
    if (state.override === "FREE") {
        return {
            theme: "green",
            dotColor: "#16a34a",
            pill: "잠깐 여유 시간",
            emoji: "💬",
            headline: "지금 잠깐 여유가 생겼어요",
            route: "승무원이 직접 보낸 안부 신호예요",
            countryKey,
            nextCheck: "현재 카톡 확인이 비교적 수월해요",
            homeReturnText,
            guide: "가볍게 카톡 인사를 나눠보세요. (음성·화상통화는 여건에 따라 어려울 수 있어요)"
        };
    }

    if (items.length === 0) {
        return {
            theme: "slate",
            dotColor: "#64748b",
            pill: "일정 등록 대기 중",
            emoji: "🗓️",
            headline: "아직 등록된 비행 일정이 없어요",
            route: "비행 스케줄이 등록되면 자동으로 상태가 표시됩니다",
            countryKey: "KR",
            nextCheck: "일정 등록 후 자동 계산",
            homeReturnText: "",
            guide: "아직 이번 달 비행 스케줄이 입력되지 않았어요. 편하게 카톡으로 안부를 남겨보세요."
        };
    }

    if (active && active.type === "FLIGHT") {
        const ready = formatTz(active.effEndMs + 30 * 60000, "Asia/Seoul");
        const c = COUNTRIES[active.country] || COUNTRIES.KR;
        return {
            theme: "red",
            dotColor: "#dc2626",
            pill: "비행 근무 중 · 연락 불가",
            emoji: "✈️",
            headline: `${c.name} 노선 비행 중이에요`,
            route: `${active.flightId ? `${active.flightId} · ` : ""}${active.title}`,
            countryKey: active.country,
            nextCheck: `${ready.dayTime}경 이후 예상`,
            homeReturnText,
            guide: "기내 근무 중이라 휴대폰이 비행기 모드예요. 카톡을 남겨두시면 착륙 후 여유가 될 때 확인합니다.",
            activeId: active.id,
            hasDelayBadge: active.effDelayMin > 0,
            delayMin: active.effDelayMin
        };
    }

    if (prevFlight && (prevFlight.effEndMs - prevFlight.effStartMs) >= 7 * 3600000) {
        const restEnd = prevFlight.effEndMs + 5.5 * 3600000;
        if (nowMs >= prevFlight.effEndMs && nowMs < restEnd && active?.type === "LAYOVER") {
            const wake = formatTz(restEnd, "Asia/Seoul");
            return {
                theme: "amber",
                dotColor: "#f59e0b",
                pill: "비행 직후 회복 수면",
                emoji: "😴",
                headline: "도착 후 피로 회복 잠을 잘 시간이에요",
                route: `${prevFlight.flightId || ""} 장거리 비행 완료`.trim(),
                countryKey: active.country,
                nextCheck: `${wake.dayTime}경 이후 예상`,
                homeReturnText,
                guide: "긴 비행을 마치고 호텔에서 깊이 쉬고 있을 시간대예요. 전화보다는 카톡 메시지를 남겨주세요.",
                activeId: active.id
            };
        }
    }

    if (active && active.type === "LAYOVER") {
        const c = COUNTRIES[active.country] || COUNTRIES.KR;
        const lc = formatTz(nowMs, c.tz);
        if (lc.h24 >= 22 || lc.h24 < 7) {
            return {
                theme: "amber",
                dotColor: "#f59e0b",
                pill: "현지 새벽 · 취침 시간",
                emoji: "🌙",
                headline: `${c.name} 현지는 지금 잠든 밤이에요`,
                route: active.title,
                countryKey: active.country,
                nextCheck: "현지 아침 기상 이후 (한국 오후~저녁경)",
                homeReturnText,
                guide: `한국은 깨어있는 시간이지만 현지는 ${lc.clock12}이에요. 조용히 카톡만 남겨두시는 걸 추천해요.`,
                activeId: active.id
            };
        }
        return {
            theme: "green",
            dotColor: "#16a34a",
            pill: "해외 체류 · 현지 낮",
            emoji: "🌤️",
            headline: `${c.name} 현지 낮 시간대예요`,
            route: active.title,
            countryKey: active.country,
            nextCheck: "일정상 여유 추정 구간 (여건 따라 상이)",
            homeReturnText,
            guide: "현지 낮 시간이지만 식사·외출·휴식 중일 수 있어요. 먼저 가볍게 카톡으로 안부를 남겨보세요.",
            activeId: active.id
        };
    }

    if (active && (active.type === "STANDBY" || active.type === "TRAINING")) {
        const endFmt = formatTz(active.effEndMs, "Asia/Seoul");
        return {
            theme: "amber",
            dotColor: "#f59e0b",
            pill: "대기 · 지상 근무 중",
            emoji: "📋",
            headline: `${active.title} 시간이에요`,
            route: active.note || "호출 대기 중",
            countryKey: active.country,
            nextCheck: `${endFmt.dayTime}경 종료 예정`,
            homeReturnText,
            guide: "대기 또는 교육 중이라 바로 통화가 어려울 수 있으니 카톡 메시지를 먼저 남겨주세요.",
            activeId: active.id
        };
    }

    return {
        theme: "green",
        dotColor: "#16a34a",
        pill: "한국 체류 · 휴무",
        emoji: "🏡",
        headline: "비행 없이 한국에 머무는 날이에요",
        route: active ? active.title : "현재 진행 중인 비행 없음",
        countryKey: "KR",
        nextCheck: "일정상 여유 구간 (개인 여건 따라 상이)",
        homeReturnText: "",
        guide: "시차 없는 한국 체류 기간이에요. 개인 휴식이나 외출 중일 수 있으니 편하게 카톡을 남겨보세요.",
        activeId: active?.id
    };
}

function showExclusiveView(viewId, showBottomNav) {
    document.querySelectorAll("main.view").forEach((el) => {
        el.classList.toggle("active", el.id === viewId);
    });
    document.getElementById("bottomNav").classList.toggle("hidden", !showBottomNav);
}

function renderAdvancedDrawer(st, nowMs) {
    const items = getEffectiveItems();
    const flights = items.filter((i) => i.type === "FLIGHT");
    const nextOutbound = flights.find((f) => f.effEndMs >= nowMs && (f.title.startsWith("인천") || f.title.startsWith("김포"))) || flights[0];

    // 1. 체류지 날씨 & 옷차림
    const targetCountry = st.countryKey === "KR" ? (nextOutbound?.country || "KR") : st.countryKey;
    const cMeta = COUNTRIES[targetCountry] || COUNTRIES.KR;
    document.getElementById("advWeatherCountry").textContent = `${cMeta.flag} ${cMeta.name}`;
    document.getElementById("advWeatherBody").innerHTML = items.length === 0
        ? "비행 일정이 등록되면 다음 체류지 날씨와 복장 참고 정보가 표시됩니다."
        : `• 기온/날씨: <strong>${cMeta.weather}</strong><br>• 사복 참고: ${cMeta.outfit}`;

    // 2. 면세·심부름 장바구니
    const shopEl = document.getElementById("advShopList");
    shopEl.innerHTML = state.shopping.map((s) => `
        <div class="adv-shop-item ${s.done ? "done" : ""}">
            <label>
                <input type="checkbox" data-shoptoggle="${s.id}" ${s.done ? "checked" : ""}>
                <span>${escapeHtml(s.text)}</span>
            </label>
            <button type="button" class="tiny-del-btn" data-shopdel="${s.id}">삭제</button>
        </div>
    `).join("") || `<p class="adv-sub">등록된 심부름 메모가 없습니다.</p>`;

    shopEl.querySelectorAll("[data-shoptoggle]").forEach((chk) => {
        chk.addEventListener("change", () => {
            const found = state.shopping.find((x) => x.id === chk.dataset.shoptoggle);
            if (found) found.done = chk.checked;
            saveFamilySharedMemo();
            render();
        });
    });

    shopEl.querySelectorAll("[data-shopdel]").forEach((btn) => {
        btn.addEventListener("click", () => {
            state.shopping = state.shopping.filter((x) => x.id !== btn.dataset.shopdel);
            saveFamilySharedMemo();
            render();
        });
    });

    // 3. 쇼업(Show-up) 출발 데드라인 역산기 (공항 이동시간 수정은 승무원 본인만 가능)
    const driveInp = document.getElementById("inpAirportDriveMin");
    driveInp.disabled = !(IS_CREW_ROUTE && state.isCrewAuthenticated);
    const showupEl = document.getElementById("advShowupBody");
    if (nextOutbound) {
        const stdMs = nextOutbound.effStartMs;
        const showupMs = stdMs - 140 * 60000;
        const leaveMs = showupMs - (state.airportDriveMin + 25) * 60000;
        showupEl.innerHTML = `
            <div>• 기준 출국편: <strong>${escapeHtml(nextOutbound.flightId || "항공편")} (${escapeHtml(nextOutbound.title)})</strong></div>
            <div>• 출발(STD): ${formatTz(stdMs, "Asia/Seoul").shortRange}</div>
            <div>• 브리핑 쇼업(-2h20m): ${formatTz(showupMs, "Asia/Seoul").shortRange}</div>
            <div class="adv-deadline">🚨 집 출발 권장: ${formatTz(leaveMs, "Asia/Seoul").dayTime}까지 출발 (주차버퍼 25분 포함)</div>
        `;
    } else {
        showupEl.textContent = "예정된 출국 항공편이 등록되면 집 출발 권장 시각이 자동 계산됩니다.";
    }

    // 4. 파트너·가족 중요 일정 관리 리스트
    document.getElementById("busyEventCount").textContent = String(state.busyEvents.length);
    const busyEl = document.getElementById("busyEventList");
    busyEl.innerHTML = state.busyEvents.map((b) => `
        <div class="adv-shop-item">
            <span><strong>${escapeHtml(b.title)}</strong> (${formatTz(b.startMs, "Asia/Seoul").shortRange})</span>
            <button type="button" class="tiny-del-btn" data-busydel="${b.id}">삭제</button>
        </div>
    `).join("") || `<p class="adv-sub">등록된 중요 일정이 없습니다.</p>`;

    busyEl.querySelectorAll("[data-busydel]").forEach((btn) => {
        btn.addEventListener("click", () => {
            state.busyEvents = state.busyEvents.filter((x) => x.id !== btn.dataset.busydel);
            saveFamilySharedMemo();
            render();
            runSwapCheck();
        });
    });

    // 5. 월간 피로도 & 체류비(퍼디엠 — 오직 비밀번호 인증 완료된 승무원 본인에게만 노출!)
    const totalFlightHrs = Math.round(flights.reduce((a, f) => a + (f.effEndMs - f.effStartMs) / 3600000, 0) * 10) / 10;
    const longHauls = flights.filter((f) => (f.effEndMs - f.effStartMs) >= 7 * 3600000).length;
    const fatigue = flights.length === 0 ? 0 : Math.min(98, Math.round(totalFlightHrs * 1.15 + longHauls * 10));

    document.getElementById("advStatsGrid").innerHTML = `
        <div class="adv-stat-box">
            <span>등록된 비행시간</span>
            <strong>약 ${totalFlightHrs}시간</strong>
        </div>
        <div class="adv-stat-box">
            <span>시차 피로도 참고</span>
            <strong style="color:${fatigue >= 70 ? "#dc2626" : "#0f172a"};">${flights.length === 0 ? "일정 없음" : `약 ${fatigue}점 (${fatigue >= 70 ? "높음" : "보통"})`}</strong>
        </div>
    `;

    const canViewPrivateCrewInfo = IS_CREW_ROUTE && state.isCrewAuthenticated;
    const pdWrap = document.getElementById("crewOnlyPerDiemWrap");
    const pdVal = document.getElementById("crewOnlyPerDiemVal");
    const hintEl = document.getElementById("advSummaryHint");

    if (canViewPrivateCrewInfo) {
        const layovers = items.filter((i) => i.type === "LAYOVER");
        const rawUsd = layovers.reduce((acc, l) => {
            const hrs = (l.effEndMs - l.effStartMs) / 3600000;
            return acc + hrs * (COUNTRIES[l.country]?.rateUsd || 3.5);
        }, 0);
        const roundedUsd = Math.round(rawUsd / 10) * 10;
        const roundedManWon = Math.round((roundedUsd * 1390) / 10000);

        pdWrap.classList.remove("hidden");
        pdVal.textContent = layovers.length === 0
            ? "체류비(퍼디엠) 개략 가늠치: 등록된 해외 체류(LAYOVER) 일정이 없습니다."
            : `체류비(퍼디엠) 개략 가늠치: 약 $${roundedUsd} 내외 (약 ${roundedManWon}만 원대 추정)`;
        hintEl.textContent = "(날씨·심부름·출근역산·스왑·피로도·체류비🔒)";
    } else {
        pdWrap.classList.add("hidden");
        pdVal.textContent = "";
        hintEl.textContent = "(날씨·심부름·출근역산·스왑·피로도)";
    }
}

function render() {
    const canManageCrew = IS_CREW_ROUTE && state.isCrewAuthenticated;

    // 상단 헤더 액션 버튼 및 배지 노출 제어 (파트너·부모님·가족 공유 페이지에서는 완전 숨김!)
    document.getElementById("crewHeaderActions").classList.toggle("hidden", !canManageCrew);
    document.getElementById("crewRoleBadge").classList.toggle("hidden", !canManageCrew);

    // 1) 초기 로딩 중
    if (state.loading) {
        document.getElementById("headerTitle").textContent = "CrewPing";
        document.getElementById("headerDot").style.background = "#94a3b8";
        showExclusiveView("view-loading", false);
        return;
    }

    // 2) 미등록 최초 접속 상태 -> 샘플 데이터("김하늘") 노출 없이 등록 안내 화면 표시
    if (!state.isConfigured) {
        document.getElementById("headerDot").style.background = "#2563eb";
        if (IS_CREW_ROUTE) {
            document.getElementById("headerTitle").textContent = "CrewPing · 초기 등록";
            showExclusiveView("view-crew-onboarding", false);
        } else {
            document.getElementById("headerTitle").textContent = "CrewPing";
            showExclusiveView("view-family-empty", false);
        }
        return;
    }

    // 3) 이미 등록된 상태에서 승무원 페이지(?mode=crew) 접속 시 본인 인증 잠금 체크
    if (IS_CREW_ROUTE && !state.isCrewAuthenticated) {
        document.getElementById("headerTitle").textContent = "승무원 전용 페이지";
        document.getElementById("headerDot").style.background = "#6d28d9";
        showExclusiveView("view-crew-lock", false);
        return;
    }

    // 4) 정상 메인 화면 (가족 공유 뷰 또는 인증 완료된 승무원 본인 뷰)
    showExclusiveView(`view-${state.activeTab}`, true);

    const nowMs = getNowMs();
    const st = evaluateStatus(nowMs);
    document.getElementById("headerTitle").textContent = state.crewName || "CrewPing";
    document.getElementById("headerDot").style.background = st.dotColor;

    // 승무원 본인 모드에서 아직 일정이 0건이면 상단 등록 가이드 배너 표시
    document.getElementById("crewNoScheduleBanner").classList.toggle("hidden", !(canManageCrew && state.items.length === 0));

    const card = document.getElementById("statusCard");
    card.className = `status-card theme-${st.theme}`;
    document.getElementById("statusPill").textContent = st.pill;

    const showDelay = Boolean(state.isDelayed || st.hasDelayBadge);
    const delayBadgeEl = document.getElementById("delayBadge");
    delayBadgeEl.classList.toggle("hidden", !showDelay);
    if (showDelay) {
        delayBadgeEl.textContent = `⚠️ +${st.delayMin || state.delayMin}분 지연 반영`;
    }

    document.getElementById("statusEmoji").textContent = st.emoji;
    document.getElementById("statusHeadline").textContent = st.headline;
    document.getElementById("statusRoute").textContent = st.route;

    const kr = formatTz(nowMs, "Asia/Seoul");
    const cMeta = COUNTRIES[st.countryKey] || COUNTRIES.KR;
    const lc = formatTz(nowMs, cMeta.tz);
    const diff = getDiffHours(nowMs, cMeta.tz);

    document.getElementById("kstTime").textContent = kr.clock12;
    document.getElementById("kstDate").textContent = kr.dateLabel;
    document.getElementById("localLabel").textContent = `${cMeta.flag} ${cMeta.name} 현지`;
    document.getElementById("localTime").textContent = lc.clock12;
    document.getElementById("localDiff").textContent = diff === 0
        ? "한국과 시차 없음"
        : `한국보다 ${Math.abs(diff)}시간 ${diff < 0 ? "느림" : "빠름"}`;

    document.getElementById("nextCheckText").textContent = st.nextCheck;
    const retRow = document.getElementById("homeReturnRow");
    if (st.homeReturnText) {
        retRow.classList.remove("hidden");
        document.getElementById("homeReturnText").textContent = st.homeReturnText;
    } else {
        retRow.classList.add("hidden");
    }

    document.getElementById("gentleGuideText").textContent = st.guide;

    // 승무원 본인 전용 원터치 바는 오직 인증된 본인에게만 노출
    document.getElementById("crewQuickBar").classList.toggle("hidden", !canManageCrew);
    document.getElementById("btnResetAuto").classList.toggle("hidden", !state.override);
    document.querySelectorAll(".cq-btn").forEach((b) => {
        b.classList.toggle("active", state.override === b.dataset.ov);
    });

    renderAdvancedDrawer(st, nowMs);

    // 이번 달 일정 타임라인 렌더링
    const items = getEffectiveItems().filter((it) => state.filter === "all" || it.type === "FLIGHT");
    const iconMap = { FLIGHT: "✈️", LAYOVER: "🌍", STANDBY: "📋", TRAINING: "🎓", OFF: "🏠" };
    const tagMap = { FLIGHT: "비행", LAYOVER: "체류", STANDBY: "스탠바이", TRAINING: "교육", OFF: "휴무" };

    const timelineEl = document.getElementById("scheduleTimeline");
    if (items.length === 0) {
        timelineEl.innerHTML = `
            <div class="guide-card center-guide" style="margin-top:4px;">
                <div class="guide-emoji" style="font-size:32px;">📭</div>
                <strong style="font-size:15px;">등록된 일정이 없습니다</strong>
                <p class="guide-desc" style="margin-top:4px;">
                    ${canManageCrew ? "우측 상단 ⚙️ 버튼을 눌러 캘린더(.ics)를 연결하거나 수동으로 일정을 추가해 보세요." : "승무원이 일정을 등록하면 이곳에 순서대로 표시됩니다."}
                </p>
            </div>
        `;
    } else {
        timelineEl.innerHTML = items.map((it) => {
            const s = formatTz(it.effStartMs, "Asia/Seoul").shortRange;
            const e = formatTz(it.effEndMs, "Asia/Seoul").shortRange;
            return `
                <article class="sc-item ${it.id === st.activeId ? "now" : ""}">
                    <div class="sc-icon">${iconMap[it.type] || "📌"}</div>
                    <div class="sc-body">
                        <div class="sc-top">
                            <strong class="sc-title">${escapeHtml(it.flightId ? `${it.flightId} · ${it.title}` : it.title)}</strong>
                            <span class="sc-tag ${it.type}">${tagMap[it.type] || it.type}</span>
                        </div>
                        <div class="sc-time">${s} ~ ${e} (KST)${it.effDelayMin ? ` · ⚠️ +${it.effDelayMin}분 지연` : ""}</div>
                        ${it.note ? `<div class="sc-note">${escapeHtml(it.note)}</div>` : ""}
                    </div>
                    ${canManageCrew ? `<button type="button" class="tiny-del-btn" data-itemdel="${it.id}">삭제</button>` : ""}
                </article>
            `;
        }).join("");

        if (canManageCrew) {
            timelineEl.querySelectorAll("[data-itemdel]").forEach((btn) => {
                btn.addEventListener("click", () => {
                    state.items = state.items.filter((x) => x.id !== btn.dataset.itemdel);
                    saveCrewSync();
                    render();
                });
            });
        }
    }

    if (canManageCrew) {
        document.getElementById("inpSimCustomDt").value = msToLocalInput(nowMs);
        document.getElementById("btnToggleDelay").textContent = state.isDelayed ? "+45분 지연 끄기" : "+45분 지연 켜기";
        document.getElementById("kakaoPreviewBubble").textContent =
            `[CrewPing 안내봇]\n${st.emoji} ${st.headline}\n• 한국: ${kr.clock12} / ${cMeta.name}: ${lc.clock12}\n• 개략적 확인 예상: ${st.nextCheck}\n\n※ 예측된 참고 시간이라 당사자 여건·컨디션에 따라 연락이 바로 닿지 않을 수 있어요 ❤️`;
    }
}

function escapeHtml(str) {
    return String(str || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function runSwapCheck() {
    const sv = document.getElementById("advSwapStart").value;
    const ev = document.getElementById("advSwapEnd").value;
    const box = document.getElementById("advSwapResult");
    if (!sv || !ev) return;

    box.classList.remove("hidden");
    const sMs = kstToMs(sv);
    const eMs = kstToMs(ev);
    if (eMs <= sMs) {
        box.className = "swap-res-box conflict";
        box.textContent = "⚠️ 종료 일시는 시작 일시보다 뒤여야 합니다.";
        return;
    }

    const busyHits = state.busyEvents.filter((b) => sMs <= b.endMs && eMs >= b.startMs);
    const flightHits = state.items.filter((i) => i.type === "FLIGHT" && sMs <= i.endMs && eMs >= i.startMs);

    if (busyHits.length === 0 && flightHits.length === 0) {
        box.className = "swap-res-box ok";
        box.innerHTML = "✅ <strong>겹치는 일정 없음!</strong> 기존 비행 및 등록된 파트너·부모님 중요 일정과 충돌하지 않습니다.";
    } else {
        const reasons = [
            ...busyHits.map((b) => `• ${escapeHtml(b.title)} (${formatTz(b.startMs, "Asia/Seoul").shortRange})`),
            ...flightHits.map((f) => `• 기존 비행 중복: ${escapeHtml(f.flightId || "")} ${escapeHtml(f.title)}`)
        ];
        box.className = "swap-res-box conflict";
        box.innerHTML = `🚨 <strong>일정 겹침 ${reasons.length}건 주의!</strong><br>${reasons.join("<br>")}`;
    }
}

function parseIcsText(icsText) {
    const unfolded = icsText.replace(/\r?\n[ \t]/g, "");
    const blocks = unfolded.split("BEGIN:VEVENT").slice(1);
    const out = [];

    function parseDt(val) {
        if (!val) return null;
        const v = val.trim();
        if (/^\d{8}$/.test(v)) {
            return Date.UTC(Number(v.slice(0, 4)), Number(v.slice(4, 6)) - 1, Number(v.slice(6, 8)), -9, 0, 0);
        }
        const m = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$/);
        if (!m) return null;
        return m[7] === "Z"
            ? Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), 0)
            : Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]) - 9, Number(m[5]), 0);
    }

    blocks.forEach((blk, idx) => {
        const body = blk.split("END:VEVENT")[0];
        const props = {};
        body.split(/\r?\n/).forEach((line) => {
            const idxColon = line.indexOf(":");
            if (idxColon > 0) {
                props[line.slice(0, idxColon).split(";")[0].toUpperCase()] = line.slice(idxColon + 1).trim();
            }
        });

        const startMs = parseDt(props.DTSTART);
        const endMs = parseDt(props.DTEND) || (startMs ? startMs + 3600000 : null);
        if (!startMs || !endMs || endMs <= startMs) return;

        const summary = (props.SUMMARY || "일정").replace(/\\,/g, ",");
        const desc = (props.DESCRIPTION || "").replace(/\\n/g, " ");
        const loc = (props.LOCATION || "").replace(/\\,/g, ",");
        const full = `${summary} ${loc} ${desc}`.toLowerCase();

        const fm = summary.match(/\b([A-Z]{2}\d{3,4})\b/i);
        const flightId = fm ? fm[1].toUpperCase() : "";

        let country = "KR";
        for (const [code, meta] of Object.entries(COUNTRIES)) {
            if (code !== "KR" && meta.keywords.some((k) => full.includes(k))) {
                country = code;
                break;
            }
        }

        let type = "LAYOVER";
        if (flightId || summary.includes("비행") || summary.includes("->") || summary.includes("→")) type = "FLIGHT";
        else if (full.includes("스탠바이") || full.includes("대기")) type = "STANDBY";
        else if (full.includes("휴무") || full.includes("off")) type = "OFF";

        out.push({
            id: `ics-${Date.now()}-${idx}`,
            type,
            flightId,
            country,
            startMs,
            endMs,
            title: summary.replace(flightId, "").trim() || summary,
            note: desc
        });
    });
    out.sort((a, b) => a.startMs - b.startMs);
    return out;
}

function buildPartnerIcs() {
    const lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CrewPing Mobile v1//KO",
        `X-WR-CALNAME:${state.crewName || "CrewPing"} 스케줄`
    ];
    getEffectiveItems().forEach((it) => {
        const toUtc = (ms) => {
            const d = new Date(ms);
            return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}00Z`;
        };
        lines.push(
            "BEGIN:VEVENT",
            `UID:${it.id}@crewping.v1`,
            `DTSTART:${toUtc(it.effStartMs)}`,
            `DTEND:${toUtc(it.effEndMs)}`,
            `SUMMARY:${it.flightId ? `[${it.flightId}] ` : ""}${it.title}${it.effDelayMin ? ` (+${it.effDelayMin}분 지연)` : ""}`,
            "END:VEVENT"
        );
    });
    lines.push("END:VCALENDAR");
    return lines.join("\r\n");
}

function applyServerData(data) {
    state.isConfigured = Boolean(data.isConfigured);
    state.hasPin = Boolean(data.hasPin);
    state.isCrewAuthenticated = Boolean(IS_CREW_ROUTE && data.authValid);
    state.crewName = data.crewName || "";
    if (data.authValid && typeof data.icsUrl === "string") {
        state.icsUrl = data.icsUrl;
    }
    state.airportDriveMin = Number(data.airportDriveMin) || 60;
    state.override = data.override || null;
    state.items = Array.isArray(data.items) ? data.items : [];
    state.shopping = Array.isArray(data.shopping) ? data.shopping : [];
    state.busyEvents = Array.isArray(data.busyEvents) ? data.busyEvents : [];

    document.getElementById("inpCrewName").value = state.crewName;
    document.getElementById("inpIcsUrl").value = state.icsUrl;
    document.getElementById("inpAirportDriveMin").value = state.airportDriveMin;
}

function persistLocalFallback(extra = {}) {
    try {
        const prev = JSON.parse(localStorage.getItem(LOCAL_DATA_KEY) || "{}");
        const merged = {
            isConfigured: state.isConfigured,
            pinPlain: extra.pinPlain !== undefined ? extra.pinPlain : (prev.pinPlain || ""),
            crewName: state.crewName,
            icsUrl: state.icsUrl,
            airportDriveMin: state.airportDriveMin,
            override: state.override,
            items: state.items,
            shopping: state.shopping,
            busyEvents: state.busyEvents
        };
        localStorage.setItem(LOCAL_DATA_KEY, JSON.stringify(merged));
    } catch (_) {}
}

async function loadInitialState() {
    try {
        state.authToken = localStorage.getItem(AUTH_TOKEN_KEY) || "";
    } catch (_) {}

    if (IS_HTTP) {
        try {
            const headers = state.authToken ? { "X-Crew-Auth": state.authToken } : {};
            const res = await fetch(`/api/crew/${encodeURIComponent(SLUG)}`, { headers });
            if (res.ok) {
                const data = await res.json();
                applyServerData(data);
                if (!data.authValid && state.authToken) {
                    state.authToken = "";
                    try { localStorage.removeItem(AUTH_TOKEN_KEY); } catch (_) {}
                }
            }
        } catch (_) {}
    } else {
        // 로컬 file:// 미리보기 폴백 (샘플 데이터 없음!)
        try {
            const raw = localStorage.getItem(LOCAL_DATA_KEY);
            if (raw) {
                const p = JSON.parse(raw);
                state.isConfigured = Boolean(p.isConfigured);
                state.hasPin = Boolean(p.pinPlain);
                state.isCrewAuthenticated = Boolean(IS_CREW_ROUTE && state.authToken && state.authToken === p.pinPlain);
                state.crewName = p.crewName || "";
                state.icsUrl = p.icsUrl || "";
                state.airportDriveMin = Number(p.airportDriveMin) || 60;
                state.override = p.override || null;
                state.items = Array.isArray(p.items) ? p.items : [];
                state.shopping = Array.isArray(p.shopping) ? p.shopping : [];
                state.busyEvents = Array.isArray(p.busyEvents) ? p.busyEvents : [];
                document.getElementById("inpCrewName").value = state.crewName;
                document.getElementById("inpIcsUrl").value = state.icsUrl;
                document.getElementById("inpAirportDriveMin").value = state.airportDriveMin;
            }
        } catch (_) {}
    }

    state.loading = false;
    render();
}

async function saveCrewSync(options = {}) {
    if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return null;

    const payload = {
        crewName: state.crewName,
        icsUrl: state.icsUrl,
        airportDriveMin: state.airportDriveMin,
        override: state.override,
        items: state.items,
        shopping: state.shopping,
        busyEvents: state.busyEvents,
        pullIcsNow: Boolean(options.pullIcsNow),
        ...(options.newPin ? { newPin: options.newPin } : {}),
        ...(options.resetAll ? { resetAll: true } : {})
    };

    if (!IS_HTTP) {
        if (options.resetAll) {
            try {
                localStorage.removeItem(LOCAL_DATA_KEY);
                localStorage.removeItem(AUTH_TOKEN_KEY);
            } catch (_) {}
            state.isConfigured = false;
            state.hasPin = false;
            state.isCrewAuthenticated = false;
            state.authToken = "";
            state.crewName = "";
            state.icsUrl = "";
            state.items = [];
            state.shopping = [];
            state.busyEvents = [];
            render();
            return { ok: true };
        }
        if (options.newPin) {
            state.authToken = options.newPin;
            try { localStorage.setItem(AUTH_TOKEN_KEY, options.newPin); } catch (_) {}
            persistLocalFallback({ pinPlain: options.newPin });
        } else {
            persistLocalFallback();
        }
        return { ok: true };
    }

    try {
        const res = await fetch(`/api/crew/${encodeURIComponent(SLUG)}/sync`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-Crew-Auth": state.authToken
            },
            body: JSON.stringify(payload)
        });
        const json = await res.json().catch(() => null);
        if (res.ok && json?.ok) {
            if (json.token) {
                state.authToken = json.token;
                try { localStorage.setItem(AUTH_TOKEN_KEY, json.token); } catch (_) {}
            }
            if (json.data) {
                applyServerData(json.data);
                render();
            }
        }
        return json;
    } catch (_) {
        return null;
    }
}

async function saveFamilySharedMemo() {
    if (!state.isConfigured) return;
    if (!IS_HTTP) {
        persistLocalFallback();
        return;
    }
    try {
        await fetch(`/api/crew/${encodeURIComponent(SLUG)}/sync`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                familyMemoOnly: true,
                shopping: state.shopping,
                busyEvents: state.busyEvents
            })
        });
    } catch (_) {}
}

function getShareUrls() {
    const base = window.location.origin + window.location.pathname;
    const crewParam = SLUG !== "default" ? `crew=${encodeURIComponent(SLUG)}` : "";
    const familyUrl = crewParam ? `${base}?${crewParam}` : base;
    const crewUrl = crewParam ? `${base}?${crewParam}&mode=crew` : `${base}?mode=crew`;
    return { familyUrl, crewUrl };
}

function initDefaultDateInputs() {
    const now = Date.now();
    const tomorrow9am = new Date(now + 24 * 3600000);
    const startStr = msToLocalInput(tomorrow9am.getTime()).slice(0, 11) + "09:00";
    const endStr = msToLocalInput(tomorrow9am.getTime()).slice(0, 11) + "13:00";

    document.getElementById("qaStart").value = startStr;
    document.getElementById("qaEnd").value = endStr;
    document.getElementById("advSwapStart").value = startStr;
    document.getElementById("advSwapEnd").value = endStr;
    document.getElementById("busyStart").value = startStr;
    document.getElementById("busyEnd").value = endStr;
}

function init() {
    initDefaultDateInputs();

    // 역할별로 완전히 분리된 사용 가이드 링크 연결 (가족 페이지에서는 가족용 가이드로만 연결!)
    const guideBase = IS_HTTP ? "/guide" : "guide.html";
    const crewQuery = SLUG !== "default" ? `crew=${encodeURIComponent(SLUG)}` : "";
    const familyGuideHref = crewQuery ? `${guideBase}?${crewQuery}` : guideBase;
    const crewGuideHref = crewQuery ? `${guideBase}?${crewQuery}&mode=crew` : `${guideBase}?mode=crew`;
    document.getElementById("btnOpenGuide").href = IS_CREW_ROUTE ? crewGuideHref : familyGuideHref;
    document.getElementById("btnEmptyFamilyGuide").href = familyGuideHref;
    document.getElementById("btnOnboardingGuide").href = crewGuideHref;

    // 하단 탭 전환
    document.querySelectorAll(".nav-item").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".nav-item").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            state.activeTab = btn.dataset.view;
            render();
            window.scrollTo({ top: 0, behavior: "smooth" });
        });
    });

    // 1. 승무원 최초 접속 온보딩 폼 처리
    document.getElementById("obIcsFile").addEventListener("change", async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const parsed = parseIcsText(await file.text());
        state.pendingOnboardItems = parsed;
        document.getElementById("obFileStatus").textContent = parsed.length > 0
            ? `✅ ${parsed.length}개 일정 준비됨`
            : "⚠️ 파일에서 일정을 찾지 못했습니다";
    });

    document.getElementById("onboardingForm").addEventListener("submit", async (e) => {
        e.preventDefault();
        const errEl = document.getElementById("obErrorMsg");
        errEl.classList.add("hidden");

        const crewName = document.getElementById("obCrewName").value.trim();
        const newPin = document.getElementById("obCrewPin").value.trim();
        const icsUrl = document.getElementById("obIcsUrl").value.trim();

        if (!crewName || newPin.length < 4) {
            errEl.textContent = "승무원 호칭과 4자리 이상 비밀번호를 입력해 주세요.";
            errEl.classList.remove("hidden");
            return;
        }

        const submitBtn = document.getElementById("btnSubmitOnboarding");
        submitBtn.disabled = true;
        submitBtn.textContent = "등록 중...";

        if (IS_HTTP) {
            try {
                const res = await fetch(`/api/crew/${encodeURIComponent(SLUG)}/sync`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        crewName,
                        newPin,
                        icsUrl,
                        airportDriveMin: 60,
                        items: state.pendingOnboardItems
                    })
                });
                const json = await res.json().catch(() => ({}));
                if (!res.ok || !json.ok) {
                    errEl.textContent = json.error || "등록 중 오류가 발생했습니다.";
                    errEl.classList.remove("hidden");
                    submitBtn.disabled = false;
                    submitBtn.textContent = "🚀 등록 완료하고 시작하기";
                    return;
                }
                state.authToken = json.token;
                try { localStorage.setItem(AUTH_TOKEN_KEY, json.token); } catch (_) {}
                applyServerData(json.data);
            } catch (_) {
                errEl.textContent = "네트워크 오류가 발생했습니다. 다시 시도해 주세요.";
                errEl.classList.remove("hidden");
            }
        } else {
            state.isConfigured = true;
            state.hasPin = true;
            state.isCrewAuthenticated = true;
            state.authToken = newPin;
            state.crewName = crewName;
            state.icsUrl = icsUrl;
            state.items = [...state.pendingOnboardItems];
            try { localStorage.setItem(AUTH_TOKEN_KEY, newPin); } catch (_) {}
            persistLocalFallback({ pinPlain: newPin });
            document.getElementById("inpCrewName").value = state.crewName;
            document.getElementById("inpIcsUrl").value = state.icsUrl;
        }

        submitBtn.disabled = false;
        submitBtn.textContent = "🚀 등록 완료하고 시작하기";
        render();
    });

    // 2. 승무원 전용 페이지 비밀번호 잠금 해제 처리
    document.getElementById("crewUnlockForm").addEventListener("submit", async (e) => {
        e.preventDefault();
        const pin = document.getElementById("inpUnlockPin").value.trim();
        const errEl = document.getElementById("unlockErrorMsg");
        errEl.classList.add("hidden");

        if (!pin) return;

        if (IS_HTTP) {
            try {
                const res = await fetch(`/api/crew/${encodeURIComponent(SLUG)}/auth`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ pin })
                });
                const json = await res.json().catch(() => ({}));
                if (!res.ok || !json.ok) {
                    errEl.textContent = json.error || "비밀번호가 일치하지 않습니다.";
                    errEl.classList.remove("hidden");
                    return;
                }
                state.authToken = json.token;
                try { localStorage.setItem(AUTH_TOKEN_KEY, json.token); } catch (_) {}
                document.getElementById("inpUnlockPin").value = "";
                applyServerData(json.data);
                render();
            } catch (_) {
                errEl.textContent = "인증 요청 중 오류가 발생했습니다.";
                errEl.classList.remove("hidden");
            }
        } else {
            const saved = JSON.parse(localStorage.getItem(LOCAL_DATA_KEY) || "{}");
            if (saved.pinPlain && pin === saved.pinPlain) {
                state.isCrewAuthenticated = true;
                state.authToken = pin;
                try { localStorage.setItem(AUTH_TOKEN_KEY, pin); } catch (_) {}
                document.getElementById("inpUnlockPin").value = "";
                render();
            } else {
                errEl.textContent = "비밀번호가 일치하지 않습니다.";
                errEl.classList.remove("hidden");
            }
        }
    });

    // 승무원 페이지 수동 잠금 버튼
    document.getElementById("btnLockCrew").addEventListener("click", () => {
        state.isCrewAuthenticated = false;
        state.authToken = "";
        try { localStorage.removeItem(AUTH_TOKEN_KEY); } catch (_) {}
        document.getElementById("settingsSheet").classList.add("hidden");
        document.getElementById("simSheet").classList.add("hidden");
        render();
    });

    // 원터치 상태 오버라이드 (본인 인증 시에만 작동)
    document.querySelectorAll(".cq-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
            const val = btn.dataset.ov;
            state.override = state.override === val ? null : val;
            saveCrewSync();
            render();
        });
    });

    document.getElementById("btnResetAuto").addEventListener("click", () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        state.override = null;
        saveCrewSync();
        render();
    });

    // 일정 미등록 안내 배너 버튼
    document.getElementById("btnBannerOpenSettings").addEventListener("click", () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        document.getElementById("settingsSheet").classList.remove("hidden");
    });

    document.getElementById("btnBannerCopyFamily").addEventListener("click", () => {
        const { familyUrl } = getShareUrls();
        navigator.clipboard?.writeText(familyUrl);
        const t = document.getElementById("bannerCopyToast");
        t.textContent = "✅ 가족 공유용 링크가 복사되었습니다!";
        setTimeout(() => { t.textContent = ""; }, 2500);
    });

    // 상세 서랍 내부: 심부름 추가, 공항 이동시간, 스왑 체커, 중요일정 추가
    document.getElementById("advShopForm").addEventListener("submit", (e) => {
        e.preventDefault();
        const inp = document.getElementById("advShopInput");
        const val = inp.value.trim();
        if (!val) return;
        state.shopping.push({ id: `sh-${Date.now()}`, text: val, done: false });
        inp.value = "";
        saveFamilySharedMemo();
        render();
    });

    document.getElementById("inpAirportDriveMin").addEventListener("change", (e) => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        state.airportDriveMin = Number(e.target.value) || 60;
        saveCrewSync();
        render();
    });

    document.getElementById("btnRunSwapCheck").addEventListener("click", runSwapCheck);

    document.getElementById("busyAddForm").addEventListener("submit", (e) => {
        e.preventDefault();
        const sMs = kstToMs(document.getElementById("busyStart").value);
        const eMs = kstToMs(document.getElementById("busyEnd").value);
        const title = document.getElementById("busyTitle").value.trim();
        if (eMs <= sMs || !title) return;
        state.busyEvents.push({ id: `bz-${Date.now()}`, title, startMs: sMs, endMs: eMs });
        document.getElementById("busyTitle").value = "";
        saveFamilySharedMemo();
        render();
        runSwapCheck();
    });

    // 일정 필터 & .ics 내보내기
    document.querySelectorAll(".fp-btn").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".fp-btn").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            state.filter = btn.dataset.filter;
            render();
        });
    });

    document.getElementById("btnExportIcs").addEventListener("click", () => {
        const blob = new Blob([buildPartnerIcs()], { type: "text/calendar;charset=utf-8" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = "crewping-schedule.ics";
        a.click();
        URL.revokeObjectURL(url);
    });

    // 모달 열기/닫기 (오직 인증된 승무원 본인만 오픈 가능하도록 이중 가드!)
    document.getElementById("btnOpenSettings").addEventListener("click", () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        document.getElementById("settingsSheet").classList.remove("hidden");
    });

    document.getElementById("btnOpenSim").addEventListener("click", () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        document.getElementById("simSheet").classList.remove("hidden");
    });

    document.querySelectorAll("[data-close]").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.getElementById(btn.dataset.close).classList.add("hidden");
        });
    });

    document.querySelectorAll(".sheet-backdrop").forEach((bd) => {
        bd.addEventListener("click", (e) => {
            if (e.target === bd) bd.classList.add("hidden");
        });
    });

    const toast = document.getElementById("settingsToast");
    const showToast = (msg) => {
        toast.textContent = msg;
        setTimeout(() => { toast.textContent = ""; }, 2600);
    };

    document.getElementById("btnSaveSettings").addEventListener("click", async () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        state.crewName = document.getElementById("inpCrewName").value.trim() || state.crewName;
        state.icsUrl = document.getElementById("inpIcsUrl").value.trim();
        showToast("⏳ 저장 및 동기화 중...");
        const res = await saveCrewSync({ pullIcsNow: true });
        render();
        if (res?.pulledCount > 0) {
            showToast(`✅ 저장 완료! 캘린더에서 ${res.pulledCount}개 일정을 불러왔습니다.`);
        } else {
            showToast("✅ 설정이 저장되었습니다!");
        }
    });

    document.getElementById("inpIcsFile").addEventListener("change", async (e) => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        const file = e.target.files?.[0];
        if (!file) return;
        const parsed = parseIcsText(await file.text());
        if (parsed.length > 0) {
            state.items.push(...parsed);
            state.items.sort((a, b) => a.startMs - b.startMs);
            await saveCrewSync();
            render();
            showToast(`✅ ${parsed.length}개 일정이 추가되었습니다!`);
        } else {
            showToast("⚠️ 파일에서 일정을 찾지 못했습니다.");
        }
    });

    document.getElementById("btnCopyFamilyLink").addEventListener("click", () => {
        const { familyUrl } = getShareUrls();
        navigator.clipboard?.writeText(familyUrl);
        showToast("✅ 파트너·가족 공유용 링크 복사됨!");
    });

    document.getElementById("btnCopyCrewLink").addEventListener("click", () => {
        const { crewUrl } = getShareUrls();
        navigator.clipboard?.writeText(crewUrl);
        showToast("✅ 승무원 본인 전용 링크 복사됨!");
    });

    document.getElementById("quickAddForm").addEventListener("submit", async (e) => {
        e.preventDefault();
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        const type = document.getElementById("qaType").value;
        const country = document.getElementById("qaCountry").value;
        const startMs = kstToMs(document.getElementById("qaStart").value);
        const endMs = kstToMs(document.getElementById("qaEnd").value);
        const rawTitle = document.getElementById("qaTitle").value.trim();
        if (endMs <= startMs || !rawTitle) return;

        const fm = rawTitle.match(/\b([A-Z]{2}\d{3,4})\b/i);
        const flightId = fm ? fm[1].toUpperCase() : "";
        state.items.push({
            id: `qa-${Date.now()}`,
            type,
            flightId,
            country,
            startMs,
            endMs,
            title: rawTitle.replace(flightId, "").trim() || rawTitle,
            note: ""
        });
        state.items.sort((a, b) => a.startMs - b.startMs);
        document.getElementById("qaTitle").value = "";
        await saveCrewSync();
        render();
        showToast("✅ 일정이 추가되었습니다!");
    });

    document.getElementById("btnChangePin").addEventListener("click", async () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        const newPin = document.getElementById("inpNewPin").value.trim();
        if (newPin.length < 4) {
            showToast("⚠️ 비밀번호는 4자리 이상 입력해 주세요.");
            return;
        }
        await saveCrewSync({ newPin });
        document.getElementById("inpNewPin").value = "";
        showToast("✅ 새 비밀번호로 변경되었습니다!");
    });

    document.getElementById("btnResetAllData").addEventListener("click", async () => {
        if (!IS_CREW_ROUTE || !state.isCrewAuthenticated) return;
        if (!window.confirm("등록된 사용자 정보, 비밀번호, 일정을 모두 초기화하시겠습니까?")) return;
        await saveCrewSync({ resetAll: true });
        try { localStorage.removeItem(AUTH_TOKEN_KEY); } catch (_) {}
        state.authToken = "";
        state.isCrewAuthenticated = false;
        document.getElementById("settingsSheet").classList.add("hidden");
        render();
    });

    // 시뮬레이터 시트: 임의 시각 입력 + 실시간 복귀 + 오프셋 칩 + 연착
    document.getElementById("inpSimCustomDt").addEventListener("change", (e) => {
        if (!e.target.value) return;
        state.simMs = kstToMs(e.target.value);
        document.querySelectorAll(".sim-chip").forEach((c) => c.classList.remove("active"));
        render();
    });

    document.getElementById("btnSimNowReal").addEventListener("click", () => {
        state.simMs = null;
        document.querySelectorAll(".sim-chip").forEach((c) => c.classList.remove("active"));
        render();
    });

    document.querySelectorAll(".sim-chip").forEach((chip) => {
        chip.addEventListener("click", () => {
            document.querySelectorAll(".sim-chip").forEach((c) => c.classList.remove("active"));
            chip.classList.add("active");
            const offsetHrs = Number(chip.dataset.simoffset || 0);
            state.simMs = offsetHrs === 0 ? null : Date.now() + offsetHrs * 3600000;
            render();
        });
    });

    document.getElementById("btnToggleDelay").addEventListener("click", () => {
        state.isDelayed = !state.isDelayed;
        render();
    });

    // 30초마다 실시간 시계 자동 갱신
    setInterval(() => {
        if (!state.loading && state.isConfigured && state.simMs === null) {
            render();
        }
    }, 30000);

    render();
    loadInitialState();
}

document.addEventListener("DOMContentLoaded", init);
