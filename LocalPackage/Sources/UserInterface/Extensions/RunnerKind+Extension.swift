/*
 RunnerKind+Extension.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/10.
 Copyright 2026 Kyome22 (Takuto Nakamura)

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

import DataSource

extension RunnerKind {
    var localizedName: String {
        switch self {
        case .working:
            String(localized: "working", table: "RunnerNames", bundle: .module)
        case .searching:
            String(localized: "searching", table: "RunnerNames", bundle: .module)
        case .solving:
            String(localized: "solving", table: "RunnerNames", bundle: .module)
        case .listening:
            String(localized: "listening", table: "RunnerNames", bundle: .module)
        case .connecting:
            String(localized: "connecting", table: "RunnerNames", bundle: .module)
        case .weaving:
            String(localized: "weaving", table: "RunnerNames", bundle: .module)
        case .composing:
            String(localized: "composing", table: "RunnerNames", bundle: .module)
        case .breathing:
            String(localized: "breathing", table: "RunnerNames", bundle: .module)
        case .shaping:
            String(localized: "shaping", table: "RunnerNames", bundle: .module)
        }
    }
}
