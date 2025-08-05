# Contributing to Vaultly 🔐

First off, thank you for taking the time to contribute to **Vaultly**!  
Your help makes this offline, privacy-first password manager even better.  

---

## 🛠 How to Contribute

We welcome contributions of all kinds:

- 🐛 **Bug Reports** – Found an issue? Open an [Issue](../../issues) and describe it.
- 💡 **Feature Requests** – Have an idea for improvement? Share it in [Discussions](../../discussions) or open an Issue.
- 🔧 **Code Contributions** – Fix a bug, add a feature, or improve the documentation.

---

## 📥 Setting Up Your Development Environment

1. **Fork the repository**  
   Click the **Fork** button on GitHub to create your own copy.

2. **Clone your fork locally**

   ```bash
   git clone https://github.com/<your-username>/vaultly.git
   cd vaultly```

3. **Install Flutter dependencies**

`flutter pub get`

4. **Run the app**

`flutter run`

>💡 Make sure your device or emulator is connected.

---

## 📏 Coding Guidelines

- Follow **Flutter & Dart** best practices
- use **meaningful commit messages**
  - Example: `fix: resolve null error on vault unlock`
  - Example: `feat: add biometric unlock support`
- Keep pull requests **focused and small**
- Add comments for **non-obvious logic**
- Use **snake_case** for files and **CamelCase** for classes

---

## 🔀 Pull Request Workflow

1. Create a new branch for your changes:
`git checkout -b feature/my-feature`

2. Commit your work:
`git commit -m "feat: add new feature description"`

3. Push to your fork:
`git push origin feature/my-feature`

4. Open a Pull Request to the `main` branch of this repository.

---

## ✅ Contribution Checklist

Before opening a Pull Request, make sure to:

- Code builds and runs locally
- Tests (if any) pass successfully
- No sensitive data (passwords, API keys) is included
- PR description explains what and why

---

## 🛡 Security & Privacy

Vaultly is a security-focused app.

- Do not submit code that weakens encryption or stores passwords in plain text.
- If you discover a security vulnerability, do not open a public issue.
Instead, contact: Coming soon

---

## ❤️ Thanks for Contributing

Your time and effort are greatly appreciated.
Together, we’re making a truly offline, private, and secure password manager for everyone.
