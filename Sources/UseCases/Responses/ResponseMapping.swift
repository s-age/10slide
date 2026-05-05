import Foundation

extension SlideshowResponse {
    init(from entity: Slideshow) {
        self.init(
            id: entity.id,
            name: entity.name,
            slides: entity.slides.map { SlideResponse(from: $0) },
            config: SlideshowConfigResponse(from: entity.config),
            createdAt: entity.createdAt
        )
    }
}

extension SlideResponse {
    init(from entity: Slide) {
        self.init(
            id: entity.id,
            localIdentifier: entity.localIdentifier,
            order: entity.order,
            duration: entity.duration,
            title: entity.title
        )
    }
}

extension SlideshowConfigResponse {
    init(from entity: SlideshowConfig) {
        self.init(
            duration: SlideDurationResponse(from: entity.duration),
            transition: TransitionTypeResponse(from: entity.transition),
            loop: entity.loop
        )
    }

    var toDomain: SlideshowConfig {
        SlideshowConfig(
            duration: duration.toDomain,
            transition: transition.toDomain,
            loop: loop
        )
    }
}

extension SlideDurationResponse {
    init(from entity: SlideDuration) {
        self = switch entity {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }

    var toDomain: SlideDuration {
        switch self {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }
}

extension TransitionTypeResponse {
    init(from entity: TransitionType) {
        self = switch entity {
        case .none: .none
        case .fade: .fade
        case .slide: .slide
        case .dissolve: .dissolve
        }
    }

    var toDomain: TransitionType {
        switch self {
        case .none: .none
        case .fade: .fade
        case .slide: .slide
        case .dissolve: .dissolve
        }
    }
}
