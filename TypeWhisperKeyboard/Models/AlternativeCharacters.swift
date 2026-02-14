import Foundation

enum AlternativeCharacters {
    private static let map: [String: [String]] = [
        // Vowels
        "a": ["à", "á", "â", "ä", "æ", "ã", "å"],
        "e": ["è", "é", "ê", "ë", "ę", "ė"],
        "i": ["î", "ï", "í", "ì", "į"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "õ"],
        "u": ["û", "ü", "ù", "ú"],
        // Umlauts (reverse mapping)
        "ä": ["a", "à", "á", "â", "ã"],
        "ö": ["o", "ò", "ó", "ô", "õ"],
        "ü": ["u", "ù", "ú", "û"],
        // Consonants
        "c": ["ç", "ć", "č"],
        "n": ["ñ", "ń"],
        "s": ["ß", "ś", "š"],
        "ß": ["s", "ś"],
        "ñ": ["n", "ń"],
        "y": ["ÿ"],
        "l": ["ł"],
        "z": ["ž", "ź", "ż"],
        "d": ["ð"],
        "r": ["ř"],
        "t": ["þ", "ť"],
    ]

    static func alternatives(for key: String, shifted: Bool) -> [String]? {
        let lower = key.lowercased()
        guard let alts = map[lower], !alts.isEmpty else { return nil }
        return shifted ? alts.map { $0.uppercased() } : alts
    }
}
