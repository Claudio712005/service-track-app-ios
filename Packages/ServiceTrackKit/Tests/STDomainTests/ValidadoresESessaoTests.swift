import XCTest
@testable import STDomain

final class ValidadoresTests: XCTestCase {
    func testCPF() {
        XCTAssertTrue(Validadores.cpfValido("54927170063"))
        XCTAssertTrue(Validadores.cpfValido("549.271.700-63"))
        XCTAssertFalse(Validadores.cpfValido("54927170064"))
        XCTAssertFalse(Validadores.cpfValido("11111111111"))
        XCTAssertFalse(Validadores.cpfValido("123"))
    }

    func testPlaca() {
        XCTAssertTrue(Validadores.placaValida("ABC1D23"))
        XCTAssertTrue(Validadores.placaValida("ABC1234"))
        XCTAssertTrue(Validadores.placaValida("abc-1234"))
        XCTAssertFalse(Validadores.placaValida("AB12345"))
        XCTAssertFalse(Validadores.placaValida("ABCD123"))
    }

    func testTelefone() {
        XCTAssertTrue(Validadores.telefoneValido("11987654321"))
        XCTAssertTrue(Validadores.telefoneValido("(11) 3456-7890"))
        XCTAssertFalse(Validadores.telefoneValido("123456"))
    }
}

final class SessaoTests: XCTestCase {
    private func jwt(payload: String) -> String {
        let base64 = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(base64).assinatura"
    }

    func testDecodeClaims() {
        let exp = Int(Date.now.timeIntervalSince1970) + 3600
        let token = jwt(payload: #"{"sub":"abc","upn":"a@b.c","groups":["CLIENTE"],"exp":\#(exp)}"#)
        let claims = JWTClaims(token: token)
        XCTAssertEqual(claims?.sub, "abc")
        XCTAssertEqual(claims?.groups, ["CLIENTE"])
        XCTAssertEqual(claims?.exp?.timeIntervalSince1970 ?? 0, TimeInterval(exp), accuracy: 1)
    }

    func testSessaoExpirada() {
        let expirado = jwt(payload: #"{"exp": 1000}"#)
        let sessao = Sessao(token: expirado, usuarioId: UUID(), cpf: "52998224725", email: "e", roles: ["CLIENTE"])
        XCTAssertTrue(sessao.expirada())
        XCTAssertTrue(sessao.isCliente)
    }

    func testRoleGate() {
        let sessao = Sessao(token: "t", usuarioId: UUID(), cpf: "52998224725", email: "e", roles: ["MECANICO"])
        XCTAssertFalse(sessao.isCliente)
    }

    func testTokenOpacoSemCrash() {
        XCTAssertNil(JWTClaims(token: "mock-jwt-token-"))
    }
}
