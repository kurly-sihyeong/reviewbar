import SwiftUI
import AppKit

struct ContentView: View {
    let model: AppModel
    @Environment(\.openURL) private var openURL
    @State private var contentHeight: CGFloat = 0

    private let maxListHeight: CGFloat = 600

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let err = model.errorMessage { errorBanner(err) }
            Divider()
            listOrLoading
            Divider()
            footerBar
        }
        .frame(width: 400)   // 가로만 고정, 세로는 컨텐츠에 맞춰 동적
        .background(WindowAccessor { window in   // 메뉴 열 때마다 새로고침 관찰
            model.attachWindow(window)
        })
    }

    // MARK: - 본문 (첫 로딩 / 카드 목록)

    @ViewBuilder
    private var listOrLoading: some View {
        if model.lastUpdated == nil && model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("GitHub에서 불러오는 중…")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
        } else {
            ScrollView {
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        GroupCard(title: "리뷰할 PR", subtitle: "다른 사람", systemImage: "tray.and.arrow.down",
                                  total: model.reviewPending.count + model.reviewApproved.count) {
                            SubSection(title: "미승인", systemImage: "clock", tint: .orange,
                                       prs: model.reviewPending, showAuthor: true)
                            SubSection(title: "승인됨", systemImage: "checkmark.seal.fill", tint: .green,
                                       prs: model.reviewApproved, showAuthor: true)
                        }
                        GroupCard(title: "내 PR", subtitle: "내가 작성", systemImage: "person.crop.circle",
                                  total: model.minePending.count + model.mineApproved.count) {
                            SubSection(title: "리뷰 전", systemImage: "pencil.circle", tint: .orange,
                                       prs: model.minePending, showAuthor: false)
                            SubSection(title: "리뷰 완료", systemImage: "paperplane.fill", tint: .green,
                                       prs: model.mineApproved, showAuthor: false)
                        }
                    }
                }
                .padding(12)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(height: min(max(contentHeight, 1), maxListHeight))
        }
    }

    // MARK: - 헤더 / 에러 / 푸터

    private var headerBar: some View {
        HStack(spacing: 8) {
            if let icon = MenuBarIcon.github {
                Image(nsImage: icon).resizable().frame(width: 15, height: 15).opacity(0.7)
            } else {
                Image(systemName: "arrow.triangle.branch").foregroundStyle(.secondary)
            }
            Text("PR 리뷰 현황").font(.headline)
            Spacer()
            if model.isLoading {
                if model.lastUpdated != nil {
                    Text("갱신 중").font(.caption2).foregroundStyle(.tertiary)
                }
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func errorBanner(_ msg: String) -> some View {
        Text("⚠︎ \(msg)")
            .font(.caption).foregroundStyle(.red).lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.bottom, 6)
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            Button { Task { await model.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
            .pointerStyle(.link)
            .help("새로고침")

            if let t = model.lastUpdated {
                Text("\(t, style: .relative) 전")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Spacer()

            Button { openURL(Config.webSearchURL(Config.reviewBase)) } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.glass).pointerStyle(.link).help("리뷰요청 검색 결과 열기")

            Button { openURL(Config.webSearchURL(Config.mineBase)) } label: {
                Image(systemName: "person.crop.circle")
            }
            .buttonStyle(.glass).pointerStyle(.link).help("내 PR 검색 결과 열기")

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.glass).pointerStyle(.link).help("앱 종료")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - 대분류 카드

struct GroupCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let total: Int
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                CountPill(count: total)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass(cornerRadius: 14)
    }
}

// MARK: - 하위 분류 (미승인/승인 · 리뷰 전/완료)

struct SubSection: View {
    let title: String
    let systemImage: String
    let tint: Color
    let prs: [PullRequest]
    let showAuthor: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.caption).foregroundStyle(tint)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text("\(prs.count)").font(.caption).foregroundStyle(.tertiary)
            }
            if prs.isEmpty {
                Text("없음").font(.caption).foregroundStyle(.tertiary)
                    .padding(.leading, 4).padding(.vertical, 1)
            } else {
                ForEach(prs) { pr in
                    PRRow(pr: pr, showAuthor: showAuthor, tint: tint)
                        .onTapGesture { if let u = URL(string: pr.url) { openURL(u) } }
                }
            }
        }
    }
}

// MARK: - PR 행

struct PRRow: View {
    let pr: PullRequest
    let showAuthor: Bool
    let tint: Color
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(tint).frame(width: 6, height: 6).padding(.top, 6)

            AsyncImage(url: URL(string: pr.author?.avatarUrl ?? "")) { image in
                image.resizable()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 18, height: 18)
            .clipShape(Circle())
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(pr.title)
                    .font(.callout).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !pr.labelList.isEmpty { labelChips }
                Text(metaLine).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var labelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pr.labelList) { label in
                    Text(label.name)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color(hex: label.color).opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(Color(hex: label.color).opacity(0.55), lineWidth: 0.5))
                }
            }
        }
    }

    private var metaLine: String {
        let author = showAuthor ? "@\(pr.author?.login ?? "?") · " : ""
        let rel = pr.createdAt.formatted(.relative(presentation: .named))
        return "\(author)\(pr.repoName) #\(pr.number) · \(rel)"
    }
}

// MARK: - 카운트 pill

struct CountPill: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
