import WidgetKit
import SwiftUI

@main
struct SondeWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        RecentUpdatesWidget()
    }
}
