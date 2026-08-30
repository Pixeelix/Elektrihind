//
//  SettingsComponents.swift
//  NordPrice
//

import SwiftUI
import UIKit

struct SettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Threshold text field

final class ThresholdFieldProxy {
    weak var field: UITextField?
    func focus() { field?.becomeFirstResponder() }
}

struct ThresholdTextField: UIViewRepresentable {
    @Binding var value: Double
    let formatter: NumberFormatter
    let proxy: ThresholdFieldProxy
    var onFocus: () -> Void = {}
    var onBlur: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.textAlignment = .right
        tf.font = .systemFont(ofSize: 17)
        tf.delegate = context.coordinator
        proxy.field = tf

        let bar = UIToolbar()
        bar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let ok = UIBarButtonItem(title: "OK", style: .done, target: context.coordinator, action: #selector(Coordinator.ok))
        bar.items = [spacer, ok]
        tf.inputAccessoryView = bar

        tf.text = formatter.string(from: NSNumber(value: value)) ?? ""
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        guard !tf.isFirstResponder else { return }
        tf.text = formatter.string(from: NSNumber(value: value)) ?? ""
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ThresholdTextField

        init(_ p: ThresholdTextField) { parent = p }

        @objc func ok() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            parent.onFocus()
            DispatchQueue.main.async {
                let end = tf.endOfDocument
                tf.selectedTextRange = tf.textRange(from: end, to: end)
            }
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            parent.onBlur()
            let text = tf.text ?? ""
            if let n = parent.formatter.number(from: text) {
                parent.value = n.doubleValue
            } else if let v = Double(text.replacingOccurrences(of: ",", with: ".")) {
                parent.value = v
            }
            tf.text = parent.formatter.string(from: NSNumber(value: parent.value)) ?? ""
        }
    }
}

