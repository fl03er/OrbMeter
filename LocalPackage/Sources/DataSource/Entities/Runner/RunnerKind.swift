/*
 RunnerKind.swift
 DataSource

 Created by Takuto Nakamura on 2026/05/09.
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

public enum RunnerKind: String, Sendable, Identifiable, CaseIterable {
    case working = "working"
    case searching = "searching"
    case solving = "solving"
    case listening = "listening"
    case connecting = "connecting"
    case weaving = "weaving"
    case composing = "composing"
    case breathing = "breathing"
    case shaping = "shaping"

    public var id: String { rawValue }

    var numberOfResources: Int {
        switch self {
        case .working: 16
        case .searching: 16
        case .solving: 47
        case .listening: 17
        case .connecting: 23
        case .weaving: 34
        case .composing: 29
        case .breathing: 24
        case .shaping: 52
        }
    }

    var frameOrder: FrameOrder {
        .ascending(numberOfResources)
    }
}
