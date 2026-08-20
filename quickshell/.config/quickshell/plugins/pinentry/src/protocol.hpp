#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qstring.h>

class QLocalSocket;

namespace luke::quickshell::pinentry {

constexpr qsizetype MaxBridgeMessageSize = 64 * 1024;

QString defaultSocketPath();
QByteArray jsonLine(const QJsonObject& object);
bool readJsonLine(QLocalSocket& socket, QJsonObject* object, QString* error, int timeoutMs);

} // namespace luke::quickshell::pinentry
