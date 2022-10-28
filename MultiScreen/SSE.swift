// https://gist.github.com/rizumita/d51a6e4c2f1232111a2339c206cfaaa0
// See notes in ViewController#handleSSEMessage where we are reconstructing
// and entire Location struct (as in Location.swift) in order to serialize
// it for WebKit/Javascript. Ideally all the "Any" -related hoop-jumping
// below can and will be replaced by a well-known and well-defined SSE
// message struct that can be easily decoded/encoded. Given the variety of
// different SSE message types I don't know whether this is easy or not
// yet.

struct AnyCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    
    init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: [Any].Type, forKey key: K) throws -> [Any] {
    var container = try self.nestedUnkeyedContainer(forKey: key)
    return try container.decode(type)
    }
    
    func decodeIfPresent(_ type: [Any].Type, forKey key: K) throws -> [Any]? {
    guard contains(key) else { return .none }
    return try decode(type, forKey: key)
    }
    
    func decode(_ type: [String:Any].Type, forKey key: K) throws -> [String:Any] {
    let container = try nestedContainer(keyedBy: AnyCodingKeys.self, forKey: key)
    return try container.decode(type)
    }
    
    func decodeIfPresent(_ type: [String:Any].Type, forKey key: K) throws -> [String:Any]? {
    guard contains(key) else { return .none }
    return try decode(type, forKey: key)
    }
    
    func decode(_ type: [String:Any].Type) throws -> [String:Any] {
    var dictionary = [String:Any]()
    
    allKeys.forEach { key in
        if let value = try? decode(Bool.self, forKey: key) {
        dictionary[key.stringValue] = value
        } else if let value = try? decode(String.self, forKey: key) {
        dictionary[key.stringValue] = value
        } else if let value = try? decode(Int64.self, forKey: key) {
        dictionary[key.stringValue] = value
        } else if let value = try? decode(Double.self, forKey: key) {
        dictionary[key.stringValue] = value
        } else if let value = try? decode([String:Any].self, forKey: key) {
        dictionary[key.stringValue] = value
        } else if let value = try? decode([Any].self, forKey: key) {
        dictionary[key.stringValue] = value
        }
    }
    
    return dictionary
    }
}

extension UnkeyedDecodingContainer {
    mutating func decode(_ type: [Any].Type) throws -> [Any] {
    var array = [Any]()
    
    while isAtEnd == false {
        if let value = try? decode(Bool.self) {
        array.append(value)
        } else if let value = try? decode(String.self) {
        array.append(value)
        } else if let value = try? decode(Int64.self) {
        array.append(value)
        } else if let value = try? decode(Double.self) {
        array.append(value)
        } else if let value = try? decode([String:Any].self) {
        array.append(value)
        } else if let value = try? decode([Any].self) {
        array.append(value)
        }
    }
    
    return array
    }
    
    mutating func decode(_ type: [String:Any].Type) throws -> [String:Any] {
    let nestedContainer = try self.nestedContainer(keyedBy: AnyCodingKeys.self)
    return try nestedContainer.decode(type)
    }
}

struct SSEMessage: Decodable {
    let type: String
    let data: Data?
    
    struct Data: Decodable {
    let items: [String:Any]
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKeys.self)
        items = try container.decode([String:Any].self)
    }
    }
}
