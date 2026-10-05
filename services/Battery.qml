//  VELVET  ·  services/Battery.qml
pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real percentage: device?.percentage ?? 0
    readonly property int percent: Math.round(percentage * 100)
    readonly property bool charging: device ? device.state === UPowerDeviceState.Charging : false
    readonly property bool full: device ? device.state === UPowerDeviceState.FullyCharged : false
    readonly property bool low: available && !charging && percent <= 20
    readonly property bool critical: available && !charging && percent <= 8
    readonly property real timeToEmpty: device?.timeToEmpty ?? 0
    readonly property real timeToFull: device?.timeToFull ?? 0

    readonly property string timeRemaining: {
        const secs = charging ? timeToFull : timeToEmpty;
        if (secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
