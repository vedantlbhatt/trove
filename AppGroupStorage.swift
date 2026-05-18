// AppGroupStorage.swift
// Shared storage helpers for App Group pipeline
//
// IMPORTANT: Set the app group identifier below. This must match the App Group
// capability configured for BOTH the main app target and the Share Extension target.

import Foundation
import UniformTypeIdentifiers
import UIKit

enum AppGroupStorage {
    // Replace with your real App Group identifier, e.g., "group.com.yourcompany.catchapp"
    static let appGroupID = "group.com.app.catch"

    // Directory inside the shared container for incoming items
    static let inboxDirectoryName = "ShareInbox"

    // MARK: - Types
    enum InboxRecord: Codable {
        case link(url: URL)
        case file(url: URL)
    }

    // MARK: - Container URLs
    private static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func inboxDirectoryURL() -> URL? {
        guard let base = containerURL() else { return nil }
        let url = base.appendingPathComponent(inboxDirectoryName, conformingTo: .folder)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // MARK: - Save primitives
    @discardableResult
    static func saveFile(at sourceURL: URL) -> URL? {
        guard let inbox = inboxDirectoryURL() else { return nil }
        let destination = inbox.appendingPathComponent(UUID().uuidString + "-" + sourceURL.lastPathComponent)
        do {
            // If source is outside the group container, copy; if within, move is fine too
            if FileManager.default.isReadableFile(atPath: sourceURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destination)
            }
            return destination
        } catch {
            // If copy fails (e.g. same volume), try move
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destination)
                return destination
            } catch {
                print("AppGroupStorage: failed to persist file: \(error)")
                return nil
            }
        }
    }

    @discardableResult
    static func saveImage(_ image: UIImage, quality: CGFloat = 0.9) -> URL? {
        guard let inbox = inboxDirectoryURL() else { return nil }
        let url = inbox.appendingPathComponent("image-\(UUID().uuidString).jpg")
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("AppGroupStorage: failed to write image: \(error)")
            return nil
        }
    }

    @discardableResult
    static func saveData(_ data: Data, suggestedName: String) -> URL? {
        guard let inbox = inboxDirectoryURL() else { return nil }
        let url = inbox.appendingPathComponent("\(UUID().uuidString)-\(suggestedName)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("AppGroupStorage: failed to write data: \(error)")
            return nil
        }
    }

    // MARK: - Inbox index (UserDefaults)
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static let inboxKey = "shared.inbox.records"

    static func appendInboxRecord(_ record: InboxRecord) {
        var current = fetchInboxRecords()
        current.append(record)
        saveInboxRecords(current)
    }

    static func fetchInboxRecords() -> [InboxRecord] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: inboxKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([InboxRecord].self, from: data)
        } catch {
            print("AppGroupStorage: failed to decode inbox: \(error)")
            return []
        }
    }

    static func saveInboxRecords(_ records: [InboxRecord]) {
        guard let defaults = defaults else { return }
        do {
            let data = try JSONEncoder().encode(records)
            defaults.set(data, forKey: inboxKey)
        } catch {
            print("AppGroupStorage: failed to encode inbox: \(error)")
        }
    }

    static func clearInbox() {
        defaults?.removeObject(forKey: inboxKey)
    }
}
