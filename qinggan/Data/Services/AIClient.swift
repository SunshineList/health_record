import Foundation

final class AIClient: AIClientProtocol {
    let host: String
    init(host: String) { self.host = host }
    private func request(path: String, body: Data, apiKey: String) async throws -> Data {
        guard let url = URL(string: host + path) else { return Data() }
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
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "weight": ["type": "number"],
                            "kcal": ["type": "number"],
                            "protein": ["type": "number"],
                            "fat": ["type": "number"],
                            "carb": ["type": "number"]
                        ],
                        "required": ["name", "weight", "kcal", "protein", "fat", "carb"]
                    ]
                ]
            ],
            "required": ["items"]
        ]
        let systemMsg: [String: Any] = ["role": "system", "content": "你是一个饮食识别助手，只返回符合 JSON Schema 的 JSON。"]
        let userMsg: [String: Any] = [
            "role": "user",
            "content": [
                ["type": "input_text", "text": "识别图片中的食物，输出 items 列表（中文名称），重量单位克，宏量营养单位克，热量单位kcal。"],
                ["type": "input_image", "image_base64": data.base64EncodedString()]
            ]
        ]
        let payload: [String: Any] = [
            "model": config.visionModel,
            "messages": [systemMsg, userMsg],
            "response_format": "json",
            "json_schema": schema
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let resp = try await request(path: "/v1/chat/completions", body: body, apiKey: apiKey)
        var items: [FoodItemModel] = []
        if let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any], let arr = json["items"] as? [[String: Any]] {
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
        return AIDishRecognitionResponse(items: items, rawJSON: resp)
    }
    func sendChat(messages: [AIMessage], summary: HealthSummary?, config: AIConfig) async throws -> AIChatResponse {
        let apiKey = KeychainService.shared.getAPIKey()
        var arr: [[String: Any]] = []
        for m in messages { arr.append(["role": m.role.rawValue, "content": m.content]) }
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "message": ["type": "string"],
                "tips": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["message"]
        ]
        var payload: [String: Any] = [
            "model": config.textModel,
            "messages": arr,
            "system": "你是一位资深健康生活方式专家（营养、运动、睡眠、压力管理、行为改变）。请基于用户最近数据与提问，给出具体、可执行、温和的中文建议：\n1）不做医疗诊断与药物建议；\n2）建议包含量化目标（数值/时间窗口/频次），示例如‘晚间散步20分钟，每周5次’；\n3）结构清晰，最多3条要点；\n4）如信息不足，先简短澄清再给出可行默认方案；\n5）避免夸大承诺与绝对化措辞。 尽量多的使用一些emoji"
        ]
        if let summary, config.allowSummary { payload["summary"] = ["totalKcal": summary.totalKcal, "avgSteps": summary.avgSteps, "avgWeight": summary.avgWeight as Any, "avgWaist": summary.avgWaist as Any] }
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