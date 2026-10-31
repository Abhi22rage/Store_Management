# Task Plan: Sales Invoice, Dynamic UPI QR Payment & Account Settings

> Feature workflow implementation: Sales billing, dynamic NPCI UPI QR code payment, dual-format invoice receipt (A4 + Thermal POS), PDF download, system & WhatsApp sharing, and Account & Payment Settings.

---

### Task 1: Database Migration for Payment Transactions & Merchant Payment Settings ✅
- **Action**: Add SQL migration for `payment_transactions` table and extend `app_settings` with merchant UPI and bank settlement fields (`merchant_upi_id`, `upi_display_name`, `account_holder_name`, `bank_name`, `account_number`, `ifsc_code`, `account_type`, `gateway_status`).
- **File**: [migration_payments.sql](file:///d:/PC_Dukan/docs/migration_payments.sql)
- **Status**: Completed. Fully verified with foreign keys, indexes, and RLS policies.

### Task 2: Service Layer & UPI QR Specification Generator ✅
- **Action**: 
  - Create [upi_payment_service.dart](file:///d:/PC_Dukan/app/lib/src/core/services/upi_payment_service.dart) to generate standards-compliant NPCI UPI deep-link URIs (`upi://pay?pa=...&pn=...&am=...&tn=...&tr=...&cu=INR`) and handle payment transaction lifecycles (Pending, Processing, Paid, Failed, Cancelled).
  - Update [api_service.dart](file:///d:/PC_Dukan/app/lib/src/core/services/api_service.dart) to save payment transactions, update payment status, and load/persist merchant payment settings.
- **Status**: Completed. NPCI spec URL encoding, unique reference IDs, and transaction lifecycle handling verified.

### Task 3: Account & Payment Settings Module ✅
- **Action**:
  - Enhance [settings_screen.dart](file:///d:/PC_Dukan/app/lib/src/presentation/screens/settings/settings_screen.dart) with a dedicated **Account & Payment Settings** section.
  - Form fields: Store Name, Address, Contact, Email, GSTIN, Merchant UPI ID / VPA, UPI Display Name, Default Payment Method, Gateway Configuration Status, Bank Account Holder, Bank Name, Account Number, IFSC Code, Account Type.
  - Implement UPI ID (`^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$`) and IFSC validation (`^[A-Z]{4}0[A-Z0-9]{6}$`), live dynamic QR code preview, persistence to Supabase and SharedPreferences, and admin role authorization.
- **Status**: Completed. Form validation, live test QR preview, diagnostics dialog, and multi-tier persistence verified.

### Task 4: Dynamic UPI QR Payment Screen / Dialog ✅
- **Action**:
  - Build [upi_payment_dialog.dart](file:///d:/PC_Dukan/app/lib/src/presentation/screens/sales/widgets/upi_payment_dialog.dart) with prominent dynamic QR code (`qr_flutter`), merchant VPA, store name, invoice number, exact payable amount, clear customer instructions, timer/status badges, and Cashier UTR / Reference ID confirmation and Sandbox simulation mode.
  - Protect against duplicate payments, and allow safe cancellation and retry without recording duplicate sales.
- **Status**: Completed. Dynamic QR recalculation, cashier UTR verification, sandbox mode, and safe cancellation verified.

### Task 5: Sales Checkout Integration (Pending -> Paid Workflow) ✅
- **Action**:
  - In [sales_screen.dart](file:///d:/PC_Dukan/app/lib/src/presentation/screens/sales/sales_screen.dart) and [manual_sale_screen.dart](file:///d:/PC_Dukan/app/lib/src/presentation/screens/sales/manual_sale_screen.dart):
  - When UPI is selected or during checkout, open the UPI Payment dialog.
  - Enforce "On Verified Payment Only" rule: commit the sale record to database and decrement stock ONLY after verified payment confirmation.
  - Store payment method as 'UPI', status as 'PAID', and associate gateway transaction reference ID.
- **Status**: Completed. Proceed to Payment button, verified payment commits, zero phantom deductions on cancel.

### Task 6: Final Invoice Screen & Dual-Format Print/Download/Share ✅
- **Action**:
  - Build [invoice_receipt_dialog.dart](file:///d:/PC_Dukan/app/lib/src/presentation/screens/sales/widgets/invoice_receipt_dialog.dart) and [invoice_pdf_helper.dart](file:///d:/PC_Dukan/app/lib/src/core/utils/invoice_pdf_helper.dart) using `pdf` and `printing` packages.
  - Layouts: Dual format — Professional A4 Invoice and 58mm/80mm POS Thermal Receipt.
  - Actions:
    1. **Print Invoice**: Direct printer-friendly dialog via `Printing.layoutPdf()`.
    2. **Download Invoice**: Generates and downloads `Invoice_{invoice_number}.pdf`.
    3. **Share Invoice**: System sharing via `SharePlus` or direct WhatsApp share link (`https://wa.me/?text=...`).
- **Status**: Completed. Automatic pop-up post payment and re-accessible from sales history.

### Task 7: Verification & Code Quality ✅
- **Action**: Run `flutter analyze` to ensure zero compilation or lint errors. Test complete end-to-end POS workflow from cart to payment to invoice printing.
- **Status**: Completed. Full `flutter analyze` exited with code 0 (No issues found!).
