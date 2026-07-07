import SwiftUI

/// Máscaras de entrada (spec §14 STTextField). Aplicadas sobre os dígitos.
public enum STMascara: Sendable {
    case cpf
    case telefone
    case placa
    case nenhuma

    public func aplicar(_ texto: String) -> String {
        switch self {
        case .nenhuma:
            return texto
        case .cpf:
            let d = String(texto.filter(\.isNumber).prefix(11))
            var resultado = ""
            for (i, c) in d.enumerated() {
                if i == 3 || i == 6 { resultado.append(".") }
                if i == 9 { resultado.append("-") }
                resultado.append(c)
            }
            return resultado
        case .telefone:
            let d = String(texto.filter(\.isNumber).prefix(11))
            guard d.count > 2 else { return d.isEmpty ? "" : "(\(d)" }
            let ddd = d.prefix(2)
            let resto = String(d.dropFirst(2))
            let corte = resto.count > 8 ? 5 : 4
            if resto.count <= corte { return "(\(ddd)) \(resto)" }
            return "(\(ddd)) \(resto.prefix(corte))-\(resto.dropFirst(corte))"
        case .placa:
            return String(texto.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(7))
        }
    }

    /// Valor limpo enviado à API (RN-12: backend valida o formato final).
    public func desmascarar(_ texto: String) -> String {
        switch self {
        case .cpf, .telefone: texto.filter(\.isNumber)
        case .placa, .nenhuma: texto
        }
    }
}

/// Campo do Design System: label flutuante, validação inline, máscara,
/// segredo com olho, estados §13.8, erro associado ao campo (§16).
public struct STTextField: View {
    let label: String
    @Binding var texto: String
    let mascara: STMascara
    let seguro: Bool
    let erro: String?
    #if os(iOS)
    let teclado: UIKeyboardType
    #endif

    @State private var revelado = false
    @FocusState private var focado: Bool

    #if os(iOS)
    public init(_ label: String, texto: Binding<String>, mascara: STMascara = .nenhuma,
                seguro: Bool = false, erro: String? = nil, teclado: UIKeyboardType = .default) {
        self.label = label
        self._texto = texto
        self.mascara = mascara
        self.seguro = seguro
        self.erro = erro
        self.teclado = teclado
    }
    #else
    public init(_ label: String, texto: Binding<String>, mascara: STMascara = .nenhuma,
                seguro: Bool = false, erro: String? = nil) {
        self.label = label
        self._texto = texto
        self.mascara = mascara
        self.seguro = seguro
        self.erro = erro
    }
    #endif

    private var labelFlutuando: Bool { focado || !texto.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            ZStack(alignment: .leading) {
                Text(label)
                    .font(labelFlutuando ? DSFont.caption : DSFont.body)
                    .foregroundStyle(erro == nil ? DSColor.textTertiary : DSColor.danger)
                    .offset(y: labelFlutuando ? -16 : 0)
                    .animation(DSMotion.toque, value: labelFlutuando)
                    .accessibilityHidden(true)

                HStack {
                    campo
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                        .focused($focado)
                        .offset(y: labelFlutuando ? 6 : 0)
                        .onChange(of: texto) { _, novo in
                            let mascarado = mascara.aplicar(novo)
                            if mascarado != novo { texto = mascarado }
                        }

                    if seguro {
                        Button {
                            revelado.toggle()
                        } label: {
                            Image(systemName: revelado ? "eye.slash" : "eye")
                                .foregroundStyle(DSColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(revelado ? "Ocultar senha" : "Mostrar senha")
                    }
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .frame(minHeight: 58)
            .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(corBorda, lineWidth: focado || erro != nil ? 1.5 : 1)
            )
            .contentShape(.rect)
            .onTapGesture { focado = true }

            if let erro {
                Text(erro)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.danger)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(erro.map { "\(label). Erro: \($0)" } ?? label)
    }

    @ViewBuilder
    private var campo: some View {
        Group {
            if seguro && !revelado {
                SecureField("", text: $texto)
            } else {
                TextField("", text: $texto)
            }
        }
        #if os(iOS)
        .keyboardType(teclado)
        .textInputAutocapitalization(mascara == .placa ? .characters : .never)
        .autocorrectionDisabled()
        #endif
    }

    private var corBorda: Color {
        if erro != nil { return DSColor.danger }
        return focado ? DSColor.brandPrimary : DSColor.borderSubtle
    }
}

/// Medidor de força de senha (cadastro/alterar senha — spec §15.1/§15.12).
public struct STMedidorForcaSenha: View {
    public enum Forca: Int, CaseIterable {
        case fraca = 1, media = 2, forte = 3

        public var rotulo: String {
            switch self {
            case .fraca: "Fraca"
            case .media: "Média"
            case .forte: "Forte"
            }
        }

        var cor: Color {
            switch self {
            case .fraca: DSColor.danger
            case .media: DSColor.warning
            case .forte: DSColor.success
            }
        }
    }

    let senha: String

    public init(senha: String) {
        self.senha = senha
    }

    /// Contrato exige min 6; maiúscula/número/símbolo recomendados (spec §4.1).
    public static func avaliar(_ senha: String) -> Forca? {
        guard senha.count >= 6 else { return senha.isEmpty ? nil : .fraca }
        var pontos = 0
        if senha.count >= 8 { pontos += 1 }
        if senha.contains(where: \.isUppercase) { pontos += 1 }
        if senha.contains(where: \.isNumber) { pontos += 1 }
        if senha.contains(where: { !$0.isLetter && !$0.isNumber }) { pontos += 1 }
        switch pontos {
        case 0...1: return .fraca
        case 2...3: return .media
        default: return .forte
        }
    }

    public var body: some View {
        let forca = Self.avaliar(senha)
        HStack(spacing: DSSpacing.sm) {
            ForEach(Forca.allCases, id: \.rawValue) { nivel in
                Capsule()
                    .fill(forca != nil && nivel.rawValue <= forca!.rawValue
                          ? forca!.cor : DSColor.borderSubtle)
                    .frame(height: 4)
            }
            Text(forca?.rotulo ?? " ")
                .font(DSFont.caption)
                .foregroundStyle(forca?.cor ?? DSColor.textTertiary)
                .frame(width: 48, alignment: .trailing)
        }
        .animation(DSMotion.toque, value: senha)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(forca.map { "Força da senha: \($0.rotulo)" } ?? "Força da senha")
    }
}
