import SwiftUI
import UIKit

struct CountdownTimerPicker: UIViewRepresentable {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        picker.showsSelectionIndicator = false // Disable default selection indicators
        picker.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(picker)
        
        // Add static labels overlay positioned to align with selected numbers
        let hoursLabel = UILabel()
        hoursLabel.text = "hours"
        hoursLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        hoursLabel.textColor = UIColor.systemGray
        hoursLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let minutesLabel = UILabel()
        minutesLabel.text = "min"
        minutesLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        minutesLabel.textColor = UIColor.systemGray
        minutesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let secondsLabel = UILabel()
        secondsLabel.text = "sec"
        secondsLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        secondsLabel.textColor = UIColor.systemGray
        secondsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(hoursLabel)
        containerView.addSubview(minutesLabel)
        containerView.addSubview(secondsLabel)
        
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: containerView.topAnchor),
            picker.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Position labels to align with selected numbers (right-aligned in each column)
            hoursLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            hoursLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: containerView.frame.width / 6 + 83),
            
            minutesLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            minutesLabel.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -containerView.frame.width / 6 + 20),
            
            secondsLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            secondsLabel.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -containerView.frame.width / 6 + -44)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let picker = uiView.subviews.first as? UIPickerView {
            picker.reloadAllComponents()
            picker.selectRow(hours, inComponent: 0, animated: false)
            picker.selectRow(minutes, inComponent: 1, animated: false)
            picker.selectRow(seconds, inComponent: 2, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        let parent: CountdownTimerPicker
        
        init(_ parent: CountdownTimerPicker) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 3
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return 24 // Hours
            case 1: return 60 // Minutes
            case 2: return 60 // Seconds
            default: return 0
            }
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            return String(row)
        }
        
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            return 32 // Increase row height from default (around 30) to 40
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case 0:
                parent.hours = row
            case 1:
                parent.minutes = row
            case 2:
                parent.seconds = row
            default:
                break
            }
        }
    }
}

#Preview {
    CountdownTimerPicker(
        hours: .constant(0),
        minutes: .constant(0),
        seconds: .constant(0)
    )
} 
