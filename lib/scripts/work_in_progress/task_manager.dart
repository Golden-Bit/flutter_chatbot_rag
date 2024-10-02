import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TaskBoard(),
    );
  }
}

class TaskBoard extends StatefulWidget {
  @override
  _TaskBoardState createState() => _TaskBoardState();
}

class _TaskBoardState extends State<TaskBoard> {
  List<TaskColumnData> taskColumns = [
    TaskColumnData('To Do', []),
    TaskColumnData('In Progress', []),
    TaskColumnData('Done', []),
  ];

  List<Label> labels = [];
  List<Member> members = [
    Member(name: 'John Doe'),
    Member(name: 'Jane Smith'),
    Member(name: 'Alice Johnson'),
    Member(name: 'Bob Brown'),
    Member(name: 'Charlie White'),
    Member(name: 'Daisy Green'),
    Member(name: 'Eve Black'),
    Member(name: 'Frank Yellow'),
    Member(name: 'Grace Blue'),
    Member(name: 'Hank Red'),
  ];

  String _customizeMarkdownCheckboxes(String markdown) {
    return markdown.replaceAllMapped(
      RegExp(r'- \[( |x)\] '),
      (match) {
        final isChecked = match.group(1) == 'x';
        return '\n ${isChecked ? '☑️' : '⬜'} ';
      },
    );
  }

  void _addTask(Task task, String list) {
    setState(() {
      for (var column in taskColumns) {
        if (column.title == list) {
          column.tasks.add(task);
          break;
        }
      }
    });
  }

  void _removeTask(Task task) {
    setState(() {
      for (var column in taskColumns) {
        column.tasks.remove(task);
      }
    });
  }

  void _duplicateTask(Task task, String list) {
    final duplicatedTask = Task(
      title: '${task.title} (Copy)',
      description: task.description,
      list: list,
      markerColor: task.markerColor,
      members: task.members.map((member) => Member(name: member.name)).toList(),
      labels: task.labels.map((label) => Label(
        name: label.name,
        color: label.color,
      )).toList(),
      dueDate: task.dueDate,
      estimatedTime: task.estimatedTime,
      attachments: task.attachments,
    );
    _addTask(duplicatedTask, list);
  }

  void _removeTaskColumn(String columnTitle) {
    setState(() {
      taskColumns.removeWhere((column) => column.title == columnTitle);
    });
  }

  void _duplicateTaskColumn(TaskColumnData column) {
    final duplicatedColumn = TaskColumnData(
      '${column.title} (Copy)',
      column.tasks.map((task) => Task(
        title: '${task.title} (Copy)',
        description: task.description,
        list: '${column.title} (Copy)',
        markerColor: task.markerColor,
        members: task.members.map((member) => Member(name: member.name)).toList(),
        labels: task.labels.map((label) => Label(
          name: label.name,
          color: label.color,
        )).toList(),
        dueDate: task.dueDate,
        estimatedTime: task.estimatedTime,
        attachments: task.attachments,
      )).toList(),
    );
    setState(() {
      taskColumns.add(duplicatedColumn);
    });
  }

  void _moveTask(Task task, String newList, int newIndex) {
    setState(() {
      for (var column in taskColumns) {
        if (column.title == task.list) {
          column.tasks.remove(task);
          break;
        }
      }

      task.list = newList;

      for (var column in taskColumns) {
        if (column.title == newList) {
          if (newIndex > column.tasks.length) newIndex = column.tasks.length;
          column.tasks.insert(newIndex, task);
          break;
        }
      }
    });
  }

  void _showAddTaskColumnDialog(BuildContext context) {
    final _titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Task List'),
          content: TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (taskColumns.any((column) => column.title == _titleController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('A list with this name already exists'),
                      ),
                    );
                  } else {
                    taskColumns.add(TaskColumnData(_titleController.text, []));
                  }
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'Create',
                style: TextStyle(color: Colors.grey[800]),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddTaskPage(BuildContext context, String list, {Task? task}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskPage(
          list: list,
          onAddTask: (newTask) {
            if (task != null) {
              _updateTask(task, newTask);
            } else {
              _addTask(newTask, list);
            }
          },
          labels: labels,
          members: members,
          onAddLabel: (label) {
            setState(() {
              labels.add(label);
            });
          },
          onAddMember: (member) {
            setState(() {
              members.add(member);
            });
          },
          existingTask: task,
        ),
      ),
    );
  }

  void _updateTask(Task oldTask, Task updatedTask) {
    setState(() {
      for (var column in taskColumns) {
        if (column.title == oldTask.list) {
          int index = column.tasks.indexOf(oldTask);
          if (index != -1) {
            column.tasks[index] = updatedTask;
          }
          break;
        }
      }
    });
  }

  void _showTaskDetails(Task task) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: EdgeInsets.all(0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: task.markerColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8.0),
                        topRight: Radius.circular(8.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _removeTask(task);
                            Navigator.of(context).pop();
                          },
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        if (task.description.isNotEmpty)
                          _buildTaskField(
                            title: "Description",
                            content: MarkdownBody(
                              data: _customizeMarkdownCheckboxes(task.description),
                            ),
                          ),
                        if (task.members.isNotEmpty)
                          _buildTaskField(
                            title: "Members",
                            content: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: task.members.map((member) {
                                  return Chip(
                                    label: Text(member.name, style: TextStyle(color: Colors.black87)),
                                    backgroundColor: Colors.grey[200],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        if (task.labels.isNotEmpty)
                          _buildTaskField(
                            title: "Labels",
                            content: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: task.labels.map((label) {
                                  return Chip(
                                    label: Text(label.name, style: TextStyle(color: Colors.black87)),
                                    backgroundColor: label.color,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        if (task.dueDate.isNotEmpty || task.estimatedTime.isNotEmpty)
                          _buildTaskField(
                            title: "Due Date & Estimated Time",
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.dueDate.isNotEmpty)
                                  Text('Due Date: ${task.dueDate}'),
                                if (task.estimatedTime.isNotEmpty)
                                  Text('Estimated Time: ${task.estimatedTime}'),
                              ],
                            ),
                          ),
                        if (task.attachments.isNotEmpty)
                          _buildTaskField(
                            title: "Attachments",
                            content: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: task.attachments.split(', ').map((attachment) {
                                  return Chip(
                                    label: Text(attachment),
                                    backgroundColor: Colors.grey[200],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildTaskField({required String title, required Widget content}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Board'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.add, color: Colors.grey[800]),
            label: Text(
              'Crea Task List',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onPressed: () => _showAddTaskColumnDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: taskColumns.map((column) {
            return Container(
              width: 300,
              child: TaskColumn(
                title: column.title,
                tasks: column.tasks,
                onMoveTask: _moveTask,
                onAddTask: () => _navigateToAddTaskPage(context, column.title),
                onRemoveTask: _removeTask,
                onTaskTap: _showTaskDetails,
                onDuplicateTask: _duplicateTask,
                onRemoveColumn: _removeTaskColumn,
                onDuplicateColumn: _duplicateTaskColumn,
                onEditTask: (task) => _navigateToAddTaskPage(context, column.title, task: task),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class TaskColumnData {
  String title;
  List<Task> tasks;

  TaskColumnData(this.title, this.tasks);
}

class TaskColumn extends StatefulWidget {
  final String title;
  final List<Task> tasks;
  final Function(Task, String, int) onMoveTask;
  final VoidCallback onAddTask;
  final Function(Task) onRemoveTask;
  final Function(Task) onTaskTap;
  final Function(Task, String) onDuplicateTask;
  final Function(String) onRemoveColumn;
  final Function(TaskColumnData) onDuplicateColumn;
  final Function(Task) onEditTask;

  const TaskColumn({
    required this.title,
    required this.tasks,
    required this.onMoveTask,
    required this.onAddTask,
    required this.onRemoveTask,
    required this.onTaskTap,
    required this.onDuplicateTask,
    required this.onRemoveColumn,
    required this.onDuplicateColumn,
    required this.onEditTask,
  });

  @override
  _TaskColumnState createState() => _TaskColumnState();
}

class _TaskColumnState extends State<TaskColumn> {
  late List<Task> tasks;

  @override
  void initState() {
    super.initState();
    tasks = widget.tasks;
  }

  @override
  void didUpdateWidget(TaskColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      tasks = widget.tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    widget.onRemoveColumn(widget.title);
                  } else if (value == 'duplicate') {
                    widget.onDuplicateColumn(TaskColumnData(widget.title, tasks));
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Elimina'),
                    ),
                    PopupMenuItem<String>(
                      value: 'duplicate',
                      child: Text('Duplica'),
                    ),
                  ];
                },
              ),
            ],
          ),
          Expanded(
            child: DragTarget<Task>(
              onWillAccept: (task) => true,
              onAcceptWithDetails: (details) {
                setState(() {
                  int newIndex = (details.offset.dy ~/ 80)
                      .clamp(0, tasks.length);
                  widget.onMoveTask(details.data, widget.title, newIndex);
                });
              },
              builder: (context, candidateData, rejectedData) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return Draggable<Task>(
                      key: ValueKey(tasks[index].id),
                      data: tasks[index],
                      feedback: Material(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          width: 300,
                          child: TaskCard(
                            key: ValueKey(tasks[index].id),
                            task: tasks[index],
                            onMoveTask: widget.onMoveTask,
                            onRemoveTask: widget.onRemoveTask,
                            onTaskTap: widget.onTaskTap,
                            onDuplicateTask: widget.onDuplicateTask,
                            onEditTask: widget.onEditTask,
                          ),
                        ),
                        elevation: 6.0,
                        shadowColor: Colors.black.withOpacity(0.5),
                      ),
                      childWhenDragging: Container(),
                      child: TaskCard(
                        key: ValueKey(tasks[index].id),
                        task: tasks[index],
                        onMoveTask: widget.onMoveTask,
                        onRemoveTask: widget.onRemoveTask,
                        onTaskTap: widget.onTaskTap,
                        onDuplicateTask: widget.onDuplicateTask,
                        onEditTask: widget.onEditTask,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add, color: Colors.grey[800]),
              label: Text(
                'Crea Task',
                style: TextStyle(color: Colors.grey[800]),
              ),
              onPressed: widget.onAddTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatefulWidget {
  final Task task;
  final Function(Task, String, int) onMoveTask;
  final Function(Task) onRemoveTask;
  final Function(Task) onTaskTap;
  final Function(Task, String) onDuplicateTask;
  final Function(Task) onEditTask;

  const TaskCard({
    required this.task,
    required this.onMoveTask,
    required this.onRemoveTask,
    required this.onTaskTap,
    required this.onDuplicateTask,
    required this.onEditTask,
    Key? key,
  }) : super(key: key);

  @override
  _TaskCardState createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  String _customizeMarkdownCheckboxes(String markdown) {
    return markdown.replaceAllMapped(
      RegExp(r'- \[( |x)\] '),
      (match) {
        final isChecked = match.group(1) == 'x';
        return '\n ${isChecked ? '☑️' : '⬜'} ';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTaskTap(widget.task),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 2,
        child: Column(
          children: [
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.task.markerColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        widget.onRemoveTask(widget.task);
                      } else if (value == 'duplicate') {
                        widget.onDuplicateTask(widget.task, widget.task.list);
                      } else if (value == 'edit') {
                        widget.onEditTask(widget.task);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Elimina'),
                        ),
                        PopupMenuItem<String>(
                          value: 'duplicate',
                          child: Text('Duplica'),
                        ),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Modifica'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      widget.task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _isExpanded ? 24 : 18,
                      ),
                    ),
                    subtitle: _isExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.task.description.isNotEmpty)
                                _buildTaskField(
                                  title: "Description",
                                  content: MarkdownBody(
                                    data: _customizeMarkdownCheckboxes(widget.task.description),
                                  ),
                                ),
                              if (widget.task.members.isNotEmpty)
                                _buildTaskField(
                                  title: "Members",
                                  content: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: 4.0,
                                      children: widget.task.members.map((member) {
                                        return Chip(
                                          label: Text(member.name, style: TextStyle(color: Colors.black87)),
                                          backgroundColor: Colors.grey[200],
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              if (widget.task.labels.isNotEmpty)
                                _buildTaskField(
                                  title: "Labels",
                                  content: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: 4.0,
                                      children: widget.task.labels.map((label) {
                                        return Chip(
                                          label: Text(label.name, style: TextStyle(color: Colors.black87)),
                                          backgroundColor: label.color,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              if (widget.task.dueDate.isNotEmpty || widget.task.estimatedTime.isNotEmpty)
                                _buildTaskField(
                                  title: "Due Date & Estimated Time",
                                  content: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (widget.task.dueDate.isNotEmpty)
                                        Text('Due Date: ${widget.task.dueDate}'),
                                      if (widget.task.estimatedTime.isNotEmpty)
                                        Text('Estimated Time: ${widget.task.estimatedTime}'),
                                    ],
                                  ),
                                ),
                              if (widget.task.attachments.isNotEmpty)
                                _buildTaskField(
                                  title: "Attachments",
                                  content: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: 4.0,
                                      children: widget.task.attachments.split(', ').map((attachment) {
                                        return Chip(
                                          label: Text(attachment),
                                          backgroundColor: Colors.grey[200],
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[800],
                        ),
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskField({required String title, required Widget content}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}

class Task {
  final String id;
  String title;
  String description;
  String list;
  Color markerColor;
  List<Member> members;
  List<Label> labels;
  String dueDate;
  String estimatedTime;
  String attachments;

  Task({
    String? id,
    required this.title,
    required this.description,
    required this.list,
    required this.markerColor,
    this.members = const [],
    this.labels = const [],
    this.dueDate = '',
    this.estimatedTime = '',
    this.attachments = '',
  }) : id = id ?? Uuid().v4(); // Genera un ID univoco se non viene fornito.
}

class Member {
  String name;

  Member({required this.name});
}

class Label {
  String name;
  Color color;

  Label({required this.name, required this.color});
}

class AddTaskPage extends StatefulWidget {
  final String list;
  final Function(Task) onAddTask;
  final List<Label> labels;
  final List<Member> members;
  final Function(Label) onAddLabel;
  final Function(Member) onAddMember;
  final Task? existingTask;

  AddTaskPage({
    required this.list,
    required this.onAddTask,
    required this.labels,
    required this.members,
    required this.onAddLabel,
    required this.onAddMember,
    this.existingTask,
  });

  @override
  _AddTaskPageState createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  late TextEditingController _estimatedTimeController;
  List<String> _attachments = [];
  Color _selectedColor = Colors.transparent;
  List<Label> _selectedLabels = [];
  List<Member> _selectedMembers = [];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.existingTask?.title ?? '');
    _descriptionController = TextEditingController(text: widget.existingTask?.description ?? '');
    _dueDateController = TextEditingController(text: widget.existingTask?.dueDate ?? '');
    _estimatedTimeController = TextEditingController(text: widget.existingTask?.estimatedTime ?? '');
    _attachments = widget.existingTask?.attachments.split(', ') ?? [];
    _selectedColor = widget.existingTask?.markerColor ?? Colors.transparent;
    _selectedLabels = widget.existingTask?.labels ?? [];
    _selectedMembers = widget.existingTask?.members ?? [];
  }

  Future<void> _selectDueDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _dueDateController.text = DateFormat('yyyy-MM-dd HH:mm').format(
              DateTime(picked.year, picked.month, picked.day, time.hour,
                  time.minute));
        });
      }
    }
  }

  Future<void> _selectAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);

      if (result != null) {
        setState(() {
          _attachments.addAll(result.files.map((file) => file.name).toList());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
        ),
      );
    }
  }

  void _addLabel() {
    final _labelNameController = TextEditingController();
    Color _labelColor = Colors.transparent;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Create New Label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _labelNameController,
                    decoration: InputDecoration(labelText: 'Label Name'),
                  ),
                  Row(
                    children: [
                      Text('Select Color:'),
                      SizedBox(width: 10),
                      ...Colors.primaries.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _labelColor = color;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 5.0),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: _labelColor == color
                                  ? Border.all(width: 2.0, color: Colors.black)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    final label = Label(
                      name: _labelNameController.text,
                      color: _labelColor,
                    );
                    widget.onAddLabel(label);
                    Navigator.of(context).pop();
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addMember() {
    final _memberNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New Member'),
          content: TextField(
            controller: _memberNameController,
            decoration: InputDecoration(labelText: 'Member Name'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final member = Member(name: _memberNameController.text);
                widget.onAddMember(member);
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showMemberMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(Offset.zero, ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: widget.members.map((Member member) {
        return PopupMenuItem<Member>(
          value: member,
          child: ListTile(
            title: Text(member.name),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedMembers.add(value);
        });
      }
    });
  }

  void _showLabelMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(Offset.zero, ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: widget.labels.map((Label label) {
        return PopupMenuItem<Label>(
          value: label,
          child: ListTile(
            title: Text(label.name),
            leading: CircleAvatar(
              backgroundColor: label.color,
            ),
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedLabels.add(value);
        });
      }
    });
  }

  Widget _buildInputField({required String title, required Widget content}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(widget.existingTask != null ? 'Edit Task' : 'Add Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputField(
                title: "Title & Description",
                content: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Title'),
                    ),
                    SizedBox(height: 8.0),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: "Members",
                content: Column(
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.start,
                      children: _selectedMembers.map((member) {
                        return Chip(
                          label: Text(
                            member.name,
                            style: TextStyle(color: Colors.black87),
                          ),
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          onDeleted: () {
                            setState(() {
                              _selectedMembers.remove(member);
                            });
                          },
                          deleteIconColor: Colors.black,
                        );
                      }).toList(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.black),
                          onPressed: _addMember,
                        ),
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(Icons.person_add, color: Colors.black),
                            onPressed: () => _showMemberMenu(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInputField(
                title: "Due Date & Estimated Time",
                content: Column(
                  children: [
                    TextField(
                      controller: _dueDateController,
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.calendar_today),
                          onPressed: () => _selectDueDate(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    TextField(
                      controller: _estimatedTimeController,
                      decoration: InputDecoration(labelText: 'Estimated Time'),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Etichette',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: _selectedLabels.map((label) {
                        return Chip(
                          label: Text(
                            label.name,
                            style: TextStyle(color: Colors.black87),
                          ),
                          backgroundColor: label.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          onDeleted: () {
                            setState(() {
                              _selectedLabels.remove(label);
                            });
                          },
                          deleteIconColor: Colors.black,
                        );
                      }).toList(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.black),
                          onPressed: _addLabel,
                        ),
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(Icons.label, color: Colors.black),
                            onPressed: () => _showLabelMenu(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.0),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: _attachments.map((attachment) {
                        return Chip(
                          label: Text(attachment),
                          backgroundColor: Colors.grey[200],
                          onDeleted: () {
                            setState(() {
                              _attachments.remove(attachment);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file),
                          onPressed: () => _selectAttachment(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Text('Select Marker Color:'),
                  SizedBox(width: 10),
                  ...Colors.primaries.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 5.0),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _selectedColor == color
                              ? Border.all(width: 2.0, color: Colors.black)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final task = Task(
                    title: _titleController.text,
                    description: _descriptionController.text,
                    list: widget.list,
                    markerColor: _selectedColor,
                    members: _selectedMembers,
                    labels: _selectedLabels,
                    dueDate: _dueDateController.text,
                    estimatedTime: _estimatedTimeController.text,
                    attachments: _attachments.join(', '),
                  );
                  widget.onAddTask(task);
                  Navigator.of(context).pop();
                },
                child: Text(
                  widget.existingTask != null ? 'Save Task' : 'Add Task',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  minimumSize: Size(double.infinity, 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
