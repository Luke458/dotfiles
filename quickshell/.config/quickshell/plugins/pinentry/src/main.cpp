#include <unistd.h>

#include <iostream>
#include <string>
#include <vector>

#include <gpg-error.h>

#include <qcoreapplication.h>
#include <qfileinfo.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qstandardpaths.h>
#include <qstring.h>
#include <qstringlist.h>

#include "protocol.hpp"

namespace {

constexpr int ConnectTimeoutMs = 2000;
constexpr int WriteTimeoutMs = 2000;
constexpr int ProbeTimeoutMs = 250;

struct State {
    QString title;
    QString description;
    QString prompt;
    QString error;
    QString okLabel;
    QString cancelLabel;
    QString notOkLabel;
    QString repeatLabel;
    QString repeatError;
    QString keyInfo;
    int timeout = 0;
};

gpg_error_t pinentryError(gpg_err_code_t code) {
    return gpg_err_make(GPG_ERR_SOURCE_PINENTRY, code);
}

void writeLine(const QString& line) {
    std::cout << line.toStdString() << '\n';
    std::cout.flush();
}

void ok(const QString& message = {}) {
    writeLine(message.isEmpty() ? "OK" : "OK " + message);
}

void err(gpg_error_t code, const QString& message) {
    writeLine(QString("ERR %1 %2").arg(static_cast<unsigned int>(code)).arg(message));
}

int hexValue(QChar character) {
    const auto value = character.toLatin1();
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    return -1;
}

QString percentDecode(const QString& input) {
    QByteArray bytes;

    for (qsizetype index = 0; index < input.length(); ++index) {
        if (input.at(index) == '%' && index + 2 < input.length()) {
            const auto high = hexValue(input.at(index + 1));
            const auto low = hexValue(input.at(index + 2));
            if (high >= 0 && low >= 0) {
                bytes.append(static_cast<char>((high << 4) | low));
                index += 2;
                continue;
            }
        }

        bytes.append(QString(input.at(index)).toUtf8());
    }

    return QString::fromUtf8(bytes);
}

QByteArray percentEncodeData(const QString& input) {
    QByteArray output;
    const auto bytes = input.toUtf8();

    for (const auto byte : bytes) {
        const auto value = static_cast<unsigned char>(byte);
        if (value == '%' || value == '\n' || value == '\r') {
            output.append('%');
            output.append("0123456789ABCDEF"[value >> 4]);
            output.append("0123456789ABCDEF"[value & 0x0f]);
        } else {
            output.append(static_cast<char>(value));
        }
    }

    return output;
}

void writeData(const QString& data) {
    const auto encoded = percentEncodeData(data);
    constexpr qsizetype ChunkSize = 900;

    if (encoded.isEmpty()) {
        std::cout << "D \n";
        std::cout.flush();
        return;
    }

    for (qsizetype offset = 0; offset < encoded.size(); offset += ChunkSize) {
        const auto chunk = encoded.mid(offset, ChunkSize);
        std::cout << "D " << chunk.constData() << '\n';
    }

    std::cout.flush();
}

QString stripAccelerators(QString text) {
    text.replace("__", "\u0001");
    text.remove('_');
    text.replace("\u0001", "_");
    return text;
}

void reset(State& state) {
    state = {};
}

void applyOption(State& state, const QString& argument) {
    const auto index = argument.indexOf('=');
    const auto key = index < 0 ? argument : argument.left(index);
    const auto value = index < 0 ? QString() : percentDecode(argument.mid(index + 1));

    if (key == "timeout") state.timeout = value.toInt();
    else if (key == "default-ok" && state.okLabel.isEmpty()) state.okLabel = stripAccelerators(value);
    else if (key == "default-cancel" && state.cancelLabel.isEmpty()) state.cancelLabel = stripAccelerators(value);
    else if (key == "default-prompt" && state.prompt.isEmpty()) state.prompt = stripAccelerators(value);
}

QJsonObject requestPayload(const State& state, const QString& mode, bool oneButton) {
    return {
        {"mode", mode},
        {"title", state.title},
        {"description", state.description},
        {"prompt", state.prompt},
        {"error", state.error},
        {"okLabel", state.okLabel},
        {"cancelLabel", state.cancelLabel},
        {"notOkLabel", state.notOkLabel},
        {"repeatLabel", state.repeatLabel},
        {"repeatError", state.repeatError},
        {"keyInfo", state.keyInfo},
        {"oneButton", oneButton},
        {"timeout", state.timeout},
    };
}

bool sendBridgeRequest(const QJsonObject& payload, QJsonObject* response, QString* errorMessage) {
    QLocalSocket socket;
    socket.connectToServer(luke::quickshell::pinentry::defaultSocketPath());

    if (!socket.waitForConnected(ConnectTimeoutMs)) {
        if (errorMessage) *errorMessage = socket.errorString();
        return false;
    }

    socket.write(luke::quickshell::pinentry::jsonLine(payload));
    if (!socket.waitForBytesWritten(WriteTimeoutMs)) {
        if (errorMessage) *errorMessage = socket.errorString();
        return false;
    }

    const auto timeout = payload.value("timeout").toInt() > 0 ? payload.value("timeout").toInt() * 1000 : -1;
    return luke::quickshell::pinentry::readJsonLine(socket, response, errorMessage, timeout);
}

bool bridgeAvailable() {
    QLocalSocket socket;
    socket.connectToServer(luke::quickshell::pinentry::defaultSocketPath());

    if (!socket.waitForConnected(ProbeTimeoutMs)) return false;

    socket.disconnectFromServer();
    return true;
}

QStringList fallbackCandidates() {
    QStringList candidates;

    const auto configuredFallback = qEnvironmentVariable("QUICKSHELL_PINENTRY_FALLBACK");
    if (!configuredFallback.isEmpty()) candidates.push_back(configuredFallback);

    const QStringList names = {
        "pinentry-curses",
        "pinentry-tty",
        "pinentry-qt6",
        "pinentry-qt5",
        "pinentry-gnome3",
        "pinentry-gtk-2",
        "pinentry-qt",
    };

    for (const auto& name : names) {
        const auto path = QStandardPaths::findExecutable(name);
        if (!path.isEmpty()) candidates.push_back(path);
    }

    candidates.removeDuplicates();
    return candidates;
}

QString canonicalPath(const QString& path) {
    const QFileInfo info(path);
    const auto canonical = info.canonicalFilePath();
    return canonical.isEmpty() ? info.absoluteFilePath() : canonical;
}

void execFallbackPinentry(const QStringList& arguments) {
    const auto self = canonicalPath(QCoreApplication::applicationFilePath());

    for (const auto& candidate : fallbackCandidates()) {
        const QFileInfo info(candidate);
        if (!info.exists() || !info.isExecutable()) continue;

        const auto executable = canonicalPath(candidate);
        if (executable == self) continue;

        std::vector<QByteArray> argumentBytes;
        argumentBytes.reserve(static_cast<std::size_t>(arguments.size()) + 1);
        argumentBytes.push_back(QFile::encodeName(executable));

        for (qsizetype index = 1; index < arguments.size(); ++index) {
            argumentBytes.push_back(arguments.at(index).toLocal8Bit());
        }

        std::vector<char*> argv;
        argv.reserve(argumentBytes.size() + 1);
        for (auto& argument : argumentBytes) {
            argv.push_back(argument.data());
        }
        argv.push_back(nullptr);

        qputenv("QUICKSHELL_PINENTRY_FALLBACK_ACTIVE", "1");
        execv(argumentBytes.front().constData(), argv.data());
    }
}

bool performRequest(State& state, const QString& mode, bool oneButton) {
    QJsonObject response;
    QString errorMessage;

    if (!sendBridgeRequest(requestPayload(state, mode, oneButton), &response, &errorMessage)) {
        err(pinentryError(GPG_ERR_NO_PIN_ENTRY), errorMessage);
        return false;
    }

    const auto status = response.value("status").toString();
    if (status == "ok") {
        if (mode == "getpin") writeData(response.value("secret").toString());
        ok();
        state.error.clear();
        return true;
    }

    if (status == "notok") {
        err(pinentryError(GPG_ERR_NOT_CONFIRMED), "Not confirmed");
        state.error.clear();
        return false;
    }

    if (status == "cancel") {
        err(pinentryError(GPG_ERR_CANCELED), "Operation cancelled");
        state.error.clear();
        return false;
    }

    err(pinentryError(GPG_ERR_NO_PIN_ENTRY), response.value("message").toString("pinentry bridge failed"));
    return false;
}

QString readLogicalLine(std::string line) {
    auto result = QString::fromStdString(line);
    if (result.endsWith('\r')) result.chop(1);

    while (result.endsWith('\\')) {
        result.chop(1);

        std::string next;
        if (!std::getline(std::cin, next)) break;

        auto continuation = QString::fromStdString(next);
        if (continuation.endsWith('\r')) continuation.chop(1);

        result += ' ';
        result += continuation;
    }

    return result;
}

int runProtocol() {
    State state;
    ok("pinentry-quickshell");

    std::string rawLine;
    while (std::getline(std::cin, rawLine)) {
        const auto line = readLogicalLine(rawLine).trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;

        const auto separator = line.indexOf(' ');
        auto command = separator < 0 ? line : line.left(separator);
        const auto argument = separator < 0 ? QString() : line.mid(separator + 1);
        command = command.toUpper();

        if (command == "BYE") {
            ok("closing connection");
            return 0;
        } else if (command == "NOP") {
            ok();
        } else if (command == "RESET") {
            reset(state);
            ok();
        } else if (command == "OPTION") {
            applyOption(state, argument);
            ok();
        } else if (command == "SETTIMEOUT") {
            state.timeout = argument.toInt();
            ok();
        } else if (command == "SETDESC") {
            state.description = percentDecode(argument);
            ok();
        } else if (command == "SETPROMPT") {
            state.prompt = stripAccelerators(percentDecode(argument));
            ok();
        } else if (command == "SETTITLE") {
            state.title = percentDecode(argument);
            ok();
        } else if (command == "SETOK") {
            state.okLabel = stripAccelerators(percentDecode(argument));
            ok();
        } else if (command == "SETCANCEL") {
            state.cancelLabel = stripAccelerators(percentDecode(argument));
            ok();
        } else if (command == "SETNOTOK") {
            state.notOkLabel = stripAccelerators(percentDecode(argument));
            ok();
        } else if (command == "SETREPEAT") {
            state.repeatLabel = stripAccelerators(percentDecode(argument));
            ok();
        } else if (command == "SETREPEATERROR") {
            state.repeatError = percentDecode(argument);
            ok();
        } else if (command == "SETERROR") {
            state.error = percentDecode(argument);
            ok();
        } else if (command == "SETKEYINFO") {
            state.keyInfo = percentDecode(argument);
            ok();
        } else if (command == "SETQUALITYBAR" || command == "SETQUALITYBAR_TT" || command == "SETGENPIN"
                   || command == "SETGENPIN_TT") {
            ok();
        } else if (command == "GETPIN") {
            performRequest(state, "getpin", false);
        } else if (command == "CONFIRM") {
            performRequest(state, "confirm", argument.contains("--one-button"));
        } else if (command == "MESSAGE") {
            performRequest(state, "message", true);
        } else if (command == "GETINFO") {
            const auto key = argument.trimmed();
            if (key == "pid") writeData(QString::number(QCoreApplication::applicationPid()));
            else if (key == "version") writeData("pinentry-quickshell 0.1");
            ok();
        } else if (command == "HELP") {
            writeLine("# GETPIN CONFIRM MESSAGE SETDESC SETPROMPT SETTITLE SETOK SETCANCEL SETERROR OPTION BYE");
            ok();
        } else {
            err(pinentryError(GPG_ERR_ASS_UNKNOWN_CMD), "Unknown command");
        }
    }

    return 0;
}

} // namespace

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    const auto arguments = QCoreApplication::arguments();

    if (arguments.contains("--version")) {
        std::cout << "pinentry-quickshell 0.1\n";
        return 0;
    }

    if (arguments.contains("--help")) {
        std::cout << "Usage: pinentry-quickshell [pinentry-options]\n";
        return 0;
    }

    if (!qEnvironmentVariableIsSet("QUICKSHELL_PINENTRY_FALLBACK_ACTIVE") && !bridgeAvailable()) {
        execFallbackPinentry(arguments);
    }

    return runProtocol();
}
