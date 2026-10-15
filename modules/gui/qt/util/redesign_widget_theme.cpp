// SPDX-License-Identifier: GPL-2.0-or-later
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "redesign_widget_theme.hpp"
#include "maininterface/mainctx.hpp"
#include "color_scheme_model.hpp"
#include <QApplication>
#include <QStyleHints>
#include <QWidget>
#include <QPointer>

void applyRedesignWidgetTheme(QWidget* widget, MainCtx* ctx)
{
    widget->setProperty("redesignDialog", true);
    widget->setAttribute(Qt::WA_StyledBackground);
    const auto applyTheme = [widget, ctx = QPointer<MainCtx>(ctx)] {
        if (!ctx) return;
        const auto scheme = ctx->getColorScheme()->currentScheme();
        const bool light = scheme == ColorSchemeModel::Day ||
            (scheme == ColorSchemeModel::System && qApp->styleHints()->colorScheme() == Qt::ColorScheme::Light);
        const QString background = light ? "#acacac" : "#1b1b1b";
        const QString field = light ? "#dedede" : "#090909";
        const QString foreground = light ? "#404040" : "#8f8f8f";
        const QString bright = light ? "#2e2e2e" : "#e5e5e5";
        const QString border = light ? "#969696" : "#292929";
        const QString hover = light ? "#d5d5d5" : "#292929";
        const auto accent = ctx->redesignAccent().name();
        const auto dp = [ctx](int value) { return qRound(value * ctx->getIntfScaleFactor()); };
        QPalette colors = widget->palette();
        colors.setColor(QPalette::Window, QColor(background));
        colors.setColor(QPalette::WindowText, QColor(foreground));
        colors.setColor(QPalette::Base, QColor(field));
        colors.setColor(QPalette::AlternateBase, QColor(background));
        colors.setColor(QPalette::Text, QColor(bright));
        colors.setColor(QPalette::Button, QColor(field));
        colors.setColor(QPalette::ButtonText, QColor(foreground));
        colors.setColor(QPalette::Highlight, QColor(accent));
        colors.setColor(QPalette::HighlightedText, QColor("#161616"));
        colors.setColor(QPalette::Link, QColor(accent));
        widget->setPalette(colors);
        widget->setStyleSheet(QStringLiteral(
            "QWidget { font-family: Inter; font-size: %1px; color: %2; }"
            "QWidget[redesignDialog=\"true\"], QDialog, QTabWidget::pane { background: %3; border: none; }"
            "QLineEdit, QTextEdit, QComboBox, QAbstractItemView { background: %4; alternate-background-color: %3; color: %5; border: 1px solid %6; border-radius: 4px; padding: 5px; selection-background-color: %7; selection-color: #161616; }"
            "QLineEdit:focus, QTextEdit:focus { border-color: %7; }"
            "QPushButton { background: %4; border: 1px solid transparent; border-radius: 4px; padding: 6px 16px; min-height: 18px; }"
            "QToolButton { background: transparent; border: 1px solid transparent; border-radius: 4px; padding: 4px; }"
            "QToolButton:hover { background: %8; }"
            "QToolButton:focus { border-color: %7; }"
            "QPushButton:hover { background: %8; }"
            "QPushButton:focus { border-color: %7; }"
            "QPushButton:pressed { background: %7; color: #161616; }"
            "QPushButton#saveMetadataButton, QPushButton[redesignPrimary=\"true\"] { background: %7; color: #161616; }"
            "QPushButton#saveMetadataButton:hover { border-color: %5; }"
            "QPushButton[redesignPrimary=\"true\"]:disabled { background: %8; color: %2; }"
            "QWidget:disabled { color: %6; }"
            "QTabBar::tab { background: %4; padding: 10px 16px; border-bottom: 2px solid transparent; }"
            "QTabBar::tab:selected { color: %5; border-bottom-color: %7; }"
            "QTabBar::tab:hover { background: %8; }"
            "QHeaderView { background: %8; border: none; padding: 0; border-radius: 0; }"
            "QHeaderView::section { background: %8; color: %5; border: none; padding: 6px; }"
            "QTableCornerButton::section { background: %8; border: none; }"
            "QGraphicsView { background: %4; border: none; }"
            "QScrollBar:vertical { background: %3; width: 6px; margin: 0; }"
            "QScrollBar:horizontal { background: %3; height: 6px; margin: 0; }"
            "QScrollBar::handle { background: %6; border-radius: 3px; }"
            "QScrollBar::handle:vertical { min-height: 24px; }"
            "QScrollBar::handle:horizontal { min-width: 24px; }"
            "QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }"
            "QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }"
            "QScrollArea, QScrollArea > QWidget > QWidget { background: %3; border: none; }")
            .arg(dp(14)).arg(foreground, background, field, bright, border, accent, hover));
    };
    applyTheme();
    if (ctx) {
        QObject::connect(ctx, &MainCtx::redesignAccentChanged, widget, applyTheme);
        QObject::connect(ctx, &MainCtx::intfScaleFactorChanged, widget, applyTheme);
        QObject::connect(ctx->getColorScheme(), &ColorSchemeModel::currentChanged, widget, applyTheme);
        QObject::connect(qApp->styleHints(), &QStyleHints::colorSchemeChanged, widget, applyTheme);
    }
}
