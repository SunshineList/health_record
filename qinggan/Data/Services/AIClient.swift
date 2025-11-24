import Foundation
import UIKit

final class AIClient: AIClientProtocol {
    let host: String
    init(host: String) { self.host = host }
    private func request(path: String, body: Data, apiKey: String) async throws -> Data {
        guard let url = URL(string: host + path), !host.isEmpty else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
    func analyzeImage(data: Data, config: AIConfig) async throws -> AIDishRecognitionResponse {
        let apiKey = KeychainService.shared.getAPIKey()
        let base64 = (UIImage(data: data)?.jpegData(compressionQuality: 0.9) ?? data).base64EncodedString()
        let systemMsg: [String: Any] = ["role": "system", "content": "你是一个饮食识别助手。请识别图片中的食物并估算重量、总热量与宏量营养（蛋白/脂肪/碳水，单位克）。输出严格的 JSON 对象，不附加任何文本：{\"items\":[{\"name\":中文名,\"weight\":克,\"kcal\":千卡,\"protein\":克,\"fat\":克,\"carb\":克}...]}。宏量比例需贴近食物类别：主食/谷物以碳水为主，肉类以蛋白为主，油脂以脂肪为主，坚果高脂肪，水果高碳水，蔬菜碳水为主且少量蛋白，乳制品较均衡。确保能量守恒：kcal ≈ protein*4 + carb*4 + fat*9（允许±10%）。所有数值为正数；无法精确时给出合理估算且不留空值。"]
        let userMsg: [String: Any] = [
            "role": "user",
            "content": [
                [
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                ],
                ["type": "text", "text": "识别图片中的食物并估算重量、总热量与蛋白/脂肪/碳水（单位克）；请直接给出严格 JSON，数值满足能量守恒。"]
            ]
        ]
        let payload: [String: Any] = [
            "model": config.visionModel,
            "messages": [systemMsg, userMsg],
            "response_format": ["type": "json_object"]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let resp = try await request(path: "/v1/chat/completions", body: body, apiKey: apiKey)
        var items: [FoodItemModel] = []
        if let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String,
            let contentData = content.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
            let arr = obj["items"] as? [[String: Any]] {
            for e in arr {
                let name = e["name"] as? String ?? ""
                let weight = e["weight"] as? Double ?? 0
                let kcal = e["kcal"] as? Double ?? 0
                let protein = e["protein"] as? Double ?? 0
                let fat = e["fat"] as? Double ?? 0
                let carb = e["carb"] as? Double ?? 0
                items.append(FoodItemModel(name: name, weight: weight, kcal: kcal, protein: protein, fat: fat, carb: carb))
            }
        }
        else if let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
                let content = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String {
            if let range = content.range(of: "\\{[\\s\\S]*\\}", options: .regularExpression) {
                let sub = String(content[range])
                if let data = sub.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arr = obj["items"] as? [[String: Any]] {
                    for e in arr {
                        let name = e["name"] as? String ?? ""
                        let weight = e["weight"] as? Double ?? 0
                        let kcal = e["kcal"] as? Double ?? 0
                        let protein = e["protein"] as? Double ?? 0
                        let fat = e["fat"] as? Double ?? 0
                        let carb = e["carb"] as? Double ?? 0
                        items.append(FoodItemModel(name: name, weight: weight, kcal: kcal, protein: protein, fat: fat, carb: carb))
                    }
                }
            }
        }
        return AIDishRecognitionResponse(items: items, rawJSON: resp)
    }
    func estimateNutritionByText(name: String, grams: Double, config: AIConfig) async throws -> FoodItemModel {
        let apiKey = KeychainService.shared.getAPIKey()
        let systemMsg: [String: Any] = [
            "role": "system",
            "content": "你是一个营养估算助手。根据食物中文名称与克重，估算总热量与宏量营养（蛋白/脂肪/碳水，单位克）。输出严格 JSON 对象，不附加任何文本：{\"name\":中文名,\"weight\":克,\"kcal\":千卡,\"protein\":克,\"fat\":克,\"carb\":克}。宏量比例贴合食物类别；确保能量守恒：kcal ≈ protein*4 + carb*4 + fat*9（允许±10%）。所有数值为正；无法精确时给出合理估算且不留空值。"
        ]
        let userMsg: [String: Any] = [
            "role": "user",
            "content": "食物：\(name)；重量：\(Int(grams)) 克。请直接给出严格 JSON。"
        ]
        let payload: [String: Any] = [
            "model": config.textModel,
            "messages": [systemMsg, userMsg],
            "response_format": ["type": "json_object"]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let resp = try await request(path: "/v1/chat/completions", body: body, apiKey: apiKey)
        if let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String,
           let data = content.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let n = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
            let w = obj["weight"] as? Double ?? grams
            let kcal = obj["kcal"] as? Double ?? 0
            let p = obj["protein"] as? Double ?? 0
            let f = obj["fat"] as? Double ?? 0
            let c = obj["carb"] as? Double ?? 0
            return FoodItemModel(name: n, weight: w, kcal: kcal, protein: p, fat: f, carb: c)
        }
        if let content = ((try? JSONSerialization.jsonObject(with: resp) as? [String: Any])?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any],
           let text = content["content"] as? String,
           let range = text.range(of: "\\{[\\s\\S]*\\}", options: .regularExpression),
           let data = String(text[range]).data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let n = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
            let w = obj["weight"] as? Double ?? grams
            let kcal = obj["kcal"] as? Double ?? 0
            let p = obj["protein"] as? Double ?? 0
            let f = obj["fat"] as? Double ?? 0
            let c = obj["carb"] as? Double ?? 0
            return FoodItemModel(name: n, weight: w, kcal: kcal, protein: p, fat: f, carb: c)
        }
        return FoodItemModel(name: name, weight: grams, kcal: 0, protein: 0, fat: 0, carb: 0)
    }
    func sendChat(messages: [AIMessage], summary: HealthSummary?, config: AIConfig) async throws -> AIChatResponse {
        let apiKey = KeychainService.shared.getAPIKey()
        var arr: [[String: Any]] = []
        var content = "你是一位资深健康生活方式专家（营养🥗、运动🏃‍♂️、睡眠🛌、压力管理🧘、行为改变🔁）。请基于用户最近数据与提问，给出具体、可执行、温和的中文建议：\n1）不做医疗诊断与药物建议❌；\n2）建议包含量化目标（数值/时间窗口/频次），示例：‘晚间散步20分钟，每周5次’📅；\n3）结构清晰，最多3条要点（每条前置表情符号以增强可读性）✨；\n4）如信息不足，先简短澄清再给出可行默认方案🤝；\n5）避免夸大承诺与绝对化措辞⚖️。"
        if let s = summary {
            let wAvg = s.avgWeight.map { String(format: "%.1f", $0) } ?? "—"
            let wMin = s.minWeight.map { String(format: "%.1f", $0) } ?? "—"
            let wMax = s.maxWeight.map { String(format: "%.1f", $0) } ?? "—"
            let kAvg = s.avgKcalPerDay.map { String(format: "%.0f", $0) } ?? "—"
            let kMin = s.minKcalPerDay.map { String(format: "%.0f", $0) } ?? "—"
            let kMax = s.maxKcalPerDay.map { String(format: "%.0f", $0) } ?? "—"
            let sMin = s.minSteps.map { String($0) } ?? "—"
            let sMax = s.maxSteps.map { String($0) } ?? "—"
            let kTrend = s.kcalTrend ?? "—"
            let stepTrend = s.stepsTrend ?? "—"
            let weightTrend = s.weightTrend ?? "—"
            content += "\n最近7天统计：\n- 热量（每日）：均值 \(kAvg) kcal，最高 \(kMax)，最低 \(kMin)\n- 步数：均值 \(s.avgSteps) 步，最高 \(sMax)，最低 \(sMin)\n- 体重：均值 \(wAvg) kg，最高 \(wMax)，最低 \(wMin)\n- 趋势：热量 \(kTrend)，步数 \(stepTrend)，体重 \(weightTrend)\n\n请输出中文 2–4 句：先简要总结上述统计与趋势，再给出两条建议（饮食+运动），建议需可执行（含具体量化与频次）。"
        }
        let systemMsg = ["role": "system", "content": content]
        arr.append(systemMsg)
        for m in messages { arr.append(["role": m.role.rawValue, "content": m.content]) }
        let payload: [String: Any] = [
            "model": config.textModel,
            "messages": arr
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let resp = try await request(path: "/v1/chat/completions", body: body, apiKey: apiKey)
        if let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any] {
            if let choices = json["choices"] as? [[String: Any]], let first = choices.first, let message = first["message"] as? [String: Any], let content = message["content"] as? String {
                return AIChatResponse(text: content)
            }
            if let msg = json["message"] as? String { return AIChatResponse(text: msg) }
        }
        return AIChatResponse(text: String(data: resp, encoding: .utf8) ?? "")
    }
}
