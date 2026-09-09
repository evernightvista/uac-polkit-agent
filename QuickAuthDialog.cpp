/*  This file is part of the KDE project
    SPDX-FileCopyrightText: 2021 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include "QuickAuthDialog.h"
#include "IdentitiesModel.h"
#include "config.h"

#include <PolkitQt1/Authority>

#include <KConfigGroup>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KNotification>
#include <KRuntimePlatform>
#include <KUser>

#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

QuickAuthDialog::QuickAuthDialog(const QString &actionId,
                                 const QString &message,
                                 [[maybe_unused]] const PolkitQt1::Details &details,
                                 const PolkitQt1::Identity::List &identities)
    : QObject(nullptr)
    , m_actionId(actionId)
    , m_config("uacpolkitagentrc")
{
    auto engine = new QQmlApplicationEngine(this);
    QVariantMap props = {
        {"mainText", message},
        {"sevenLike", m_config.group("General").readEntry("sevenLike", true)},
    };

    const auto actions = PolkitQt1::Authority::instance()->enumerateActionsSync();
    for (const PolkitQt1::ActionDescription &desc : actions) {
        if (actionId == desc.actionId()) {
            qDebug() << "Action description has been found";
            props.insert("descriptionString", desc.description());
            props.insert("descriptionActionId", desc.actionId());
            props.insert("descriptionVendorName", desc.vendorName());
            props.insert("descriptionVendorUrl", desc.vendorUrl());
            props.insert("descriptionIcon", desc.iconName());
            break;
        }
    }

    engine->setInitialProperties(props);
    engine->rootContext()->setContextObject(new KLocalizedQmlContext(engine));

    if (KRuntimePlatform::runtimePlatform().contains("phone")) {
        // If this is Plasma Mobile
        engine->load("qrc:/qml/MobileQuickAuthDialog.qml");
    } else {
        // If this is Plasma Desktop, or other platforms
        engine->load("qrc:/qml/QuickAuthDialog.qml");
    }

    if (engine->rootObjects().isEmpty()) {
        // constFirst() on an empty list would be a silent segfault. The QML
        // engine has already printed the actual error right above this line.
        qFatal("Failed to load the authentication dialog QML, aborting");
    }

    m_theDialog = qobject_cast<QQuickWindow *>(engine->rootObjects().constFirst());
    if (!m_theDialog) {
        qFatal("Failed to cast QML root object to QQuickWindow, aborting");
    }

    auto idents = qobject_cast<IdentitiesModel *>(m_theDialog->property("identitiesModel").value<QObject *>());
    if (!idents) {
        qFatal("Failed to obtain IdentitiesModel from QML dialog, aborting");
    }
    idents->setIdentities(identities, false);
    if (!identities.isEmpty()) {
        int initialIndex = std::max(0, idents->indexForUser(KUser().loginName()));
        m_theDialog->setProperty("identitiesCurrentIndex", initialIndex);
    }

    // listen for dialog accept/reject
    connect(m_theDialog, SIGNAL(accept()), this, SIGNAL(okClicked()));
    connect(m_theDialog, SIGNAL(reject()), this, SIGNAL(rejected()));
    connect(m_theDialog, SIGNAL(userSelected()), this, SIGNAL(userSelected()));
}

enum KirigamiInlineMessageTypes { Information = 0, Positive = 1, Warning = 2, Error = 3 };

QString QuickAuthDialog::actionId() const
{
    return m_actionId;
}

QString QuickAuthDialog::password() const
{
    if (!m_theDialog) {
        return {};
    }
    return m_theDialog->property("password").toString();
}

void QuickAuthDialog::showError(const QString &message)
{
    if (!m_theDialog) {
        return;
    }
    m_theDialog->setProperty("inlineMessageType", Error);
    m_theDialog->setProperty("inlineMessageText", message);
}

void QuickAuthDialog::showInfo(const QString &message)
{
    if (!m_theDialog) {
        return;
    }
    m_theDialog->setProperty("inlineMessageType", Information);
    m_theDialog->setProperty("inlineMessageText", message);
}

PolkitQt1::Identity QuickAuthDialog::adminUserSelected() const
{
    if (!m_theDialog) {
        return {};
    }
    return PolkitQt1::Identity::fromString(m_theDialog->property("selectedIdentity").toString());
}

void QuickAuthDialog::authenticationFailure()
{
    if (!m_theDialog) {
        return;
    }
    // Use QMetaObject::invokeMethod instead of the deprecated
    // QTimer::singleShot(receiver, SLOT(...)) form.  The QML-side
    // authenticationFailure() is a QML function, not a C++ slot, so it
    // can only be reached through the string-based meta-object lookup.
    QMetaObject::invokeMethod(m_theDialog, "authenticationFailure", Qt::QueuedConnection);
}

void QuickAuthDialog::show()
{
    if (!m_theDialog) {
        return;
    }
    KNotification *notification = new KNotification("authenticate");
    notification->setText(i18n("Authentication Required"));
    notification->sendEvent();
    QTimer::singleShot(0, m_theDialog, &QWindow::show);
}

void QuickAuthDialog::hide()
{
    if (!m_theDialog) {
        return;
    }
    QTimer::singleShot(0, m_theDialog, &QWindow::hide);
}

void QuickAuthDialog::request([[maybe_unused]] const QString &request, [[maybe_unused]] bool echo)
{
    if (!m_theDialog) {
        return;
    }
    // QML-side request() is a QML function — use invokeMethod, not SLOT().
    QMetaObject::invokeMethod(m_theDialog, "request", Qt::QueuedConnection);
}

#include "moc_QuickAuthDialog.cpp"
