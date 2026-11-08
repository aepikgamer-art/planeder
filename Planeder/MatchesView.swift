import SwiftUI

struct MatchesView: View {
    @ObservedObject var store: MatchStore

    var body: some View {
        NavigationStack {
            Group {
                if store.matches.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "heart.slash").font(.system(size: 52)).foregroundStyle(.secondary)
                        Text("No matches yet, go swipe").font(.headline)
                    }
                } else {
                    List {
                        ForEach(store.matches) { match in
                            HStack(spacing: 12) {
                                AsyncImage(url: match.plane.imageURL.flatMap { URL(string: $0) }) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(match.plane.reg).font(.headline)
                                        if match.superLiked {
                                            Image(systemName: "airplane.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    Text("\(match.plane.airline) · \(match.plane.aircraft)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Unmatch", role: .destructive) { store.remove(match) }
                            }
                        }
 
                   }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Matches ✈️")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
