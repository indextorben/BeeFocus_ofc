import Foundation
import SwiftUI
import UIKit
import MessageUI

final class MailShareService: ObservableObject {
    struct MailComposerData: Identifiable {
        let id = UUID()
        let subject: String
        let body: String
        let recipients: [String]?
    }

    @Published var exportData: ShareData?
    @Published var mailComposerData: MailComposerData?

    func shareTodosByMail(_ todos: [TodoItem], languageCode: String, recipients: [String]? = nil) {
        let subject = LocalizationManager.shared.localizedString(forKey: "Todos Export")
        let body = formattedTodoList(todos, languageCode: languageCode)
        if MFMailComposeViewController.canSendMail() {
            mailComposerData = MailComposerData(subject: subject, body: body, recipients: recipients)
        } else {
            exportData = ShareData(image: textAsImage(body))
        }
    }

    private func formattedTodoList(_ todos: [TodoItem], languageCode: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: languageCode)
        return todos.map { todo in
            let title = todo.title
            let category = todo.category?.name ?? "-"
            let due: String
            if let d = todo.dueDate { due = formatter.string(from: d) } else { due = "—" }
            let status = todo.isCompleted ? "✅" : "⬜️"
            return "\(status) \(title)\n  Kategorie: \(category)\n  Fällig bis: \(due)\n"
        }.joined(separator: "\n")
    }

    private func textAsImage(_ text: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let maxSize = CGSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        let bounds = (text as NSString).boundingRect(with: maxSize, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        let size = CGSize(width: ceil(bounds.width) + 40, height: ceil(bounds.height) + 40)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        (text as NSString).draw(in: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40), withAttributes: attributes)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

#if canImport(MessageUI)
struct MailComposerWrapperView: UIViewControllerRepresentable {
    var subject: String
    var body: String
    var recipients: [String]?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let recipients = recipients {
            vc.setToRecipients(recipients)
        }
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
#endif
