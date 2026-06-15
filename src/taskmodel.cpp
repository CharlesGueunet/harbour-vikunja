#include "taskmodel.h"
#include <QDebug>
#include <algorithm>

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

int TaskModel::count() const
{
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
    case CreatedAtRole:
        return item.createdAt;
    case UpdatedAtRole:
        return item.updatedAt;
    case PriorityRole:
        return item.priority;
    case ProjectIdRole:
        return item.projectId;
    case LabelsRole:
        return item.labels;
    case PercentDoneRole:
        return item.percentDone;
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
    roles[CreatedAtRole] = "createdAt";
    roles[UpdatedAtRole] = "updatedAt";
    roles[PriorityRole] = "priority";
    roles[ProjectIdRole] = "projectId";
    roles[LabelsRole] = "labels";
    roles[PercentDoneRole] = "percentDone";
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
            item.createdAt = obj.value(QStringLiteral("created")).toString();
            item.updatedAt = obj.value(QStringLiteral("updated")).toString();
            item.priority = obj.value(QStringLiteral("priority")).toInt();
            item.projectId = obj.value(QStringLiteral("project_id")).toInt();
            
            double percent = obj.value(QStringLiteral("percent_done")).toDouble();
            if (percent > 0.0) {
                qWarning() << "[VikunjaApi] Task title:" << title 
                           << "raw percent_done type:" << obj.value(QStringLiteral("percent_done")).type()
                           << "value:" << obj.value(QStringLiteral("percent_done"))
                           << "toDouble:" << percent;
            }
            if (percent > 0.0 && percent <= 1.0) {
                percent *= 100.0;
            }
            item.percentDone = percent;

            QVariantList labelList;
            QJsonArray labelsArr = obj.value(QStringLiteral("labels")).toArray();
            for (const QJsonValue &labelVal : labelsArr) {
                if (labelVal.isObject()) {
                    QJsonObject labelObj = labelVal.toObject();
                    QVariantMap labelMap;
                    labelMap[QStringLiteral("id")] = labelObj.value(QStringLiteral("id")).toInt();
                    labelMap[QStringLiteral("title")] = labelObj.value(QStringLiteral("title")).toString();
                    QString hexColor = labelObj.value(QStringLiteral("hex_color")).toString();
                    if (!hexColor.isEmpty() && !hexColor.startsWith('#')) {
                        hexColor = '#' + hexColor;
                    }
                    labelMap[QStringLiteral("hexColor")] = hexColor;
                    labelList.append(labelMap);
                }
            }
            item.labels = labelList;

            m_tasks.append(item);
            loadedCount++;
        }
    }

    // Sort tasks. Pinned tasks (priority >= 2: Medium, High, Urgent, DO NOW) go to the top.
    // Within those groups, tasks are sorted by last updated date descending.
    std::sort(m_tasks.begin(), m_tasks.end(), [](const TaskItem &a, const TaskItem &b) {
        bool aPinned = (a.priority >= 2);
        bool bPinned = (b.priority >= 2);
        if (aPinned != bPinned) {
            return aPinned; // Pinned tasks come first
        }
        QString aTime = a.updatedAt.isEmpty() ? a.createdAt : a.updatedAt;
        QString bTime = b.updatedAt.isEmpty() ? b.createdAt : b.updatedAt;
        return aTime > bTime;
    });

    endResetModel();
    emit countChanged();
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
            emit countChanged();
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
        map[QStringLiteral("percentDone")] = item.percentDone;
        map[QStringLiteral("labels")] = item.labels;
        map[QStringLiteral("priority")] = item.priority;
    }
    return map;
}

void TaskModel::updateTaskFromJsonObject(const QJsonObject &obj)
{
    int taskId = obj.value(QStringLiteral("id")).toInt();
    for (int i = 0; i < m_tasks.count(); ++i) {
        if (m_tasks.at(i).id == taskId) {
            m_tasks[i].title = obj.value(QStringLiteral("title")).toString();
            m_tasks[i].description = obj.value(QStringLiteral("description")).toString();
            m_tasks[i].done = obj.value(QStringLiteral("done")).toBool();
            m_tasks[i].dueDate = obj.value(QStringLiteral("due_date")).toString();
            m_tasks[i].updatedAt = obj.value(QStringLiteral("updated")).toString();
            m_tasks[i].priority = obj.value(QStringLiteral("priority")).toInt();
            
            double percent = obj.value(QStringLiteral("percent_done")).toDouble();
            if (percent > 0.0 && percent <= 1.0) {
                percent *= 100.0;
            }
            m_tasks[i].percentDone = percent;

            QVariantList labelList;
            QJsonArray labelsArr = obj.value(QStringLiteral("labels")).toArray();
            for (const QJsonValue &labelVal : labelsArr) {
                if (labelVal.isObject()) {
                    QJsonObject labelObj = labelVal.toObject();
                    QVariantMap labelMap;
                    labelMap[QStringLiteral("id")] = labelObj.value(QStringLiteral("id")).toInt();
                    labelMap[QStringLiteral("title")] = labelObj.value(QStringLiteral("title")).toString();
                    QString hexColor = labelObj.value(QStringLiteral("hex_color")).toString();
                    if (!hexColor.isEmpty() && !hexColor.startsWith('#')) {
                        hexColor = '#' + hexColor;
                    }
                    labelMap[QStringLiteral("hexColor")] = hexColor;
                    labelList.append(labelMap);
                }
            }
            m_tasks[i].labels = labelList;

            QModelIndex index = createIndex(i, 0);
            emit dataChanged(index, index, QVector<int>() << TitleRole << DescriptionRole << DoneRole << DueDateRole << LabelsRole << PercentDoneRole << UpdatedAtRole << PriorityRole);
            break;
        }
    }
}
