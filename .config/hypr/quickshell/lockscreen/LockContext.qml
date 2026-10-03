import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    // Сбрасываем ошибку, как только пользователь начинает печатать
    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "") return;
        root.unlockInProgress = true;
        pam.start();
    }

    // Реальная проверка пароля через системный PAM
    PamContext {
        id: pam
        // Используем стандартный конфиг входа в систему
        configDirectory: "/etc/pam.d"
        config: "login"

        onPamMessage: {
            if (this.responseRequired) {
                // Отправляем введённый пароль в систему для проверки
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(); // Пароль верный! Разблокируем.
            } else {
                root.currentText = ""; // Пароль неверный, очищаем поле
                root.showFailure = true; // Показываем ошибку
            }
            root.unlockInProgress = false;
        }
    }
}
