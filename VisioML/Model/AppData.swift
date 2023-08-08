import Combine
import Foundation
import CoreImage
import ImageIO

class AppData: ObservableObject {

  static let shared = AppData()
  
  @Published var navigation = NavigationState()
  @Published var settings = WorkspaceSettings() {
    didSet {
      guard let dirUrl = workingFolder?.appendingPathComponent(".visioannotate") else {
          return
      }
      var isDirectory: ObjCBool = ObjCBool(false)
      let exists = FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDirectory)
      if !exists || !isDirectory.boolValue {
        do {
          try FileManager.default.createDirectory(at: dirUrl, withIntermediateDirectories: false)
        } catch {
          print("\(error.localizedDescription)")
          return
        }
      }
      let url = dirUrl.appendingPathComponent("workspace.json")
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      guard let data = try? encoder.encode(settings) else {
        return
      }
      try! data.write(to: url)
    }
  }
  @Published var annotatedImages = [AnnotatedImage]()
  @Published var outputImages = [AnnotatedImage]()
  @Published var workingFolder: URL?
  @Published var outFolder: URL?
  @Published var viewportSize: CGSize = CGSize.zero
  @Published var draftCoords = CGRect?.none
  @Published var dragFromCentre = true
  @Published var showImagesInSidebar = true
  var cancelSyntheticsProcess = false

  var currentScaleFactor: CGFloat? {
    guard let image = activeImage, let size = image.size else {
      return nil
    }
    return viewportSize.width / size.width
  }
  
  var pendingImages: Int {
    (outFolder == nil ? annotatedImages : outputImages).reduce(0) {
      $0 + ($1.isEnabled ? 0 : 1)
    }
  }

  var folderWatcher: DirectoryWatcher?

  var activeImage: AnnotatedImage? {
    guard let activeImageIndex = activeImageIndex else {
      return nil
    }
    return annotatedImages[activeImageIndex]
  }

  var activeImageIndex: Int? {
    annotatedImages.firstIndex(where: { $0.isActive == true } )
  }

  func toggleNavigator() {
    navigation.isNavigatorVisible.toggle()
  }
  
  func activateImage(_ annotatedImage: AnnotatedImage) {
    guard let index = annotatedImages.firstIndex(where: { $0.id == annotatedImage.id }) else {
      return
    }
    if let activeImageIndex = activeImageIndex {
      annotatedImages[activeImageIndex].isActive.toggle()
    }
    annotatedImages[index].isActive.toggle()
  }

  func toggleImage(_ annotatedImage: AnnotatedImage) {
    guard let index = annotatedImages.firstIndex(where: { $0.id == annotatedImage.id }) else {
      return
    }
    annotatedImages[index].isMarked.toggle()
  }

  func unsetWorkingFolder() {
    annotatedImages = []
    settings = WorkspaceSettings()
    workingFolder = nil
    outFolder = nil
  }
  
  func unsetOutFolder() {
    outFolder = nil
  }
  
  private func isDir(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    guard exists && isDirectory.boolValue else {
      return false
    }
    return true
  }

  func setWorkingFolder(_ url: URL) {
    guard isDir(url), let folderWatcher = DirectoryWatcher(url, callback: {
      self.refreshImages()
    }) else {
      return
    }
    self.folderWatcher = folderWatcher
    workingFolder = url
    loadSettings()
    loadJSON()
    refreshImages()
    navigation.isNavigatorVisible = true
    if annotatedImages.count > 0 {
      annotatedImages[0].isActive = true
    }
  }

  func setOutFolder(_ url: URL) {
    guard isDir(url) else {
      return
    }
    outFolder = url
  }

  func refreshImages() {
    guard let folder = workingFolder else {
      return
    }
    let files = try! FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
    let imageFiles = files.filter { $0.isImage }
    
    // Remove deleted images
    for image in annotatedImages {
      // Chceck if image is in dir contents
      if imageFiles.first(where: { $0 == image.url }) == nil {
        // Remove image from internal array
        annotatedImages.removeAll { $0.url == image.url }
      }
    }
    // Add new images only
    for file in imageFiles {
      guard annotatedImages.first(where: { $0.url == file }) == nil else {
        // Image was already there, leave as is
        continue
      }
      // Add the new image
      annotatedImages.append(AnnotatedImage(url: file))
    }
    // TODO: Handle renames
  }

  func loadSettings() {
    guard
      let url = workingFolder?.appendingPathComponent(".visioannotate") else {
        return
    }
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    guard
      exists && isDirectory.boolValue,
      let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]),
      let jsonFile = contents.first(where: { $0.lastPathComponent == "workspace.json" })
    else {
      return
    }
    settings = load(jsonFile) ?? WorkspaceSettings()
  }

  func loadJSON() {
    guard
      let url = workingFolder,
      let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]),
      let jsonFile = contents.first(where: { $0.lastPathComponent == "annotations.json" })
    else {
      return
    }
    annotatedImages = load(jsonFile) ?? []
  }

  func load<T: Decodable>(_ file: URL) -> T? {
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      fatalError("Couldn't load \(file.absoluteString) from main bundle:\n\(error)")
    }
    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      return nil
    }
  }

  private func saveJSON(imagesOverride: [AnnotatedImage]? = nil) {
    guard let folderUrl = outFolder ?? workingFolder else {
      return
    }
    let url = folderUrl.appendingPathComponent("annotations.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(imagesOverride ?? annotatedImages) else {
      return
    }
    try! data.write(to: url)
  }
  
  func export() {
    guard let folderUrl = outFolder else {
      print("only export images for output folder")
      saveJSON()
      return
    }
    
    var scaledImages: [AnnotatedImage] = []
    for annotatedImage in annotatedImages {
      let destinationUrl = folderUrl.appending(path: annotatedImage.shortName)
      guard let scaledImage = annotatedImage.exportImage(destinationURL: destinationUrl) else { return }
      scaledImages.append(scaledImage)
    }
    saveJSON(imagesOverride: scaledImages)
  }
  
  func removeActiveAnnotation() {
    annotatedImages.removeActiveAnnotation()
  }

  func activateNextImage() {
    annotatedImages.activateNext()
  }

  func activatePreviousImage() {
    annotatedImages.activateNext(reverse: true)
  }
}
