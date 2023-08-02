import SwiftUI

struct ImageViewer: View {

  @Binding var image: AnnotatedImage
  let scaleFactor: CGFloat
  let showAnnotationLabels: Bool
  let draftCoords: CGRect?
  let dragFromCentre: Bool

  @State var creatingAnnotation = false
  @State var movingAnnotation = false
  @State var newAnnotationCenter = CGPoint.zero
  @State var newAnnotationCorner = CGPoint.zero
  @State var movingAnnotationSize = CGSize.zero
  
  var newAnnotationSize: CGSize {
    CGSize(
      width: abs(newAnnotationCenter.x - newAnnotationCorner.x) * 2,
      height: abs(newAnnotationCenter.y - newAnnotationCorner.y) * 2
    )
  }
  
  var newAnnotation: CGRect {
    CGRect(origin: newAnnotationCenter, size: newAnnotationSize)
  }

  var annotations: [Annotation] {
    image.annotations
  }
  
  func handleDragChangeFromCentre(gestureValue: DragGesture.Value) {
    if !self.creatingAnnotation {
      self.creatingAnnotation.toggle()
      self.newAnnotationCenter = gestureValue.startLocation
    }
    self.newAnnotationCorner = gestureValue.location
  }
  
  func handleDragChangeFromCorner(gestureValue: DragGesture.Value) {
    if !self.creatingAnnotation {
      self.creatingAnnotation.toggle()
      self.newAnnotationCorner = gestureValue.startLocation
    }
    
    let width = gestureValue.location.x - gestureValue.startLocation.x
    let height = gestureValue.location.y - gestureValue.startLocation.y
    
    let midpointX = gestureValue.startLocation.x + (width / 2.0)
    let midpointY = gestureValue.startLocation.y + (height / 2.0)
    
    self.newAnnotationCenter = CGPoint(x: midpointX, y: midpointY)
  }
  
  var body: some View {
    GeometryReader { p in
      Image(nsImage: NSImage(byReferencing: self.image.url))
      .resizable()
      .aspectRatio(contentMode: .fit)
      .anchorPreference(
        key: ImageSizePrefKey.self,
        value: .bounds,
        transform: {
          p[$0].size
        }
      )
      .gesture(
        DragGesture()
        .onChanged {
          if (dragFromCentre) {
            handleDragChangeFromCentre(gestureValue: $0)
          } else {
            handleDragChangeFromCorner(gestureValue: $0)
          }
        }
        .onEnded { _ in
          self.image.addAnnotation(withCoordinates: self.newAnnotation.scaledBy(1 / self.scaleFactor))
          self.creatingAnnotation.toggle()
        }
      )
      .border(Color.accentColor, width: 1)
      .overlay(
        self.annotationsBody
      )
      .clipped()
    }
  }
  
  var annotationsBody: some View {
    ZStack { // (alignment: .topLeading) {
      if creatingAnnotation {
        Rectangle()
        .frame(width: newAnnotationSize.width, height: newAnnotationSize.height)
        .position(newAnnotationCenter)
        .foregroundColor(.blue)
        .opacity(0.5)
      }
      if movingAnnotation {
        Rectangle()
        .frame(width: movingAnnotationSize.width, height: movingAnnotationSize.height)
        .position(newAnnotationCenter)
        .foregroundColor(.green)
        .opacity(0.5)
      }
      if draftCoords != nil {
        Rectangle()
        .frame(width: draftCoords!.size.scaledBy(self.scaleFactor).width, height: draftCoords!.size.scaledBy(self.scaleFactor).height)
        .position(draftCoords!.origin.scaledBy(self.scaleFactor))
        .foregroundColor(.green)
        .opacity(0.5)
      }
      ForEach(annotations) { annotation in
        Rectangle()
        .frame(width: annotation.size.scaledBy(self.scaleFactor).width, height: annotation.size.scaledBy(self.scaleFactor).height)
        .position(annotation.origin.scaledBy(self.scaleFactor))
        .foregroundColor(annotation.isSelected ? .yellow : .blue)
        .opacity(annotation.isMoving ? 0.25 : 0.5)
        .overlay(
          !self.showAnnotationLabels
            ? nil
            : Text("\(annotation.label)")
            .lineLimit(1)
            .fixedSize()
            .font(.footnote)
            .foregroundColor(.secondary)
            .background(annotation.isSelected ? Color.yellow : Color.blue)
            .position(annotation.origin.scaledBy(self.scaleFactor))
            .offset(x: annotation.size.scaledBy(self.scaleFactor).width / 2, y: annotation.size.scaledBy(self.scaleFactor).height / 2)
        )
        .onTapGesture {
          self.image.toggle(annotation: annotation)
        }
        .gesture(
          DragGesture()
          .onChanged {
            if !self.movingAnnotation {
              self.movingAnnotation.toggle()
              self.image.beginMoving(annotation: annotation)
              self.movingAnnotationSize = annotation.size.scaledBy(self.scaleFactor)
            }
            self.newAnnotationCenter = $0.location
          }
          .onEnded { _ in
            self.image.move(annotation: annotation, to: self.newAnnotationCenter.scaledBy(1 / self.scaleFactor))
            self.movingAnnotation.toggle()
          }
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct ImageViewer_Previews: PreviewProvider {
  static var previews: some View {
    ImageViewer(image: .constant(AnnotatedImage(url: URL(string: "")!)), scaleFactor: 1.5, showAnnotationLabels: false, draftCoords: nil, dragFromCentre: true)
  }
}
