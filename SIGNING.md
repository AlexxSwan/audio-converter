# 🔑 Подпись APK (для обновления поверх старой версии)

По умолчанию debug-сборки подписаны случайным ключом, который каждый раз новый.
Из-за этого Android не даёт обновить приложение — просит удалить старую версию.

Чтобы APK подписывался **одним и тем же ключом** между сборками,
нужно один раз создать keystore и добавить его в GitHub Secrets.

## 📋 Пошаговая инструкция

### Шаг 1. Создайте keystore локально

Откройте cmd и введите (одной строкой):

```cmd
keytool -genkey -v -keystore C:\Users\Alexx\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Ответьте на вопросы:
- **Keystore password**: `audio2026` (или любой — запомните!)
- **Re-enter**: `audio2026`
- **First and last name?**: `Alexx Swan`
- **Organizational unit?**: `SwanLab`
- **Organization?**: `SwanLab`
- **City?**: `Moscow`
- **State?**: `Moscow`
- **Country code?**: `RU`
- **Is correct?**: `y`

Создастся файл `C:\Users\Alexx\upload-keystore.jks`.

### Шаг 2. Закодируйте keystore в base64

В cmd:
```cmd
certutil -encode C:\Users\Alexx\upload-keystore.jks C:\Users\Alexx\upload-keystore.b64
```

Откройте `C:\Users\Alexx\upload-keystore.b64` в Блокноте.
Удалите первую строку (`-----BEGIN CERTIFICATE-----`) и последнюю (`-----END CERTIFICATE-----`).
Оставьте только base64-строку (одна длинная строка).

Скопируйте её в Блокнот (Ctrl+A → Ctrl+C).

### Шаг 3. Добавьте 4 секрета на GitHub

1. Откройте https://github.com/AlexxSwan/audio-converter/settings/secrets/actions
2. Нажмите **"New repository secret"** для каждого:

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | вставьте base64-строку из Шага 2 |
| `KEYSTORE_PASSWORD` | `audio2026` (или ваш пароль из Шага 1) |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | `audio2026` (тот же пароль) |

### Шаг 4. Готово!

При следующем push в GitHub Actions:
- Workflow автоматически декодирует keystore из секрета
- Создаст `key.properties` с вашими паролями
- Соберёт **release APK** (а не debug)
- APK будет подписан вашим постоянным ключом

Теперь новый APK можно устанавливать **поверх старого** — Android увидит ту же подпись.

## 🔄 Что если нужно сменить ключ?

Если ключ скомпрометирован или вы хотите его сменить:
1. Создайте новый keystore (Шаг 1)
2. Обновите секреты на GitHub (Шаг 3)
3. Пользователям придётся удалить старую версию и поставить новую
   (Android не даёт менять подпись у установленного приложения)

## ⚠️ Важно

- **Не коммитьте** `upload-keystore.jks` в репозиторий (он в `.gitignore`)
- **Не коммитьте** `android/key.properties` (тоже в `.gitignore`)
- Храните `upload-keystore.jks` в надёжном месте (например, в Dropbox/Google Drive)
- Если потеряете keystore — больше не сможете обновлять приложение!

## 🆘 Если что-то не работает

1. Проверьте логи workflow на GitHub Actions
2. Убедитесь, что все 4 секрета добавлены
3. Имена секретов должны быть **точно** как в таблице выше
4. base64-строка не должна содержать переносов строк (одна длинная строка)
