//
//  TransactionFormView.swift
//  SwiftExpenseTrackerApp
//
//  Created by Claudio da Silva Arauo Filho on 14/06/26.
//

import SwiftUI

struct TransactionFormView: View {
    var id: UUID?

    @State private var selection = CategoryType.income
    @State private var description = ""
    @State private var amount = "0,00"

    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color {
        selection == .income ? .green : .red
    }
    
    private var backgroundColor: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 28) {
                header

                amountSection

                TypeTransactionSelector(selection: $selection)
                    .padding(.horizontal, 24)

                formCard

                Spacer()

                saveButton
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Cancelar")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundColor(.blue)
            }

            Spacer()

            Text(id == nil ? "Nova transação" : "Transação")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Cancelar")
            }
            .font(.system(size: 17))
            .opacity(0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private var amountSection: some View {
        VStack(spacing: 12) {
            Text("VALOR")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .tracking(1.2)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("R$")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(accentColor)

                Text(amount)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.45))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .padding(.top, 26)
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            formTextFieldRow(
                title: "Descrição",
                placeholder: "Ex: Mercado, Salário...",
                text: $description
            )

            Divider()
                .padding(.leading, 24)

            selectableRow(
                title: "Categoria",
                value: "Selecionar",
                icon: "chevron.right"
            )

            Divider()
                .padding(.leading, 24)

            selectableRow(
                title: "Data",
                value: "11/06/2026",
                icon: "calendar"
            )
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 24)
    }

    private func formTextFieldRow(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(.primary)

            Spacer()

            TextField(placeholder, text: text)
                .font(.system(size: 18))
                .multilineTextAlignment(.trailing)
                .foregroundColor(.primary)
                .tint(accentColor)
        }
        .frame(height: 64)
        .padding(.horizontal, 24)
    }

    private func selectableRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        Button {

        } label: {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(.primary)

                Spacer()

                Text(value)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(value == "Selecionar" ? .secondary.opacity(0.55) : .primary)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.65))
            }
            .frame(height: 64)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        Button {

        } label: {
            Text("Salvar transação")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(accentColor.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.horizontal, 24)
        .shadow(color: accentColor.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    TransactionFormView()
}
