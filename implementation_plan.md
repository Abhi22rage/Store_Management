# Settings Page Implementation Plan

Enhance and properly implement all setting modules in the Smart Dukan Flutter application so that every setting option is functional, persistent (via SharedPreferences/DataRepository), clean, and intuitive.

## User Review Required

> [!IMPORTANT]
> The current Settings screen contains several placeholder options (Currency, Security, Backup, Printers, About). We will replace all placeholders with fully functional, persisted settings modules.

## Proposed Changes

### Presentation / Settings Screen & Modules

#### [MODIFY] [settings_screen.dart](file:///d:/PC_Dukan/smart_dukan/app/lib/src/presentation/screens/settings/settings_screen.dart)
- Reorganize settings cards into clear logical categories:
  1. **Business Information**
     - **Store Details**: Manage Store Name, Address, Contact Phone, GSTIN, and Receipt Header Tagline.
     - **Branch Management**: Direct navigation to `/settings/branches`.
     - **Supplier Directory**: Direct navigation to `/suppliers`.
  2. **Tax & Inventory Rules**
     - **Tax Rates Configuration**: SGST %, CGST %, IGST %, and Tax Inclusive/Exclusive billing calculation option.
     - **Stock Alerts**: Low stock threshold (units) and low stock alert toggle.
  3. **Localization & Currency**
     - **Currency & Format**: Currency symbol selection (`₹`, `$`, `€`, `£`), symbol placement (Before/After), and Date Format options (`DD/MM/YYYY`, `MM/DD/YYYY`).
  4. **User & Security**
     - **Staff & Role Management**: Navigation to `/settings/users`.
     - **Security Settings**: Password change, session timeout configuration, and local PIN security lock option.
  5. **Hardware & Printing**
     - **POS Receipt Printer Settings**: Paper size (58mm thermal / 80mm thermal), receipt header & footer text, auto-print receipts upon sale completion.
  6. **Data & System**
     - **Backup & Restore**: Export inventory and sales data cache as JSON file / copyable payload, and restore/clear cache options.
     - **About & Diagnostics**: App version info, Supabase connection status check, and cache purge utility.

### Core Services

#### [MODIFY] [data_repository.dart](file:///d:/PC_Dukan/smart_dukan/app/lib/src/core/services/data_repository.dart)
- Add utility functions for cache clearing (`clearAllCaches()`) and generating a full data export JSON.

## Verification Plan

### Automated Tests
- Run Flutter analysis: `flutter analyze` inside `smart_dukan/app` to confirm build validity and zero lint warnings.

### Manual Verification
- Test saving each configuration dialog and verify persistence across application restarts using `SharedPreferences`.
