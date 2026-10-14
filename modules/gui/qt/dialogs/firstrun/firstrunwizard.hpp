// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2021-2026 VLC authors and VideoLAN
#ifndef VLC_FIRSTRUNWIZARD_H
#define VLC_FIRSTRUNWIZARD_H

#include <QObject>
#include <QVariantList>
#include "maininterface/mainctx.hpp"

/** Native operations for the three-page first-run view. */
class FirstRunWizard : public QObject
{
    Q_OBJECT
    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QString defaultFolder READ defaultFolder NOTIFY ctxChanged FINAL)
    Q_PROPERTY(bool hasMediaLibrary READ hasMediaLibrary NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QVariantList shortcuts READ shortcuts NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged FINAL)
public:
    explicit FirstRunWizard(QObject* parent = nullptr);
    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QString defaultFolder() const;
    bool hasMediaLibrary() const;
    QVariantList shortcuts() const;
    QString errorMessage() const { return m_error; }
    Q_INVOKABLE bool validateFolder(const QString& folder);
    Q_INVOKABLE QString browseFolder(const QString& initial);
    Q_INVOKABLE bool finish(const QString& folder, int scheme, const QString& accent, bool onlineMetadata);
    Q_INVOKABLE bool skip();
signals:
    void ctxChanged();
    void errorChanged();
private:
    bool fail(const QString& error);
    static QString folderPath(const QString& folder);
    MainCtx* m_ctx = nullptr;
    QString m_error;
};
#endif
