# ToDo List in Bash

A linux CLI to-do list written in Bash. Tasks are stored in a local CSV file amking them persist across different sessions.

## Requirements

- Bash 4.0 or later
- Standard Unix tools: `grep`, `cut`, `sed`, `mktemp`
  (Most likely already installed)

## Setup

Clone or download the script, then make it executable:

```bash
chmod +x todo.sh
```

Run it in terminal:

```bash
./todo.sh
```

`tasks.csv` is created automatically in the same directory, if it does not already exist.

## Menu

```
To-Do List   3 total  2 pending  1 done
------------------------------------------
1) Add Task
2) View Tasks
3) Edit Task
4) Delete Task
5) Mark as Done
6) Search
7) Stats
0) Quit
------------------------------------------
Choice:
```

The header line shows an updated count of total, pending, and done tasks every time the menu is loaded.

## Usage

### Adding Tasks

Enter a title (required), a due date, and optional notes. Pressing Enter on the date field defaults to the current date.

```
Title: Submit the Project
Due date [YYYY-MM-DD, Enter = today (2026-5-13)]:
Notes (optional): code and readme
Task #1 added.
```

Dates must follow the format `YYYY-MM-DD`. The script will reject anything else and ask again until a valid date is entered.

### Viewing Tasks

Prints all tasks as a table. Pending tasks are shown in yellow, done tasks in green.

```
ID    Title                         Status      Date          Notes
--------------------------------------------------------------------
1     Buy groceries                 Pending     2025-05-12    milk, eggs, bread
2     Submit assignment             Done        2025-05-10
```

### Editing Tasks

Shows the task list, then asks for the ID of the task to edit. Each field shows its current value in brackets. Press Enter to keep it unchanged.

```
Task ID: 1
Leave blank to keep the current value.
New title [Submit the Project]: Edit the project 
New date [2026-05-14] (YYYY-MM-DD, Enter = keep):
New notes [milk, eggs, bread]: edit readme
Task #1 updated.
```

### 4. Delete Task

Shows the task list, asks for an ID, then asks for confirmation before removing the task permanently.

```
Task ID: 1
Delete task #1? [y/N]: y
Task #1 deleted.
```

Entering anything other than `y` or `Y` cancels the deletion.

### Marking as Done

Shows the task list and asks for the ID of the task to mark complete. The status changes from `Pending` to `Done`. Running this on a task that is already done does nothing.

```
Task ID: 2
Task #2 marked as done.
```

### Searching

Searches across all fields (title, status, date, notes) case-insensitively and prints any matching rows.

```
Search keyword: assignment
2     Submit assignment             Done        2025-05-17
```

### 7. Stats

Shows a count breakdown and an ASCII progress bar based on how many tasks are done.

```
Total   : 4
Done    : 1
Pending : 3
Progress [#####---------------] 25%
```

## Storage

All tasks are saved to `tasks.csv` in the same directory as the script. The format is as shown:

```
ID,Title,Status,Date,Notes
1,Buy groceries,Pending,2025-05-12,milk and eggs
2,Submit assignment,Done,2025-05-10,
```

You can open this file in any spreadsheet application or edit it directly, but make sure the header row stays intact and no field contains a raw comma (the script replaces commas in user input with semicolons automatically).

## Notes

- IDs are assigned automatically and never reused within a session.
- Deleting a task does not renumber the remaining IDs.
- The script does not support multi-word search with quotes; just type the keyword directly.
