using Toybox.Graphics;

// 칸 크기에 맞춰 폰트 크기와 좌표를 계산한다. zz 시리즈 공통 배치:
//   - 칸 폭 > 화면 폭 75% 면 넓은 칸, 아니면 좁은 칸
//   - 좁은 칸: 아이콘 좌상단, 보조값 우상단(바깥쪽 끝에 배터리), 메인값 우하단
//   - 넓은 칸: 타이틀 줄(아이콘 + 이름, 오른쪽에 기어비·배터리) + 가운데 세로선, 왼쪽 값 / 오른쪽 구동계
//   - 넓고 높은 칸: 구동계를 가운데 크게, 맨 아래 한 줄에 단수·기어비·톱니수
module Layout {

    // 화면 폭 246 / 282 / 420 / 480 (540·840 / 1040 / 550·850 / 1050·1060)
    const C10_MCAP = [ 34, 42, 65, 74 ];    // 좁은 칸 메인 숫자 높이
    const C10_SCAP = [ 20, 24, 36, 41 ];    // 보조값(기어비) 숫자 높이
    const C10_DCAP = [ 12, 15, 22, 25 ];    // 기어비 소수점 아래 (보조값의 0.62배)
    const C10_HCAP = [ 24, 29, 46, 52 ];    // 앞기어 숫자 (메인의 0.7배)
    const WIDE_VCAP = [ 35, 42, 63, 72 ];   // 넓은 칸 값
    const WIDE_TCAP = [ 13, 15, 23, 26 ];   // 넓은 칸 타이틀
    const WIDE_LCAP = [ 10, 12, 18, 21 ];   // 넓은 칸 라벨(톱니수)

    const ICON_K = 1.08;                    // 아이콘 높이 = 보조값 숫자 높이 x 1.08

    class Frame {
        var w = 0;
        var h = 0;
        var fam = 0;
        var wide = false;
        var tall = false;       // 넓고 높은 칸 (구동계를 가운데 크게)

        var L = 0;
        var T = 0;
        var R = 0;
        var B = 0;
        var ug = 2;             // 글자 사이 기본 간격

        // 글자 높이
        var mainCap = 0;        // 큰 숫자
        var subCap = 0;         // 기어비 정수부 / 좁은 칸 윗줄
        var decCap = 0;         // 기어비 소수점 아래
        var headCap = 0;        // 앞기어 숫자 높이 (메인의 70%)
        var labelCap = 0;       // 톱니수 라벨

        // 윗줄 (좁은 칸) / 타이틀 줄 (넓은 칸)
        var topBase = 0;        // 윗줄 글자 바닥선
        var iconX = 0;
        var iconSize = 0;       // 0 이면 아이콘 숨김
        var iconTop = 0;        // 아이콘 글리프 윗선
        var battW = 0;          // 0 이면 배터리 숨김
        var battH = 0;
        var battRight = 0;
        var battCY = 0;
        var tlineH = 0;         // 넓은 칸 타이틀 줄 높이
        var titleY = 0;         // 넓은 칸 타이틀 글자 윗선

        // 값
        var mainRight = 0;      // 좁은 칸: 오른쪽 정렬 x / 넓은 칸: 왼쪽 절반 가운데 x
        var mainTop = 0;        // 글자 윗선
        var mainCenter = false; // 넓은 칸은 가운데 정렬
        var ratioCap = 0;       // 넓고 낮은 칸: 오른쪽 아래 기어비 글자 높이
        var bigRatio = false;   // 기어비를 WideVal(큰 글씨)로

        // 구동계 그림이 들어갈 영역
        var ringCY = 0;
        var areaL = 0;
        var areaR = 0;
        var areaTop = 0;
        var areaBot = 0;
        var divX = -1;          // >= 0 이면 세로 구분선

        // 넓고 높은 칸 맨 아랫줄
        var footBase = 0;       // 글자 바닥선 (0 이면 없음)
        var warnTop = -1;       // 크로스체인 문구 윗선 (< 0 이면 그리지 않음)
    }

    function famOf(screenW) {
        if (screenW >= 470) { return 3; }
        if (screenW >= 400) { return 2; }
        if (screenW >= 270) { return 1; }
        return 0;
    }

    function pct(v, p, lo) {
        var r = (v * p + 0.5).toNumber();
        return (r < lo) ? lo : r;
    }

    // ---- 좁은 칸 -----------------------------------------------------
    function compute(w, h, screenW, showIcon, showBatt) {
        var f = new Frame();
        f.w = w;
        f.h = h;
        f.fam = famOf(screenW);
        var k = f.fam;
        f.L = pct(w, 0.03, 2);
        f.T = pct(h, 0.05, 2);
        f.R = w - f.L;
        f.B = h - f.T;
        f.ug = pct(w, 0.02, 2);

        f.mainCap = C10_MCAP[k];
        f.subCap  = C10_SCAP[k];
        f.decCap  = C10_DCAP[k];
        f.headCap = C10_HCAP[k];
        f.labelCap = WIDE_LCAP[k];

        // 칸이 낮으면 윗줄을 빼고 큰 숫자만
        var topH = f.subCap;
        if (f.T + topH + f.mainCap > f.B) {
            topH = 0;
        }
        f.topBase = f.T + topH;

        if (topH > 0 && showIcon && w >= 64) {
            f.iconSize = (f.subCap * ICON_K + 0.5).toNumber();
            f.iconX = f.L;
            f.iconTop = f.T + (f.subCap - f.iconSize) / 2;
        }
        if (topH > 0 && showBatt) {
            var bc = (f.subCap * 0.62 + 0.5).toNumber();
            f.battW = (bc * 0.95 + 0.5).toNumber();
            f.battH = (bc * 0.52 + 0.5).toNumber();
            if (f.battH < 5) { f.battH = 5; }
            f.battRight = f.R;
            f.battCY = f.T + f.subCap / 2;
        }

        f.mainRight = f.R;
        f.mainTop = f.B - f.mainCap;

        // 동심원은 윗줄 아래 남는 높이를 다 쓴다
        f.areaL = f.L;
        f.areaTop = f.topBase;
        f.areaBot = f.B;
        f.ringCY = (f.areaTop + f.areaBot) / 2;
        return f;
    }

    // ---- 넓은 칸 -----------------------------------------------------
    function computeWide(w, h, screenW, showIcon, showBatt, showTeeth) {
        var f = new Frame();
        f.wide = true;
        f.w = w;
        f.h = h;
        f.fam = famOf(screenW);
        var k = f.fam;
        f.L = pct(w, 0.04, 3);
        f.T = pct(h, 0.05, 2);
        f.R = w - f.L;
        f.B = h - f.T;
        f.ug = pct(w, 0.02, 2);
        f.tall = (h >= w * 0.45);

        f.mainCap = WIDE_VCAP[k];
        f.subCap  = C10_SCAP[k];
        f.decCap  = C10_DCAP[k];
        f.labelCap = WIDE_LCAP[k];

        var tcap = WIDE_TCAP[k];
        // 아이콘은 10분할 칸과 같은 크기 (보조값 숫자 높이 기준) — 타이틀 줄이 그만큼 높아진다
        var isz = (C10_SCAP[k] * ICON_K + 0.5).toNumber();
        f.tlineH = (tcap * 1.25 + 0.5).toNumber();
        if (showIcon && isz > f.tlineH) {
            f.tlineH = isz;
        }
        f.titleY = f.T + (f.tlineH - tcap) / 2;
        f.topBase = f.titleY + tcap;
        if (showIcon) {
            f.iconSize = isz;
            f.iconX = f.L;
            f.iconTop = f.T + (f.tlineH - isz) / 2;
        }
        if (showBatt) {
            var bc = tcap;
            f.battW = (bc * 0.95 + 0.5).toNumber();
            f.battH = (bc * 0.52 + 0.5).toNumber();
            if (f.battH < 5) { f.battH = 5; }
            f.battRight = f.R;
            f.battCY = f.T + f.tlineH / 2;
        }

        var top = f.T + f.tlineH + pct(h, 0.04, 2);
        if (f.tall) {
            // 구동계는 칸 전체 가운데, 맨 아래 한 줄에 단수·기어비·톱니수
            f.footBase = f.B;
            f.areaL = f.L;
            f.areaR = f.R;
            f.areaTop = top;
            f.areaBot = f.B - f.subCap - pct(h, 0.02, 2);
            f.mainCenter = false;
            f.mainRight = f.L;                      // 아랫줄 왼쪽부터
            f.mainTop = f.B - f.subCap;
            f.warnTop = top - pct(h, 0.01, 1);
        } else {
            // 낮고 넓은 칸: 왼쪽에 정보 줄, 오른쪽에 구동계 (구동계가 칸 높이를 다 쓴다)
            f.divX = -1;
            f.mainCap = C10_SCAP[k];                // 기어 숫자는 작게 — 그만큼 동심원이 커진다
            f.areaL = f.L;
            f.areaR = f.R;
            f.areaTop = f.T;
            f.areaBot = f.B;
            f.mainCenter = false;
            f.mainRight = f.L;
            f.mainTop = f.B - f.mainCap;            // 기어 숫자는 왼쪽 아래
            f.footBase = f.B;
            f.bigRatio = (f.B - (f.T + f.tlineH) >= WIDE_VCAP[k]);
            f.ratioCap = f.bigRatio ? WIDE_VCAP[k] : C10_SCAP[k];
        }
        f.ringCY = (f.areaTop + f.areaBot) / 2;
        return f;
    }

    function min(a, b) { return (a < b) ? a : b; }
    function max(a, b) { return (a > b) ? a : b; }
}
