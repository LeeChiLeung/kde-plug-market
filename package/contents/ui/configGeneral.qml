import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

ColumnLayout {
    id: configRoot
    spacing: Kirigami.Units.largeSpacing

    property string cfg_displayMode
    property string cfg_dataSource
    property alias cfg_tickers: tickersField.text
    property alias cfg_flipInterval: flipIntervalSpin.value
    property alias cfg_refreshInterval: refreshIntervalSpin.value
    property alias cfg_scrollSpeed: scrollSpeedSpin.value
    property alias cfg_separator: separatorField.text
    property alias cfg_showName: showNameCheck.checked
    property string cfg_colorMode
    property string cfg_borderStyle
    property string cfg_clickAction

    property alias cfg_onlyTradingHours: onlyTradingHoursCheck.checked
    property alias cfg_weekendOff: weekendOffCheck.checked
    property alias cfg_morningStart: morningStartField.text
    property alias cfg_morningEnd: morningEndField.text
    property alias cfg_afternoonStart: afternoonStartField.text
    property alias cfg_afternoonEnd: afternoonEndField.text

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.ComboBox {
            id: displayModeCombo
            Kirigami.FormData.label: i18n("Display Mode (显示模式):")
            model: [
                { text: i18n("上下翻滚 (垂直轮播 - 极简节省面板空间)"), value: "vertical" },
                { text: i18n("横向走马灯 (水平无限平滑滚动)"), value: "horizontal" }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: syncIndex()
            Connections {
                target: configRoot
                function onCfg_displayModeChanged() { displayModeCombo.syncIndex(); }
            }
            function syncIndex() {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === configRoot.cfg_displayMode) {
                        displayModeCombo.currentIndex = i;
                        return;
                    }
                }
                displayModeCombo.currentIndex = 0;
            }
            onActivated: configRoot.cfg_displayMode = model[currentIndex].value
        }

        QQC2.ComboBox {
            id: dataSourceCombo
            Kirigami.FormData.label: i18n("Data Source (数据源):")
            model: [
                { text: i18n("Tencent (腾讯财经) - 极速快照 / 推荐"), value: "tencent" },
                { text: i18n("Eastmoney (东方财富) - 实时 A股/ETF/港美"), value: "eastmoney" },
                { text: i18n("Yahoo Finance (雅虎财经) - 国际市场/加密货币"), value: "yahoo" }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: syncIndex()
            Connections {
                target: configRoot
                function onCfg_dataSourceChanged() { dataSourceCombo.syncIndex(); }
            }
            function syncIndex() {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === configRoot.cfg_dataSource) {
                        dataSourceCombo.currentIndex = i;
                        return;
                    }
                }
                dataSourceCombo.currentIndex = 0;
            }
            onActivated: configRoot.cfg_dataSource = model[currentIndex].value
        }

        QQC2.TextField {
            id: tickersField
            Kirigami.FormData.label: i18n("Tickers (股票代码):")
            placeholderText: i18n("601138,000001,510300,116.00700,105.AAPL")
        }

        QQC2.CheckBox {
            id: showNameCheck
            Kirigami.FormData.label: i18n("Display Name:")
            text: i18n("显示中文名称 (如 工业富联)")
        }

        QQC2.ComboBox {
            id: colorModeCombo
            Kirigami.FormData.label: i18n("Color Style (颜色风格):")
            model: [
                { text: i18n("Red up / Green down (红涨绿跌 - 中国习惯)"), value: "cn" },
                { text: i18n("Green up / Red down (绿涨红跌 - 国际习惯)"), value: "intl" },
                { text: i18n("Monochrome (无涨跌颜色)"), value: "none" }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: syncIndex()
            Connections {
                target: configRoot
                function onCfg_colorModeChanged() { colorModeCombo.syncIndex(); }
            }
            function syncIndex() {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === configRoot.cfg_colorMode) {
                        colorModeCombo.currentIndex = i;
                        return;
                    }
                }
                colorModeCombo.currentIndex = 0;
            }
            onActivated: configRoot.cfg_colorMode = model[currentIndex].value
        }

        QQC2.ComboBox {
            id: borderStyleCombo
            Kirigami.FormData.label: i18n("Border Style (边框风格):")
            model: [
                { text: i18n("White Border (白色边框 - 高亮显眼)"), value: "white" },
                { text: i18n("Borderless (无边框 - 极简融合)"), value: "none" },
                { text: i18n("Follow Theme (跟随系统主题)"), value: "theme" }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: syncIndex()
            Connections {
                target: configRoot
                function onCfg_borderStyleChanged() { borderStyleCombo.syncIndex(); }
            }
            function syncIndex() {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === configRoot.cfg_borderStyle) {
                        borderStyleCombo.currentIndex = i;
                        return;
                    }
                }
                borderStyleCombo.currentIndex = 0;
            }
            onActivated: configRoot.cfg_borderStyle = model[currentIndex].value
        }

        QQC2.ComboBox {
            id: clickActionCombo
            Kirigami.FormData.label: i18n("Click Action (展开框点击行为):")
            model: [
                { text: i18n("收起为小图标 (Click to Collapse / 默认)"), value: "toggleCollapse" },
                { text: i18n("手动刷新数据 (Click to Refresh)"), value: "refresh" }
            ]
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: syncIndex()
            Connections {
                target: configRoot
                function onCfg_clickActionChanged() { clickActionCombo.syncIndex(); }
            }
            function syncIndex() {
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === configRoot.cfg_clickAction) {
                        clickActionCombo.currentIndex = i;
                        return;
                    }
                }
                clickActionCombo.currentIndex = 0;
            }
            onActivated: configRoot.cfg_clickAction = model[currentIndex].value
        }

        QQC2.SpinBox {
            id: flipIntervalSpin
            visible: configRoot.cfg_displayMode !== "horizontal"
            Kirigami.FormData.label: i18n("Flip Interval (翻滚间隔):")
            from: 1
            to: 60
            stepSize: 1
            editable: true
        }

        QQC2.SpinBox {
            id: refreshIntervalSpin
            Kirigami.FormData.label: i18n("Refresh (盘中刷新):")
            from: 3
            to: 3600
            stepSize: 5
            editable: true
        }

        QQC2.SpinBox {
            id: scrollSpeedSpin
            visible: configRoot.cfg_displayMode === "horizontal"
            Kirigami.FormData.label: i18n("Scroll Speed (走马灯速度):")
            from: 0
            to: 240
            stepSize: 5
            editable: true
        }

        QQC2.TextField {
            id: separatorField
            visible: configRoot.cfg_displayMode === "horizontal"
            Kirigami.FormData.label: i18n("Separator (分隔符):")
            placeholderText: "    |    "
        }

        // ================= 交易时段设置 =================
        QQC2.CheckBox {
            id: onlyTradingHoursCheck
            Kirigami.FormData.label: i18n("Trading Hours Control:")
            text: i18n("仅在交易时段自动刷新 (休市期间静止，展示收盘缓存)")
        }

        QQC2.CheckBox {
            id: weekendOffCheck
            visible: onlyTradingHoursCheck.checked
            Kirigami.FormData.label: i18n("Weekend Off (周末休市):")
            text: i18n("周六/周日全天休市不发起网络刷新")
        }

        RowLayout {
            visible: onlyTradingHoursCheck.checked
            Kirigami.FormData.label: i18n("Morning Session (早市):")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: morningStartField
                Layout.preferredWidth: 85
                placeholderText: "09:25"
            }
            QQC2.Label { text: "~" }
            QQC2.TextField {
                id: morningEndField
                Layout.preferredWidth: 85
                placeholderText: "11:30"
            }
        }

        RowLayout {
            visible: onlyTradingHoursCheck.checked
            Kirigami.FormData.label: i18n("Afternoon Session (午市):")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: afternoonStartField
                Layout.preferredWidth: 85
                placeholderText: "13:00"
            }
            QQC2.Label { text: "~" }
            QQC2.TextField {
                id: afternoonEndField
                Layout.preferredWidth: 85
                placeholderText: "15:05"
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: Kirigami.Units.fontMetrics.font.pixelSize * 0.9
        opacity: 0.85
        text: i18n("<b>使用贴士：</b><br>" +
                   "• <b>交易时段节流：</b>默认 09:25-11:30 与 13:00-15:05 自动请求，非交易时段暂停网络查询，保持收盘数据。<br>" +
                   "• <b>休市手动刷新：</b>在休市时段直接鼠标左键点击任务栏挂件，即可手动触发一次最新快照查询。")
    }
}
