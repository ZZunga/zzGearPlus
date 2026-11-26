using Toybox.Application.Properties;
using Toybox.Lang;

// 설정 스냅샷 + 캐싱 (zzPowerPlus 와 같은 방식).
// onUpdate 는 1Hz 이므로 매번 Properties 를 읽지 않고 캐시를 쓰고 onSettingsChanged 에서 invalidate().
module Config {

    // 배경색 (bgMode)
    enum {
        BG_AUTO  = 0,   // 기기 화면과 같은 색으로 칠함 (1050/1060 은 #17181D / 남색 글씨)
        BG_PLAIN = 1,   // 기기가 알려준 검정 / 흰색 그대로
        BG_CLEAR = 2    // 칠하지 않음 (기기 배경이 그대로 비침)
    }

    // 큰 숫자에 무엇을 둘지 (mainValue)
    enum {
        MAIN_GEAR  = 0,     // 기어 단수 "2-5" (기본), 윗줄은 기어비
        MAIN_RATIO = 1      // 기어비 "3.2", 윗줄은 기어 단수
    }

    // 크로스체인 경고 (crossWarn)
    enum {
        CROSS_OFF   = 0,
        CROSS_EDGE  = 1,    // 양 끝 한 단 (기본)
        CROSS_WIDE  = 2     // 양 끝 두 단
    }

    class Snapshot {
        var bgMode     = BG_AUTO;  // 배경색
        var mainValue  = MAIN_GEAR;
        var showIcon   = true;      // 좌상단 기어 아이콘
        var showBatt   = true;      // 배터리 (ANT+ 가 알려줄 때만)
        var showUsage  = true;      // 기어별 사용 시간 (링 색 진하기)
        var showTeeth  = true;      // 넓고 높은 칸 아래 톱니수 "50 / 17 T"
        var crossWarn  = CROSS_EDGE;
        var reverseRear = false;    // 뒤 단수 번호가 큰 스프라켓부터 매겨지는 구동계
    }

    var _cache = null;

    function invalidate() {
        _cache = null;
    }

    function _get(key, dflt) {
        try {
            var v = Properties.getValue(key);
            if (v != null) {
                return v;
            }
        } catch (ex) {
        }
        return dflt;
    }

    function _num(key, dflt, lo, hi) {
        var v = _get(key, dflt);
        if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long) {
            v = v.toNumber();
        }
        if (!(v instanceof Lang.Number)) {
            return dflt;
        }
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function _bool(key, dflt) {
        var v = _get(key, dflt);
        return (v instanceof Lang.Boolean) ? v : dflt;
    }

    function read() {
        if (_cache != null) {
            return _cache;
        }
        var s = new Snapshot();
        s.mainValue   = _num("mainValue", MAIN_GEAR, 0, 1);
        s.showIcon    = _bool("showIcon", true);
        s.showBatt    = _bool("showBattery", true);
        s.showUsage   = _bool("showUsage", true);
        s.showTeeth   = _bool("showTeeth", true);
        s.crossWarn   = _num("crossWarn", CROSS_EDGE, 0, 2);
        s.reverseRear = _bool("reverseRear", false);
        s.bgMode      = _num("bgMode", BG_AUTO, 0, 2);
        _cache = s;
        return s;
    }
}
