/*
 SystemInfo+Figure.swift
 UserInterface

 Created by fl03er on 2026/10/20.
 Copyright 2026 fl03er

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import SystemInfoKit

// What each dashboard card's figure shows (see MetricFigureView).
extension SystemInfo {
    var figureKind: MetricFigureView.Kind {
        switch type {
        case .cpu: .cpu
        case .memory: .memory
        case .storage: .storage
        case .battery: .battery
        case .network: .network
        }
    }

    /// Load, fill or charge in 0...1; for the network, traffic on a log scale from 1 kB/s to 10 MB/s.
    var figureValue: Double {
        if let network = self as? NetworkInfo {
            let total = network.upload.byteCount + network.download.byteCount
            guard network.hasConnection, total > 1_000 else { return 0 }
            return min(1, log10(total / 1_000) / 4)
        }
        if let battery = self as? BatteryInfo, !battery.isInstalled {
            return 1
        }
        return min(1, max(0, percentage.rawValue))
    }

    /// Battery: 1 on power, 0 on battery. Network: -1 all upload ... 1 all download.
    var figureAux: Double {
        if let battery = self as? BatteryInfo {
            return battery.isCharging || !battery.isInstalled || battery.adapterName != nil ? 1 : 0
        }
        if let network = self as? NetworkInfo {
            let up = network.upload.byteCount, down = network.download.byteCount
            return up + down > 0 ? (down - up) / (up + down) : 0
        }
        return 0
    }
}
