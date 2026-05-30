#ifndef TASKMODEL_H
#define TASKMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QVector>

#include <QDateTime>
#include <QVariantList>

struct TaskItem
{
    int id;
    QString title;
    QString description;
    bool done;
    QString dueDate;
    int projectId;
    QVariantList labels;
};

class TaskModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum TaskRoles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        DescriptionRole,
        DoneRole,
        DueDateRole,
        ProjectIdRole,
        LabelsRole
    };

    explicit TaskModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void loadTasks(const QJsonArray &jsonArray);
    Q_INVOKABLE void updateTaskStatus(int taskId, bool done);
    Q_INVOKABLE void removeTask(int taskId);
    Q_INVOKABLE QVariantMap getTask(int index) const;

private:
    QVector<TaskItem> m_tasks;
};

#endif // TASKMODEL_H
