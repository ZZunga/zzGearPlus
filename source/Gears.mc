using Toybox.Activity;
using Toybox.AntPlus;
using Toybox.Application.Storage;
using Toybox.Lang;

// 기어 데이터.
//  1순위: Activity.Info 의 frontDerailleur*/rearDerailleur* (가민이 직접 해석 — 시마노 Di2 도 들어온다)
//         이 값은 1 부터 센다 (BRM기어에서 확인한 동작).
//  2순위: AntPlus.Shifting 리스너 (Info 가 비어 있을 때). ANT+ 원값은 0 부터이므로 +1 해서 맞춘다.
//  배터리: AntPlus.Shifting.getBatteryStatus() — 5단계 상태값 (스램 AXS 등. 시마노 Di2 는 주지 않는다)
// 기어별 사용 시간은 뒤 단수 기준으로 누적한다 (타이머가 흐른 만큼만 더하므로 자동 일시정지는 빠진다).
module Gears {

    const MAX_REAR = 13;        // 사용 시간 배열 크기 (12단 + 여유)

    // 시뮬레이터용 가짜 기어 데이터. 시뮬레이터는 변속기 값을 못 넣으므로
    // 화면을 확인할 때만 true 로 바꿔서 빌드한다 (스토어 빌드는 반드시 false).
    const DEMO = false;
    const DEMO_CAS = [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34];
    const DEMO_FR = [34, 50];
    var _demoTick = 0;

    var fIdx = null;            // 앞 단수 (1 부터)
    var fMax = null;            // 앞 단 수
    var fSize = null;           // 앞 톱니 수
    var rIdx = null;            // 뒤 단수 (1 부터, 1 = 가장 작은 스프라켓이 기본)
    var rMax = null;
    var rSize = null;

    var battStatus = null;      // AntPlus.BATT_STATUS_* (1 새것 ~ 5 위험), null = 모름

    var usage as Lang.Array<Lang.Number> or Null = null;    // 뒤 단수별 누적 ms (0 번째 = 1단)
    var usageMax = 0;

    var _shift = null;
    var _listener = null;
    var _antF = null;
    var _antFMax = null;
    var _antFSize = null;
    var _antR = null;
    var _antRMax = null;
    var _antRSize = null;

    class Listener extends AntPlus.ShiftingListener {
        function initialize() {
            AntPlus.ShiftingListener.initialize();
        }

        // data: AntPlus.ShiftingStatus (frontDerailleur / rearDerailleur = DerailleurStatus)
        function onShiftingUpdate(data) {
            var f = data.frontDerailleur;
            if (f != null) {
                if (f.gearIndex != null && f.gearIndex < AntPlus.FRONT_GEAR_INVALID) { Gears._antF = f.gearIndex + 1; }
                if (f.gearMax != null && f.gearMax != AntPlus.MAX_GEARS_INVALID) { Gears._antFMax = f.gearMax; }
                if (f.gearSize != null && f.gearSize > 0) { Gears._antFSize = f.gearSize; }
            }
            var r = data.rearDerailleur;
            if (r != null) {
                if (r.gearIndex != null && r.gearIndex < AntPlus.REAR_GEAR_INVALID) { Gears._antR = r.gearIndex + 1; }
                if (r.gearMax != null && r.gearMax != AntPlus.MAX_GEARS_INVALID) { Gears._antRMax = r.gearMax; }
                if (r.gearSize != null && r.gearSize > 0) { Gears._antRSize = r.gearSize; }
            }
        }
    }

    function start() {
        if (_shift != null) {
            return;
        }
        try {
            _listener = new Listener();
            _shift = new AntPlus.Shifting(_listener);
        } catch (ex) {
            _shift = null;
            _listener = null;
        }
    }

    function reset() {
        usage = null;
        usageMax = 0;
        try {
            Storage.deleteValue("gearUse");
            Storage.deleteValue("gearUseT");
        } catch (ex) {
        }
    }

    function pickVal(v, fallback) {
        if (v != null && v > 0) {
            return v;
        }
        return fallback;
    }

    // 시뮬레이터용: 2초마다 한 단씩 오르내리고, 양 끝에서 앞 체인링이 바뀐다
    function demo() {
        _demoTick++;
        var n = DEMO_CAS.size();
        var step = (_demoTick / 2) % (n * 2);
        var i = (step < n) ? step : (n * 2 - 1 - step);
        rMax = n;
        rIdx = i + 1;
        rSize = DEMO_CAS[i];
        fMax = 2;
        fIdx = (i < 3) ? 1 : 2;          // 양 끝에서 크로스체인이 한 번씩 보이도록
        fSize = DEMO_FR[fIdx - 1];
        battStatus = 3;
    }

    // 1Hz. dtMs = 지난 1초 동안 타이머가 흐른 시간 (0 이면 누적하지 않는다)
    function update(info, dtMs) {
        if (DEMO) {
            demo();
        } else if (info != null) {
            fIdx  = pickVal((info has :frontDerailleurIndex) ? info.frontDerailleurIndex : null, _antF);
            fMax  = pickVal((info has :frontDerailleurMax) ? info.frontDerailleurMax : null, _antFMax);
            fSize = pickVal((info has :frontDerailleurSize) ? info.frontDerailleurSize : null, _antFSize);
            rIdx  = pickVal((info has :rearDerailleurIndex) ? info.rearDerailleurIndex : null, _antR);
            rMax  = pickVal((info has :rearDerailleurMax) ? info.rearDerailleurMax : null, _antRMax);
            rSize = pickVal((info has :rearDerailleurSize) ? info.rearDerailleurSize : null, _antRSize);
        }

        if (fMax != null && fMax > 7) { fMax = null; }
        if (rMax != null && rMax > 31) { rMax = null; }
        if (fIdx != null && fMax != null && fIdx > fMax) { fIdx = fMax; }
        if (rIdx != null && rMax != null && rIdx > rMax) { rIdx = rMax; }

        if (dtMs > 0 && rIdx != null && rIdx >= 1 && rIdx <= MAX_REAR) {
            var u = usage;
            if (u == null) {
                u = new [MAX_REAR];
                for (var i = 0; i < MAX_REAR; i++) { u[i] = 0; }
                usage = u;
            }
            var k = rIdx - 1;
            u[k] = u[k] + dtMs;
            if (u[k] > usageMax) { usageMax = u[k]; }
        }
    }

    // 배터리 상태 (10초에 한 번만 물어본다)
    function pollBattery() {
        if (_shift == null) {
            return;
        }
        try {
            var all = null;                 // 부품 번호 없음 = 시스템 전체 (SDK 타입은 Number 로 적혀 있다)
            var b = _shift.getBatteryStatus(all);
            if (b != null && b.batteryStatus != null) {
                var s = b.batteryStatus;
                battStatus = (s >= 1 && s <= 5) ? s : null;
            }
        } catch (ex) {
            battStatus = null;
        }
    }

    // 1x 구동계인가. 앞 정보가 아직 없으면 2x 로 보고 앞 체인링도 그린다
    function oneX() {
        return (fMax != null && fMax <= 1);
    }

    function haveGear() {
        return (rIdx != null);
    }

    // 기어비 (앞/뒤 톱니). 톱니 수를 모르면 null
    function ratio() {
        if (fSize == null || rSize == null || rSize <= 0) {
            return null;
        }
        return fSize.toFloat() / rSize.toFloat();
    }

    // 표시용 기어 문자열. withFront 가 false 거나 1x 면 뒤 단수만
    function gearStr(withFront) {
        if (rIdx == null) {
            return "--";
        }
        var r = rIdx.toString();
        if (!withFront || oneX() || fIdx == null) {
            return r;
        }
        return fIdx.toString() + "-" + r;
    }

    // 글자 크기 기준이 되는 가장 긴 문자열 ("2-12" / "12")
    function refStr(withFront) {
        var n = (rMax != null) ? rMax : 12;
        var r = n.toString();
        if (!withFront || oneX()) {
            return r;
        }
        var f = (fMax != null) ? fMax : 2;
        return f.toString() + "-" + r;
    }

    // 크로스체인: 큰 체인링 + 가장 가벼운 쪽 끝, 작은 체인링 + 가장 무거운 쪽 끝
    //  mode: Config.CROSS_OFF / CROSS_EDGE (끝 1단) / CROSS_WIDE (끝 2단)
    //  뒤 1단 = 가장 작은 스프라켓이 기본. 반대로 매기는 구동계는 설정(reverseRear)으로 뒤집는다.
    function cross(mode, reverseRear) {
        if (mode == 0 || oneX() || fIdx == null || rIdx == null || rMax == null || fMax == null) {
            return false;
        }
        var n = (mode == 2) ? 2 : 1;
        if (rMax <= n * 2) {
            return false;
        }
        var small = (rIdx <= n);                // 가장 작은 스프라켓 쪽
        var large = (rIdx > rMax - n);          // 가장 큰 스프라켓 쪽
        if (reverseRear) {
            var t = small;
            small = large;
            large = t;
        }
        if (fIdx >= fMax) {
            return large;                       // 큰 체인링 + 큰 스프라켓
        }
        if (fIdx <= 1) {
            return small;                       // 작은 체인링 + 작은 스프라켓
        }
        return false;
    }

    // 그릴 때 쓰는 현재 뒤 기어 (0 부터). 모르면 -1
    function rearPos() {
        if (rIdx == null) {
            return -1;
        }
        return rIdx - 1;
    }

    // 앞 기어 (0 부터). 모르면 -1
    function frontPos() {
        if (fIdx == null) {
            return -1;
        }
        return fIdx - 1;
    }

    // i 번째(0 부터) 뒤 기어의 사용 비율 (0.0 ~ 1.0)
    function useRatio(i) {
        var u = usage;
        if (u == null || usageMax <= 0 || i < 0 || i >= MAX_REAR) {
            return 0.0;
        }
        return u[i].toFloat() / usageMax.toFloat();
    }

    // ---- 저장 (활동 중 앱이 다시 켜져도 사용 시간 유지) ----
    function save(timerMs) {
        if (usage == null) {
            return;
        }
        try {
            Storage.setValue("gearUse", usage);
            Storage.setValue("gearUseT", timerMs);
        } catch (ex) {
        }
    }

    // 저장된 사용 시간 복원. 저장 당시 타이머 값을 돌려준다 (없으면 null)
    function restore(timerMs) {
        try {
            var t = Storage.getValue("gearUseT");
            var u = Storage.getValue("gearUse");
            if (t == null || u == null || !(u instanceof Lang.Array) || u.size() != MAX_REAR) {
                return null;
            }
            if (t > timerMs + 5000) {
                return null;                    // 다른(더 긴) 활동의 기록
            }
            var arr = u as Lang.Array<Lang.Number>;
            usageMax = 0;
            for (var i = 0; i < MAX_REAR; i++) {
                if (arr[i] == null) { arr[i] = 0; }
                if (arr[i] > usageMax) { usageMax = arr[i]; }
            }
            usage = arr;
            return t;
        } catch (ex) {
        }
        return null;
    }
}
