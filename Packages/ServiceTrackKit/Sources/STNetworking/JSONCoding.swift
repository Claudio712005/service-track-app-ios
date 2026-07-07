import Foundation

/// Parsing tolerante de datas (spec §11.4, resolve C5): a API mistura
/// `date-time` sem offset (camelCase), sufixo `Z` (dashboard) e `yyyy-MM-dd`.
public enum STJSON {
    private static let isoComFracao: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func formatter(_ formato: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        // Sem offset na string: assume horário do servidor (spec §7.2).
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        f.dateFormat = formato
        return f
    }

    private static let dataHoraSemOffset = formatter("yyyy-MM-dd'T'HH:mm:ss")
    private static let dataHoraSemOffsetFracao = formatter("yyyy-MM-dd'T'HH:mm:ss.SSS")
    private static let somenteData = formatter("yyyy-MM-dd")

    public static func parseDate(_ valor: String) -> Date? {
        isoComFracao.date(from: valor)
            ?? iso.date(from: valor)
            ?? dataHoraSemOffsetFracao.date(from: valor)
            ?? dataHoraSemOffset.date(from: valor)
            ?? somenteData.date(from: valor)
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let valor = try container.decode(String.self)
            guard let date = parseDate(valor) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Data em formato não reconhecido: \(valor)"
                )
            }
            return date
        }
        return decoder
    }

    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dataHoraSemOffset.string(from: date))
        }
        return encoder
    }

    /// Encoder para campos `format: date` (ex.: `dataNascimento`).
    public static func stringData(_ date: Date) -> String {
        somenteData.string(from: date)
    }
}
