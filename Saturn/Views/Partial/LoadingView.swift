//
//  LoadingView.swift
//  Saturn
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
        VStack {
            Spacer()
            if isFailed {
                LoadingFailedView(isFailed: $isFailed,
                                  onTapRetry: onTapRetry)
                
            } else {
                SpinnerView(configuration: .init(width: 50, height: 50, lineWidth: 10.0))
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
            
            VStack(spacing: 6) {
                Text("Could not load stories")
                    .fontWeight(.medium)
                    .font(.title3)
                
                Text("Please check your connection and try again")
                    .font(.body)
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
                            .foregroundColor( Color.accentColor )
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
