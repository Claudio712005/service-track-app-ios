import Foundation

// RN-12: validação no cliente para UX imediata; o backend é a autoridade final.

public enum Validadores {
    /// CPF válido (dígitos verificadores). Aceita com ou sem máscara.
    public static func cpfValido(_ cpf: String) -> Bool {
        let digitos = cpf.filter(\.isNumber).compactMap { $0.wholeNumberValue }
        guard digitos.count == 11, Set(digitos).count > 1 else { return false }

        func dv(_ slice: ArraySlice<Int>, peso inicial: Int) -> Int {
            let soma = zip(slice, stride(from: inicial, through: 2, by: -1)).map(*).reduce(0, +)
            let resto = soma % 11
            return resto < 2 ? 0 : 11 - resto
        }

        return dv(digitos[0..<9], peso: 10) == digitos[9]
            && dv(digitos[0..<10], peso: 11) == digitos[10]
    }

    /// Placa brasileira: formato antigo `ABC1234` ou Mercosul `ABC1D23` (spec §4.2).
    public static func placaValida(_ placa: String) -> Bool {
        let normalizada = placa.uppercased().replacingOccurrences(of: "-", with: "")
        let antigo = "^[A-Z]{3}[0-9]{4}$"
        let mercosul = "^[A-Z]{3}[0-9][A-Z][0-9]{2}$"
        return normalizada.range(of: antigo, options: .regularExpression) != nil
            || normalizada.range(of: mercosul, options: .regularExpression) != nil
    }

    /// Telefone: 10–11 dígitos (spec §4.1).
    public static func telefoneValido(_ telefone: String) -> Bool {
        let digitos = telefone.filter(\.isNumber)
        return (10...11).contains(digitos.count)
    }

    public static func emailValido(_ email: String) -> Bool {
        email.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
    }

    /// Senha mínima do contrato (`minLength 6`).
    public static func senhaValida(_ senha: String) -> Bool {
        senha.count >= 6
    }
}
