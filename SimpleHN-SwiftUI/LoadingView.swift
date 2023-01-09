//
//  LoadingView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 17/8/2022.
//

import SwiftUI

struct LoadingView: View {
    @Binding var isFailed: Bool
    let onTapRetry: () -> Void
    
    init(isFailed: Binding<Bool> = .constant(false), onTapRetry: @escaping () -> Void = {}) {
        _isFailed = isFailed
        self.onTapRetry = onTapRetry
    }
    
    var body: some View {
        return VStack() {
            Spacer()
            
            if isFailed {
                LoadingFailedView(isFailed: $isFailed, onTapRetry: onTapRetry)
                
            } else {
                ProgressView()
                    .scaleEffect(2)
            }

            Spacer()
        }
    }
}

struct LoadingFailedView: View {
    @GestureState var isRetryTapped: Bool = false
    @Binding var isFailed: Bool
    
    let onTapRetry: () -> Void
    
    var body: some View {
        let tap = DragGesture(minimumDistance: 0)
            .updating($isRetryTapped) { (_, isTapped, _) in
                isTapped = true
            }
        
        VStack {
            Image(systemName: "exclamationmark.circle.fill")
                .renderingMode(.template)
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(Color.gray.opacity(0.3))
                .padding(.bottom, 10)
            
            VStack(spacing: 3) {
                Text("Oops, a problem occurred")
                    .font(.headline)
                
                Text("Please check your connection and try again")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
            }
            
            Button {
                isFailed = false
                onTapRetry()
                
            } label: {
                Text("Try again")
                    .foregroundColor(.white)
                    .padding([.top, .bottom], 12)
                    .padding([.leading, .trailing], 30)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundColor( isRetryTapped ? Color("SBAccentDarkColor") : Color.accentColor )
                    }
            }
            .simultaneousGesture(tap)
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
        LoadingView(isFailed: .constant(true))
    }
}
