//
//  MailController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 19.12.18.
//

import Foundation
import PerfectLib
import PerfectMustache
import PerfectThread
import PerfectSMTP
import PerfectCURL

class MailController {

    class MailNotSetupError: Error {}

    enum Templates: String {
        case confirmMail = "confirm_mail.mustache"
        case resetPassword = "reset_password.mustache"
    }

    public private(set) static var global = MailController()

    public static var clientURL: String? {
        didSet {
            setupClient()
        }
    }
    public static var clientUsername: String? {
        didSet {
            setupClient()
        }
    }
    public static var clientPassword: String? {
        didSet {
            setupClient()
        }
    }
    private static var client: SMTPClient?

    public static var fromName: String? {
        didSet {
            setupFrom()
        }
    }
    public static var fromAddress: String? {
        didSet {
            setupFrom()
        }
    }
    private static var from: Recipient? = Recipient(
        name: "0815.Tirol - Map",
        address: "map@0815.tirol"
    )
    public static var baseURI: String = "http://127.0.0.1:9000"
    public static var footerHtml: String = "<h1>HI!</h1>"

    public var isSetup: Bool {
        return MailController.client != nil && MailController.from != nil
    }

    private static func setupClient() {
        if clientURL == nil || clientURL! == "" || clientPassword == nil ||
           clientPassword! == "" || clientUsername == nil || clientUsername! == "" {
            client = nil
        } else {
            client = SMTPClient(url: clientURL!, username: clientUsername!,
                                password: clientPassword!, requiresTLSUpgrade: true)
        }
    }

    private static func setupFrom() {
        if fromName == nil || fromName! == "" || fromAddress == nil || fromAddress! == "" {
            from = nil
        } else {
            from = Recipient(name: fromName!, address: fromAddress!)
        }
    }

    private init() {}

    public func setup() throws {

    }

    public func sendConfirmEmail(recipient: Recipient, key: String, completion: @escaping (Int) -> Void) throws {

        if !isSetup {
            throw MailNotSetupError()
        }

        var values = MustacheEvaluationContext.MapType()

        values["footer_html"] = MailController.footerHtml
        values["email_confirm_title_1"] = Localizer.global.get(value: "email_confirm_title_1",
                                                               replace: ["name": recipient.name])
        values["email_confirm_title_2"] = Localizer.global.get(value: "email_confirm_title_2",
                                                               replace: ["name": WebRequestHandler.title])
        values["email_confirm_subtitle"] = Localizer.global.get(value: "email_confirm_subtitle")
        values["email_confirm_button"] = Localizer.global.get(value: "email_confirm_button")
        values["email_automail_info"] = Localizer.global.get(value: "email_automail_info")
        values["email_confirm_href"] = "\(MailController.baseURI)/confirmemail/\(key.encodeUrl() ?? "")"

        let subject = Localizer.global.get(value: "email_confirm_subject", replace: ["name": WebRequestHandler.title])

        try sendMail(template: .confirmMail, values: values, recipient: recipient,
                     subject: subject, completion: { (code) in
            completion(code)
        })

    }

    public func sendResetEmail(recipient: Recipient, key: String, completion: @escaping (Int) -> Void) throws {

        if !isSetup {
            throw MailNotSetupError()
        }

        var values = MustacheEvaluationContext.MapType()

        values["footer_html"] = MailController.footerHtml
        values["email_reset_title_1"] = Localizer.global.get(value: "email_reset_title_1",
                                                             replace: ["name": recipient.name])
        values["email_reset_title_2"] = Localizer.global.get(value: "email_reset_title_2",
                                                             replace: ["name": WebRequestHandler.title])
        values["email_reset_subtitle"] = Localizer.global.get(value: "email_reset_subtitle")
        values["email_reset_button"] = Localizer.global.get(value: "email_reset_button")
        values["email_automail_info"] = Localizer.global.get(value: "email_automail_info")
        values["email_reset_href"] = "\(MailController.baseURI)/resetpassword/\(key.encodeUrl() ?? "")"

        let subject = Localizer.global.get(value: "email_reset_subject", replace: ["name": WebRequestHandler.title])

        try sendMail(template: .resetPassword, values: values, recipient: recipient,
                     subject: subject, completion: { (code) in
            completion(code)
        })

    }

    private func sendMail(template: Templates, values: MustacheEvaluationContext.MapType,
                          recipient: Recipient, subject: String, completion: @escaping (Int) -> Void) throws {

        if !isSetup {
            throw MailNotSetupError()
        }

        let path = "\(projectroot)/resources/mail/\(template.rawValue)"

        let context = MustacheEvaluationContext(templatePath: path)
        let collector = MustacheEvaluationOutputCollector()
        context.extendValues(with: values)
        let string = try context.formulateResponse(withCollector: collector)

        try sendMail(text: string, isHtml: true, recipient: recipient, subject: subject, completion: { (code) in
            completion(code)
        })

    }

    public func sendMail(text: String, isHtml: Bool, recipient: Recipient,
                         subject: String, completion: @escaping (Int) -> Void) throws {

        if !isSetup {
            throw MailNotSetupError()
        }

        let email = EMail(client: MailController.client!)
        email.subject = subject
        email.from = MailController.from!
        if isHtml {
            email.html = text
        } else {
            email.text = text
        }
        email.to = [recipient]

        do {
            try email.send(completion: { (code, _, _) in
                if code != 250 {
                    Log.error(message: "[MailController] Failed to send Email.")
                }
                completion(code)
            })
        } catch {
            if let error = error as? CURLResponse.Error {
                Log.error(message: "[MailController] Failed to sent email. Got error: \(error.description)")
            } else {
                Log.error(message: "[MailController] Failed to sent email. Got error: \(error.localizedDescription)")
            }
            throw error
        }
    }
}
