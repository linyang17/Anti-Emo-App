import SwiftUI
import MessageUI

struct FeedbackView: View {
    enum Category: String, CaseIterable, Identifiable {
        case bug
        case suggestion
        case others
        
        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }
    
    @State private var title: String = ""
    @State private var category: Category = .bug
    @State private var content: String = ""
    
    @State private var showMailCompose = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    
    var body: some View {
        Form {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Title")) {
                TextField("Enter title", text: $title)
            }
            
            Section(header: Text("Content")) {
                TextEditor(text: $content)
                    .frame(minHeight: 150, maxHeight: 200)
            }
            
            Section {
                Button("Send") {
                    sendEmail()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Feedback")
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipients: ["lumio1mio@gmail.com"],
                subject: "\(category.displayName): \(title)",
                body: content,
                isPresented: $showMailCompose,
                result: $mailResult
            )
        }
        .alert("Cannot Send Email", isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
    }
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            showMailCompose = true
        } else {
            let subject = "\(category.displayName): \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let mailtoString = "mailto:lumio1mio@gmail.com?subject=\(subject)&body=\(body)"
            if let mailtoURL = URL(string: mailtoString), UIApplication.shared.canOpenURL(mailtoURL) {
                UIApplication.shared.open(mailtoURL)
            } else {
                alertMessage = "Your device is not configured to send mail."
                showAlert = true
            }
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var subject: String
    var body: String
    
    @Binding var isPresented: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(isPresented: Binding<Bool>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _isPresented = isPresented
            _result = result
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                isPresented = false
            }
            if let error = error {
                self.result = .failure(error)
            } else {
                self.result = .success(result)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, result: $result)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }
}
