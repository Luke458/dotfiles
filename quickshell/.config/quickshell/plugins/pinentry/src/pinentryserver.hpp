#pragma once

#include <qbytearray.h>
#include <qjsonobject.h>
#include <qlocalserver.h>
#include <qobject.h>
#include <qpointer.h>
#include <qqmlintegration.h>
#include <qqmlparserstatus.h>
#include <qstring.h>

class QLocalSocket;

namespace luke::quickshell::pinentry {

class PinentryRequest : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("PinentryRequest objects are created by PinentryServer.")

    Q_PROPERTY(Mode mode READ mode CONSTANT)
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString description READ description CONSTANT)
    Q_PROPERTY(QString prompt READ prompt CONSTANT)
    Q_PROPERTY(QString error READ error CONSTANT)
    Q_PROPERTY(QString okLabel READ okLabel CONSTANT)
    Q_PROPERTY(QString cancelLabel READ cancelLabel CONSTANT)
    Q_PROPERTY(QString notOkLabel READ notOkLabel CONSTANT)
    Q_PROPERTY(QString repeatLabel READ repeatLabel CONSTANT)
    Q_PROPERTY(QString repeatError READ repeatError CONSTANT)
    Q_PROPERTY(QString keyInfo READ keyInfo CONSTANT)
    Q_PROPERTY(bool oneButton READ oneButton CONSTANT)

public:
    enum Mode {
        GetPin,
        Confirm,
        Message,
    };
    Q_ENUM(Mode)

    explicit PinentryRequest(QJsonObject payload, QObject* parent = nullptr);

    Mode mode() const { return mMode; }
    QString title() const { return mTitle; }
    QString description() const { return mDescription; }
    QString prompt() const { return mPrompt; }
    QString error() const { return mError; }
    QString okLabel() const { return mOkLabel; }
    QString cancelLabel() const { return mCancelLabel; }
    QString notOkLabel() const { return mNotOkLabel; }
    QString repeatLabel() const { return mRepeatLabel; }
    QString repeatError() const { return mRepeatError; }
    QString keyInfo() const { return mKeyInfo; }
    bool oneButton() const { return mOneButton; }

private:
    Mode mMode = GetPin;
    QString mTitle;
    QString mDescription;
    QString mPrompt;
    QString mError;
    QString mOkLabel;
    QString mCancelLabel;
    QString mNotOkLabel;
    QString mRepeatLabel;
    QString mRepeatError;
    QString mKeyInfo;
    bool mOneButton = false;
};

class PinentryServer : public QObject, public QQmlParserStatus {
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)

    Q_PROPERTY(QString socketPath READ socketPath WRITE setSocketPath NOTIFY socketPathChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool listening READ listening NOTIFY listeningChanged)
    Q_PROPERTY(PinentryRequest* activeRequest READ activeRequest NOTIFY activeRequestChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeRequestChanged)

public:
    explicit PinentryServer(QObject* parent = nullptr);
    ~PinentryServer() override;
    Q_DISABLE_COPY_MOVE(PinentryServer)

    void classBegin() override {}
    void componentComplete() override;

    QString socketPath() const { return mSocketPath; }
    void setSocketPath(const QString& socketPath);

    bool enabled() const { return mEnabled; }
    void setEnabled(bool enabled);

    bool listening() const { return mListening; }
    PinentryRequest* activeRequest() const { return mActiveRequest; }
    bool active() const { return mActiveRequest != nullptr; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void submit(const QString& secret);
    Q_INVOKABLE void accept();
    Q_INVOKABLE void reject();
    Q_INVOKABLE void cancel();

signals:
    void requestStarted(luke::quickshell::pinentry::PinentryRequest* request);
    void socketPathChanged();
    void enabledChanged();
    void listeningChanged();
    void activeRequestChanged();

private slots:
    void onNewConnection();
    void onReadyRead();
    void onDisconnected();

private:
    void sendError(QLocalSocket* socket, const QString& message);
    void reply(const QJsonObject& payload);
    void clearActiveRequest();
    void setListening(bool listening);

    QLocalServer mServer;
    QString mSocketPath;
    bool mEnabled = true;
    bool mCompleted = false;
    bool mListening = false;
    QPointer<QLocalSocket> mActiveSocket;
    QByteArray mReadBuffer;
    PinentryRequest* mActiveRequest = nullptr;
};

} // namespace luke::quickshell::pinentry
