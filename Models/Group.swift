//
//  Group.swift
//  FitTrack
//
//  Created on 1/25/2026.
//

import Foundation

struct Group: Identifiable, Codable {
    let id: UUID
    var name: String
    var code: String // Unique code for joining
    var memberIds: [UUID]
    var createdBy: UUID
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, code: String = "", memberIds: [UUID] = [], createdBy: UUID, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.code = code.isEmpty ? Self.generateGroupCode() : code
        self.memberIds = memberIds
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
    
    private static func generateGroupCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
