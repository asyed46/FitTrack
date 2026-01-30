//
//  SupabaseConfig.swift
//  FitTrack
//
//  Local (uncommitted) Supabase configuration loader.
//

import Foundation

struct SupabaseConfig {
    let urlString: String
    let anonKey: String

    static func load() -> SupabaseConfig {
        // 1) Xcode scheme env vars (best local-only option; never committed)
        let env = ProcessInfo.processInfo.environment
        if let urlString = env["SUPABASE_URL"], !urlString.isEmpty,
           let anonKey = env["SUPABASE_ANON_KEY"], !anonKey.isEmpty {
            return SupabaseConfig(urlString: urlString, anonKey: anonKey)
        }

        // Prefer a local, untracked plist in the app bundle.
        // Create it by copying SupabaseConfig.example.plist -> SupabaseConfig.plist
        // and filling in values.
        if let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            let urlString = (dict["SUPABASE_URL"] as? String) ?? ""
            let anonKey = (dict["SUPABASE_ANON_KEY"] as? String) ?? ""
            return SupabaseConfig(urlString: urlString, anonKey: anonKey)
        }

        // Fallback to Info.plist (not recommended for secrets; useful for CI/preview).
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
        return SupabaseConfig(urlString: urlString, anonKey: anonKey)
    }
}
