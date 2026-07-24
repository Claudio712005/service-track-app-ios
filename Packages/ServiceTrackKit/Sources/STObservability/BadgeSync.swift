import Foundation

public enum BadgeSync {
  public static func deveAvisar(anterior: Int, atual: Int) -> Bool {
        atual > anterior && atual > 0
    }

    public static func corpoDoAviso(quantidade: Int) -> String {
        quantidade == 1
            ? "Você tem 1 novo aviso da oficina."
            : "Você tem \(quantidade) novos avisos da oficina."
    }
}
