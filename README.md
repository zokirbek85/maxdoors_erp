# MaxDoors ERP

B2B eshiklar va aksessuarlar savdosi uchun yaratilayotgan **ERP/CRM tizimi**.  
Frontend — Flutter, Backend — PocketBase asosida.  

---

## 🚀 Texnologiyalar

- **Backend:** [PocketBase](https://pocketbase.io/) (Go + SQLite)
  - REST API
  - Realtime
  - Migratsiyalar
- **Frontend:** [Flutter](https://flutter.dev/) (Dart)
  - Multi-platform (Windows, Android, iOS, Web)
  - Provider (state management)
  - Printing & PDF (hisobot va hujjatlar uchun)

---

## 📂 Papka struktura

```
maxdoors_erp/
│
├── maxdoors_backend/        # PocketBase server
│   ├── pb_data/             # Ma'lumotlar bazasi (test uchun commit qilingan)
│   ├── pb_migrations/       # Migratsiyalar
│   └── pocketbase.exe       # (lokalda ishlatish uchun qo‘shiladi)
│
├── maxdoors_frontend/       # Flutter frontend
│   ├── lib/                 # Asosiy kodlar
│   ├── assets/              # Fontlar, rasmlar
│   ├── pubspec.yaml         # Flutter dependency'lar
│   └── build/               # (ignore qilingan)
│
├── .gitignore
└── README.md
```

---

## ⚡️ Ishga tushirish

### Backend (PocketBase)
1. [PocketBase release](https://github.com/pocketbase/pocketbase/releases) dan `pocketbase.exe` yuklab oling.
2. `maxdoors_backend/` papkasiga qo‘ying.
3. Serverni ishga tushiring:
   ```powershell
   cd maxdoors_backend
   .\pocketbase.exe serve
   ```
4. Dashboard: [http://127.0.0.1:8090/_/](http://127.0.0.1:8090/_/)

> **Eslatma:** Hozircha `pb_data/` repo ichida test ma’lumotlar bilan commit qilingan. Keyinchalik production uchun `.gitignore` ga qo‘shish tavsiya etiladi.

---

### Frontend (Flutter)
1. Flutter SDK o‘rnatilgan bo‘lishi kerak (`flutter doctor` bilan tekshiring).
2. Paketlarni o‘rnating:
   ```powershell
   cd maxdoors_frontend
   flutter pub get
   ```
3. Windows’da ishga tushirish:
   ```powershell
   flutter run -d windows
   ```
   Android uchun:
   ```powershell
   flutter run -d android
   ```

---

## 👥 Rollar va imkoniyatlar

- **Admin:** Foydalanuvchilarni boshqarish, import/eksport, barcha modullar
- **Accountant:** To‘lovlar, statistikalar, buyurtmalarni tasdiqlash
- **Manager:** Buyurtma yaratish, dillerlar bilan ishlash
- **Warehouseman:** Ombor, qoldiq, buyurtmani yig‘ish va jo‘natish
- **Owner:** Faqat analitika va hisobotlar

---

## ✅ Statuslar

Buyurtma quyidagi statuslarga ega bo‘lishi mumkin:
- `created` — yangi yaratilgan
- `edit_requested` — tahrir so‘ralgan
- `editable` — tahrirga ochilgan
- `packed` — yig‘ilgan
- `shipped` — jo‘natilgan

---

## 📦 Import imkoniyatlari

- Mahsulotlar ro‘yxati importi
- Ombor qoldiqlari va narxlarini import qilish
- Foydalanuvchilarni CRUD

---

## 📝 Rejalashtirilgan funksiyalar

- Order template’lari
- Offline rejim (mobil manager uchun)
- Ikkinchi til (RU/EN)
- KPI va analitika modullari
- Backup va roll-back siyosati

---

## 🔒 Eslatma

Bu loyiha hozircha **test ma’lumotlar** bilan ishlamoqda.  
Production ma’lumotlar uchun `pb_data/` ni **repository’da saqlamang** — maxfiy joyda saqlash yoki Git LFS’dan foydalanish kerak bo‘ladi.

---

## 📌 GitHub repo

[github.com/zokirbek85/maxdoors_erp](https://github.com/zokirbek85/maxdoors_erp)

---
