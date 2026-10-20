import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    readonly property string displayMode: Plasmoid.configuration.displayMode || "vertical"
    readonly property string dataSource: Plasmoid.configuration.dataSource || "tencent"
    readonly property string tickerList: normalizeTickers(Plasmoid.configuration.tickers)
    readonly property int flipIntervalMs: Math.max(1000, toPositiveInt(Plasmoid.configuration.flipInterval, 4) * 1000)
    readonly property int refreshIntervalMs: Math.max(3000, toPositiveInt(Plasmoid.configuration.refreshInterval, 30) * 1000)
    readonly property int scrollSpeed: toPositiveInt(Plasmoid.configuration.scrollSpeed, 60)
    readonly property string separator: Plasmoid.configuration.separator && Plasmoid.configuration.separator.length
        ? Plasmoid.configuration.separator
        : "    |    "
    readonly property bool showName: Plasmoid.configuration.showName !== false
    readonly property string colorMode: Plasmoid.configuration.colorMode || "cn"
    readonly property string borderStyle: Plasmoid.configuration.borderStyle || "white"
    property bool collapsed: Plasmoid.configuration.collapsed || false
    readonly property string clickAction: Plasmoid.configuration.clickAction || "toggleCollapse"

    function toggleCollapse() {
        root.collapsed = !root.collapsed;
        Plasmoid.configuration.collapsed = root.collapsed;
        if (!root.collapsed) {
            if (root.isTradingTime() || root.rawQuoteItems.length === 0) {
                root.fetchQuotes();
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("立即刷新行情")
            icon.name: "view-refresh"
            onTriggered: root.fetchQuotes()
        },
        PlasmaCore.Action {
            text: root.collapsed ? i18n("展开行情展示") : i18n("收起为小图标")
            icon.name: root.collapsed ? "format-indent-more" : "format-indent-less"
            onTriggered: root.toggleCollapse()
        }
    ]

    // 交易时段控制
    readonly property bool onlyTradingHours: Plasmoid.configuration.onlyTradingHours !== false
    readonly property bool weekendOff: Plasmoid.configuration.weekendOff !== false
    readonly property string morningStart: Plasmoid.configuration.morningStart || "09:25"
    readonly property string morningEnd: Plasmoid.configuration.morningEnd || "11:30"
    readonly property string afternoonStart: Plasmoid.configuration.afternoonStart || "13:00"
    readonly property string afternoonEnd: Plasmoid.configuration.afternoonEnd || "15:05"

    property string displayHtml: "正在加载行情数据..."
    property string displayText: "正在加载行情数据..."
    property string statusText: "等待首次数据刷新..."
    property date lastUpdated: new Date(0)
    property var latestSegments: []
    property var rawQuoteItems: []
    property int activeRequestId: 0

    // 尺寸控制：折叠时自适应为一个图标大小 (正方形)；展开时根据显示模式展示
    Layout.minimumWidth: root.collapsed
        ? (root.height > 0 ? root.height : 28)
        : (displayMode === "vertical" ? 120 : 260)
    Layout.preferredWidth: root.collapsed
        ? (root.height > 0 ? root.height : 28)
        : (displayMode === "vertical" ? 165 : 380)
    Layout.maximumWidth: root.collapsed
        ? (root.height > 0 ? root.height : 28)
        : (displayMode === "vertical" ? 280 : 2000)
    Layout.minimumHeight: 24
    Layout.preferredHeight: 28
    implicitWidth: root.collapsed
        ? (root.height > 0 ? root.height : 28)
        : (displayMode === "vertical" ? 165 : 380)
    implicitHeight: 28

    switchWidth: root.collapsed ? 28 : (displayMode === "vertical" ? 165 : 380)
    switchHeight: 28

    toolTipMainText: i18n("全球股市行情 (Stock Ticker)")
    toolTipSubText: tooltipText()

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation
        : compactRepresentation
    compactRepresentation: tickerRepresentation
    fullRepresentation: tickerRepresentation

    // 定时器：检测时段并定时请求刷新行情
    Timer {
        id: dataTimer
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // 如果处于交易时段，或者本地尚无缓存数据（刚启动时），执行网络请求
            if (root.isTradingTime() || root.rawQuoteItems.length === 0) {
                root.fetchQuotes();
            } else {
                root.updateClosedStatus();
            }
        }
    }

    Component {
        id: tickerRepresentation

        Item {
            id: container
            anchors.fill: parent
            clip: true

            // ================= 状态一：折叠形态 (小图标 📈) =================
            Item {
                id: collapsedView
                visible: root.collapsed
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: collapsedMouseArea.containsMouse ? Qt.alpha("#ffffff", 0.15) : "transparent"
                    border.width: root.borderStyle === "none" ? 0 : 1
                    border.color: root.borderStyle === "white"
                        ? "#ffffff"
                        : (root.borderStyle === "none"
                            ? "transparent"
                            : (PlasmaCore.Theme.textColor ? Qt.alpha(PlasmaCore.Theme.textColor, 0.25) : "#ffffff"))
                    radius: 4

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: "📈"
                        font.pixelSize: Math.max(12, Math.min(parent.height - 8, 16))
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: collapsedMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            root.fetchQuotes();
                        } else {
                            root.toggleCollapse();
                        }
                    }
                }
            }

            // ================= 状态二：展开形态 (完整展示条) =================
            Item {
                id: expandedView
                visible: !root.collapsed
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: expandedMouseArea.containsMouse ? Qt.alpha("#ffffff", 0.08) : "transparent"
                    border.width: root.borderStyle === "none" ? 0 : 1
                    border.color: root.borderStyle === "white"
                        ? "#ffffff"
                        : (root.borderStyle === "none"
                            ? "transparent"
                            : (PlasmaCore.Theme.textColor ? Qt.alpha(PlasmaCore.Theme.textColor, 0.25) : "#ffffff"))
                    radius: 4
                }

                // ================= 模式一：垂直翻滚模式 (上下滚动，极省空间) =================
                Item {
                    id: verticalFlipper
                    visible: root.displayMode === "vertical"
                    anchors.fill: parent
                    clip: true

                property int currentFlipIndex: 0
                property bool isHovered: false

                Timer {
                    id: flipTimer
                    interval: root.flipIntervalMs
                    running: !root.collapsed && root.displayMode === "vertical" && root.rawQuoteItems.length > 1 && !verticalFlipper.isHovered
                    repeat: true
                    onTriggered: {
                        if (root.rawQuoteItems.length <= 1) return;
                        var nextIdx = (verticalFlipper.currentFlipIndex + 1) % root.rawQuoteItems.length;
                        nextLabel.text = root.formatQuoteHtml(root.rawQuoteItems[nextIdx]);
                        flipAnimation.start();
                    }
                }

                PlasmaComponents.Label {
                    id: currentLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: root.rawQuoteItems.length > 0
                        ? root.formatQuoteHtml(root.rawQuoteItems[Math.min(verticalFlipper.currentFlipIndex, root.rawQuoteItems.length - 1)])
                        : root.displayHtml
                    font.pixelSize: 13
                    font.bold: true
                    y: 0
                    opacity: 1
                }

                PlasmaComponents.Label {
                    id: nextLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: ""
                    font.pixelSize: 13
                    font.bold: true
                    y: parent.height
                    opacity: 0
                }

                ParallelAnimation {
                    id: flipAnimation
                    NumberAnimation {
                        target: currentLabel
                        property: "y"
                        from: 0
                        to: -container.height
                        duration: 380
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: currentLabel
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 380
                    }
                    NumberAnimation {
                        target: nextLabel
                        property: "y"
                        from: container.height
                        to: 0
                        duration: 380
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: nextLabel
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 380
                    }
                    onFinished: {
                        verticalFlipper.currentFlipIndex = (verticalFlipper.currentFlipIndex + 1) % root.rawQuoteItems.length;
                        currentLabel.text = nextLabel.text;
                        currentLabel.y = 0;
                        currentLabel.opacity = 1;
                        nextLabel.y = container.height;
                        nextLabel.opacity = 0;
                    }
                }
            }

            // ================= 模式二：水平走马灯模式 (横向无缝滚动) =================
            Item {
                id: horizontalTicker
                visible: root.displayMode === "horizontal"
                anchors.fill: parent
                clip: true

                // 当速度为 0 时：静态左对齐展示
                PlasmaComponents.Label {
                    id: staticLabel
                    visible: root.scrollSpeed <= 0
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: root.displayHtml
                    font.pixelSize: 13
                    font.bold: true
                }

                // 当速度 > 0 时：无限平滑滚动
                PlasmaComponents.Label {
                    id: scrollingLabel
                    visible: root.scrollSpeed > 0
                    textFormat: Text.RichText
                    text: root.displayHtml
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    x: container.width

                    NumberAnimation on x {
                        id: scrollAnim
                        from: container.width
                        to: -scrollingLabel.paintedWidth
                        duration: Math.max(2000, ((container.width + scrollingLabel.paintedWidth) / Math.max(10, root.scrollSpeed)) * 1000)
                        loops: Animation.Infinite
                        running: !root.collapsed && root.displayMode === "horizontal" && root.scrollSpeed > 0 && scrollingLabel.paintedWidth > 0
                    }
                }
            }

            // 鼠标交互：悬停暂停 + 点击收起/刷新
            MouseArea {
                id: expandedMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onEntered: {
                    verticalFlipper.isHovered = true;
                    if (root.displayMode === "horizontal" && root.scrollSpeed > 0) {
                        scrollAnim.pause();
                    }
                }
                onExited: {
                    verticalFlipper.isHovered = false;
                    if (root.displayMode === "horizontal" && root.scrollSpeed > 0) {
                        scrollAnim.resume();
                    }
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.fetchQuotes();
                    } else {
                        if (root.clickAction === "refresh") {
                            root.fetchQuotes();
                        } else {
                            root.toggleCollapse();
                        }
                    }
                }
            }
        }
    }
    }

    onRefreshIntervalMsChanged: dataTimer.restart()
    onDataSourceChanged: {
        latestSegments = [];
        rawQuoteItems = [];
        fetchQuotes();
        dataTimer.restart();
    }
    onColorModeChanged: rebuildDisplayText()
    onShowNameChanged: rebuildDisplayText()

    onTickerListChanged: {
        if (tickerList.length === 0) {
            latestSegments = [];
            rawQuoteItems = [];
            displayHtml = "请在设置中配置至少一个股票代码";
            displayText = "请在设置中配置至少一个股票代码";
            statusText = "未配置股票代码";
            return;
        }

        fetchQuotes();
        dataTimer.restart();
    }

    onSeparatorChanged: rebuildDisplayText()

    // 交易时间判定逻辑 (早市 + 午市 + 周末判断)
    function isTradingTime(dateObj) {
        if (!onlyTradingHours) {
            return true;
        }

        var now = dateObj || new Date();
        var day = now.getDay(); // 0 是周日，6 是周六

        if (weekendOff && (day === 0 || day === 6)) {
            return false;
        }

        var curMin = now.getHours() * 60 + now.getMinutes();

        function parseToMin(timeStr, defMin) {
            if (!timeStr) return defMin;
            var p = String(timeStr).split(":");
            if (p.length >= 2) {
                var h = parseInt(p[0], 10);
                var m = parseInt(p[1], 10);
                if (isFinite(h) && isFinite(m)) {
                    return h * 60 + m;
                }
            }
            return defMin;
        }

        var mStart = parseToMin(morningStart, 9 * 60 + 25);
        var mEnd = parseToMin(morningEnd, 11 * 60 + 30);
        var aStart = parseToMin(afternoonStart, 13 * 60);
        var aEnd = parseToMin(afternoonEnd, 15 * 60 + 5);

        var inMorning = (curMin >= mStart && curMin <= mEnd);
        var inAfternoon = (curMin >= aStart && curMin <= aEnd);

        return inMorning || inAfternoon;
    }

    function updateClosedStatus() {
        var now = new Date();
        var day = now.getDay();
        var isWk = weekendOff && (day === 0 || day === 6);
        statusText = "💤 " + (isWk ? "周末休市" : "非交易时段") + " (自动查询静止，保持收盘缓存)";
    }

    function tooltipText() {
        var lines = [];
        var inTrading = isTradingTime();
        if (onlyTradingHours) {
            if (inTrading) {
                lines.push("🟢 盘中交易时段 (自动刷新开启，每 " + Math.round(refreshIntervalMs / 1000) + " 秒)");
            } else {
                var now = new Date();
                var day = now.getDay();
                var isWk = weekendOff && (day === 0 || day === 6);
                lines.push("💤 " + (isWk ? "周末休市" : "非交易时段休市") + " (自动查询静止，展示最新收盘缓存)");
            }
        } else {
            lines.push("🟢 全天候刷新 (每 " + Math.round(refreshIntervalMs / 1000) + " 秒)");
        }

        if (lastUpdated.getTime() > 0) {
            lines.push("最新更新: " + Qt.formatTime(lastUpdated, "HH:mm:ss"));
        }
        var sourceName = dataSource === "eastmoney" ? "东方财富 (Eastmoney)"
                       : dataSource === "tencent" ? "腾讯财经 (Tencent)"
                       : "雅虎财经 (Yahoo Finance)";
        lines.push("数据源: " + sourceName);

        if (root.collapsed) {
            lines.push("💡 点击小图标 📈 展开行情展示 (中键点击刷新)");
        } else {
            var actionHint = root.clickAction === "refresh"
                ? "点击手动刷新行情 (右键可收起为小图标)"
                : "左键点击收起为小图标 (中键点击刷新)";
            lines.push("💡 " + actionHint);
        }

        if (rawQuoteItems && rawQuoteItems.length > 0) {
            lines.push("----------------------------------------");
            for (var i = 0; i < rawQuoteItems.length; ++i) {
                var item = rawQuoteItems[i];
                var sign = item.changePercent > 0 ? "+" : "";
                var pStr = isFinite(item.price) ? item.price.toFixed(2) : "N/A";
                var chgStr = isFinite(item.changePercent) ? (sign + item.changePercent.toFixed(2) + "%") : "N/A";
                var amtStr = isFinite(item.changeAmount) ? (sign + item.changeAmount.toFixed(2)) : "";
                lines.push(item.name + " (" + item.code + "): " + pStr + "  " + chgStr + (amtStr ? (" [" + amtStr + "]") : ""));
            }
        }
        return lines.join("\n");
    }

    function toPositiveInt(value, fallbackValue) {
        var parsed = parseInt(value, 10);
        if (!isFinite(parsed) || parsed <= 0) {
            return fallbackValue;
        }
        return parsed;
    }

    function normalizeTickers(value) {
        var raw = String(value || "");
        var parts = raw.split(/[\s,;|]+/);
        var cleaned = [];

        for (var i = 0; i < parts.length; ++i) {
            var ticker = parts[i].trim();
            if (ticker.length > 0) {
                cleaned.push(ticker);
            }
        }

        return cleaned.join(",");
    }

    function escapeHtml(str) {
        return String(str || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    function getColor(change) {
        if (colorMode === "none" || !isFinite(change) || change === 0) {
            return "#cccccc";
        }
        if (colorMode === "intl") {
            return change > 0 ? "#52c41a" : "#ff4d4f";
        }
        // "cn": 红涨绿跌
        return change > 0 ? "#ff4d4f" : "#52c41a";
    }

    function formatQuoteHtml(q) {
        var title = (showName && q.name && q.name.length) ? q.name : q.code;
        var priceText = isFinite(q.price) ? q.price.toFixed(2) : "N/A";
        var color = getColor(q.changePercent);
        var sign = "";
        var arrow = "";

        if (isFinite(q.changePercent)) {
            if (q.changePercent > 0) {
                sign = "+";
                arrow = "▲";
            } else if (q.changePercent < 0) {
                arrow = "▼";
            }
        }

        var changeText = isFinite(q.changePercent)
            ? (arrow + sign + q.changePercent.toFixed(2) + "%")
            : "N/A";

        return "<span style='color:" + color + ";'>" +
               escapeHtml(title) + ": " + priceText + " (" + changeText + ")</span>";
    }

    function formatQuotePlain(q) {
        var title = (showName && q.name && q.name.length) ? q.name : q.code;
        var priceText = isFinite(q.price) ? q.price.toFixed(2) : "N/A";
        var sign = (isFinite(q.changePercent) && q.changePercent > 0) ? "+" : "";
        var changeText = isFinite(q.changePercent) ? (sign + q.changePercent.toFixed(2) + "%") : "N/A";
        return title + ": " + priceText + " (" + changeText + ")";
    }

    function rebuildDisplayText() {
        if (!rawQuoteItems || rawQuoteItems.length === 0) {
            return;
        }

        var htmlList = [];
        var plainList = [];
        for (var i = 0; i < rawQuoteItems.length; ++i) {
            htmlList.push(formatQuoteHtml(rawQuoteItems[i]));
            plainList.push(formatQuotePlain(rawQuoteItems[i]));
        }

        displayHtml = htmlList.join(escapeHtml(separator));
        displayText = plainList.join(separator);
    }

    function handleFailure(message) {
        statusText = message + " 正在自动重试...";
        if (!rawQuoteItems || rawQuoteItems.length === 0) {
            displayHtml = "<span style='color:#ff7875;'>" + escapeHtml(message) + "</span>";
            displayText = message;
        }
    }

    // 将用户输入代码转换为东方财富 secid 格式
    function toEastmoneySecId(raw) {
        var c = String(raw || "").trim();
        if (c.indexOf(".") !== -1) {
            return c; // 已经带有 1. 或 0. 或 116. 或 105.
        }
        var lower = c.toLowerCase();
        if (lower.startsWith("sh")) return "1." + c.slice(2);
        if (lower.startsWith("sz") || lower.startsWith("bj")) return "0." + c.slice(2);
        if (lower.startsWith("hk")) return "116." + c.slice(2).padStart(5, "0");
        if (lower.endsWith(".hk")) return "116." + c.split(".")[0].padStart(5, "0");

        // 纯数字识别
        if (/^\d+$/.test(c)) {
            if (c.length === 5) return "116." + c; // 5 位一般为港股
            if (/^[569]/.test(c)) return "1." + c; // 沪市主板/科创板/ETF
            if (/^[031]/.test(c)) return "0." + c; // 深市主板/创业板/ETF
            if (/^[48]/.test(c)) return "0." + c; // 北交所
            return "0." + c;
        }

        // 纯英文字母（美股）
        if (/^[a-zA-Z]+$/.test(c)) {
            return "105." + c.toUpperCase();
        }

        return c;
    }

    // 将用户输入代码转换为腾讯财经格式（sh600519, sz000001, hk00700, usAAPL）
    function toTencentSymbol(raw) {
        var c = String(raw || "").trim();
        if (c.startsWith("1.")) return "sh" + c.slice(2);
        if (c.startsWith("0.")) return "sz" + c.slice(2);
        if (c.startsWith("116.")) return "hk" + c.slice(4);
        if (c.startsWith("105.") || c.startsWith("106.")) return "us" + c.slice(4);

        var lower = c.toLowerCase();
        if (lower.startsWith("sh") || lower.startsWith("sz") || lower.startsWith("hk") || lower.startsWith("us")) {
            return lower;
        }
        if (lower.endsWith(".hk")) return "hk" + c.split(".")[0].padStart(5, "0");

        if (/^\d+$/.test(c)) {
            if (c.length === 5) return "hk" + c;
            if (/^[569]/.test(c)) return "sh" + c;
            return "sz" + c;
        }

        if (/^[a-zA-Z]+$/.test(c)) {
            return "us" + c.toUpperCase();
        }

        return lower;
    }

    function fetchQuotes() {
        if (!tickerList.length) {
            latestSegments = [];
            rawQuoteItems = [];
            displayHtml = "请在设置中配置至少一个股票代码";
            displayText = "请在设置中配置至少一个股票代码";
            statusText = "未配置股票代码";
            return;
        }

        var requestId = ++activeRequestId;
        var requestedSymbols = tickerList.split(",");

        if (dataSource === "eastmoney") {
            fetchEastmoney(requestId, requestedSymbols);
        } else if (dataSource === "tencent") {
            fetchTencent(requestId, requestedSymbols);
        } else {
            fetchYahoo(requestId, requestedSymbols);
        }
    }

    // 1. 东方财富 API
    function fetchEastmoney(requestId, requestedSymbols) {
        var secIds = [];
        for (var i = 0; i < requestedSymbols.length; ++i) {
            secIds.push(toEastmoneySecId(requestedSymbols[i]));
        }

        var url = "https://push2delay.eastmoney.com/api/qt/ulist.np/get?fltt=2&fields=f2,f3,f4,f12,f13,f14&secids=" + secIds.join(",");
        var xhr = new XMLHttpRequest();
        statusText = "正在刷新 " + secIds.length + " 只标的 (东方财富)...";

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || requestId !== activeRequestId) return;
            if (xhr.status !== 200) {
                // 东财接口受阻或被代理拦截时，自动无缝降级切换至腾讯财经数据源
                console.log("Eastmoney HTTP " + xhr.status + ", auto fallback to Tencent...");
                fetchTencent(requestId, requestedSymbols);
                return;
            }

            try {
                var payload = JSON.parse(xhr.responseText);
                var list = (payload.data && payload.data.diff) ? payload.data.diff : [];
                var quoteMap = {};
                var items = [];

                for (var j = 0; j < list.length; ++j) {
                    var item = list[j];
                    var code = String(item.f12 || "");
                    var mkt = String(item.f13 !== undefined ? item.f13 : "");
                    var fullSecId = (mkt ? (mkt + ".") : "") + code;
                    var name = String(item.f14 || code);
                    var price = Number(item.f2);
                    var changePercent = Number(item.f3);
                    var changeAmount = Number(item.f4);

                    var q = {
                        code: code,
                        secId: fullSecId,
                        name: name,
                        price: price,
                        changePercent: changePercent,
                        changeAmount: changeAmount
                    };

                    quoteMap[fullSecId] = q;
                    quoteMap[code] = q;
                }

                for (var k = 0; k < secIds.length; ++k) {
                    var sId = secIds[k];
                    var rawSym = requestedSymbols[k];
                    var hit = quoteMap[sId] || quoteMap[rawSym];
                    if (hit) {
                        items.push(hit);
                    } else {
                        items.push({
                            code: rawSym,
                            secId: sId,
                            name: rawSym,
                            price: NaN,
                            changePercent: NaN,
                            changeAmount: NaN
                        });
                    }
                }

                rawQuoteItems = items;
                rebuildDisplayText();
                lastUpdated = new Date();
                statusText = "已同步 " + items.length + " 只标的行情 (东方财富)";
            } catch (e) {
                handleFailure("解析东财行情数据失败");
            }
        };

        xhr.onerror = function() {
            if (requestId === activeRequestId) {
                console.log("Eastmoney network error, auto fallback to Tencent...");
                fetchTencent(requestId, requestedSymbols);
            }
        };

        xhr.open("GET", url);
        xhr.send();
    }

    // 2. 腾讯财经 API
    function fetchTencent(requestId, requestedSymbols) {
        var tencentSymbols = [];
        for (var i = 0; i < requestedSymbols.length; ++i) {
            tencentSymbols.push(toTencentSymbol(requestedSymbols[i]));
        }

        var url = "https://qt.gtimg.cn/q=" + tencentSymbols.join(",");
        var xhr = new XMLHttpRequest();
        statusText = "正在刷新 " + tencentSymbols.length + " 只标的 (腾讯财经)...";

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || requestId !== activeRequestId) return;
            if (xhr.status !== 200) {
                handleFailure("腾讯接口返回 HTTP " + xhr.status);
                return;
            }

            try {
                var text = xhr.responseText;
                var lines = text.split(";");
                var quoteMap = {};
                var items = [];

                for (var j = 0; j < lines.length; ++j) {
                    var line = lines[j].trim();
                    var eqIdx = line.indexOf("=");
                    if (eqIdx === -1) continue;
                    var varName = line.slice(0, eqIdx).trim();
                    var sym = varName.replace(/^v_/, "");
                    var content = line.slice(eqIdx + 1).replace(/^"/, "").replace(/"$/, "");
                    var parts = content.split("~");
                    if (parts.length < 33) continue;

                    var name = parts[1];
                    var code = parts[2];
                    var price = Number(parts[3]);
                    var changeAmount = Number(parts[31]);
                    var changePercent = Number(parts[32]);

                    var q = {
                        code: code,
                        symbol: sym,
                        name: name,
                        price: price,
                        changePercent: changePercent,
                        changeAmount: changeAmount
                    };

                    quoteMap[sym] = q;
                    quoteMap[code] = q;
                }

                for (var k = 0; k < tencentSymbols.length; ++k) {
                    var tSym = tencentSymbols[k];
                    var rawSym = requestedSymbols[k];
                    var hit = quoteMap[tSym] || quoteMap[rawSym];
                    if (hit) {
                        items.push(hit);
                    } else {
                        items.push({
                            code: rawSym,
                            name: rawSym,
                            price: NaN,
                            changePercent: NaN,
                            changeAmount: NaN
                        });
                    }
                }

                rawQuoteItems = items;
                rebuildDisplayText();
                lastUpdated = new Date();
                statusText = "已同步 " + items.length + " 只标的行情 (腾讯财经)";
            } catch (e) {
                handleFailure("解析腾讯行情数据失败");
            }
        };

        xhr.onerror = function() {
            if (requestId === activeRequestId) handleFailure("网络连接异常 (腾讯)");
        };

        xhr.open("GET", url);
        xhr.send();
    }

    // 3. 雅虎财经 API (保留原有国际市场兜底)
    function fetchYahoo(requestId, requestedSymbols) {
        var url = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=" + encodeURIComponent(requestedSymbols.join(","));
        var xhr = new XMLHttpRequest();
        statusText = "正在刷新 " + requestedSymbols.length + " 只标的 (Yahoo Finance)...";

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || requestId !== activeRequestId) return;
            if (xhr.status !== 200) {
                if (xhr.status === 401 || xhr.status === 403 || xhr.status === 429) {
                    handleFailure("雅虎财经接口已拒绝访问(HTTP " + xhr.status + ")，请在设置中切换为腾讯财经或东方财富");
                } else {
                    handleFailure("Yahoo HTTP " + xhr.status);
                }
                return;
            }

            try {
                var payload = JSON.parse(xhr.responseText);
                var result = payload.quoteResponse && payload.quoteResponse.result
                    ? payload.quoteResponse.result
                    : [];
                var quoteMap = {};
                var items = [];

                for (var i = 0; i < result.length; ++i) {
                    var r = result[i];
                    if (r && r.symbol) {
                        var q = {
                            code: r.symbol,
                            name: r.shortName || r.longName || r.symbol,
                            price: Number(r.regularMarketPrice),
                            changePercent: Number(r.regularMarketChangePercent),
                            changeAmount: Number(r.regularMarketChange)
                        };
                        quoteMap[r.symbol.toUpperCase()] = q;
                    }
                }

                for (var k = 0; k < requestedSymbols.length; ++k) {
                    var req = requestedSymbols[k].toUpperCase();
                    var hit = quoteMap[req];
                    if (hit) {
                        items.push(hit);
                    } else {
                        items.push({
                            code: req,
                            name: req,
                            price: NaN,
                            changePercent: NaN,
                            changeAmount: NaN
                        });
                    }
                }

                rawQuoteItems = items;
                rebuildDisplayText();
                lastUpdated = new Date();
                statusText = "已同步 " + items.length + " 只标的行情 (Yahoo Finance)";
            } catch (e) {
                handleFailure("解析雅虎行情数据失败");
            }
        };

        xhr.onerror = function() {
            if (requestId === activeRequestId) handleFailure("网络连接异常 (Yahoo)");
        };

        xhr.open("GET", url);
        xhr.send();
    }
}
