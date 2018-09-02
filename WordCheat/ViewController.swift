import UIKit

final class ViewController: UITableViewController {
    private let lookupQueue = DispatchQueue(label: "lookup")
    private lazy var lookupDebouncer = createDebouncer(queue: lookupQueue)
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Enter Letters"
        searchController.searchBar.delegate = self
        searchController.searchBar.scopeButtonTitles = scopePrefixes
        return searchController
    }()
    private var dictionaries: [Lookup] = []
    private var words: [(length: Int, words: [String])] = []
    private let scopePrefixes = ["WWF", "TWL06", "SOWPODS"]
    private let wildcard: Character = "?"
    private let alphabet = Character.alphabet().map(String.init)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController
        definesPresentationContext = true
        prepareDictionaries()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.searchBar.becomeFirstResponder()
    }
    
    private func prepareDictionaries() {
        lookupQueue.async { [weak self] in
            self?.dictionaries = [
                AnagramDictionary(filename: "wordswithfriends_anagrams")!,
                AnagramDictionary(filename: "twl06_anagrams")!,
                AnagramDictionary(filename: "sowpods_anagrams")!,
            ]
        }
    }

    private func combinations(for searchText: String,
                              in dictionary: Lookup) -> LazyCollection<[Combination]> {
        guard let wildcardIndex = searchText.index(of: wildcard) else {
            return dictionary.combinations(for: searchText)
        }
        let nextIndex = searchText.index(after: wildcardIndex)
        return alphabet
            .map { searchText.replacingCharacters(in: wildcardIndex..<nextIndex, with: $0) }
            .map { combinations(for: $0, in: dictionary) }
            .reduce([Combination](), +)
            .sorted(by: { $0.0 > $1.0 })
            .lazy
    }
    
    fileprivate func filter(_ searchText: String, at index: Int) {
        if searchText.isEmpty || searchText.count < 2 {
            searchController.searchBar.scopeButtonTitles = scopePrefixes
            words = []
            tableView.reloadData()
        } else {
            lookupDebouncer { [weak self] in
                guard let `self` = self else { return }
                let combinations = self.combinations(for: searchText, in: self.dictionaries[index])
                let results = combinations.reduce(0, { $0 + $1.words.count })
                let prefixes = self.scopePrefixes.suffix(at: index, count: results)
                DispatchQueue.main.async {
                    self.searchController.searchBar.scopeButtonTitles = prefixes
                    self.words = Array(combinations)
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension Character {
    static func alphabet() -> [Character] {
        let a = Unicode.Scalar("a").value, z = Unicode.Scalar("z").value
        return (a...z).compactMap(Unicode.Scalar.init).map(Character.init)
    }
}

extension Sequence where Element == String {
    func suffix(at index: Int, count: Int) -> [String] {
        guard count > 0 else { return Array(self) }
        return enumerated().map {
            return $0 == index && count > 0 ? "\($1) (\(count))" : $1
        }
    }
}

extension ViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return words.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return words[section].words.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(words[section].length) letter words"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = words[indexPath.section].words[indexPath.row]
        return cell
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filter(searchBar.text ?? "", at: selectedScope)
    }
}

extension ViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        filter(searchBar.text ?? "", at: searchBar.selectedScopeButtonIndex)
    }
}
