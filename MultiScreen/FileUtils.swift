import UIKit

class FileUtils {
    
    static func AbsPath(_ rel_path:String)->String{
        let path = BundlePath(rel_path)
        return "file://" + path
    }
    
    static func BundlePath(_ rel_path:String)->String{
        return Bundle.main.resourcePath! + "/www.bundle/" + rel_path as String
    }
    
    static func FileContents(_ path:String)->Result<String, Error>{
        
        do {
            let content = try String(contentsOfFile:path, encoding:String.Encoding.utf8) as String
            return .success(content)
        } catch let error  {
            return .failure(error)
        }
    }
    
    static func ConcatenateFileContents(_ paths:Array<String>)->Result<String, Error>{
        
        var concatenated = ""
        
        for path in paths {
            
            let bundle_path = BundlePath(path)
            let rsp = FileContents(bundle_path)
            
            switch rsp {
            case .failure(let error):
                print(error)
            case .success(let body):
                concatenated += body;
            }
        }
        
        return .success(concatenated)
    }
    
}
