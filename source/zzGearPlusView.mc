using Toybox.Activity;
using Toybox.FitContributor;
using Toybox.Graphics;
using Toybox.System;
using Toybox.WatchUi;

// zzGearPlus 데이터 필드.
//   앞 체인링 + 뒤 카세트를 동심원으로 그리고, 현재 기어를 굵은 색 링으로 표시한다.
//   회색 링의 진하기 = 그 기어에서 보낸 시간. 크로스체인이면 현재 링·아이콘·기어비가 빨강.
// 레이아웃 XML 없이 코드로 그린다 (zzPowerPlus 와 같은 방식).
class zzGearPlusView extends WatchUi.DataField {

    hidden var mFrame = null;
    hidden var mMainF = null;       // 큰 숫자
    hidden var mSubF = null;        // 기어비 정수부 + 아이콘 '@'
    hidden var mDecF = null;        // 기어비 소수점 아래
    hidden var mHeadF = null;       // 앞기어 숫자 (메인의 70%)
    hidden var mTitleF = null;      // 넓은 칸 타이틀 + 아이콘
    hidden var mLabelF = null;      // 톱니수 라벨
    hidden var mIconF = null;       // 기어 아이콘 폰트 ('@' 글리프 하나, 칸 종류에 맞는 크기)

    hidden var mLastTimer = null;
    hidden var mRestored = false;
    hidden var mTick = 0;
    hidden var mBg = Graphics.COLOR_WHITE;
    hidden var mBig = false;        // 1050/1060 (화면폭 480 이상). onUpdate 에서 매번 묻지 않는다
    // 그리기 공통값: 인자로 넘기면 호출마다 스택을 먹는다 (데이터 필드 스택은 RAM 과 별개로 작다)
    hidden var mCfg = null;
    hidden var mDark = false;
    hidden var mFg = Graphics.COLOR_BLACK;
    hidden var mDim = Graphics.COLOR_DK_GRAY;
    hidden var mAccent = Graphics.COLOR_ORANGE;
    hidden var mBlue = Graphics.COLOR_DK_BLUE;
    hidden var mRatioColor = Graphics.COLOR_DK_BLUE;
    hidden var mCross = false;

    hidden var mFitFront = null;
    hidden var mFitRear = null;
    hidden var mFitRatio = null;

    function initialize() {
        DataField.initialize();
        Gears.start();
        try {
            mFitFront = createField("front_gear", 0, FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_RECORD });
            mFitRear = createField("rear_gear", 1, FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_RECORD });
            mFitRatio = createField("gear_ratio", 2, FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_RECORD });
        } catch (ex) {
            mFitFront = null;
            mFitRear = null;
            mFitRatio = null;
        }
    }

    function onSettingsChanged() {
        mFrame = null;
    }

    // ---- 데이터 (1Hz) ------------------------------------------------

    function compute(info) {
        mTick++;

        var running = true;
        if (info has :timerState) {
            running = (info.timerState == Activity.TIMER_STATE_ON);
        }

        var t = (info has :timerTime) ? info.timerTime : null;
        var dt = 0;
        if (t != null) {
            if (!mRestored) {
                mRestored = true;
                if (t > 0) {
                    var saved = Gears.restore(t);
                    if (saved != null) {
                        mLastTimer = saved;
                    }
                }
            }
            if (mLastTimer != null && t < mLastTimer) {
                Gears.reset();                  // 새 활동
                mLastTimer = null;
            }
            if (mLastTimer != null) {
                var d = t - mLastTimer;
                if (running && d > 0 && d < 5000) {
                    dt = d;
                }
            }
            mLastTimer = t;
        }

        Gears.update(info, dt);

        if (mTick % 10 == 1) {
            Gears.pollBattery();
        }
        if (mTick % 60 == 0 && t != null) {
            Gears.save(t);
        }

        if (running) {
            // 그래프에는 톱니 수를 남긴다 (단수보다 해석하기 쉽고 단위가 T 로 맞는다)
            if (mFitFront != null && Gears.fSize != null) {
                mFitFront.setData(Gears.fSize);
            }
            if (mFitRear != null && Gears.rSize != null) {
                mFitRear.setData(Gears.rSize);
            }
            if (mFitRatio != null) {
                var r = Gears.ratio();
                if (r != null) {
                    mFitRatio.setData(r);
                }
            }
        }
    }

    function persist() {
        if (mLastTimer != null) {
            Gears.save(mLastTimer);
        }
    }

    function onTimerPause() {
        persist();
    }

    function onTimerStop() {
        persist();
    }

    function onTimerReset() {
        Gears.reset();
        mLastTimer = null;
        mRestored = false;
    }

    // ---- 폰트 / 프레임 ------------------------------------------------

    hidden function makeFrame(dc) {
        var cfg = Config.read();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var screenW = System.getDeviceSettings().screenWidth;
        mBig = (screenW >= 480);

        mMainF = null;
        mSubF = null;
        mDecF = null;
        mHeadF = null;
        mTitleF = null;
        mLabelF = null;
        mIconF = null;

        if (w > screenW * 0.75) {
            mFrame = Layout.computeWide(w, h, screenW, cfg.showIcon, cfg.showBatt, cfg.showTeeth);
            mTitleF = WatchUi.loadResource(Rez.Fonts.WideTitle);
            mLabelF = WatchUi.loadResource(Rez.Fonts.WideLabel);
            if (cfg.showIcon) {
                mIconF = WatchUi.loadResource(Rez.Fonts.IconSub);   // 아이콘 크기는 10분할 칸과 동일
            }
            if (mFrame.tall) {
                mSubF = WatchUi.loadResource(Rez.Fonts.C10Sub);
                mDecF = WatchUi.loadResource(Rez.Fonts.C10Dec);
            } else {
                mMainF = WatchUi.loadResource(Rez.Fonts.C10Sub);   // 넓고 낮은 칸의 기어 숫자 (작게)
            }
        } else {
            mFrame = Layout.compute(w, h, screenW, cfg.showIcon, cfg.showBatt);
            mMainF = WatchUi.loadResource(Rez.Fonts.C10Main);
            mSubF = WatchUi.loadResource(Rez.Fonts.C10Sub);
            mDecF = WatchUi.loadResource(Rez.Fonts.C10Dec);
            mHeadF = WatchUi.loadResource(Rez.Fonts.C10Head);
            if (cfg.showIcon && mFrame.iconSize > 0) {
                mIconF = WatchUi.loadResource(Rez.Fonts.IconSub);
            }
        }
    }

    function onLayout(dc) {
        makeFrame(dc);
    }

    // ---- 그리기 ------------------------------------------------------

    function onUpdate(dc) {
        var cfg = Config.read();
        if (mFrame == null || mFrame.w != dc.getWidth() || mFrame.h != dc.getHeight()) {
            makeFrame(dc);
        }
        var f = mFrame;

        // 배경색 (설정 bgMode)
        //   0 자동 : 1050/1060 은 기기 화면과 같은 색으로 칠한다 (#17181D / 남색 글씨)
        //   1 그대로 : 기기가 알려준 검정·흰색 그대로 칠한다
        //   2 투명 : 아예 칠하지 않아 기기 배경이 그대로 비친다 (테마가 무엇이든 일치)
        var bg = getBackgroundColor();
        var sysClear = (bg == Graphics.COLOR_TRANSPARENT);   // 기기가 "투명"이라고 알려준 경우
        var dark = (bg == Graphics.COLOR_BLACK || sysClear);
        var soft = mBig && (cfg.bgMode != Config.BG_PLAIN);
        var fg;
        if (dark) {
            bg = soft ? 0x17181D : Graphics.COLOR_BLACK;
            fg = Graphics.COLOR_WHITE;
        } else {
            bg = soft ? 0xDCDCDC : Graphics.COLOR_WHITE;   // 1050/1060 의 밝은 배경은 순백이 아니다
            fg = soft ? 0x313152 : Graphics.COLOR_BLACK;
        }
        var dim = dark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;

        mBg = bg;
        // 지우기만 투명으로 (mBg 는 도형 속을 파낼 때 쓰므로 실제 색 유지).
        // 자동 모드에서도 기기가 투명이라고 알려줬으면 칠하지 않는다 - 그게 색이 어긋나던 원인.
        var noFill = (cfg.bgMode == Config.BG_CLEAR)
                  || (cfg.bgMode == Config.BG_AUTO && sysClear);
        var clearBg = noFill ? Graphics.COLOR_TRANSPARENT : bg;
        dc.setColor(clearBg, clearBg);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var cross = Gears.cross(cfg.crossWarn, cfg.reverseRear);
        var accent = cross ? (dark ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED)
                           : Graphics.COLOR_ORANGE;
        var blue = dark ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE;
        var ratioColor = cross ? accent : blue;

        mCfg = cfg;
        mDark = dark;
        mFg = fg;
        mDim = dim;
        mAccent = accent;
        mBlue = blue;
        mRatioColor = ratioColor;
        mCross = cross;

        if (f.wide) {
            // 호출 깊이를 줄이려고 drawWide 를 거치지 않고 바로 나눈다
            var title = (f.w < 300) ? "zzGear+" : "zzGearPlus";
            if (f.tall) {
                drawWideTall(dc, f, title);
            } else {
                drawWideShort(dc, f, title);
            }
        } else {
            drawNarrow(dc, f);
        }
    }

    // ---- 좁은 칸 ----
    hidden function drawNarrow(dc, f) {
        if (mCfg.gearView == Config.GV_BAR) {
            // 막대는 칸을 다 쓰고, 오른쪽 위 빈 자리에 기어 숫자를 넣는다
            drawBars(dc, f.L, f.R, f.areaTop, f.B, false);
            var areaH = f.B - f.areaTop;
            var big = (f.mainCap <= (areaH * 62) / 100);
            var cap = big ? f.mainCap : f.subCap;
            drawMainNarrow(dc, f, ((f.R - f.L) * 45) / 100, f.areaTop + cap + f.ug);
        } else {
            // 1) 동심원: 크기는 칸 높이로 고정, 자리만 오른쪽으로 10%
            var rr = (f.areaBot - f.areaTop) / 2;
            var cx = f.areaL + rr + (f.w * 10) / 100;
            if (cx + rr > f.R) {
                cx = f.R - rr;
            }
            if (rr > 8) {
                drawCassette(dc, cx, f.ringCY, rr);
            }

            // 2) 기어 숫자: 동심원 오른쪽에 남는 폭에 맞춰 (앞기어는 70% 크기)
            drawMainNarrow(dc, f, f.R - (cx + rr) - f.ug * 2, f.B);
        }

        // 3) 윗줄: 아이콘 / 바깥쪽 끝 배터리 / 그 안쪽 기어비
        var xr = f.R;
        if (f.battW > 0 && Gears.battStatus != null) {
            drawBattery(dc, f.battRight, f.battCY, f.battW, f.battH, Gears.battStatus);
            xr = f.battRight - f.battW - (f.battH / 5) - f.ug * 2;
        }
        drawIcon(dc, f.iconX, f.iconTop, mAccent);
        if (f.topBase > f.T && mSubF != null) {
            var tv = topValue(false);
            if (tv != null) {
                drawRatio(dc, xr, f.topBase, f.subCap, f.decCap, mSubF, mDecF, mRatioColor, tv);
            }
        }
    }

    // 좁은 칸 기어 숫자. 앞기어는 뒷기어의 70% 크기로 앞에 붙인다.
    //  avail 안에 들어가는 가장 큰 조합을 고른다 (메인+70% -> 보조+소수 -> 보조만)
    hidden function drawMainNarrow(dc, f, avail, baseY) {
        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        if (mCfg.mainValue == Config.MAIN_RATIO || Gears.oneX() || Gears.fIdx == null) {
            // 한 덩어리 (기어비 표시거나 1x)
            var one = mainValue(false);
            var oneRef = mainRef(false);
            var fo = mMainF;
            var co = f.mainCap;
            if (dc.getTextWidthInPixels(oneRef, mMainF) > avail && mSubF != null) {
                fo = mSubF;
                co = f.subCap;
            }
            dc.drawText(f.mainRight, baseY - co, fo, one, Graphics.TEXT_JUSTIFY_RIGHT);
            return;
        }

        var head = Gears.fIdx.toString() + "-";                      // "2-"
        var tail = Gears.rIdx.toString();                            // "8"
        var refHead = ((Gears.fMax != null) ? Gears.fMax : 2).toString() + "-";
        var refTail = ((Gears.rMax != null) ? Gears.rMax : 12).toString();

        var ft = mMainF;
        var fh = mHeadF;
        var ct = f.mainCap;
        var ch = f.headCap;
        if (dc.getTextWidthInPixels(refTail, ft) + dc.getTextWidthInPixels(refHead, fh) > avail) {
            ft = mSubF;
            fh = mDecF;
            ct = f.subCap;
            ch = f.decCap;
        }
        if (ft == null || fh == null) {
            ft = mSubF;
            fh = mSubF;
            ct = f.subCap;
            ch = f.subCap;
        }
        dc.drawText(f.mainRight, baseY - ct, ft, tail, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(f.mainRight - dc.getTextWidthInPixels(tail, ft), baseY - ch, fh, head, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---- 넓은 칸 ----
    // 넓고 낮은 칸 (높은 칸은 onUpdate 에서 drawWideTall 로 바로 간다)
    hidden function drawWideShort(dc, f, title) {
        // 왼쪽 위 아이콘 + 이름 / 왼쪽 아래 기어 숫자 / 오른쪽 위 기어비 + 배터리
        // 가운데: 구동계 (타이틀 줄 아래 높이를 다 쓴다)
        var x = f.L;
        if (mIconF != null) {
            drawIcon(dc, x, f.iconTop, mAccent);
            x += dc.getTextWidthInPixels("@", mIconF) + f.ug;
        }
        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, f.titleY, mTitleF, title, Graphics.TEXT_JUSTIFY_LEFT);
        var leftEnd = x + dc.getTextWidthInPixels(title, mTitleF);

        // 왼쪽 아래: 기어 숫자
        var wRef = dc.getTextWidthInPixels(mainRef(true), mMainF);
        dc.drawText(f.L, f.mainTop, mMainF, mainValue(true), Graphics.TEXT_JUSTIFY_LEFT);
        if (f.L + wRef > leftEnd) {
            leftEnd = f.L + wRef;
        }

        // 오른쪽 위: 바깥쪽 끝에 배터리, 그 왼쪽에 기어비 (10분할 칸과 같은 크기)
        var xr = f.R;
        if (f.battW > 0 && Gears.battStatus != null) {
            drawBattery(dc, f.battRight, f.battCY, f.battW, f.battH, Gears.battStatus);
            xr = f.battRight - f.battW - f.battH / 5 - f.ug * 2;
        }
        var rs = ratioStr();
        if (rs != null) {
            dc.setColor(mRatioColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xr, f.T + (f.tlineH - f.subCap) / 2, mMainF, rs, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // 구동계: 타이틀 줄 아래부터 칸 바닥까지 (앞 체인링이 10분할 칸 동심원과 같은 크기가 된다)
        drawTrain(dc, f, leftEnd + f.ug * 2, f.R, f.T + f.tlineH, f.B, 100, f.w / 2);
    }

    // 넓고 높은 칸: 구동계를 가운데 크게, 맨 아랫줄에 단수·기어비·톱니수
    hidden function drawWideTall(dc, f, title) {
        var x = f.L;
        if (mIconF != null) {
            drawIcon(dc, x, f.iconTop, mAccent);
            x += dc.getTextWidthInPixels("@", mIconF) + f.ug;
        }
        if (f.battW > 0 && Gears.battStatus != null) {
            drawBattery(dc, f.battRight, f.battCY, f.battW, f.battH, Gears.battStatus);
        }
        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, f.titleY, mTitleF, title, Graphics.TEXT_JUSTIFY_LEFT);

        var areaTop = f.areaTop;
        if (mCross && f.warnTop >= 0) {
            var warn = WatchUi.loadResource(Rez.Strings.crossMsg);
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(f.w / 2, f.warnTop, Graphics.FONT_XTINY, warn, Graphics.TEXT_JUSTIFY_CENTER);
            areaTop = f.warnTop + dc.getFontHeight(Graphics.FONT_XTINY);
        }
        drawTrain(dc, f, f.L, f.R, areaTop, f.areaBot, 95, -1);

        // 맨 아랫줄: 단수 + 기어비 (+ 톱니수)
        var s = mainValue(true);
        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(f.L, f.mainTop, mSubF, s, Graphics.TEXT_JUSTIFY_LEFT);
        var x2 = f.L + dc.getTextWidthInPixels(mainRef(true), mSubF) + f.ug * 2;
        x2 = drawRatioLeft(dc, x2, f.footBase, f.subCap, f.decCap, mSubF, mDecF, mRatioColor, topValue(true));
        if (mCfg.showTeeth && mLabelF != null) {
            var teeth = teethStr();
            if (teeth != null && x2 + f.ug * 2 + dc.getTextWidthInPixels(teeth, mLabelF) <= f.R) {
                dc.setColor(mDim, Graphics.COLOR_TRANSPARENT);
                dc.drawText(f.R, f.footBase - f.labelCap, mLabelF, teeth, Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
    }

    // 앞 체인링 + 뒤 카세트를 주어진 네모 안에 가장 크게 그린다.
    //  fcx >= 0 이면 크기는 그대로 두고 앞 체인링 가운데만 그 x 로 옮긴다 (칸 밖으로 나가면 안쪽으로 당김)
    hidden function drawTrain(dc, f, aL, aR, aTop, aBot, pct, fcx) {
        var availH = aBot - aTop;
        var areaW = aR - aL;
        if (availH <= 16 || areaW <= 16) {
            return;
        }
        if (mCfg.gearView == Config.GV_BAR) {
            var cut = (availH * (100 - pct)) / 200;
            drawBars(dc, aL, aR, aTop + cut, aBot - cut, !Gears.oneX());
            return;
        }

        var cy = (aTop + aBot) / 2;
        if (Gears.oneX()) {
            var rc = (Layout.min(availH / 2, areaW / 2) * pct) / 100;
            drawCassette(dc, (aL + aR) / 2, cy, rc);
            return;
        }
        var rf = (Layout.min(availH / 2, (areaW * 25) / 100) * pct) / 100;
        if (rf < 6) {
            return;
        }
        var rc2 = (rf * 10) / 12;
        var gap = (rf * 22) / 100;
        var gw = 2 * rf + gap + 2 * rc2;
        var fx = (aL + aR) / 2 - gw / 2 + rf;
        if (fcx >= 0) {
            fx = fcx;
            if (fx + rf + gap + 2 * rc2 > aR) {
                fx = aR - gap - 2 * rc2 - rf;
            }
            if (fx - rf < aL) {
                fx = aL + rf;
            }
        }
        drawFront(dc, fx, cy, rf);
        drawCassette(dc, fx + rf + gap + rc2, cy, rc2);
    }

    // 기어 아이콘: 글리프 하나짜리 폰트 (안티앨리어싱 + 글자색 그대로)
    hidden function drawIcon(dc, x, y, color) {
        if (mIconF == null) {
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, mIconF, "@", Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ---- 카세트 옆모습(막대) ------------------------------------------

    // 막대 하나 = 스프라켓 하나. 높이 = 톱니 크기, 가로 자리 = 단수.
    //  회색 진하기는 동심원과 같은 뜻 (그 기어에서 보낸 시간).
    //  현재 기어는 주황(크로스체인이면 빨강)으로 칠하고 위에 짧은 선을 하나 더 찍는다.
    hidden function drawBars(dc, aL, aR, aTop, aBot, withFront) {
        var h = aBot - aTop;
        var w = aR - aL;
        if (h < 10 || w < 20) {
            return;
        }

        var n = (Gears.rMax != null) ? Gears.rMax : 12;
        if (n < 2) { n = 2; }
        if (n > 12) { n = 12; }

        var fn = 0;
        if (withFront) {
            fn = (Gears.fMax != null) ? Gears.fMax : 2;
            if (fn < 1) { fn = 1; }
            if (fn > 3) { fn = 3; }
        }

        var slots = n + ((fn > 0) ? fn + 1 : 0);     // 앞기어 + 구분 한 칸
        var step = w / slots;
        if (step < 3 && fn > 0) {                    // 좁으면 앞기어는 접는다
            fn = 0;
            slots = n;
            step = w / slots;
        }
        if (step < 2) {
            return;
        }
        var bw = (step * 58) / 100;
        if (bw < 2) { bw = 2; }
        var mark = h / 12;
        if (mark < 2) { mark = 2; }
        var bh0 = h - mark - 1;                      // 현재 기어 표시선 자리를 위에 남긴다
        if (bh0 < 6) { bh0 = h; }

        var x = aL + (w - step * slots) / 2;         // 남는 폭은 양쪽에 반씩
        var base = mDark ? 0x3A3A40 : 0xC6C6CC;

        if (fn > 0) {
            var fcur = Gears.frontPos();
            for (var i = 0; i < fn; i++) {
                var fh = (fn <= 1) ? bh0 : ((bh0 * (58 + (42 * i) / (fn - 1))) / 100);
                var fx = x + (step - bw) / 2;
                if (i == fcur) {
                    dc.setColor(mBlue, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(fx, aBot - fh, bw, fh);
                    dc.fillRectangle(fx, aBot - fh - mark - 1, bw, mark);
                } else {
                    dc.setColor(base, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(fx, aBot - fh, bw, fh);
                }
                x += step;
            }
            dc.setColor(mDim, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + step / 2, aTop + h / 5, 1, h - h / 5);
            x += step;
        }

        var cur = Gears.rearPos();
        var small = !mCfg.reverseRear;               // 뒤 1단 = 가장 작은 스프라켓
        for (var pos = 0; pos < n; pos++) {
            // 왼쪽이 큰 스프라켓 — 실제 카세트를 옆에서 본 순서.
            //  오른쪽 위가 비므로 그 자리에 기어 숫자를 넣는다.
            var j = small ? (n - 1 - pos) : pos;
            var p = (n <= 1) ? 0 : ((60 * pos) / (n - 1));
            var bh = (bh0 * (100 - p)) / 100;
            var bx = x + (step - bw) / 2;
            if (j == cur) {
                dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, aBot - bh, bw, bh);
                dc.fillRectangle(bx, aBot - bh - mark - 1, bw, mark);
            } else {
                dc.setColor(ringColor(j, n, n), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, aBot - bh, bw, bh);
            }
            x += step;
        }
    }

    // ---- 동심원 ------------------------------------------------------

    // 뒤 카세트: 링 간격·굵기 균일, 안쪽 = 가벼운 기어(작은 톱니), 바깥 = 무거운 기어.
    //  회색 링의 진하기 = 그 기어에서 보낸 시간. 현재 기어만 굵은 주황(크로스체인이면 빨강).
    hidden function drawCassette(dc, cx, cy, R) {
        var n = (Gears.rMax != null) ? Gears.rMax : 12;
        if (n < 2) { n = 2; }
        if (n > 12) { n = 12; }
        var cur = Gears.rearPos();
        var shown = n;
        if (R * 2 < 64 && n > 6) {
            shown = 6;                                  // 작은 칸은 링을 줄인다
        }
        var hole = (R * 34) / 100;
        var sp = (R - hole) / (shown - 1);
        var w0 = (sp * 40) / 100;
        if (w0 < 1) { w0 = 1; }
        var wc = sp;
        if (wc < 2) { wc = 2; }

        var curShown = -1;
        if (cur >= 0) {
            curShown = (n <= 1) ? 0 : ((cur * (shown - 1)) / (n - 1));
        }

        for (var i = 0; i < shown; i++) {
            if (i == curShown) {
                continue;
            }
            var col = ringColor(i, shown, n);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(w0);
            dc.drawCircle(cx, cy, hole + sp * i);
        }
        if (curShown >= 0) {
            dc.setColor(mAccent, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(wc);
            dc.drawCircle(cx, cy, hole + sp * curShown);
        }
        dc.setPenWidth(1);
    }

    // 앞 체인링: 실제처럼 뒤보다 크다. 현재 쪽이 파랑, 굵기는 카세트와 같다.
    hidden function drawFront(dc, cx, cy, R) {
        var n = (Gears.fMax != null) ? Gears.fMax : 2;
        if (n < 1) { n = 1; }
        if (n > 3) { n = 3; }
        var cur = Gears.frontPos();
        var base = mDark ? 0x3A3A40 : 0xC6C6CC;
        var w0 = (R * 7) / 100;
        if (w0 < 1) { w0 = 1; }
        var wc = (R * 11) / 100;
        if (wc < 2) { wc = 2; }
        for (var i = 0; i < n; i++) {
            var r = (n <= 1) ? R : ((R * (68 + (32 * i) / (n - 1))) / 100);
            if (i == cur) {
                dc.setColor(mBlue, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(wc);
            } else {
                dc.setColor(base, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(w0);
            }
            dc.drawCircle(cx, cy, r);
        }
        dc.setPenWidth(1);
    }

    // 사용 시간이 많은 기어일수록 진한 회색 (굵기는 건드리지 않는다)
    hidden function ringColor(i, shown, n) {
        var base = mDark ? 0x3A3A40 : 0xC6C6CC;
        var used = mDark ? 0x8A8A92 : 0x808086;
        if (!mCfg.showUsage) {
            return base;
        }
        var idx = (shown == n) ? i : ((i * (n - 1)) / (shown - 1));
        // 호출 깊이를 줄이려고 Gears.useRatio / blend 를 여기에 펼쳤다
        // (넓고 높은 칸은 onUpdate 에서 여기까지 7단계라 스택이 모자랐다)
        var u = Gears.usage;
        if (u == null || Gears.usageMax <= 0 || idx < 0 || idx >= Gears.MAX_REAR) {
            return base;
        }
        var t = u[idx].toFloat() / Gears.usageMax.toFloat();
        if (t <= 0.0) {
            return base;
        }
        if (t > 1.0) { t = 1.0; }
        var r1 = (base >> 16) & 0xFF;
        var g1 = (base >> 8) & 0xFF;
        var b1 = base & 0xFF;
        var r = (r1 + (((used >> 16) & 0xFF) - r1) * t).toNumber();
        var g = (g1 + (((used >> 8) & 0xFF) - g1) * t).toNumber();
        var b = (b1 + ((used & 0xFF) - b1) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    hidden function blend(c1, c2, t) {
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;
        var r = (r1 + (r2 - r1) * t).toNumber();
        var g = (g1 + (g2 - g1) * t).toNumber();
        var b = (b1 + (b2 - b1) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // ---- 배터리 ------------------------------------------------------
    // ANT+ 는 퍼센트가 아니라 5단계 상태를 준다 (1 새것 / 2 좋음 / 3 보통 / 4 낮음 / 5 위험).
    //  시계앱과 같은 색: 보통 이상 초록, 낮음 노랑, 위험 빨강.
    hidden function drawBattery(dc, right, cy, w, h, status) {
        var col = mDim;
        var fill = 0;
        if (status <= 2) {
            col = mDark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
            fill = 100;
        } else if (status == 3) {
            col = mDark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
            fill = 65;
        } else if (status == 4) {
            col = Graphics.COLOR_YELLOW;
            fill = 35;
        } else {
            col = mDark ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED;
            fill = 12;
        }
        var tip = h / 5;
        if (tip < 1) { tip = 1; }
        var x = right - w - tip;
        var y = cy - h / 2;
        var pen = h / 8;
        if (pen < 1) { pen = 1; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawRectangle(x, y, w, h);
        dc.fillRectangle(x + w, y + (h * 3) / 10, tip, (h * 4) / 10);
        var ins = pen * 2;
        var fw = ((w - 2 * ins) * fill) / 100;
        if (fw > 0) {
            dc.fillRectangle(x + ins, y + ins, fw, h - 2 * ins);
        }
        dc.setPenWidth(1);
    }

    // ---- 글자 --------------------------------------------------------

    // 기어비. 오른쪽 정렬, 왼쪽 끝 x 를 돌려준다 (소수점 아래도 같은 크기)
    hidden function drawRatio(dc, right, base, cap, dcap, bigF, smallF, color, s) {
        if (s == null || bigF == null) {
            return right;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right, base - cap, bigF, s, Graphics.TEXT_JUSTIFY_RIGHT);
        return right - dc.getTextWidthInPixels(s, bigF);
    }

    // 왼쪽 정렬 기어비. 오른쪽 끝 x 를 돌려준다
    hidden function drawRatioLeft(dc, x, base, cap, dcap, bigF, smallF, color, s) {
        if (s == null || bigF == null) {
            return x;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, base - cap, bigF, s, Graphics.TEXT_JUSTIFY_LEFT);
        return x + dc.getTextWidthInPixels(s, bigF);
    }

    // 큰 숫자 (설정: 기어 단수 / 기어비). withFront: 앞 단수까지 붙일지 (좁은 칸은 뒤 단수만)
    hidden function mainValue(withFront) {
        if (mCfg.mainValue == Config.MAIN_RATIO) {
            var r = ratioStr();
            return (r != null) ? r : "--";
        }
        return Gears.gearStr(withFront);
    }

    // 큰 숫자 자리에 들어갈 수 있는 가장 긴 문자열 (글자 크기 고정용)
    hidden function mainRef(withFront) {
        if (mCfg.mainValue == Config.MAIN_RATIO) {
            return "9.9";
        }
        return Gears.refStr(withFront);
    }

    // 윗줄 보조값 (큰 숫자의 반대쪽). 값이 없으면 null -> 그리지 않는다
    hidden function topValue(withFront) {
        if (mCfg.mainValue == Config.MAIN_RATIO) {
            return Gears.gearStr(withFront);
        }
        return ratioStr();
    }

    hidden function ratioStr() {
        var r = Gears.ratio();
        if (r == null) {
            return null;
        }
        var n = (r * 10 + 0.5).toNumber();
        return (n / 10).toString() + "." + (n % 10).toString();
    }

    hidden function teethStr() {
        if (Gears.fSize == null || Gears.rSize == null) {
            return null;
        }
        if (Gears.oneX()) {
            return Gears.fSize.toString() + " / " + Gears.rSize.toString() + " T";
        }
        return Gears.fSize.toString() + " / " + Gears.rSize.toString() + " T";
    }
}
