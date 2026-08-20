#include "pinentryserver.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qlocalsocket.h>
#include <qloggingcategory.h>
#include <qtimer.h>

#include "protocol.hpp"

Q_LOGGING_CATEGORY(logPinentry, "luke.quickshell.pinentry", QtWarningMsg)

namespace luke::quickshell::pinentry {

PinentryRequest::PinentryRequest(QJsonObject payload, QObject* parent)
    : QObject(parent)
    , mTitle(payload.value("title").toString())
    , mDescription(payload.value("description").toString())
    , mPrompt(payload.value("prompt").toString())
    , mError(payload.value("error").toString())
    , mOkLabel(payload.value("okLabel").toString())
    , mCancelLabel(payload.value("cancelLabel").toString())
    , mNotOkLabel(payload.value("notOkLabel").toString())
    , mRepeatLabel(payload.value("repeatLabel").toString())
    , mRepeatError(payload.value("repeatError").toString())
    , mKeyInfo(payload.value("keyInfo").toString())
    , mOneButton(payload.value("oneButton").toBool()) {
    const auto mode = payload.value("mode").toString();
    if (mode == "confirm") mMode = Confirm;
    else if (mode == "message") mMode = Message;
}

PinentryServer::PinentryServer(QObject* parent)
    : QObject(parent)
    , mSocketPath(defaultSocketPath()) {
    QObject::connect(&mServer, &QLocalServer::newConnection, this, &PinentryServer::onNewConnection);
}

PinentryServer::~PinentryServer() {
    stop();
}

void PinentryServer::componentComplete() {
    mCompleted = true;
    if (mEnabled) start();
}

void PinentryServer::setSocketPath(const QString& socketPath) {
    if (mSocketPath == socketPath) return;

    if (mListening) {
        qCWarning(logPinentry) << "cannot change PinentryServer.socketPath while listening.";
        return;
    }

    mSocketPath = socketPath;
    emit socketPathChanged();
}

void PinentryServer::setEnabled(bool enabled) {
    if (mEnabled == enabled) return;
    mEnabled = enabled;
    emit enabledChanged();

    if (!mCompleted) return;
    if (mEnabled) start();
    else stop();
}

void PinentryServer::start() {
    if (mListening) return;

    const auto retry = [this]() {
        QTimer::singleShot(50, this, [this]() {
            if (mEnabled && !mListening)
                start();
        });
    };

    const auto socketFile = QFileInfo(mSocketPath);
    const auto dir = socketFile.dir();
    if (!dir.mkpath(".")) {
        qCWarning(logPinentry) << "failed to create pinentry socket directory" << dir.path();
        return;
    }

    mServer.setSocketOptions(QLocalServer::UserAccessOption);

    // During a Quickshell reload, the new QML tree completes before the old
    // tree is destroyed. With access options enabled, Qt listens on a private
    // temporary socket and renames it over mSocketPath. If we listen while the
    // old server is alive, its later close() unlinks our newly published path.
    // Wait for the existing listener to go away instead of stealing its name.
    if (QFileInfo::exists(mSocketPath)) {
        QLocalSocket probe;
        probe.connectToServer(mSocketPath);

        if (probe.waitForConnected(100)) {
            probe.abort();
            retry();
            return;
        }

        if (!QLocalServer::removeServer(mSocketPath)) {
            qCWarning(logPinentry) << "failed to remove stale pinentry socket" << mSocketPath;
            retry();
            return;
        }
    }

    if (!mServer.listen(mSocketPath)) {
        if (mServer.serverError() == QAbstractSocket::AddressInUseError) {
            retry();
            return;
        }

        qCWarning(logPinentry) << "failed to listen on pinentry socket" << mSocketPath << ':'
                              << mServer.errorString();
        return;
    }

    qCInfo(logPinentry) << "listening on pinentry socket" << mSocketPath;
    setListening(true);
}

void PinentryServer::stop() {
    if (mActiveSocket) reply({{"status", "cancel"}});

    if (mListening) {
        mServer.close();
        setListening(false);
    }
}

void PinentryServer::submit(const QString& secret) {
    if (!mActiveRequest) return;
    if (mActiveRequest->mode() != PinentryRequest::GetPin) {
        qCWarning(logPinentry) << "submit called for a non-GETPIN request.";
        return;
    }

    reply({{"status", "ok"}, {"secret", secret}});
}

void PinentryServer::accept() {
    if (mActiveRequest) reply({{"status", "ok"}});
}

void PinentryServer::reject() {
    if (mActiveRequest) reply({{"status", "notok"}});
}

void PinentryServer::cancel() {
    if (mActiveRequest) reply({{"status", "cancel"}});
}

void PinentryServer::onNewConnection() {
    while (auto* socket = mServer.nextPendingConnection()) {
        socket->setParent(this);

        if (mActiveSocket || mActiveRequest) {
            QObject::connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            sendError(socket, "pinentry prompt already active");
            continue;
        }

        mActiveSocket = socket;
        mReadBuffer.clear();

        QObject::connect(socket, &QLocalSocket::readyRead, this, &PinentryServer::onReadyRead);
        QObject::connect(socket, &QLocalSocket::disconnected, this, &PinentryServer::onDisconnected);
    }
}

void PinentryServer::onReadyRead() {
    auto* socket = qobject_cast<QLocalSocket*>(sender());
    if (!socket || socket != mActiveSocket) return;

    mReadBuffer.append(socket->readAll());
    if (mReadBuffer.size() > MaxBridgeMessageSize) {
        sendError(socket, "pinentry request was too large");
        clearActiveRequest();
        return;
    }

    if (!mReadBuffer.contains('\n')) return;

    const auto line = mReadBuffer.left(mReadBuffer.indexOf('\n')).trimmed();
    auto parseError = QJsonParseError();
    const auto document = QJsonDocument::fromJson(line, &parseError);

    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        sendError(socket, "invalid pinentry request");
        clearActiveRequest();
        return;
    }

    mActiveRequest = new PinentryRequest(document.object(), this);
    emit activeRequestChanged();
    emit requestStarted(mActiveRequest);
}

void PinentryServer::onDisconnected() {
    auto* socket = qobject_cast<QLocalSocket*>(sender());
    if (!socket) return;

    if (socket == mActiveSocket) clearActiveRequest();
    socket->deleteLater();
}

void PinentryServer::sendError(QLocalSocket* socket, const QString& message) {
    if (!socket) return;
    socket->write(jsonLine({{"status", "error"}, {"message", message}}));
    socket->flush();
    socket->disconnectFromServer();
}

void PinentryServer::reply(const QJsonObject& payload) {
    if (mActiveSocket) {
        mActiveSocket->write(jsonLine(payload));
        mActiveSocket->flush();
        mActiveSocket->disconnectFromServer();
    }

    clearActiveRequest();
}

void PinentryServer::clearActiveRequest() {
    if (mActiveRequest) {
        mActiveRequest->deleteLater();
        mActiveRequest = nullptr;
        emit activeRequestChanged();
    }

    mReadBuffer.clear();
    mActiveSocket = nullptr;
}

void PinentryServer::setListening(bool listening) {
    if (mListening == listening) return;
    mListening = listening;
    emit listeningChanged();
}

} // namespace luke::quickshell::pinentry
