#include <qpa/qplatformthemeplugin.h>
#include <qpa/qplatformthemefactory_p.h>
#include <QApplication>
#include <QDBusConnection>
#include <QSettings>
#include <QStandardPaths>
#include <QStyle>
#include <QTimer>

class ThemeNotifications final : public QObject {
    Q_OBJECT
public:
    explicit ThemeNotifications(QObject *parent) : QObject(parent) {
        QDBusConnection::sessionBus().connect(QString(), "/KGlobalSettings",
            "org.kde.KGlobalSettings", "notifyChange", this, SLOT(changed(int,int)));

        QTimer::singleShot(0, this, [this] { changed(2, 0); });
    }
public slots:
    void changed(int type, int) {
        if (type != 0 && type != 2) return;
        auto app = qobject_cast<QApplication *>(QCoreApplication::instance());
        if (!app) return;
        QSettings globals(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                          + "/kdeglobals", QSettings::IniFormat);
        const auto key = globals.value("KDE/widgetStyle", "kvantum").toString();

        if (type == 2 && (key == "kvantum" || key == "kvantum-dark")
                && app->style()->objectName().compare(key, Qt::CaseInsensitive) != 0)
            app->setStyle(key);
        QPalette palette = app->palette();
        app->style()->polish(palette);
        app->setPalette(palette);
    }
};

class VladiKdeBridge final : public QPlatformThemePlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QPA.QPlatformThemeFactoryInterface.5.1" FILE "qt5-kde-bridge.json")
public:
    QPlatformTheme *create(const QString &key, const QStringList &) override {
        if (key.compare("kde", Qt::CaseInsensitive) != 0) return nullptr;
        auto native = QPlatformThemeFactory::create("gtk3");
        if (native) new ThemeNotifications(QCoreApplication::instance());
        return native;
    }
};
#include "qt5-kde-bridge.moc"
