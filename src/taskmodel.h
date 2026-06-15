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
    QString createdAt;  // ISO 8601, used for sorting
    QString updatedAt;  // ISO 8601, used for sorting
    int priority;
    int projectId;
    QVariantList labels;
    double percentDone;
};

class TaskModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum TaskRoles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        DescriptionRole,
        DoneRole,
        DueDateRole,
        CreatedAtRole,
        ProjectIdRole,
        LabelsRole,
        PercentDoneRole,
        UpdatedAtRole,
        PriorityRole
    };

    explicit TaskModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    Q_INVOKABLE void loadTasks(const QJsonArray &jsonArray);
    Q_INVOKABLE void updateTaskStatus(int taskId, bool done);
    Q_INVOKABLE void updateTaskFromJsonObject(const QJsonObject &obj);
    Q_INVOKABLE void removeTask(int taskId);
    Q_INVOKABLE QVariantMap getTask(int index) const;

private:
    QVector<TaskItem> m_tasks;

signals:
    void countChanged();
};

#endif // TASKMODEL_H
