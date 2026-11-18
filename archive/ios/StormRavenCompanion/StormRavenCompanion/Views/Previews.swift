import SwiftUI

#if DEBUG
/// Canvas preview data for the status screen (not compiled into release paths).
struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        StatusView().preferredColorScheme(.dark)
    }
}
#endif
