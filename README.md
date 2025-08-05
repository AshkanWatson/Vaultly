# Vaultly 🔐  

*A 100% offline, encrypted password manager built with Flutter.*

Vaultly is an open-source, cross-platform password manager that stores your credentials **only on your device**.  
No cloud. No trackers. Just strong encryption and full offline control.  

---

## ✨ Features

- **Fully Offline** – Your data never leaves your device.  
- **Local Encrypted Database** – Credentials stored using **AES-256 encryption**.  
- **Cross-Platform** – Built with Flutter for Android, iOS, Windows, macOS, and Linux.  
- **Secure Export & Import** – Back up your vault with encryption; restore it easily.  
- **Biometric Lock** – Optional Face ID / Fingerprint for faster access.  
- **Open Source** – Transparent and auditable security.

---

## 🔐 How It Works

1. User creates a **master password** (never stored anywhere).  
2. Vaultly derives an **encryption key** (Argon2 / PBKDF2) from the master password.  
3. All credentials are stored in an **encrypted local database (SQLCipher)**.  
4. When you unlock the app, data is **decrypted in memory only**.  

[ Master Password ] -> [ Key Derivation ] -> [ AES-256 Encrypted Local DB ]

---

## 📦 Tech Stack

- **Flutter** – Cross-platform UI  
- **Dart** – App logic  
- **SQLCipher / sqflite** – Encrypted local storage  
- **crypto** package – Encryption and key derivation  

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK installed  
- Android Studio / Xcode for mobile builds

### Run the app

```bash
flutter pub get
flutter run
```

---

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License – see the [LICENSE](https://github.com/AshkanWatson/Vaultly) file for details.

---

## 💡 Security Tip

Your master password cannot be recovered. Keep it safe!
