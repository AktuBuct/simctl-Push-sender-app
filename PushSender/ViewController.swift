//
//  ViewController.swift
//  PushSender
//
//  Created by Станислав В. Зеликсон on 13.10.2020.
//  Copyright © 2020 AktuBuct. All rights reserved.
//

import Cocoa
import ShellOut

class ViewController: NSViewController {

    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var textField: NSTextField!

    @IBOutlet weak var deviceIdTextField: NSTextField!
    @IBOutlet weak var bundleIdTextField: NSTextField!

    private var originalNotifications: [[String: Any]] = []
    private var cachedNotifications: [Int: [String: Any]] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        loadIds()
        textField.delegate = self
        guard let path = Bundle.main.path(forResource: "notifications", ofType: "json") else {
            return
        }
        
        let url = URL(fileURLWithPath: path) as URL
        guard let data = try? Data(contentsOf: url) else { return }
        originalNotifications = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
}

//MARK: - Actions
extension ViewController {
    @IBAction func resetButtonPress(_ sender: Any) {
        guard tableView.selectedRow != -1 else { return }
        cachedNotifications[tableView.selectedRow] = nil
        showNotificationJsonText()
    }

    @IBAction func sendButtonDidPress(_ sender: Any) {
        saveIds()
        guard let data = textField.stringValue.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: FileManager.default.currentDirectoryPath.appending("/push.apns")) {
            try? FileManager.default.removeItem(atPath: FileManager.default.currentDirectoryPath.appending("/push.apns"))
        }
        if FileManager.default.createFile(atPath: FileManager.default.currentDirectoryPath.appending("/push.apns"), contents: data) {
            let deviceId = deviceIdTextField.stringValue.isEmpty ? "booted" : deviceIdTextField.stringValue
            let command = "xcrun simctl push \(deviceId) \(bundleIdTextField.stringValue) push.apns"
            _ = try? shellOut(to: command)
        }
    }
}

extension ViewController: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        originalNotifications.count
    }
}

extension ViewController: NSTableViewDelegate {
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "pushFileCell"),
            owner: nil
        ) as? NSTableCellView

        let notification = originalNotifications[row]
        let text = [
            (notification["type"] as? String) ?? "Unknown",
            "-",
            (((notification["aps"] as? [String: Any])?["alert"] as? [String: Any])?["loc-key"] as? String) ?? ""
        ].joined(separator: " ")
        cell?.textField?.stringValue = text
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        showNotificationJsonText()
    }
}

extension ViewController: NSTextFieldDelegate {
    public func controlTextDidChange(_ obj: Notification) {
        guard
            let data = textField.stringValue.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            tableView.selectedRow != -1
        else { return }
        cachedNotifications[tableView.selectedRow] = json
    }
}

private extension ViewController {

    private func showNotificationJsonText() {
        let element = cachedNotifications[tableView.selectedRow] ?? originalNotifications[tableView.selectedRow]
        guard let data = try? JSONSerialization.data(withJSONObject: element, options: .prettyPrinted) else { return }
        let str = String(data: data, encoding: .utf8)
        textField.stringValue = str ?? "Error"
    }

    func saveIds() {
        UserDefaults.standard.set(bundleIdTextField.stringValue, forKey: "bundleId")
        UserDefaults.standard.set(deviceIdTextField.stringValue, forKey: "deviceId")
    }

    func loadIds() {
        bundleIdTextField.stringValue = UserDefaults.standard.string(forKey: "bundleId") ?? ""
        deviceIdTextField.stringValue = UserDefaults.standard.string(forKey: "deviceId") ?? ""
    }
}
