import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Charge utile du glisser-déposer tiroir → journée. DTO `Codable` en `.json` :
/// un `UTType` maison ne se déclenche pas avec `CodableRepresentation` sous Xcode 26 (ADR-008).
nonisolated struct TaskDragItem: Codable, Transferable, Sendable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
