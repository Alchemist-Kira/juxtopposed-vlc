/*****************************************************************************
 * mediainfo.cpp : Information about an item
 ****************************************************************************
 * Copyright (C) 2006-2008 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 ******************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "mediainfo.hpp"
#include "player/player_controller.hpp"
#include "maininterface/mainctx.hpp"
#include "util/color_scheme_model.hpp"

#include <vlc_url.h>

#include <QTabWidget>
#include <QGridLayout>
#include <QLineEdit>
#include <QLabel>
#include <QPushButton>
#include <QApplication>
#include <QStyleHints>
#include <QScrollArea>

/* This Dialog has two main modes:
    - General Mode that shows the current Played item, and the stats
    - Single mode that shows the info on ONE SINGLE Item on the playlist
   Please be Careful of not breaking one the modes behaviour... */

MediaInfoDialog::MediaInfoDialog(qt_intf_t *_p_intf,
                                 SharedInputItem p_item )
    : QVLCFrame( _p_intf )
{
    isMainInputInfo = ( p_item == NULL );

    if ( isMainInputInfo )
        setWindowTitle( qtr( "Current Media Information" ) );
    else
        setWindowTitle( qtr( "Media Information" ) );
    setWindowRole( "vlc-media-info" );
    setObjectName( "redesignMediaInfo" );
    setAttribute( Qt::WA_StyledBackground );

    setWindowFlags( Qt::Window | Qt::CustomizeWindowHint |
                    Qt::WindowCloseButtonHint | Qt::WindowMinimizeButtonHint );

    /* TabWidgets and Tabs creation */
    infoTabW = new QTabWidget;

    MP = new MetaPanel( infoTabW, p_intf );
    auto *metaScrollArea = new QScrollArea( infoTabW );
    metaScrollArea->setWidgetResizable( true );
    metaScrollArea->setFrameShape( QFrame::NoFrame );
    metaScrollArea->setWidget( MP );
    infoTabW->insertTab( META_PANEL, metaScrollArea, qtr( "&General" ) );
    EMP = new ExtraMetaPanel( infoTabW );
    infoTabW->insertTab( EXTRAMETA_PANEL, EMP, qtr( "&Metadata" ) );
    IP = new InfoPanel( infoTabW );
    infoTabW->insertTab( INFO_PANEL, IP, qtr( "Co&dec" ) );
    if( isMainInputInfo )
    {
        ISP = new InputStatsPanel( infoTabW );
        infoTabW->insertTab( INPUTSTATS_PANEL, ISP, qtr( "S&tatistics" ) );
    }

    QGridLayout *layout = new QGridLayout( this );

    /* No need to use a QDialogButtonBox here */
    saveMetaButton = new QPushButton( qtr( "&Save Metadata" ) );
    saveMetaButton->setObjectName( "saveMetadataButton" );
    saveMetaButton->hide();
    QPushButton *closeButton = new QPushButton( qtr( "&Close" ) );
    closeButton->setMaximumWidth(closeButton->minimumSizeHint().width());
    closeButton->setDefault( true );

    QLabel *uriLabel = new QLabel( qtr( "Location:" ) );
    uriLabel->setSizePolicy( QSizePolicy::Fixed, QSizePolicy::Preferred );
    uriLine = new QLineEdit;
    uriLine->setReadOnly( true );

    layout->addWidget( infoTabW, 0, 0, 1, 8 );
    layout->addWidget( uriLabel, 1, 0, 1, 1 );
    layout->addWidget( uriLine, 1, 1, 1, 7 );
    layout->addWidget( saveMetaButton, 2, 6 );
    layout->addWidget( closeButton, 2, 7 );

    BUTTONACT( closeButton, &MediaInfoDialog::close );

    /* The tabs buttons are shown in the main dialog for space and cosmetics */
    BUTTONACT( saveMetaButton, &MediaInfoDialog::saveMeta );

    /* Let the MetaData Panel update the URI */
    connect( MP, &MetaPanel::uriSet, this, &MediaInfoDialog::updateURI );
    connect( MP, &MetaPanel::editing, saveMetaButton, &QPushButton::show );

    /* Display the buttonBar according to the Tab selected */
    connect( infoTabW, &QTabWidget::currentChanged, this, &MediaInfoDialog::updateButtons );

    /* If using the General Mode */
    if( isMainInputInfo )
    {
        msg_Dbg( p_intf, "Using a general info windows" );
        /**
         * Connects on the various signals of input_Manager
         * For the currently playing element
         **/
        connect( THEMIM, &PlayerController::infoChanged,
                  IP, &InfoPanel::update, Qt::DirectConnection  );
        connect( THEMIM, &PlayerController::inputChanged,
            MP, [this]() {
                MP->update( SharedInputItem { THEMIM->getInput() } );
            }, Qt::DirectConnection  );
        connect( THEMIM, &PlayerController::currentMetaChanged,
                  EMP, &ExtraMetaPanel::update, Qt::DirectConnection );
        connect( THEMIM, &PlayerController::statisticsUpdated,
                  ISP, &InputStatsPanel::update, Qt::DirectConnection);

        p_item = SharedInputItem{ THEMIM->getInput() };
    }
    else
        msg_Dbg( p_intf, "Using an item specific info windows" );

    /* Call update at start, so info is filled up at beginning */
    if( p_item )
        updateAllTabs( p_item );

    const auto applyTheme = [this] {
        const auto ctx = p_intf->p_mi;
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
        QPalette colors = palette();
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
        setPalette(colors);
        setStyleSheet(QStringLiteral(
            "QWidget { font-family: Inter; font-size: %1px; color: %2; }"
            "QWidget#redesignMediaInfo, QDialog, QTabWidget::pane { background: %3; border: none; }"
            "QLineEdit, QTextEdit, QAbstractItemView { background: %4; alternate-background-color: %3; color: %5; border: 1px solid %6; border-radius: 4px; padding: 5px; selection-background-color: %7; selection-color: #161616; }"
            "QLineEdit:focus, QTextEdit:focus { border-color: %7; }"
            "QPushButton { background: %4; border: 1px solid transparent; border-radius: 4px; padding: 6px 16px; min-height: 18px; }"
            "QPushButton:hover { background: %8; }"
            "QPushButton:focus { border-color: %7; }"
            "QPushButton:pressed { background: %7; color: #161616; }"
            "QPushButton#saveMetadataButton { background: %7; color: #161616; }"
            "QPushButton#saveMetadataButton:hover { border-color: %5; }"
            "QWidget:disabled { color: %6; }"
            "QTabBar::tab { background: %4; padding: 10px 16px; border-bottom: 2px solid transparent; }"
            "QTabBar::tab:selected { color: %5; border-bottom-color: %7; }"
            "QTabBar::tab:hover { background: %8; }"
            "QHeaderView::section { background: %8; color: %5; border: none; padding: 6px; }"
            "QTableCornerButton::section { background: %8; border: none; }"
            "QGraphicsView { background: %4; border: none; }"
            "QScrollArea, QScrollArea > QWidget > QWidget { background: %3; border: none; }")
            .arg(dp(14)).arg(foreground, background, field, bright, border, accent, hover));
    };
    applyTheme();
    if (p_intf->p_mi) {
        connect(p_intf->p_mi, &MainCtx::redesignAccentChanged, this, applyTheme);
        connect(p_intf->p_mi, &MainCtx::intfScaleFactorChanged, this, applyTheme);
        connect(p_intf->p_mi->getColorScheme(), &ColorSchemeModel::currentChanged, this, applyTheme);
        connect(qApp->styleHints(), &QStyleHints::colorSchemeChanged, this, applyTheme);
    }
    restoreWidgetPosition( "Mediainfo", QSize( 720 , 720 ) );
}

MediaInfoDialog::~MediaInfoDialog()
{
    saveWidgetPosition( "Mediainfo" );
}

void MediaInfoDialog::showTab( panel i_tab = META_PANEL )
{
    infoTabW->setCurrentIndex( i_tab );
    show();
}

int MediaInfoDialog::currentTab()
{
    return infoTabW->currentIndex();
}

void MediaInfoDialog::saveMeta()
{
    bool success = MP->saveMeta();
    if (success)
        saveMetaButton->hide();
}

void MediaInfoDialog::updateAllTabs( const SharedInputItem& p_item )
{
    if (! p_item)
        return;

    IP->update( p_item.get() );
    MP->update( p_item );
    EMP->update( p_item.get() );

    if( isMainInputInfo && p_item->p_stats ) ISP->update( *p_item->p_stats );
}

void MediaInfoDialog::clearAllTabs()
{
    IP->clear();
    MP->clear();
    EMP->clear();

    if( isMainInputInfo ) ISP->clear();
}

void MediaInfoDialog::close()
{
    hide();

    /* if dialog is closed, revert editing if not saved */
    if( MP->isInEditMode() )
    {
        MP->setEditMode( false );
        updateButtons( 0 );
    }

    if( !isMainInputInfo )
        deleteLater();
}

void MediaInfoDialog::updateButtons( int i_tab )
{
    if( MP->isInEditMode() && i_tab == 0 )
        saveMetaButton->show();
    else
        saveMetaButton->hide();
}

void MediaInfoDialog::updateURI( const QString& uri )
{
    QString location;

    /* If URI points to a local file, show the path instead of the URI */
    char *path = vlc_uri2path( qtu( uri ) );
    if( path != NULL )
    {
        location = qfu( path );
        free( path );
    }
    else
        location = uri;

    uriLine->setText( location );
}
