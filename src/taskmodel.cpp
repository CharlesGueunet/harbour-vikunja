#include "taskmodel.h"
#include <QDebug>

TaskModel::TaskModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TaskModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_tasks.count();
}

QVariant TaskModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tasks.count()) {
        return QVariant();
    }

    const TaskItem &item = m_tasks.at(index.row());

    switch (role) {
    case IdRole:
        return item.id;
    case TitleRole:
        return item.title;
    case DescriptionRole:
        return item.description;
    case DoneRole:
        return item.done;
    case DueDateRole:
        return item.dueDate;
    case ProjectIdRole:
        return item.projectId;
    case LabelsRole:
        return item.labels;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> TaskModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[TitleRole] = "title";
    roles[DescriptionRole] = "description";
    roles[DoneRole] = "done";
    roles[DueDateRole] = "dueDate";
    roles[ProjectIdRole] = "projectId";
    roles[LabelsRole] = "labels";
    return roles;
}

void TaskModel::loadTasks(const QJsonArray &jsonArray)
{
    beginResetModel();
    m_tasks.clear();

    int loadedCount = 0;

    for (const QJsonValue &value : jsonArray) {
        if (value.isObject()) {
            QJsonObject obj = value.toObject();
            QString title = obj.value(QStringLiteral("title")).toString();
            bool done = obj.value(QStringLiteral("done")).toBool();

            TaskItem item;
            item.id = obj.value(QStringLiteral("id")).toInt();
            item.title = title;
            item.description = obj.value(QStringLiteral("description")).toString();
            item.done = done;
            item.dueDate = obj.value(QStringLiteral("due_date")).toString();
            item.projectId = obj.value(QStringLiteral("project_id")).toInt();

            QVariantList labelList;
            QJsonArray labelsArr = obj.value(QStringLiteral("labels")).toArray();
            for (const QJsonValue &labelVal : labelsArr) {
                if (labelVal.isObject()) {
                    QJsonObject labelObj = labelVal.toObject();
                    QVariantMap labelMap;
                    labelMap[QStringLiteral("title")] = labelObj.value(QStringLiteral("title")).toString();
                    labelMap[QStringLiteral("hexColor")] = labelObj.value(QStringLiteral("hex_color")).toString();
                    labelList.append(labelMap);
                }
            }
            item.labels = labelList;

            m_tasks.append(item);
            loadedCount++;
        }
    }
    endResetModel();
}

void TaskModel::updateTaskStatus(int taskId, bool done)
{
    for (int i = 0; i < m_tasks.count(); ++i) {
        if (m_tasks.at(i).id == taskId) {
            m_tasks[i].done = done;
            QModelIndex index = createIndex(i, 0);
            emit dataChanged(index, index, QVector<int>() << DoneRole);
            break;
        }
    }
}

void TaskModel::removeTask(int taskId)
{
    for (int i = 0; i < m_tasks.count(); ++i) {
        if (m_tasks.at(i).id == taskId) {
            beginRemoveRows(QModelIndex(), i, i);
            m_tasks.removeAt(i);
            endRemoveRows();
            break;
        }
    }
}

QVariantMap TaskModel::getTask(int index) const
{
    QVariantMap map;
    if (index >= 0 && index < m_tasks.count()) {
        const TaskItem &item = m_tasks.at(index);
        map[QStringLiteral("id")] = item.id;
        map[QStringLiteral("title")] = item.title;
        map[QStringLiteral("description")] = item.description;
        map[QStringLiteral("done")] = item.done;
        map[QStringLiteral("dueDate")] = item.dueDate;
        map[QStringLiteral("projectId")] = item.projectId;
    }
    return map;
}
