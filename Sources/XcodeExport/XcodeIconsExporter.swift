import Foundation
import FigmaExportCore

final public class XcodeIconsExporter: XcodeImagesExporterBase {

    public func export(icons: [AssetPair<ImagePack>], append: Bool) throws -> [FileContents] {
        // Generate metadata (Assets.xcassets/Icons/Contents.json)
        let contentsFile = XcodeEmptyContents().makeFileContents(to: output.assetsFolderURL)

        // Generate assets
        let assetsFolderURL = output.assetsFolderURL
        let preservesVectorRepresentation = output.preservesVectorRepresentation
        let filter = AssetsFilter(filters: preservesVectorRepresentation ?? [])
        
        let imageAssetsFiles = try icons.flatMap { imagePack -> [FileContents] in
            var preservesVector = filter.match(name: imagePack.light.name)
            var renderMode = imagePack.light.renderMode
            
            if let first = imagePack.light.images.first,
               (first.originalName.contains("Color=") ||
               imagePack.light.name.contains("colorPickerColor")) {
                preservesVector = false
                renderMode = .original
            }
            
            return try imagePack.makeFileContents(to: assetsFolderURL, preservesVector: preservesVector, renderMode: renderMode)
        }
        
        // Generate extensions
        let imageNames = icons.map { normalizeName($0.light.name) }
        let extensionFiles = try generateExtensions(names: imageNames, append: append)

        return [contentsFile] + imageAssetsFiles + extensionFiles
    }

}
