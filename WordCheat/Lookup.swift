import Foundation

typealias Anagrams = [String]
typealias Words = [String: Anagrams]
typealias FixedLetters = [Int: Character]
typealias Combination = (length: Int, words: [String])

func hashed(_ word: String) -> String {
    return String(word.sorted())
}

func hashed(_ characters: [Character]) -> String {
    return String(characters.sorted())
}

protocol Lookup {
    /// - letters: Letters to use in anagrams (including fixed letters).
    /// - returns: Anagrams for provided the letters.
    subscript(letters: String) -> Anagrams? { get }
    /// - letters: Letters to use in anagrams (including fixed letters).
    /// - fixedLetters: Index-Character dictionary for all spots that are currently filled.
    /// - returns: Anagrams for provided the letters where fixed letters match and remaining letters.
    subscript(letters: String, fixedLetters: FixedLetters) -> Anagrams? { get }
    /// - letters: Letters to use in anagrams (including fixed letters).
    /// - returns: Anagrams for provided the letters.
    subscript(letters: [Character]) -> Anagrams? { get }
    /// - letters: Letters to use in anagrams (including fixed letters).
    /// - fixedLetters: Index-Character dictionary for all spots that are currently filled.
    /// - returns: Anagrams for provided the letters where fixed letters match and remaining letters.
    subscript(letters: [Character], fixedLetters: FixedLetters) -> Anagrams? { get }
}

extension Lookup {
    func combinations(for word: String) -> LazyCollection<[Combination]> {
        let characters = Array(word.lowercased())
        return (2...characters.count)
            .compactMap { (index) in
                let combinations = Set(characters.combinations(index).map { hashed($0) })
                    .compactMap { self[$0] }
                    .flatMap { $0 }
                    .filter { !$0.isEmpty }
                    .sorted()
                return combinations.isEmpty ? nil : (index, combinations)
            }
            .sorted(by: { $0.0 > $1.0 })
            .lazy
    }
}

extension Lookup {
    subscript(letters: String) -> Anagrams? {
        return self[Array(letters)]
    }
    subscript(letters: String, fixedLetters: FixedLetters) -> Anagrams? {
        return self[Array(letters), fixedLetters]
    }
    subscript(letters: [Character], fixedLetters: FixedLetters) -> Anagrams? {
        return self[letters]?.filter({ word in
            var remainingForWord = letters
            for (index, char) in word.enumerated() {
                if let fixed = fixedLetters[index], char != fixed {
                    return false
                }
                guard let firstIndex = remainingForWord.index(of: char) else {
                    // We ran out of viable letters for this word
                    return false
                }
                // Remove from pool, word still appears to be valid
                remainingForWord.remove(at: firstIndex)
            }
            return true
        })
    }
}

struct AnagramDictionary: Lookup {
    private let words: Words
    
    subscript(letters: [Character]) -> Anagrams? {
        return words[hashed(letters)]
    }
    
    static func deserialize(_ data: Data) -> AnagramDictionary? {
        guard let words = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! Words else {
            return nil
        }
        return AnagramDictionary(words: words)
    }
    
    static func load(_ path: String) -> AnagramDictionary? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return AnagramDictionary.deserialize(data)
    }
    
    init?(filename: String, type: String = "bin", bundle: Bundle = .main) {
        guard
            let anagramPath = bundle.path(forResource: filename, ofType: type),
            let anagramDictionary = AnagramDictionary.load(anagramPath) else {
                return nil
        }
        self = anagramDictionary
        debugPrint("Count: \(anagramDictionary.words.count)")
    }
    
    init(words: Words) {
        self.words = words
    }
}
