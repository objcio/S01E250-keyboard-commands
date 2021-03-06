//
//  Model.swift
//  VectorDrawing
//
//  Created by Chris Eidhof on 14.04.21.
//

import SwiftUI

struct Drawing {
    var elements: [Element] = []
    var selection: Set<Element.ID> = []
    
    struct Element: Identifiable {
        let id = UUID()
        var point: CGPoint
        var secondaryPoint: CGPoint?
        var _primaryPoint: CGPoint?
        
        var primaryPoint: CGPoint? {
            _primaryPoint ?? secondaryPoint?.mirrored(relativeTo: point)
        }
        
        init(point: CGPoint, secondaryPoint: CGPoint?) {
            self.point = point.rounded()
            self.secondaryPoint = secondaryPoint?.rounded()
        }
    }
}

extension Drawing.Element {
    var controlPoints: (CGPoint, CGPoint)? {
        guard let s = secondaryPoint, let p = primaryPoint else { return nil }
        return (p, s)
    }
    
    mutating func move(to: CGPoint) {
        let t = to.rounded()
        let diff = t - point
        point = t
        secondaryPoint = secondaryPoint.map { $0 + diff }
    }
    
    mutating func move(by amount: CGPoint) {
        move(to: point + amount)
    }
    
    mutating func moveControlPoint1(to: CGPoint, option: Bool) {
        let t = to.rounded()
        if option || _primaryPoint != nil {
            _primaryPoint = t
        } else {
            secondaryPoint = t.mirrored(relativeTo: point)
        }
    }
    
    mutating func moveControlPoint2(to: CGPoint, option: Bool) {
        let t = to.rounded()
        if option && _primaryPoint == nil {
            _primaryPoint = secondaryPoint?.mirrored(relativeTo: point)
        }
        secondaryPoint = t
    }
    
    mutating func resetControlPoints() {
        _primaryPoint = nil
        secondaryPoint = nil
    }
    
    mutating func setCoupledControlPoints(secondary point: CGPoint) {
        _primaryPoint = nil
        secondaryPoint = point.rounded()
    }
}

extension Drawing {
    var path: Path {
        var result = Path()
        guard let f = elements.first else { return result }
        result.move(to: f.point)
        var previousControlPoint: CGPoint? = nil
        
        for element in elements.dropFirst() {
            if let previousCP = previousControlPoint {
                let cp2 = element.controlPoints?.0 ?? element.point
                result.addCurve(to: element.point, control1: previousCP, control2: cp2)
            } else {
                if let mirrored = element.controlPoints?.0 {
                    result.addQuadCurve(to: element.point, control: mirrored)
                } else {
                    result.addLine(to: element.point)
                }
            }
            previousControlPoint = element.secondaryPoint
        }
        return result
    }

    mutating func update(for state: DragGesture.Value) {
        let isDrag = state.startLocation.distance(to: state.location) > 1
        elements.append(Element(point: state.startLocation, secondaryPoint: isDrag ? state.location : nil))
    }
    
    mutating func move(by amount: CGPoint) {
        let ixs = elements.indices.filter { idx in
            selection.contains(elements[idx].id)
        }
        for ix in ixs {
            elements[ix].move(by: amount)
        }
    }
    
    mutating func moveKeyCommand(_ direction: MoveCommandDirection, shiftPressed: Bool) {
        var point = CGPoint.zero
        let step: CGFloat = shiftPressed ? 10 : 1
        switch direction {
        case .up:
            point.y = -step
        case .down:
            point.y = step
        case .left:
            point.x = -step
        case .right:
            point.x = step
        @unknown default:
            ()
        }
        move(by: point)
    }
    
    mutating func delete() {
        elements.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
    
    mutating func select(_ id: Element.ID, exclusive: Bool) {
        if exclusive {
            selection = [id]
        } else {
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
        }
    }
}
