#include "protocol.hpp"

#include <unistd.h>

#include <qbytearray.h>
#include <qdir.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qstring.h>
#include <qtenvironmentvariables.h>

namespace luke::quickshell::pinentry {

QString defaultSocketPath() {
    const auto override = qEnvironmentVariable("QUICKSHELL_PINENTRY_SOCKET");
    if (!override.isEmpty()) return override;

    auto runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (runtimeDir.isEmpty()) runtimeDir = QString("/run/user/%1").arg(getuid());

    return QDir(QDir(runtimeDir).filePath("quickshell-pinentry")).filePath("pinentry.sock");
}

QByteArray jsonLine(const QJsonObject& object) {
    auto bytes = QJsonDocument(object).toJson(QJsonDocument::Compact);
    bytes.append('\n');
    return bytes;
}

bool readJsonLine(QLocalSocket& socket, QJsonObject* object, QString* error, int timeoutMs) {
    QByteArray buffer;

    while (!buffer.contains('\n')) {
        if (!socket.waitForReadyRead(timeoutMs)) {
            if (error) *error = socket.errorString();
            return false;
        }

        buffer.append(socket.readAll());
        if (buffer.size() > MaxBridgeMessageSize) {
            if (error) *error = "pinentry bridge response was too large";
            return false;
        }
    }

    const auto line = buffer.left(buffer.indexOf('\n')).trimmed();
    auto parseError = QJsonParseError();
    const auto document = QJsonDocument::fromJson(line, &parseError);

    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        if (error) *error = "invalid pinentry bridge response";
        return false;
    }

    if (object) *object = document.object();
    return true;
}

} // namespace luke::quickshell::pinentry
